import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/questions/question_registry.dart';
import 'package:timokid/features/qa/qa_service.dart';
import 'package:timokid/features/review_book/review_book_service.dart';

void main() {
  late AppDatabase db;
  late QaService service;
  late String childId;

  setUp(() async {
    // 19/11/2026 20:00 giờ VN (DateTime vùng UTC, trường giờ là giờ VN).
    db = AppDatabase(
      executor: NativeDatabase.memory(),
      clock: FakeClock(DateTime.utc(2026, 11, 19, 20, 0)),
    );
    addTearDown(db.close);
    service = QaService(db: db);
    childId = await service.ensureChildId();
  });

  Future<void> recordAttempt({
    String formId = 'logic.balance',
    String strand = Strand.logic,
    bool correctFirstTry = true,
  }) async {
    await db.attemptsDao.recordAttempt(
      childId: childId,
      formId: formId,
      strand: strand,
      level: 1,
      rung: 1,
      answerType: AnswerType.choice,
      correctFirstTry: correctFirstTry,
      attemptsCount: 1,
      durationMs: 1000,
    );
  }

  group('nhảy ngày', () {
    test('advanceOneDay đổi today() sang ngày mai, resetDay về lại', () {
      expect(service.today, '2026-11-19');
      expect(service.dayOffset, Duration.zero);

      service.advanceOneDay();
      expect(service.today, '2026-11-20');
      expect(service.dayOffset, const Duration(days: 1));

      service.advanceOneDay();
      expect(service.today, '2026-11-21');

      service.resetDay();
      expect(service.today, '2026-11-19');
      expect(service.dayOffset, Duration.zero);
    });

    test('nhảy ngày đổi cả đề ngày (T1-08 đọc cùng Clock)', () async {
      final before = await db.dailySetsDao.getDailySet(childId, '2026-11-19');
      expect(before, isNull);

      service.advanceOneDay();
      final setId = await db.dailySetsDao.createDailySet(
        childId: childId,
        date: service.today,
        questions: const [],
      );
      expect(setId.isNotEmpty, isTrue);
      final set = await db.dailySetsDao.getDailySet(childId, '2026-11-20');
      expect(set, isNotNull);
    });
  });

  group('đặt bậc từng mảng', () {
    test('setRung đổi đúng mảng, các mảng khác giữ nguyên', () async {
      await service.setRung(childId: childId, strand: Strand.logic, rung: 4);
      final rungs = await service.rungs(childId: childId);
      expect(rungs[Strand.logic], 4);
      expect(rungs[Strand.arith], 1);
      expect(rungs[Strand.number], 1);
      expect(rungs[Strand.geo], 1);
      expect(rungs[Strand.comb], 1);
    });

    test('setRung ngoài 1–6 thì ném ArgumentError', () async {
      expect(
        () => service.setRung(childId: childId, strand: Strand.logic, rung: 0),
        throwsArgumentError,
      );
      expect(
        () => service.setRung(childId: childId, strand: Strand.logic, rung: 7),
        throwsArgumentError,
      );
    });
  });

  group('xem sổ ôn tập và lượt trả lời', () {
    test('reviewEntries hiện mục đã vào sổ', () async {
      final reviewBook = ReviewBookService(
        reviewQueueDao: db.reviewQueueDao,
        clock: db.clock,
      );
      await reviewBook.recordAnswer(
        childId: childId,
        formId: 'logic.balance',
        rung: 2,
        correctFirstTry: false,
      );

      final entries = await service.reviewEntries(childId: childId);
      expect(entries, hasLength(1));
      expect(entries.first.formId, 'logic.balance');
      expect(entries.first.rung, 2);
      expect(entries.first.correctStreak, 0);
    });

    test('recentAttempts mới nhất trước, giới hạn 20', () async {
      for (var i = 0; i < 21; i++) {
        await recordAttempt(formId: 'logic.balance');
      }
      final attempts = await service.recentAttempts(childId: childId);
      expect(attempts, hasLength(20));
      // Mới nhất trước: lượt ghi sau cùng có createdAt lớn nhất hoặc bằng.
      expect(
        attempts.first.createdAt.isAfter(attempts.last.createdAt) ||
            attempts.first.createdAt.isAtSameMomentAs(attempts.last.createdAt),
        isTrue,
      );
    });
  });

  group('xem thử dạng bài', () {
    test('previewQuestion sinh đúng dạng và mức', () {
      final question = service.previewQuestion(
        formId: 'logic.balance',
        level: 1,
        seed: 42,
      );
      expect(question.formId, 'logic.balance');
      expect(question.difficulty, 1);
      expect(question.questionVi.isNotEmpty, isTrue);
    });

    test('previewQuestion không ghi gì vào database', () async {
      service.previewQuestion(formId: 'logic.balance', level: 1, seed: 7);
      service.previewQuestion(formId: 'arith.quick', level: 2, seed: 8);
      expect(await service.recentAttempts(childId: childId), isEmpty);
    });

    test('previewQuestion ném ArgumentError khi sai dạng/mức', () {
      expect(
        () => service.previewQuestion(formId: 'khong.co.dang', level: 1),
        throwsArgumentError,
      );
      // Tìm một dạng không hỗ trợ đủ 3 mức rồi xin mức nó không có.
      final partial = allQuestionGenerators.firstWhere(
        (g) => g.supportedLevels.length < 3,
      );
      final missing = [
        1,
        2,
        3,
      ].firstWhere((level) => !partial.supportedLevels.contains(level));
      expect(
        () => service.previewQuestion(formId: partial.formId, level: missing),
        throwsArgumentError,
      );
    });
  });

  group('xóa dữ liệu', () {
    test('clearAllData về trạng thái mới cài', () async {
      // Gieo dữ liệu: bậc 4, 2 lượt trả lời, 1 mục sổ, xu, đề ngày.
      await service.setRung(childId: childId, strand: Strand.logic, rung: 4);
      await recordAttempt(correctFirstTry: false);
      await recordAttempt();
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.xu,
        amount: 50,
        reason: 'test',
      );
      await db.dailySetsDao.createDailySet(
        childId: childId,
        date: '2026-11-19',
        questions: const [],
      );
      service.advanceOneDay();

      await service.clearAllData();

      // Bé mặc định còn, bậc về 1, sổ/lượt/xu/đề đều trống.
      final children = await db.childrenDao.getAllChildren();
      expect(children, hasLength(1));
      expect(children.first.name, 'Bé');
      final rungs = await service.rungs(childId: children.first.id);
      expect(rungs.values.toSet(), {1});
      expect(await service.reviewEntries(childId: children.first.id), isEmpty);
      expect(await service.recentAttempts(childId: children.first.id), isEmpty);
      expect(
        await db.walletDao.balance(
          childId: children.first.id,
          currency: Currency.xu,
        ),
        0,
      );
      expect(
        await db.dailySetsDao.getDailySetsForChild(children.first.id),
        isEmpty,
      );
      // Ngày QA cũng về hôm nay.
      expect(service.dayOffset, Duration.zero);
      expect(service.today, '2026-11-19');
    });

    test(
      'sau clearAllData, trigger append-only vẫn chặn xóa attempts',
      () async {
        await service.clearAllData();
        final freshChildId = (await db.childrenDao.getAllChildren()).first.id;
        await db.attemptsDao.recordAttempt(
          childId: freshChildId,
          formId: 'logic.balance',
          strand: Strand.logic,
          level: 1,
          rung: 1,
          answerType: AnswerType.choice,
          correctFirstTry: true,
          attemptsCount: 1,
          durationMs: 1000,
        );
        expect(
          () => db.customStatement('DELETE FROM attempts'),
          throwsA(anything),
        );
        // Dữ liệu vẫn còn nguyên sau lần xóa bị chặn.
        expect(
          await service.recentAttempts(childId: freshChildId),
          hasLength(1),
        );
      },
    );
  });
}
