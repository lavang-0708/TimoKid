/// Unit test cho T1-07: thang ải (bậc 1–6 theo mảng) và thành thạo
/// dạng bài.
///
/// Chạy trên DB trong bộ nhớ với [FakeClock]: mỗi lượt trả lời cho
/// đồng hồ trôi 1 phút để `createdAt` phân biệt được (thứ tự cửa sổ
/// 10 câu và mốc `windowStartedAt` đều dựa vào thời gian này).
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart' hide AnswerType;
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/ladder/ladder_config.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/questions/question.dart';

AppDatabase openMemoryDb({Clock? clock}) => AppDatabase(
  executor: NativeDatabase.memory(),
  clock: clock ?? const SystemClock(),
);

void main() {
  group('LadderConfig: ánh xạ bậc → mức và kiểu trả lời', () {
    test('bậc 1–2 Dễ, 3–4 Vừa, 5–6 Khó', () {
      expect(LadderConfig.levelForRung(1), 1);
      expect(LadderConfig.levelForRung(2), 1);
      expect(LadderConfig.levelForRung(3), 2);
      expect(LadderConfig.levelForRung(4), 2);
      expect(LadderConfig.levelForRung(5), 3);
      expect(LadderConfig.levelForRung(6), 3);
    });

    test('bậc lẻ trắc nghiệm, bậc chẵn điền số', () {
      expect(LadderConfig.answerTypeForRung(1), AnswerType.choice);
      expect(LadderConfig.answerTypeForRung(2), AnswerType.number);
      expect(LadderConfig.answerTypeForRung(3), AnswerType.choice);
      expect(LadderConfig.answerTypeForRung(4), AnswerType.number);
      expect(LadderConfig.answerTypeForRung(5), AnswerType.choice);
      expect(LadderConfig.answerTypeForRung(6), AnswerType.number);
    });

    test('mức thành thạo: cao nhất, không thấp hơn Vừa nếu dạng có Vừa', () {
      expect(LadderConfig.masteryLevelForForm({1, 2, 3}), 3);
      expect(LadderConfig.masteryLevelForForm({2, 3}), 3);
      expect(LadderConfig.masteryLevelForForm({1, 3}), 3);
      expect(LadderConfig.masteryLevelForForm({1, 2}), 2);
      expect(LadderConfig.masteryLevelForForm({2}), 2);
      expect(LadderConfig.masteryLevelForForm({1}), 1);
      expect(LadderConfig.masteryLevelForForm({3}), 3);
    });
  });

  group('LadderService: thang ải', () {
    late FakeClock clock;
    late AppDatabase db;
    late LadderService ladder;
    late String childId;

    /// Ghi một lượt trả lời của mảng `logic`, đúng ngay hay không tùy
    /// [correctFirstTry]; mỗi lượt cho đồng hồ trôi 1 phút.
    Future<void> answerStrand({
      int count = 1,
      bool correctFirstTry = true,
      int rung = 1,
    }) async {
      for (var i = 0; i < count; i++) {
        clock.advance(const Duration(minutes: 1));
        await db.attemptsDao.recordAttempt(
          childId: childId,
          formId: 'logic.balance',
          strand: Strand.logic,
          level: LadderConfig.levelForRung(rung),
          rung: rung,
          answerType: LadderConfig.answerTypeForRung(rung).name,
          correctFirstTry: correctFirstTry,
          attemptsCount: correctFirstTry ? 1 : 2,
          durationMs: 5000,
        );
      }
    }

    /// Ghi [count] lượt, trong đó [correct] lượt đúng ngay lần đầu
    /// (các lượt đúng ghi trước, các lượt sai ghi sau).
    Future<void> answerMixed({
      required int count,
      required int correct,
      int rung = 1,
    }) async {
      await answerStrand(count: correct, correctFirstTry: true, rung: rung);
      await answerStrand(
        count: count - correct,
        correctFirstTry: false,
        rung: rung,
      );
    }

    setUp(() async {
      clock = FakeClock(DateTime(2026, 11, 18, 8, 0));
      db = openMemoryDb(clock: clock);
      addTearDown(db.close);
      ladder = LadderService(
        attemptsDao: db.attemptsDao,
        skillProgressDao: db.skillProgressDao,
      );
      childId = await db.ensureSeeded();
      // Cho đồng hồ trôi qua mốc hạt giống để mọi lượt trả lời sau
      // này đều nằm trong cửa sổ (mốc `windowStartedAt` là lúc seed).
      clock.advance(const Duration(minutes: 1));
    });

    test('bé mới bắt đầu ở bậc 1 cả 5 mảng', () async {
      final rungs = await ladder.rungsFor(childId: childId);
      expect(rungs, {for (final s in Strand.all) s: 1});
      expect(await ladder.rungFor(childId: childId, strand: Strand.geo), 1);
    });

    test('lên bậc khi đúng ngay 8/10 câu gần nhất', () async {
      await answerMixed(count: 10, correct: 8);

      final result = await ladder.evaluateStrand(
        childId: childId,
        strand: Strand.logic,
      );

      expect(result.windowFull, isTrue);
      expect(result.correctCount, 8);
      expect(result.promoted, isTrue);
      expect(result.previousRung, 1);
      expect(result.newRung, 2);
      expect(await ladder.rungFor(childId: childId, strand: Strand.logic), 2);
    });

    test('không lên bậc khi chỉ đúng ngay 7/10', () async {
      await answerMixed(count: 10, correct: 7);

      final result = await ladder.evaluateStrand(
        childId: childId,
        strand: Strand.logic,
      );

      expect(result.changed, isFalse);
      expect(await ladder.rungFor(childId: childId, strand: Strand.logic), 1);
    });

    test('xuống bậc khi đúng ngay dưới 5/10', () async {
      await db.skillProgressDao.setStrandRung(
        childId: childId,
        strand: Strand.logic,
        rung: 2,
      );
      clock.advance(const Duration(minutes: 1));
      await answerMixed(count: 10, correct: 4, rung: 2);

      final result = await ladder.evaluateStrand(
        childId: childId,
        strand: Strand.logic,
      );

      expect(result.correctCount, 4);
      expect(result.demoted, isTrue);
      expect(result.newRung, 1);
    });

    test('không xuống bậc khi đúng ngay đúng 5/10', () async {
      await db.skillProgressDao.setStrandRung(
        childId: childId,
        strand: Strand.logic,
        rung: 2,
      );
      clock.advance(const Duration(minutes: 1));
      await answerMixed(count: 10, correct: 5, rung: 2);

      final result = await ladder.evaluateStrand(
        childId: childId,
        strand: Strand.logic,
      );

      expect(result.changed, isFalse);
      expect(await ladder.rungFor(childId: childId, strand: Strand.logic), 2);
    });

    test('chạm trần bậc 6: đúng hết 10/10 vẫn ở bậc 6', () async {
      await db.skillProgressDao.setStrandRung(
        childId: childId,
        strand: Strand.logic,
        rung: 6,
      );
      clock.advance(const Duration(minutes: 1));
      await answerMixed(count: 10, correct: 10, rung: 6);

      final result = await ladder.evaluateStrand(
        childId: childId,
        strand: Strand.logic,
      );

      expect(result.correctCount, 10);
      expect(result.changed, isFalse);
      expect(result.newRung, 6);
    });

    test('đáy bậc 1: sai hết 10/10 vẫn ở bậc 1', () async {
      await answerMixed(count: 10, correct: 0);

      final result = await ladder.evaluateStrand(
        childId: childId,
        strand: Strand.logic,
      );

      expect(result.correctCount, 0);
      expect(result.changed, isFalse);
      expect(result.newRung, 1);
    });

    test('cửa sổ chưa đủ 10 câu thì không đánh giá', () async {
      await answerMixed(count: 5, correct: 5);

      final result = await ladder.evaluateStrand(
        childId: childId,
        strand: Strand.logic,
      );

      expect(result.windowFull, isFalse);
      expect(result.attemptedCount, 5);
      expect(result.changed, isFalse);
    });

    test('cửa sổ 10 câu reset sau đổi bậc', () async {
      // Lên bậc 1 → 2 với 8/10 đúng ngay.
      await answerMixed(count: 10, correct: 8);
      var result = await ladder.evaluateStrand(
        childId: childId,
        strand: Strand.logic,
      );
      expect(result.newRung, 2);
      clock.advance(const Duration(minutes: 1));

      // 8 câu mới đúng ngay: cửa sổ mới chỉ có 8 câu → chưa đánh giá
      // (nếu cửa sổ cũ còn tính thì 8 câu mới + 2 câu sai cũ = 8/10
      // đã đủ lên bậc ngay).
      await answerStrand(count: 8, correctFirstTry: true, rung: 2);
      result = await ladder.evaluateStrand(
        childId: childId,
        strand: Strand.logic,
      );
      expect(result.attemptedCount, 8);
      expect(result.windowFull, isFalse);
      expect(result.changed, isFalse);

      // Thêm 2 câu đúng ngay nữa: đủ 10 câu mới, 10/10 → lên bậc 3.
      await answerStrand(count: 2, correctFirstTry: true, rung: 2);
      result = await ladder.evaluateStrand(
        childId: childId,
        strand: Strand.logic,
      );
      expect(result.attemptedCount, 10);
      expect(result.correctCount, 10);
      expect(result.newRung, 3);
    });

    test('câu đúng sau gợi ý không tính là đúng', () async {
      await db.skillProgressDao.setStrandRung(
        childId: childId,
        strand: Strand.logic,
        rung: 2,
      );
      clock.advance(const Duration(minutes: 1));
      // 2 câu đúng ngay + 8 câu đúng sau gợi ý (attemptsCount = 2,
      // correctFirstTry = false): chỉ tính 2 câu đúng → xuống bậc.
      await answerMixed(count: 10, correct: 2, rung: 2);

      final result = await ladder.evaluateStrand(
        childId: childId,
        strand: Strand.logic,
      );

      expect(result.correctCount, 2);
      expect(result.demoted, isTrue);
      expect(result.newRung, 1);
    });

    test('8 câu đúng ngay + 2 câu đúng sau gợi ý vẫn lên bậc', () async {
      await answerMixed(count: 10, correct: 8);

      final result = await ladder.evaluateStrand(
        childId: childId,
        strand: Strand.logic,
      );

      expect(result.correctCount, 8);
      expect(result.promoted, isTrue);
    });

    test('không có dòng tiến độ: đánh giá vẫn lên bậc và tạo dòng', () async {
      final freshChild = await db.childrenDao.createChild(name: 'Bé mới');
      // Ghi trực tiếp 10 lượt cho bé mới: 8 đúng ngay, 2 sai.
      for (var i = 0; i < 10; i++) {
        clock.advance(const Duration(minutes: 1));
        await db.attemptsDao.recordAttempt(
          childId: freshChild.id,
          formId: 'logic.balance',
          strand: Strand.logic,
          level: 1,
          rung: 1,
          answerType: AnswerType.choice.name,
          correctFirstTry: i < 8,
          attemptsCount: i < 8 ? 1 : 2,
          durationMs: 5000,
        );
      }

      final result = await ladder.evaluateStrand(
        childId: freshChild.id,
        strand: Strand.logic,
      );

      expect(result.promoted, isTrue);
      expect(result.newRung, 2);
      expect(
        await ladder.rungFor(childId: freshChild.id, strand: Strand.logic),
        2,
      );
    });
  });

  group('LadderService: thành thạo dạng bài', () {
    late FakeClock clock;
    late AppDatabase db;
    late LadderService ladder;
    late String childId;

    /// Ghi [count] lượt của một dạng ở [level], trong đó [correct]
    /// lượt đúng ngay lần đầu (ghi trước).
    Future<void> answerForm({
      required String formId,
      required String strand,
      required int level,
      required int count,
      required int correct,
    }) async {
      for (var i = 0; i < count; i++) {
        clock.advance(const Duration(minutes: 1));
        await db.attemptsDao.recordAttempt(
          childId: childId,
          formId: formId,
          strand: strand,
          level: level,
          rung: LadderConfig.levelForRung(1),
          answerType: AnswerType.choice.name,
          correctFirstTry: i < correct,
          attemptsCount: i < correct ? 1 : 2,
          durationMs: 5000,
        );
      }
    }

    setUp(() async {
      clock = FakeClock(DateTime(2026, 11, 18, 8, 0));
      db = openMemoryDb(clock: clock);
      addTearDown(db.close);
      ladder = LadderService(
        attemptsDao: db.attemptsDao,
        skillProgressDao: db.skillProgressDao,
      );
      childId = await db.ensureSeeded();
      clock.advance(const Duration(minutes: 1));
    });

    test('dạng có 3 mức: thành thạo khi đúng ngay 4/5 ở mức Khó', () async {
      await answerForm(
        formId: 'logic.balance',
        strand: Strand.logic,
        level: 3,
        count: 5,
        correct: 4,
      );

      final mastered = await ladder.evaluateFormMastery(
        childId: childId,
        formId: 'logic.balance',
      );

      expect(mastered, isTrue);
      expect(
        await ladder.isFormMastered(childId: childId, formId: 'logic.balance'),
        isTrue,
      );
      expect(
        await ladder.masteredForms(childId: childId),
        contains('logic.balance'),
      );
    });

    test('dạng có 3 mức: chỉ đúng ngay 3/5 ở mức Khó thì chưa thạo', () async {
      await answerForm(
        formId: 'logic.balance',
        strand: Strand.logic,
        level: 3,
        count: 5,
        correct: 3,
      );

      expect(
        await ladder.evaluateFormMastery(
          childId: childId,
          formId: 'logic.balance',
        ),
        isFalse,
      );
      expect(
        await ladder.isFormMastered(childId: childId, formId: 'logic.balance'),
        isFalse,
      );
    });

    test(
      'dạng chỉ Dễ–Vừa: câu ở mức Dễ không tính, thành thạo ở mức Vừa',
      () async {
        // 5 câu mức Dễ đúng hết: mức thành thạo là Vừa nên chưa tính.
        await answerForm(
          formId: 'comb.outfit',
          strand: Strand.comb,
          level: 1,
          count: 5,
          correct: 5,
        );
        expect(
          await ladder.evaluateFormMastery(
            childId: childId,
            formId: 'comb.outfit',
          ),
          isFalse,
        );

        // 4/5 câu mức Vừa đúng ngay → thành thạo.
        await answerForm(
          formId: 'comb.outfit',
          strand: Strand.comb,
          level: 2,
          count: 5,
          correct: 4,
        );
        expect(
          await ladder.evaluateFormMastery(
            childId: childId,
            formId: 'comb.outfit',
          ),
          isTrue,
        );
      },
    );

    test('dạng chỉ có 1 mức: thành thạo ở mức duy nhất đó', () async {
      await answerForm(
        formId: 'geo.sides',
        strand: Strand.geo,
        level: 1,
        count: 5,
        correct: 4,
      );

      expect(
        await ladder.evaluateFormMastery(childId: childId, formId: 'geo.sides'),
        isTrue,
      );
    });

    test('chưa đủ 5 câu ở mức thành thạo thì chưa thạo', () async {
      await answerForm(
        formId: 'logic.balance',
        strand: Strand.logic,
        level: 3,
        count: 4,
        correct: 4,
      );

      expect(
        await ladder.evaluateFormMastery(
          childId: childId,
          formId: 'logic.balance',
        ),
        isFalse,
      );
    });

    test('dạng không tồn tại thì báo lỗi', () async {
      expect(
        () => ladder.evaluateFormMastery(
          childId: childId,
          formId: 'logic.khongco',
        ),
        throwsArgumentError,
      );
    });
  });
}
