/// Test TowerService: chấm tầng, thưởng chỉ lần đầu, lưu tầng cao nhất
/// theo bé + mảng, sự kiện qua tầng, sinh câu đúng bậc.
library;

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/tower/tower_config.dart';
import 'package:timokid/features/tower/tower_service.dart';

void main() {
  late AppDatabase db;
  late String childId;
  late TowerService tower;

  setUp(() async {
    db = AppDatabase(
      executor: NativeDatabase.memory(),
      clock: FakeClock(DateTime(2026, 11, 23, 8)),
    );
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    tower = TowerService(db: db);
  });

  Future<TowerOutcome> clear(int floor, int correct, {String? strand}) =>
      tower.recordResult(
        childId: childId,
        strand: strand ?? Strand.logic,
        floor: floor,
        firstTryCorrect: correct,
      );

  test('chưa leo: tầng cao nhất 0, tầng kế 1', () async {
    expect(
      await tower.highestCleared(childId: childId, strand: Strand.logic),
      0,
    );
    expect(await tower.nextFloor(childId: childId, strand: Strand.logic), 1);
  });

  test('tầng thường: 3/5 qua, 2/5 trượt không thưởng không lưu', () async {
    final fail = await clear(1, 2);
    expect(fail.passed, isFalse);
    expect(fail.rewardXu, 0);
    expect(await db.walletDao.balance(childId: childId, currency: 'xu'), 0);
    expect(
      await tower.highestCleared(childId: childId, strand: Strand.logic),
      0,
    );

    final ok = await clear(1, 3);
    expect(ok.passed, isTrue);
    expect(ok.firstClear, isTrue);
    expect(ok.rewardXu, 10);
    expect(ok.nextFloor, 2);
    expect(await db.walletDao.balance(childId: childId, currency: 'xu'), 10);
    expect(
      await tower.highestCleared(childId: childId, strand: Strand.logic),
      1,
    );
  });

  test('tầng boss cần 4/5, thưởng 1 kim cương + 20 xu', () async {
    for (var f = 1; f <= 4; f++) {
      await clear(f, 5);
    }
    final fail = await clear(5, 3);
    expect(fail.passed, isFalse);
    expect(fail.passNeeded, 4);
    final ok = await clear(5, 4);
    expect(ok.passed, isTrue);
    expect(ok.isBoss, isTrue);
    expect(ok.rewardXu, 20);
    expect(ok.rewardGems, 1);
    expect(await db.walletDao.balance(childId: childId, currency: 'gem'), 1);
    // 4 tầng thường x 10 + 20.
    expect(await db.walletDao.balance(childId: childId, currency: 'xu'), 60);
  });

  test('thưởng chỉ lần qua đầu tiên: qua lại tầng cũ không cộng', () async {
    await clear(1, 5);
    final again = await clear(1, 5);
    expect(again.passed, isTrue);
    expect(again.firstClear, isFalse);
    expect(again.rewardXu, 0);
    expect(await db.walletDao.balance(childId: childId, currency: 'xu'), 10);
    expect(
      await tower.highestCleared(childId: childId, strand: Strand.logic),
      1,
    );
  });

  test('tầng 30 thưởng 3 kim cương và là tầng cuối', () async {
    await db.settingsDao.setValue(
      childId: childId,
      key: TowerConfig.settingsKey(Strand.comb),
      value: '29',
    );
    final top = await clear(30, 4, strand: Strand.comb);
    expect(top.firstClear, isTrue);
    expect(top.rewardGems, 3);
    expect(top.nextFloor, isNull);
    expect(
      await tower.nextFloor(childId: childId, strand: Strand.comb),
      isNull,
    );
  });

  test('tiến độ lưu riêng theo mảng và theo bé', () async {
    await clear(1, 5, strand: Strand.logic);
    await clear(1, 5, strand: Strand.logic);
    expect(await tower.highestCleared(childId: childId, strand: Strand.geo), 0);
    expect(
      await tower.highestCleared(childId: 'be-khac', strand: Strand.logic),
      0,
    );
    final raw = await db.settingsDao.getValue(
      childId: childId,
      key: 'tower_floor.logic',
    );
    expect(raw, '1');
  });

  test('phát sự kiện khi qua tầng, không phát khi trượt', () async {
    final events = <TowerFloorCleared>[];
    final sub = TowerService.floorCleared.listen(events.add);
    addTearDown(sub.cancel);
    await clear(1, 1);
    await clear(1, 3);
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(1));
    expect(events.single.floor, 1);
    expect(events.single.firstClear, isTrue);
  });

  test('buildTowerFloor: 5 câu cùng bậc, kiểu trả lời theo bậc', () async {
    final service = DailySetService(
      dailySetsDao: db.dailySetsDao,
      reviewQueueDao: db.reviewQueueDao,
      ladderService: LadderService(
        attemptsDao: db.attemptsDao,
        skillProgressDao: db.skillProgressDao,
      ),
      clock: db.clock,
      random: Random(3),
    );
    for (final floor in [1, 5, 12, 30]) {
      final rung = TowerConfig.rungForFloor(floor);
      final qs = await service.buildTowerFloor(
        childId: childId,
        strand: Strand.arith,
        rung: rung,
      );
      expect(qs, hasLength(5));
      expect(qs.every((q) => q.rung == rung && q.strand == Strand.arith), true);
      expect(qs.every((q) => !q.isReview), isTrue);
    }
  });
}
