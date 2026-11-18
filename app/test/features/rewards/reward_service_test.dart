/// Unit test cho T1-11: RewardService — cộng thưởng, chống trùng,
/// số dư từ `wallet_ledger`, và nghiệm thu (c) cả ngày.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/database/tables.dart' hide AnswerType;
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/math/math_session.dart';
import 'package:timokid/features/questions/question.dart';
import 'package:timokid/features/questions/question_registry.dart';
import 'package:timokid/features/rewards/reward_config.dart';
import 'package:timokid/features/rewards/reward_service.dart';

AppDatabase openMemoryDb({Clock? clock}) => AppDatabase(
  executor: NativeDatabase.memory(),
  clock: clock ?? const SystemClock(),
);

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late RewardService rewards;

  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 18, 8, 0));
    db = openMemoryDb(clock: clock);
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    rewards = RewardService(db: db, config: RewardConfig.defaults());
  });

  /// 25 câu bậc 3–4 (mức Vừa), 5 chặng × 5 câu, mỗi chặng một mảng,
  /// dạng bài riêng từng câu (40 dạng hỗ trợ mức 2). Bậc lẻ (3) là
  /// trắc nghiệm, bậc chẵn (4) là điền số. Seed chọn sao cho đáp án
  /// điền số không âm (bàn phím trong app chỉ có chữ số).
  List<DailySetQuestion> rung34Questions() {
    const strands = [
      Strand.logic,
      Strand.arith,
      Strand.number,
      Strand.geo,
      Strand.comb,
    ];
    final forms = allQuestionGenerators
        .where((g) => g.supportedLevels.contains(2))
        .toList();
    expect(forms.length, greaterThanOrEqualTo(25));
    final questions = <DailySetQuestion>[];
    for (var i = 0; i < 25; i++) {
      final rung = i.isEven ? 3 : 4;
      var seed = i * 7 + 1;
      DailySetQuestion built() => DailySetQuestion(
        formId: forms[i].formId,
        strand: strands[i ~/ 5],
        level: 2,
        rung: rung,
        answerType: rung.isOdd ? 'choice' : 'number',
        seed: seed,
      );
      var resolved = ResolvedQuestion.resolve(built());
      while (resolved.displayType == AnswerType.number &&
          resolved.question.answer < 0) {
        seed += 1;
        resolved = ResolvedQuestion.resolve(built());
      }
      questions.add(built());
    }
    return questions;
  }

  Future<DailySet> buildSet(List<DailySetQuestion> questions) async {
    final id = await db.dailySetsDao.createDailySet(
      childId: childId,
      date: clock.today(),
      questions: questions,
    );
    return (await db.dailySetsDao.getDailySetById(id))!;
  }

  /// Trả lời đúng ngay lần đầu hết một chặng rồi sang chặng tiếp.
  Future<void> answerStageCorrectly(StageSession session) async {
    for (var i = 0; i < session.resolved.length; i++) {
      final q = session.current;
      if (q.displayType == AnswerType.choice) {
        expect(await session.submitChoice(q.correctDisplayIndex), isTrue);
      } else {
        for (final ch in '${q.question.answer}'.split('')) {
          session.appendDigit(ch);
        }
        expect(await session.submitNumber(), isTrue);
      }
      await session.next();
    }
    expect(session.finished, isTrue);
  }

  group('RewardService', () {
    test('awardQuestion: đúng ngay, sau gợi ý, ôn tập', () async {
      expect(
        await rewards.awardQuestion(
          childId: childId,
          rung: 3,
          correctFirstTry: true,
          isReview: false,
        ),
        3,
      );
      expect(
        await rewards.awardQuestion(
          childId: childId,
          rung: 3,
          correctFirstTry: false,
          isReview: false,
        ),
        2,
      );
      expect(
        await rewards.awardQuestion(
          childId: childId,
          rung: 3,
          correctFirstTry: true,
          isReview: true,
        ),
        6,
      );
      // Ôn tập + sau gợi ý: chia đôi làm tròn lên RỒI nhân đôi.
      expect(
        await rewards.awardQuestion(
          childId: childId,
          rung: 3,
          correctFirstTry: false,
          isReview: true,
        ),
        4,
      );
      expect(
        await rewards.awardQuestion(
          childId: childId,
          rung: 5,
          correctFirstTry: false,
          isReview: true,
        ),
        6,
      );
      expect(await rewards.xuBalance(childId), 3 + 2 + 6 + 4 + 6);
      expect(await rewards.gemBalance(childId), 0);
      final reasons = (await db.walletDao.getEntries(childId))
          .map((e) => e.reason)
          .toList();
      expect(reasons, contains('question_correct'));
      expect(reasons, contains('question_correct_after_hint'));
      expect(reasons, contains('review_correct'));
      expect(reasons, contains('review_correct_after_hint'));
    });

    test('awardStageComplete: chặng đã xong thì không cộng lại', () async {
      final set = await buildSet(rung34Questions());
      expect(
        await rewards.awardStageComplete(
          childId: childId,
          dailySetId: set.id,
          stageIndex: 0,
        ),
        5,
      );
      // Chưa đánh dấu xong: gọi lại vẫn cộng (luồng thật đánh dấu
      // xong ngay sau khi cộng, xem test dưới).
      expect(await rewards.xuBalance(childId), 5);
      await db.dailySetsDao.updateStageStatus(
        id: set.id,
        stageIndex: 0,
        status: StageStatus.done,
      );
      expect(
        await rewards.awardStageComplete(
          childId: childId,
          dailySetId: set.id,
          stageIndex: 0,
        ),
        0,
      );
      expect(await rewards.xuBalance(childId), 5);
    });

    test('awardStageComplete: chặng tự chọn luôn cộng', () async {
      expect(
        await rewards.awardStageComplete(
          childId: childId,
          dailySetId: null,
          stageIndex: -1,
        ),
        5,
      );
      expect(
        await rewards.awardStageComplete(
          childId: childId,
          dailySetId: null,
          stageIndex: -1,
        ),
        5,
      );
      expect(await rewards.xuBalance(childId), 10);
    });

    test('awardDailyCompleteIfDone: đủ 5 chặng thì cộng một lần', () async {
      final set = await buildSet(rung34Questions());
      expect(
        await rewards.awardDailyCompleteIfDone(
          childId: childId,
          dailySetId: set.id,
        ),
        isFalse,
      );
      for (var s = 0; s < 5; s++) {
        await db.dailySetsDao.updateStageStatus(
          id: set.id,
          stageIndex: s,
          status: StageStatus.done,
        );
      }
      expect(
        await rewards.awardDailyCompleteIfDone(
          childId: childId,
          dailySetId: set.id,
        ),
        isTrue,
      );
      expect(await rewards.xuBalance(childId), 20);
      expect(await rewards.gemBalance(childId), 1);
      // Gọi lại: không cộng thêm.
      expect(
        await rewards.awardDailyCompleteIfDone(
          childId: childId,
          dailySetId: set.id,
        ),
        isFalse,
      );
      expect(await rewards.xuBalance(childId), 20);
      expect(await rewards.gemBalance(childId), 1);
      final done = await db.dailySetsDao.getDailySetById(set.id);
      expect(done!.completed, isTrue);
      expect(done.completedAt, isNotNull);
    });

    test('balances đọc từ wallet_ledger (kể cả trừ)', () async {
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.xu,
        amount: 10,
        reason: 'test',
      );
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.gem,
        amount: 2,
        reason: 'test',
      );
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.xu,
        amount: -3,
        reason: 'test',
      );
      final balances = await rewards.balances(childId);
      expect(balances[Currency.xu], 7);
      expect(balances[Currency.gem], 2);
      expect(await rewards.xuBalance(childId), 7);
      expect(await rewards.gemBalance(childId), 2);
    });

    test('nghiệm thu (c): bậc 3–4, sổ ôn tập trống, 25 câu đúng ngay '
        '→ 120 xu và 1 kim cương', () async {
      final set = await buildSet(rung34Questions());
      final questions = db.dailySetsDao.readQuestions(set);
      for (var s = 0; s < 5; s++) {
        final session = StageSession(
          db: db,
          childId: childId,
          dailySetId: set.id,
          stageIndex: s,
          questions: questions.sublist(s * 5, (s + 1) * 5),
          rewardService: rewards,
        );
        await answerStageCorrectly(session);
        // 5 câu × 3 xu + 5 xu xong chặng; chặng cuối thêm 20 xu
        // xong đề ngày.
        expect(session.xuEarned, s < 4 ? 20 : 40);
      }
      final balances = await rewards.balances(childId);
      expect(balances[Currency.xu], 120);
      expect(balances[Currency.gem], 1);
      final done = await db.dailySetsDao.getDailySetById(set.id);
      expect(done!.completed, isTrue);
      expect(
        db.dailySetsDao.readStageStatus(done),
        everyElement(StageStatus.done),
      );
      // Sổ ôn tập vẫn trống (đúng ngay hết, không câu nào vào sổ).
      expect(await db.reviewQueueDao.getAllEntries(childId), isEmpty);
      // Mở lại màn kết quả / gọi lại: không cộng thêm.
      expect(
        await rewards.awardDailyCompleteIfDone(
          childId: childId,
          dailySetId: set.id,
        ),
        isFalse,
      );
      final again = await rewards.balances(childId);
      expect(again[Currency.xu], 120);
      expect(again[Currency.gem], 1);
    });

    test('StageSession dùng bảng thưởng từ settings', () async {
      await db.settingsDao.setValue(
        key: 'rewards',
        value: jsonEncode({
          'easy': 10,
          'medium': 20,
          'hard': 30,
          'stage_complete': 7,
          'daily_complete_xu': 40,
          'daily_complete_gem': 2,
          'mastery_gem': 5,
        }),
      );
      final custom = RewardService(db: db, config: await RewardConfig.load(db));
      final set = await buildSet(rung34Questions());
      final questions = db.dailySetsDao.readQuestions(set);
      final session = StageSession(
        db: db,
        childId: childId,
        dailySetId: set.id,
        stageIndex: 0,
        questions: questions.sublist(0, 5),
        rewardService: custom,
      );
      // Câu đầu bậc 3, đúng ngay: 20 xu theo bảng mới (mặc định: 3).
      final q = session.current;
      if (q.displayType == AnswerType.choice) {
        await session.submitChoice(q.correctDisplayIndex);
      } else {
        for (final ch in '${q.question.answer}'.split('')) {
          session.appendDigit(ch);
        }
        await session.submitNumber();
      }
      expect(session.xuEarned, 20);
      expect(session.lastEarnedXu, 20);
    });
  });
}
