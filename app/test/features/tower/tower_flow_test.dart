/// Luồng tầng tháp qua StageSession: câu vẫn ghi `attempts` như chặng
/// tự chọn, không cộng xu "xong chặng", chấm qua/trượt tầng.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart' hide AnswerType;
import 'package:timokid/features/questions/question.dart' show AnswerType;
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/math/math_session.dart';
import 'package:timokid/features/tower/tower_config.dart';
import 'package:timokid/features/tower/tower_service.dart';

void main() {
  late AppDatabase db;
  late String childId;
  late DailySetService service;

  setUp(() async {
    db = AppDatabase(
      executor: NativeDatabase.memory(),
      clock: FakeClock(DateTime(2026, 11, 23, 8)),
    );
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    service = DailySetService(
      dailySetsDao: db.dailySetsDao,
      reviewQueueDao: db.reviewQueueDao,
      ladderService: LadderService(
        attemptsDao: db.attemptsDao,
        skillProgressDao: db.skillProgressDao,
      ),
      clock: db.clock,
    );
  });

  /// Chơi một tầng: [correct] câu đầu đúng ngay lần đầu, còn lại sai hai lần.
  Future<StageSession> play(int floor, int correct) async {
    final qs = await service.buildTowerFloor(
      childId: childId,
      strand: Strand.logic,
      rung: TowerConfig.rungForFloor(floor),
    );
    final session = StageSession(
      db: db,
      childId: childId,
      dailySetId: null,
      stageIndex: -1,
      questions: qs,
      towerFloor: floor,
    );
    for (var i = 0; i < session.resolved.length; i++) {
      final r = session.resolved[i];
      final right = i < correct;
      if (r.displayType == AnswerType.choice) {
        final wrong = (r.correctDisplayIndex + 1) % r.choiceCount;
        await session.submitChoice(right ? r.correctDisplayIndex : wrong);
        if (!right) await session.submitChoice(wrong);
      } else {
        String digits(int n) => '$n';
        final answer = r.question.answer;
        final typed = right ? answer : answer + 1;
        for (final ch in digits(typed).split('')) {
          session.appendDigit(ch);
        }
        await session.submitNumber();
        if (!right) {
          for (final ch in digits(typed).split('')) {
            session.appendDigit(ch);
          }
          await session.submitNumber();
        }
      }
      await session.next();
    }
    return session;
  }

  test(
    'qua tầng 1: ghi 5 attempts, thưởng 10 xu, không cộng xu chặng',
    () async {
      final session = await play(1, 5);
      expect(session.towerOutcome!.passed, isTrue);
      expect(session.towerOutcome!.rewardXu, 10);
      expect((await db.attemptsDao.getAttemptsForChild(childId)).length, 5);
      final entries = await db.walletDao.getEntries(childId);
      expect(entries.any((e) => e.reason == 'stage_complete'), isFalse);
      expect(entries.where((e) => e.reason == 'tower_clear'), hasLength(1));
      expect(
        await TowerService(db: db)
            .highestCleared(childId: childId, strand: Strand.logic),
        1,
      );
    },
  );

  test('trượt tầng 1 (2/5): không qua, thử lại được', () async {
    final fail = await play(1, 2);
    expect(fail.towerOutcome!.passed, isFalse);
    expect(fail.towerOutcome!.rewardXu, 0);
    final ok = await play(1, 3);
    expect(ok.towerOutcome!.passed, isTrue);
    expect(ok.towerOutcome!.firstClear, isTrue);
  });
}
