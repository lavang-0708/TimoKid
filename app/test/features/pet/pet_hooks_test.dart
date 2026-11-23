/// Test chỗ gắn pet vào việc học (D): xp cho câu đúng ngay lần đầu,
/// suất ăn khi xong chặng (chặng ngày, chặng tự chọn, đấu trường).
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/database/tables.dart' hide AnswerType;
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/arena/arena_config.dart';
import 'package:timokid/features/arena/arena_service.dart';
import 'package:timokid/features/arena/arena_session.dart';
import 'package:timokid/features/math/math_session.dart';
import 'package:timokid/features/onboarding/egg_service.dart';
import 'package:timokid/features/pet/pet_care_service.dart';
import 'package:timokid/features/pet/pet_service.dart';
import 'package:timokid/features/questions/question.dart';
import 'package:timokid/features/questions/question_registry.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late PetService pets;
  late PetCareService care;

  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 23, 8, 0));
    db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    pets = PetService(db: db);
    care = PetCareService(db: db);
    final eggs = EggService(db: db);
    await eggs.selectEgg(childId: childId, species: 'dog');
    await eggs.noteStageCompleted(childId);
    await eggs.consumeHatchCelebration(childId);
  });

  /// 5 câu trắc nghiệm bậc 1 (mức Dễ) của mảng logic.
  List<DailySetQuestion> fiveQuestions() {
    final forms = allQuestionGenerators
        .where((g) => g.supportedLevels.contains(1))
        .take(5)
        .toList();
    return [
      for (var i = 0; i < 5; i++)
        DailySetQuestion(
          formId: forms[i].formId,
          strand: Strand.logic,
          level: 1,
          rung: 1,
          answerType: 'choice',
          seed: i + 1,
        ),
    ];
  }

  Future<void> answerOne(StageSession s, {required bool firstTry}) async {
    final q = s.current;
    if (q.displayType == AnswerType.choice) {
      if (!firstTry) {
        final wrong = q.correctDisplayIndex == 0 ? 1 : 0;
        await s.submitChoice(wrong);
      }
      await s.submitChoice(q.correctDisplayIndex);
    } else {
      if (!firstTry) {
        s.appendDigit('9');
        await s.submitNumber();
        s.deleteDigit();
      }
      for (final ch in '${q.question.answer}'.split('')) {
        s.appendDigit(ch);
      }
      await s.submitNumber();
    }
  }

  test(
    'chặng tự chọn: mỗi câu đúng ngay +1 xp, câu đúng sau gợi ý không',
    () async {
      final s = StageSession(
        db: db,
        childId: childId,
        dailySetId: null,
        stageIndex: -1,
        questions: fiveQuestions(),
      );
      await answerOne(s, firstTry: true);
      expect((await pets.active(childId))!.xp, 1);
      await s.next();
      await answerOne(s, firstTry: false);
      // Đúng sau lần thử đầu sai: không cộng xp.
      expect((await pets.active(childId))!.xp, 1);
    },
  );

  test('xong chặng ngày: một suất ăn, chặng đó không nhận lại', () async {
    final id = await db.dailySetsDao.createDailySet(
      childId: childId,
      date: clock.today(),
      questions: [
        ...fiveQuestions(),
        ...fiveQuestions(),
        ...fiveQuestions(),
        ...fiveQuestions(),
        ...fiveQuestions(),
      ],
    );
    StageSession stage(int i) => StageSession(
      db: db,
      childId: childId,
      dailySetId: id,
      stageIndex: i,
      questions: fiveQuestions(),
    );
    final s = stage(0);
    for (var i = 0; i < 5; i++) {
      await answerOne(s, firstTry: true);
      await s.next();
    }
    expect(s.finished, isTrue);
    expect(await care.mealCount(childId), 1);
    expect((await pets.active(childId))!.xp, 5);
    expect(await care.stagesDoneToday(childId), greaterThanOrEqualTo(1));
    // Làm lại cùng chặng ngày (gọi lại hook) không cộng thêm suất.
    expect(await care.awardMeal(childId, refId: 'stage:$id:0'), isFalse);
    expect(await care.mealCount(childId), 1);
  });

  test('chặng tự chọn xong nhiều lần: mỗi lần một suất', () async {
    for (var round = 0; round < 2; round++) {
      final s = StageSession(
        db: db,
        childId: childId,
        dailySetId: null,
        stageIndex: -1,
        questions: fiveQuestions(),
      );
      for (var i = 0; i < 5; i++) {
        await answerOne(s, firstTry: true);
        await s.next();
      }
    }
    expect(await care.mealCount(childId), 2);
  });

  test('tầng tháp: xp từng câu đúng ngay, thử lại cùng tầng cùng ngày chỉ một suất', () async {
    Future<void> attempt(int floor) async {
      final s = StageSession(
        db: db,
        childId: childId,
        dailySetId: null,
        stageIndex: -1,
        questions: fiveQuestions(),
        towerFloor: floor,
      );
      for (var i = 0; i < 5; i++) {
        await answerOne(s, firstTry: true);
        await s.next();
      }
    }

    await attempt(1);
    await attempt(1);
    expect((await pets.active(childId))!.xp, 10);
    expect(await care.mealCount(childId), 1);
    await attempt(2);
    expect(await care.mealCount(childId), 2);
    clock.set(DateTime(2026, 11, 24, 8, 0));
    await attempt(1);
    expect(await care.mealCount(childId), 3);
  });

  group('đấu trường', () {
    ArenaScore score(int correct) => ArenaScore(
      correct: correct,
      total: 25,
      sectionCorrect: const [0, 0, 0, 0, 0],
      sectionTotal: 5,
      points: correct * 4,
      maxPoints: 100,
      medal: arenaMedalFor(correct),
    );

    test('nộp bài: xp = số câu đúng, một suất ăn mỗi ngày', () async {
      final arena = ArenaService(db: db);
      await arena.submit(
        childId: childId,
        score: score(18),
        duration: const Duration(minutes: 30),
      );
      expect((await pets.active(childId))!.xp, 18);
      expect(await care.mealCount(childId), 1);
      await arena.submit(
        childId: childId,
        score: score(10),
        duration: const Duration(minutes: 30),
      );
      expect((await pets.active(childId))!.xp, 28);
      expect(await care.mealCount(childId), 1);
      clock.set(DateTime(2026, 11, 24, 8, 0));
      await arena.submit(
        childId: childId,
        score: score(1),
        duration: const Duration(minutes: 30),
      );
      expect(await care.mealCount(childId), 2);
    });
  });
}
