/// Unit test Đấu trường (T2-10): dựng đề 25 câu, chấm điểm, ngưỡng huy
/// chương, thưởng kim cương một lần mỗi ngày, lưu bài thi.
library;

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/database/tables.dart' hide AnswerType;
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/arena/arena_config.dart';
import 'package:timokid/features/arena/arena_exam.dart';
import 'package:timokid/features/arena/arena_service.dart';
import 'package:timokid/features/arena/arena_session.dart';
import 'package:timokid/features/daily_set/daily_set_config.dart';
import 'package:timokid/features/ladder/ladder_config.dart';
import 'package:timokid/features/math/math_session.dart';
import 'package:timokid/features/questions/question.dart';

import '../questions/question_solvers.dart';

Map<String, int> _rungs(int r) => {for (final s in Strand.all) s: r};

/// Đáp án đúng của câu [i] dạng điền số, dưới dạng chuỗi chữ số.
String _correctText(ArenaSession s, int i) =>
    '${s.resolved[i].question.answer}';

/// Điền đúng [n] câu đầu (điền số gõ chữ số, trắc nghiệm chọn ô đúng).
void _answerCorrectly(ArenaSession s, int n) {
  for (var i = 0; i < n; i++) {
    s.goTo(i);
    final q = s.resolved[i];
    if (q.displayType == AnswerType.choice) {
      s.selectChoice(q.correctDisplayIndex);
    } else {
      for (final d in _correctText(s, i).split('')) {
        s.appendDigit(d);
      }
    }
  }
}

void main() {
  group('dựng đề', () {
    test('25 câu, 5 phần x 5 câu đúng thứ tự mảng của đề TIMO', () {
      final exam = buildArenaExam(rungs: _rungs(3), random: Random(7));
      expect(exam, hasLength(25));
      const order = [
        Strand.logic,
        Strand.arith,
        Strand.number,
        Strand.geo,
        Strand.comb,
      ];
      expect([for (final s in arenaSections) s.strand], order);
      for (var sec = 0; sec < 5; sec++) {
        for (var k = 0; k < 5; k++) {
          expect(exam[sec * 5 + k].strand, order[sec]);
        }
      }
      expect(ArenaFormat.heat.totalQuestions, 25);
      expect(ArenaFormat.heat.maxScore, 100);
      expect(ArenaFormat.heat.minutes, 90);
    });

    test('mỗi phần không lặp dạng bài, độ khó tăng dần, mọi bậc và seed', () {
      for (var rung = 1; rung <= 6; rung++) {
        for (var seed = 0; seed < 8; seed++) {
          final exam = buildArenaExam(
            rungs: _rungs(rung),
            random: Random(seed),
          );
          for (var sec = 0; sec < 5; sec++) {
            final part = exam.sublist(sec * 5, sec * 5 + 5);
            final reason = 'bậc $rung seed $seed phần $sec';
            expect(
              part.map((q) => q.formId).toSet(),
              hasLength(5),
              reason: reason,
            );
            for (final q in part) {
              expect(q.formId.startsWith('${q.strand}.'), isTrue);
            }
            final rungsInPart = part.map((q) => q.rung).toList();
            final levels = part.map((q) => q.level).toList();
            for (var k = 1; k < 5; k++) {
              expect(
                rungsInPart[k],
                greaterThanOrEqualTo(rungsInPart[k - 1]),
                reason: reason,
              );
              expect(
                levels[k],
                greaterThanOrEqualTo(levels[k - 1]),
                reason: reason,
              );
            }
            // Câu 1 đúng bậc của bé; câu 5 cao hơn tối đa 2 bậc, kẹp 6.
            expect(rungsInPart.first, rung, reason: reason);
            expect(rungsInPart.last, min(6, rung + 2), reason: reason);
            if (rung < LadderConfig.maxRung) {
              expect(
                rungsInPart.last,
                greaterThan(rungsInPart.first),
                reason: reason,
              );
            }
            // Mức nội dung đúng với bậc.
            for (final q in part) {
              expect(
                q.level == LadderConfig.levelForRung(q.rung) ||
                    (q.level - LadderConfig.levelForRung(q.rung)).abs() <= 2,
                isTrue,
              );
            }
          }
        }
      }
    });

    test('bám bậc từng mảng của bé', () {
      final rungs = {
        Strand.logic: 1,
        Strand.arith: 2,
        Strand.number: 3,
        Strand.geo: 4,
        Strand.comb: 5,
      };
      final exam = buildArenaExam(rungs: rungs, random: Random(1));
      for (var sec = 0; sec < 5; sec++) {
        expect(exam[sec * 5].rung, rungs[arenaSections[sec].strand]);
      }
      // Thiếu mảng thì bậc 1.
      final partial = buildArenaExam(rungs: const {}, random: Random(1));
      expect(partial.first.rung, 1);
    });

    test('cùng seed cho cùng đề, khác seed cho đề khác', () {
      List<String> ids(int seed) => [
        for (final q in buildArenaExam(rungs: _rungs(2), random: Random(seed)))
          '${q.formId}/${q.seed}',
      ];
      expect(ids(5), ids(5));
      expect(ids(5), isNot(ids(6)));
    });

    test('câu điền số trừ dạng choiceOnly; đáp án hợp lệ theo hàm giải', () {
      for (var seed = 0; seed < 6; seed++) {
        final exam = buildArenaExam(rungs: _rungs(4), random: Random(seed));
        for (final spec in exam) {
          final r = ResolvedQuestion.resolve(spec);
          expect(
            spec.answerType,
            DailySetConfig.isChoiceOnly(spec.formId) ? 'choice' : 'number',
          );
          // Đáp án của generator khớp hàm giải độc lập.
          expect(
            solveQuestion(r.question),
            r.question.answer,
            reason: '${spec.formId} seed ${spec.seed}',
          );
          if (r.displayType == AnswerType.number) {
            expect(r.question.answer, greaterThan(0));
          } else {
            expect(r.correctDisplayIndex, inInclusiveRange(0, 3));
            expect(r.choiceCount, greaterThanOrEqualTo(2));
          }
        }
      }
    });

    test('vòng Chung kết dựng được 30 câu, mỗi phần 6 câu', () {
      final exam = buildArenaExam(
        rungs: _rungs(3),
        random: Random(2),
        format: ArenaFormat.finalRound,
      );
      expect(exam, hasLength(30));
      for (var sec = 0; sec < 5; sec++) {
        final part = exam.sublist(sec * 6, sec * 6 + 6);
        expect(part.map((q) => q.formId).toSet(), hasLength(6));
        expect(part.first.rung, 3);
        expect(part.last.rung, 5);
      }
      expect(ArenaFormat.finalRound.maxScore, 150);
    });

    test('arenaSlotRungs: 5 câu base,base,+1,+1,+2 và kẹp trần 6', () {
      expect(arenaSlotRungs(1, 5), [1, 1, 2, 2, 3]);
      expect(arenaSlotRungs(4, 5), [4, 4, 5, 5, 6]);
      expect(arenaSlotRungs(6, 5), [6, 6, 6, 6, 6]);
      expect(arenaSlotRungs(5, 5), [5, 5, 6, 6, 6]);
    });
  });

  group('chấm điểm', () {
    ArenaSession fresh() => ArenaSession(
      questions: buildArenaExam(rungs: _rungs(2), random: Random(3)),
    );

    test('chưa trả lời gì: 0 đúng, 0 điểm, huy chương Tham gia', () {
      final s = fresh();
      final score = s.score();
      expect(score.correct, 0);
      expect(score.points, 0);
      expect(score.maxPoints, 100);
      expect(score.medal, ArenaMedal.participant);
      expect(s.unansweredCount, 25);
    });

    test('mỗi câu đúng 4 điểm; sai không bị trừ; đáp án sửa được', () {
      final s = fresh();
      _answerCorrectly(s, 10);
      expect(s.score().correct, 10);
      expect(s.score().points, 40);
      // Sửa câu 1 thành sai: chỉ mất câu đó, không trừ thêm.
      s.goTo(0);
      s.clearAnswer();
      expect(s.isAnswered(0), isFalse);
      s.appendDigit('9');
      s.appendDigit('9');
      s.appendDigit('9');
      expect(s.score().correct, 9);
      // Trả lời sai thêm các câu khác không trừ điểm.
      s.goTo(20);
      s.appendDigit('9');
      expect(s.score().correct, 9);
      expect(s.score().points, 36);
      // Sửa lại đúng.
      s.goTo(0);
      s.clearAnswer();
      for (final d in _correctText(s, 0).split('')) {
        s.appendDigit(d);
      }
      expect(s.score().correct, 10);
    });

    test('đếm đúng theo từng phần; đủ 25 câu là 100 điểm', () {
      final s = fresh();
      _answerCorrectly(s, 25);
      final score = s.score();
      expect(score.correct, 25);
      expect(score.points, 100);
      expect(score.sectionCorrect, [5, 5, 5, 5, 5]);
      expect(score.medal, ArenaMedal.gold);

      final t = fresh();
      // Chỉ phần 1 (5 câu) và phần 3 (3 câu đầu) đúng.
      _answerCorrectly(t, 5);
      for (var i = 10; i < 13; i++) {
        t.goTo(i);
        final q = t.resolved[i];
        if (q.displayType == AnswerType.choice) {
          t.selectChoice(q.correctDisplayIndex);
        } else {
          for (final d in _correctText(t, i).split('')) {
            t.appendDigit(d);
          }
        }
      }
      expect(t.score().sectionCorrect, [5, 0, 3, 0, 0]);
      expect(t.score().correct, 8);
    });

    test('điều hướng: goTo/next/previous kẹp trong 0–24', () {
      final s = fresh();
      s.previous();
      expect(s.currentIndex, 0);
      s.goTo(24);
      s.next();
      expect(s.currentIndex, 24);
      s.goTo(99);
      expect(s.currentIndex, 24);
      expect(s.sectionOf(24), 4);
      expect(s.sectionOf(7), 1);
    });

    test('trắc nghiệm: chọn, đổi, bỏ chọn khi chọn lại', () {
      final specs = buildArenaExam(rungs: _rungs(1), random: Random(0));
      // Dạng choiceOnly cho câu đầu để thử trắc nghiệm.
      final s = ArenaSession(
        questions: [
          const DailySetQuestionFixture().weekday(),
          ...specs.skip(1),
        ],
      );
      expect(s.current.displayType, AnswerType.choice);
      s.selectChoice(1);
      expect(s.selectedAt(0), 1);
      expect(s.isAnswered(0), isTrue);
      s.selectChoice(2);
      expect(s.selectedAt(0), 2);
      s.selectChoice(2);
      expect(s.selectedAt(0), isNull);
      s.selectChoice(s.current.correctDisplayIndex);
      expect(s.score().correct, 1);
      // Gõ số vào câu trắc nghiệm không có tác dụng.
      s.appendDigit('5');
      expect(s.typedAt(0), '');
    });
  });

  group('huy chương', () {
    test('ngưỡng 21 / 16 / 11 câu đúng', () {
      expect(arenaMedalFor(0), ArenaMedal.participant);
      expect(arenaMedalFor(10), ArenaMedal.participant);
      expect(arenaMedalFor(11), ArenaMedal.bronze);
      expect(arenaMedalFor(15), ArenaMedal.bronze);
      expect(arenaMedalFor(16), ArenaMedal.silver);
      expect(arenaMedalFor(20), ArenaMedal.silver);
      expect(arenaMedalFor(21), ArenaMedal.gold);
      expect(arenaMedalFor(25), ArenaMedal.gold);
    });

    test('kim cương: Vàng 5, Bạc 3, Đồng 2, Tham gia 1', () {
      expect(ArenaMedal.gold.gems, 5);
      expect(ArenaMedal.silver.gems, 3);
      expect(ArenaMedal.bronze.gems, 2);
      expect(ArenaMedal.participant.gems, 1);
      expect(ArenaMedal.fromCode('silver'), ArenaMedal.silver);
      expect(ArenaMedal.fromCode('lạ'), ArenaMedal.participant);
    });
  });

  group('lưu bài + thưởng một lần mỗi ngày', () {
    late FakeClock clock;
    late AppDatabase db;
    late String childId;
    late ArenaService service;

    setUp(() async {
      clock = FakeClock(DateTime(2026, 11, 22, 8, 0));
      db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
      addTearDown(db.close);
      childId = await db.ensureSeeded();
      service = ArenaService(db: db);
    });

    ArenaScore scoreFor(int correct) {
      final s = ArenaSession(
        questions: buildArenaExam(rungs: _rungs(2), random: Random(9)),
      );
      _answerCorrectly(s, correct);
      return s.score();
    }

    Future<int> gems() async =>
        (await db.walletDao.balances(childId))[Currency.gem]!;

    test('bài đầu trong ngày được thưởng đúng theo huy chương', () async {
      for (final (correct, expected) in [(25, 5), (16, 3), (11, 2), (3, 1)]) {
        final id = (await db.childrenDao.createChild(name: 'Bé $correct')).id;
        final result = await service.submit(
          childId: id,
          score: scoreFor(correct),
          duration: const Duration(minutes: 30),
        );
        expect(result.gemsAwarded, expected, reason: '$correct câu đúng');
        expect(result.alreadyRewardedToday, isFalse);
        expect((await db.walletDao.balances(id))[Currency.gem], expected);
      }
    });

    test('bài thứ hai cùng ngày không thưởng nhưng vẫn được lưu', () async {
      final first = await service.submit(
        childId: childId,
        score: scoreFor(12),
        duration: const Duration(minutes: 40),
      );
      expect(first.gemsAwarded, 2);
      clock.advance(const Duration(hours: 5)); // vẫn cùng ngày 22/11
      final second = await service.submit(
        childId: childId,
        score: scoreFor(25),
        duration: const Duration(minutes: 20),
      );
      expect(second.gemsAwarded, 0);
      expect(second.alreadyRewardedToday, isTrue);
      expect(await gems(), 2);
      final rows = await db.arenaAttemptsDao.getAll(childId);
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.gemsAwarded).toList()..sort(), [0, 2]);
      // Một dòng ví duy nhất cho thưởng Đấu trường hôm nay.
      final entries = await db.walletDao.getEntries(childId);
      expect(entries.where((e) => e.reason == 'arena_reward'), hasLength(1));
    });

    test('sang ngày mới (giờ Việt Nam) thì thưởng lại', () async {
      await service.submit(
        childId: childId,
        score: scoreFor(25),
        duration: const Duration(minutes: 10),
      );
      // 23:59 vẫn cùng ngày: không thưởng.
      clock.set(DateTime(2026, 11, 22, 23, 59));
      expect(
        (await service.submit(
          childId: childId,
          score: scoreFor(25),
          duration: const Duration(minutes: 10),
        )).gemsAwarded,
        0,
      );
      // 0 giờ ngày 23: thưởng lại.
      clock.set(DateTime(2026, 11, 23, 0, 0));
      expect(
        (await service.submit(
          childId: childId,
          score: scoreFor(16),
          duration: const Duration(minutes: 10),
        )).gemsAwarded,
        3,
      );
      expect(await gems(), 8);
    });

    test('lưu ngày, số câu đúng, điểm, huy chương, thời gian', () async {
      await service.submit(
        childId: childId,
        score: scoreFor(18),
        duration: const Duration(minutes: 61, seconds: 7),
      );
      final row = (await db.arenaAttemptsDao.getAll(childId)).single;
      expect(row.date, '2026-11-22');
      expect(row.mode, 'heat');
      expect(row.correctCount, 18);
      expect(row.score, 72);
      expect(row.medal, 'silver');
      expect(row.durationSec, 61 * 60 + 7);
      expect(row.gemsAwarded, 3);
    });

    test('summary: điểm cao nhất và trạng thái hôm nay', () async {
      var summary = await service.summary(childId);
      expect(summary.bestScore, isNull);
      expect(summary.rewardedToday, isFalse);
      expect(summary.attemptsToday, 0);

      await service.submit(
        childId: childId,
        score: scoreFor(18),
        duration: const Duration(minutes: 50),
      );
      clock.advance(const Duration(minutes: 70));
      await service.submit(
        childId: childId,
        score: scoreFor(9),
        duration: const Duration(minutes: 50),
      );
      summary = await service.summary(childId);
      expect(summary.bestScore, 72);
      expect(summary.bestCorrect, 18);
      expect(summary.bestMedal, ArenaMedal.silver);
      expect(summary.attemptsToday, 2);
      expect(summary.rewardedToday, isTrue);
      expect(summary.gems, 3);

      clock.set(DateTime(2026, 11, 23, 9, 0));
      summary = await service.summary(childId);
      expect(summary.rewardedToday, isFalse);
      expect(summary.attemptsToday, 0);
      expect(summary.bestScore, 72);
    });
  });
}

/// Câu cố định dạng choiceOnly cho test trắc nghiệm.
class DailySetQuestionFixture {
  const DailySetQuestionFixture();

  DailySetQuestion weekday() => const DailySetQuestion(
    formId: 'logic.weekday',
    strand: 'logic',
    level: 1,
    rung: 1,
    answerType: 'choice',
    seed: 11,
  );
}
