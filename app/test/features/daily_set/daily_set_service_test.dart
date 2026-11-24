/// Unit test cho T1-08: đề ngày (25 câu, 5 chặng theo 5 mảng).
///
/// Chạy trên DB trong bộ nhớ với [FakeClock]: ngày do test đặt nên
/// kiểm chứng được "sang ngày mới lúc 0 giờ tạo đề mới" và "mở lại đề
/// đã lưu thì không sinh lại". [Random] gieo sẵn hạt giống cố định để
/// đề sinh ra xác định.
///
/// Các kiểm tra bám theo PLAN mục T1-08 và mục "Làm rõ" (f), (g):
/// cấu trúc đề với nhiều trạng thái bậc và sổ ôn tập, câu 4 ôn tập
/// dùng bậc trong `review_queue`, không lặp dạng trong chặng, lặp thì
/// ưu tiên dạng ít gặp 7 ngày qua, chặng tự chọn.
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/database/tables.dart' hide AnswerType;
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/daily_set/daily_set_config.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/questions/question.dart';
import 'package:timokid/features/questions/question_registry.dart';

AppDatabase openMemoryDb({Clock? clock}) => AppDatabase(
  executor: NativeDatabase.memory(),
  clock: clock ?? const SystemClock(),
);

/// Một câu trong đề ngày đã lưu, dựng nhanh cho test.
DailySetQuestion makeQuestion(
  String formId,
  String strand, {
  int level = 1,
  int rung = 1,
  String answerType = 'choice',
  bool isReview = false,
  int seed = 1,
}) => DailySetQuestion(
  formId: formId,
  strand: strand,
  level: level,
  rung: rung,
  answerType: answerType,
  isReview: isReview,
  seed: seed,
);

void main() {
  group('DailySetConfig: hằng số cấu trúc đề', () {
    test('đề 25 câu = 5 chặng x 5 câu, câu ôn tập là câu 4', () {
      expect(DailySetConfig.stagesPerDay, 5);
      expect(DailySetConfig.questionsPerStage, 5);
      expect(DailySetConfig.totalQuestions, 25);
      expect(DailySetConfig.reviewSlotIndex, 3);
      expect(DailySetConfig.recentDaysForLeastSeen, 7);
    });

    test('danh sách choiceOnly khớp đúng 3 dạng trong gen.py', () {
      expect(DailySetConfig.choiceOnlyFormIds, {
        'logic.compare',
        'logic.weekday',
        'number.parityrule',
      });
    });
  });

  group('StageFormPicker: luật chọn dạng', () {
    const picker = StageFormPicker();
    final random = Random(7);

    List<QuestionGenerator> generators(List<String> formIds) => [
      for (final id in formIds) questionGeneratorFor(id)!,
    ];

    test('ô điền số ưu tiên dạng điền số chưa dùng', () {
      final picked = picker.pick(
        candidates: generators(['logic.compare', 'logic.age']),
        usedFormIds: {},
        neededType: AnswerType.number,
        usageLast7Days: {},
        random: random,
      );
      expect(picked, 'logic.age');
    });

    test('ô điền số: hết dạng số chưa dùng thì dùng dạng choiceOnly', () {
      final picked = picker.pick(
        candidates: generators(['logic.compare', 'logic.age']),
        usedFormIds: {'logic.age'},
        neededType: AnswerType.number,
        usageLast7Days: {},
        random: random,
      );
      expect(picked, 'logic.compare');
    });

    test('ô trắc nghiệm: mọi dạng đều dùng được', () {
      final picked = picker.pick(
        candidates: generators(['logic.compare', 'logic.age']),
        usedFormIds: {},
        neededType: AnswerType.choice,
        usageLast7Days: {},
        random: random,
      );
      expect(['logic.compare', 'logic.age'], contains(picked));
    });

    test('hết dạng mới: lặp dạng ít gặp nhất trong 7 ngày qua', () {
      final picked = picker.pick(
        candidates: generators(['logic.age', 'logic.balance']),
        usedFormIds: {'logic.age', 'logic.balance'},
        neededType: AnswerType.choice,
        usageLast7Days: {'logic.age': 5, 'logic.balance': 2},
        random: random,
      );
      expect(picked, 'logic.balance');
    });

    test('lặp dạng ở ô điền số: ưu tiên lặp dạng điền số', () {
      // compare ít gặp hơn (0 lần) nhưng là choiceOnly; age đã gặp
      // 3 lần nhưng điền số được → lặp age (đúng kiểu được ưu tiên
      // khi lặp — xem DECISIONS mục T1-08, điểm chờ Claude chốt).
      final picked = picker.pick(
        candidates: generators(['logic.compare', 'logic.age']),
        usedFormIds: {'logic.compare', 'logic.age'},
        neededType: AnswerType.number,
        usageLast7Days: {'logic.compare': 0, 'logic.age': 3},
        random: random,
      );
      expect(picked, 'logic.age');
    });
  });

  group('DailySetService: cấu trúc đề ngày', () {
    late FakeClock clock;
    late AppDatabase db;
    late DailySetService service;
    late String childId;

    Future<void> setRung(String strand, int rung) async {
      await db.skillProgressDao.setStrandRung(
        childId: childId,
        strand: strand,
        rung: rung,
      );
      clock.advance(const Duration(minutes: 1));
    }

    Future<void> setAllRungs(int rung) async {
      for (final strand in Strand.all) {
        await setRung(strand, rung);
      }
    }

    /// Thêm một mục vào sổ ôn tập, đến hạn vào [due].
    Future<void> addReviewEntry({
      required String formId,
      required int rung,
      required DateTime due,
    }) async {
      await db.reviewQueueDao.upsertEntry(
        childId: childId,
        formId: formId,
        rung: rung,
        dueDate: due,
      );
    }

    /// 5 câu của chặng thứ [stageIndex] trong đề đã lưu.
    List<DailySetQuestion> stageQuestions(DailySet set, int stageIndex) {
      final questions = db.dailySetsDao.readQuestions(set);
      return questions.sublist(
        stageIndex * DailySetConfig.questionsPerStage,
        (stageIndex + 1) * DailySetConfig.questionsPerStage,
      );
    }

    setUp(() async {
      clock = FakeClock(DateTime(2026, 11, 18, 8, 0));
      db = openMemoryDb(clock: clock);
      addTearDown(db.close);
      service = DailySetService(
        dailySetsDao: db.dailySetsDao,
        reviewQueueDao: db.reviewQueueDao,
        ladderService: LadderService(
          attemptsDao: db.attemptsDao,
          skillProgressDao: db.skillProgressDao,
        ),
        clock: clock,
        random: Random(42),
      );
      childId = await db.ensureSeeded();
      clock.advance(const Duration(minutes: 1));
    });

    test('đề mới có đúng 25 câu, 5 chặng theo 5 mảng', () async {
      final set = await service.getOrCreateTodaySet(childId: childId);

      expect(set.date, '2026-11-18');
      expect(set.completed, isFalse);
      expect(db.dailySetsDao.readStageStatus(set), [
        for (var i = 0; i < 5; i++) StageStatus.notStarted,
      ]);
      final questions = db.dailySetsDao.readQuestions(set);
      expect(questions, hasLength(25));
      for (var stage = 0; stage < 5; stage++) {
        final stageQs = stageQuestions(set, stage);
        expect(stageQs, hasLength(5));
        for (final q in stageQs) {
          expect(q.strand, Strand.all[stage]);
        }
      }
    });

    test('bậc 1: câu 1,2,3 bậc 1, câu 5 bậc 2 (mức 1 hết)', () async {
      final set = await service.getOrCreateTodaySet(childId: childId);

      for (var stage = 0; stage < 5; stage++) {
        final qs = stageQuestions(set, stage);
        expect(qs.map((q) => q.rung).toList(), [1, 1, 1, 1, 2]);
        expect(qs.map((q) => q.level).toList(), [1, 1, 1, 1, 1]);
        expect(qs.map((q) => q.answerType).toList(), [
          'choice',
          'choice',
          'choice',
          'choice',
          'number',
        ]);
        expect(qs.map((q) => q.isReview).toList(), [
          false,
          false,
          false,
          false,
          false,
        ]);
      }
    });

    test('bậc 6: câu 1,2 bậc 5, câu 3,4,5 bậc 6 (mức 3 hết)', () async {
      await setAllRungs(6);
      final set = await service.getOrCreateTodaySet(childId: childId);

      for (var stage = 0; stage < 5; stage++) {
        final qs = stageQuestions(set, stage);
        expect(qs.map((q) => q.rung).toList(), [5, 5, 6, 6, 6]);
        expect(qs.map((q) => q.level).toList(), [3, 3, 3, 3, 3]);
        expect(qs.map((q) => q.answerType).toList(), [
          'choice',
          'choice',
          'number',
          'number',
          'number',
        ]);
      }
    });

    test('bậc 3: câu 1,2 bậc 2 mức 1 điền số, câu 3 bậc 3 mức 2 '
        'trắc nghiệm, câu 5 bậc 4 mức 2 điền số', () async {
      await setAllRungs(3);
      final set = await service.getOrCreateTodaySet(childId: childId);

      for (var stage = 0; stage < 5; stage++) {
        final qs = stageQuestions(set, stage);
        expect(qs.map((q) => q.rung).toList(), [2, 2, 3, 3, 4]);
        expect(qs.map((q) => q.level).toList(), [1, 1, 2, 2, 2]);
        expect(qs.map((q) => q.answerType).toList(), [
          'number',
          'number',
          'choice',
          'choice',
          'number',
        ]);
      }
    });

    test('mọi câu trong đề đều hợp lệ: mức dạng hỗ trợ, bậc 1–6, '
        'dạng choiceOnly luôn trắc nghiệm', () async {
      await setRung(Strand.logic, 2);
      await setRung(Strand.arith, 4);
      await setRung(Strand.number, 6);
      await setRung(Strand.geo, 1);
      await setRung(Strand.comb, 5);
      final set = await service.getOrCreateTodaySet(childId: childId);

      final questions = db.dailySetsDao.readQuestions(set);
      expect(questions, hasLength(25));
      for (final q in questions) {
        final generator = questionGeneratorFor(q.formId);
        expect(generator, isNotNull, reason: q.formId);
        expect(
          generator!.supportedLevels,
          contains(q.level),
          reason: '${q.formId} mức ${q.level}',
        );
        expect(q.rung, inInclusiveRange(1, 6));
        expect(q.answerType, isIn(['choice', 'number']));
        expect(q.seed, isNotNull);
        if (DailySetConfig.isChoiceOnly(q.formId)) {
          expect(q.answerType, 'choice', reason: q.formId);
        }
      }
    });

    test('không lặp dạng trong cùng chặng khi còn dạng khác', () async {
      final set = await service.getOrCreateTodaySet(childId: childId);

      for (var stage = 0; stage < 5; stage++) {
        final qs = stageQuestions(set, stage);
        final distinct = qs.map((q) => q.formId).toSet();
        expect(distinct, hasLength(5), reason: Strand.all[stage]);
      }
    });

    test('mở lại đề đã lưu thì không sinh lại, giữ trạng thái chặng', () async {
      final first = await service.getOrCreateTodaySet(childId: childId);
      await db.dailySetsDao.updateStageStatus(
        id: first.id,
        stageIndex: 1,
        status: StageStatus.inProgress,
      );

      final second = await service.getOrCreateTodaySet(childId: childId);

      expect(second.id, first.id);
      // DailySetQuestion không override `==` nên so sánh qua JSON.
      String questionsJson(DailySet set) => jsonEncode(
        db.dailySetsDao.readQuestions(set).map((q) => q.toJson()).toList(),
      );
      expect(questionsJson(second), questionsJson(first));
      expect(db.dailySetsDao.readStageStatus(second), [
        StageStatus.notStarted,
        StageStatus.inProgress,
        StageStatus.notStarted,
        StageStatus.notStarted,
        StageStatus.notStarted,
      ]);
    });

    test('sang ngày mới lúc 0 giờ tạo đề mới, đề cũ vẫn còn', () async {
      clock.set(DateTime(2026, 11, 18, 23, 30));
      final yesterday = await service.getOrCreateTodaySet(childId: childId);
      expect(yesterday.date, '2026-11-18');

      clock.set(DateTime(2026, 11, 19, 0, 30));
      final today = await service.getOrCreateTodaySet(childId: childId);

      expect(today.date, '2026-11-19');
      expect(today.id, isNot(yesterday.id));
      expect(db.dailySetsDao.readQuestions(today), hasLength(25));
      final kept = await db.dailySetsDao.getDailySet(childId, '2026-11-18');
      expect(kept?.id, yesterday.id);
    });

    test('câu ôn tập: có mục đến hạn thì câu 4 là câu ôn tập, dùng bậc '
        'trong sổ, các ô khác tránh dạng đó', () async {
      await setRung(Strand.logic, 3);
      await addReviewEntry(
        formId: 'logic.balance',
        rung: 2,
        due: DateTime(2026, 11, 17, 8, 0),
      );
      final set = await service.getOrCreateTodaySet(childId: childId);

      final logicQs = stageQuestions(set, 0);
      final review = logicQs[DailySetConfig.reviewSlotIndex];
      expect(review.formId, 'logic.balance');
      expect(review.isReview, isTrue);
      expect(review.rung, 2);
      expect(review.level, 1);
      expect(review.answerType, 'number');
      // Dạng ôn tập chỉ xuất hiện đúng một lần trong chặng.
      expect(logicQs.where((q) => q.formId == 'logic.balance'), hasLength(1));
      // Các ô khác giữ đúng bậc của chặng (bậc 3).
      expect(logicQs[0].rung, 2);
      expect(logicQs[1].rung, 2);
      expect(logicQs[2].rung, 3);
      expect(logicQs[4].rung, 4);
    });

    test('không có mục đến hạn thì câu 4 là câu thường đúng bậc', () async {
      await setAllRungs(4);
      final set = await service.getOrCreateTodaySet(childId: childId);

      for (var stage = 0; stage < 5; stage++) {
        final qs = stageQuestions(set, stage);
        final q4 = qs[DailySetConfig.reviewSlotIndex];
        expect(q4.isReview, isFalse);
        expect(q4.rung, 4);
        expect(q4.level, 2);
      }
    });

    test('mục ôn tập chưa đến hạn thì không dùng', () async {
      await setRung(Strand.geo, 3);
      await addReviewEntry(
        formId: 'geo.countsq',
        rung: 2,
        due: DateTime(2026, 11, 19, 8, 0),
      );
      final set = await service.getOrCreateTodaySet(childId: childId);

      final geoQs = stageQuestions(set, 3);
      final q4 = geoQs[DailySetConfig.reviewSlotIndex];
      expect(q4.isReview, isFalse);
      expect(q4.rung, 3);
    });

    test('mục ôn tập của mảng khác không ảnh hưởng chặng này', () async {
      await addReviewEntry(
        formId: 'geo.countsq',
        rung: 2,
        due: DateTime(2026, 11, 17, 8, 0),
      );
      final set = await service.getOrCreateTodaySet(childId: childId);

      final logicQ4 = stageQuestions(set, 0)[DailySetConfig.reviewSlotIndex];
      expect(logicQ4.isReview, isFalse);
      final geoQ4 = stageQuestions(set, 3)[DailySetConfig.reviewSlotIndex];
      expect(geoQ4.isReview, isTrue);
      expect(geoQ4.formId, 'geo.countsq');
      expect(geoQ4.rung, 2);
    });

    test(
      'mục ôn tập có bậc mà dạng không hỗ trợ thì câu 4 là câu thường',
      () async {
        await setRung(Strand.logic, 3);
        // logic.equalize chỉ hỗ trợ mức 3, bậc 1 trong sổ ứng mức 1.
        await addReviewEntry(
          formId: 'logic.equalize',
          rung: 1,
          due: DateTime(2026, 11, 17, 8, 0),
        );
        final set = await service.getOrCreateTodaySet(childId: childId);

        final logicQs = stageQuestions(set, 0);
        final q4 = logicQs[DailySetConfig.reviewSlotIndex];
        expect(q4.isReview, isFalse);
        expect(q4.rung, 3);
        expect(q4.formId, isNot('logic.equalize'));
      },
    );

    /// Đề [date] gồm chặng comb dùng [combForms]; các mảng khác dùng
    /// một dạng cố định.
    Future<void> addPastSet(String date, List<String> combForms) async {
      const other = {
        'logic': 'logic.age',
        'arith': 'arith.quick',
        'number': 'number.parity',
        'geo': 'geo.countsq',
      };
      await db.dailySetsDao.createDailySet(
        childId: childId,
        date: date,
        questions: [
          for (final strand in Strand.all)
            for (var i = 0; i < combForms.length; i++)
              makeQuestion(
                strand == Strand.comb ? combForms[i] : other[strand]!,
                strand,
                seed: i + 1,
              ),
        ],
      );
    }

    test('chọn dạng mới thì ưu tiên dạng ít gặp trong 7 ngày qua', () async {
      // Hôm qua chặng comb đã gặp 5 dạng; còn 6 dạng mức 1 chưa gặp (đợt 4
      // thêm comb.flag) nên hôm nay 5 dạng phải đều lấy từ nhóm chưa gặp.
      const seen = [
        'comb.outfit',
        'comb.handshake',
        'comb.routes',
        'comb.choose2',
        'comb.makenumparity',
      ];
      await addPastSet('2026-11-17', seen);

      final set = await service.getOrCreateTodaySet(childId: childId);
      final combForms = stageQuestions(set, 4).map((q) => q.formId).toSet();
      expect(combForms, hasLength(5));
      expect(
        combForms.intersection(seen.toSet()),
        isEmpty,
        reason: '$combForms',
      );
      expect(
        {
          'comb.minsum2',
          'comb.freebie',
          'comb.vases',
          'comb.pick2',
          'comb.dice',
          'comb.flag',
        }.containsAll(combForms),
        isTrue,
        reason: '$combForms',
      );
    });

    test('đề quá 7 ngày không tính vào lịch sử ít gặp', () async {
      // Đề 8 ngày trước dùng 5 dạng; đề 2 ngày trước dùng 5 dạng còn
      // lại. Nếu đề cũ bị tính thì mọi dạng hòa nhau; không tính thì
      // hôm nay chặng comb phải là đúng 5 dạng của đề cũ.
      const oldForms = [
        'comb.outfit',
        'comb.handshake',
        'comb.routes',
        'comb.choose2',
        'comb.makenumparity',
      ];
      await addPastSet('2026-11-10', oldForms);
      await addPastSet('2026-11-16', [
        'comb.minsum2',
        'comb.freebie',
        'comb.vases',
        'comb.pick2',
        'comb.dice',
        'comb.flag',
      ]);

      final set = await service.getOrCreateTodaySet(childId: childId);
      final combForms = stageQuestions(set, 4).map((q) => q.formId).toSet();
      expect(combForms, oldForms.toSet());
    });
  });

  group('DailySetService: chặng tự chọn', () {
    late FakeClock clock;
    late AppDatabase db;
    late DailySetService service;
    late String childId;

    setUp(() async {
      clock = FakeClock(DateTime(2026, 11, 18, 8, 0));
      db = openMemoryDb(clock: clock);
      addTearDown(db.close);
      service = DailySetService(
        dailySetsDao: db.dailySetsDao,
        reviewQueueDao: db.reviewQueueDao,
        ladderService: LadderService(
          attemptsDao: db.attemptsDao,
          skillProgressDao: db.skillProgressDao,
        ),
        clock: clock,
        random: Random(42),
      );
      childId = await db.ensureSeeded();
      clock.advance(const Duration(minutes: 1));
    });

    test('sinh 5 câu theo bậc hiện tại, không lưu vào daily_sets', () async {
      await db.skillProgressDao.setStrandRung(
        childId: childId,
        strand: Strand.logic,
        rung: 3,
      );
      clock.advance(const Duration(minutes: 1));

      final stage = await service.buildExtraStage(
        childId: childId,
        strand: Strand.logic,
      );

      expect(stage, hasLength(5));
      expect(stage.map((q) => q.rung).toList(), [2, 2, 3, 3, 4]);
      expect(stage.map((q) => q.strand).toSet(), {'logic'});
      expect(await db.dailySetsDao.getDailySet(childId, '2026-11-18'), isNull);
    });

    test('chặng tự chọn cũng lấy câu ôn tập đến hạn làm câu 4', () async {
      await db.skillProgressDao.setStrandRung(
        childId: childId,
        strand: Strand.geo,
        rung: 3,
      );
      clock.advance(const Duration(minutes: 1));
      await db.reviewQueueDao.upsertEntry(
        childId: childId,
        formId: 'geo.countsq',
        rung: 2,
        dueDate: DateTime(2026, 11, 17, 8, 0),
      );

      final stage = await service.buildExtraStage(
        childId: childId,
        strand: Strand.geo,
      );

      final q4 = stage[DailySetConfig.reviewSlotIndex];
      expect(q4.isReview, isTrue);
      expect(q4.formId, 'geo.countsq');
      expect(q4.rung, 2);
    });

    test('mảng không tồn tại thì báo lỗi', () async {
      expect(
        () => service.buildExtraStage(childId: childId, strand: 'khongco'),
        throwsArgumentError,
      );
    });
  });

  group('DailySetService: phủ dạng bài của 84 dạng', () {
    test('mọi mảng đều có ít nhất 4 dạng ở mỗi mức', () {
      for (final strand in Strand.all) {
        for (var level = 1; level <= 3; level++) {
          final forms = allQuestionGenerators.where(
            (g) => g.topic == strand && g.supportedLevels.contains(level),
          );
          expect(
            forms.length,
            greaterThanOrEqualTo(4),
            reason: '$strand mức $level chỉ có ${forms.length} dạng',
          );
        }
      }
    });

    test('danh sách choiceOnly khớp với generator thật ở mọi mức', () {
      // Mỗi dạng hoặc luôn trắc nghiệm ở mọi mức nó hỗ trợ (phải có
      // trong danh sách), hoặc có ít nhất một mức điền số (phải không
      // có trong danh sách). Test này báo khi nội dung đổi.
      for (final generator in allQuestionGenerators) {
        var alwaysChoice = true;
        for (final level in generator.supportedLevels) {
          final question = generator.generate(level, Random(7));
          if (question.answerType != AnswerType.choice) {
            alwaysChoice = false;
          }
        }
        expect(
          DailySetConfig.isChoiceOnly(generator.formId),
          alwaysChoice,
          reason: generator.formId,
        );
      }
    });
  });
}
