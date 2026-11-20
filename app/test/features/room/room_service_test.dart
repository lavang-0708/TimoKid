/// Unit test cho cổng mỗi ngày của màn Phòng (T2-04):
/// [RoomService] khóa/mở theo trạng thái đề ngày, kể cả qua ngày mới.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/room/room_service.dart';

AppDatabase openMemoryDb({Clock? clock}) => AppDatabase(
  executor: NativeDatabase.memory(),
  clock: clock ?? const SystemClock(),
);

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late RoomService room;

  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 18, 8, 0));
    db = openMemoryDb(clock: clock);
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    room = RoomService(db: db);
  });

  /// Tạo đề ngày hôm nay (5 chặng, chưa làm) và trả về id đề.
  Future<String> createTodaySet() async {
    final service = DailySetService(
      dailySetsDao: db.dailySetsDao,
      reviewQueueDao: db.reviewQueueDao,
      ladderService: LadderService(
        attemptsDao: db.attemptsDao,
        skillProgressDao: db.skillProgressDao,
      ),
      clock: clock,
    );
    final set = await service.getOrCreateTodaySet(childId: childId);
    return set.id;
  }

  Future<void> markDone(String setId, int count) async {
    for (var i = 0; i < count; i++) {
      await db.dailySetsDao.updateStageStatus(
        id: setId,
        stageIndex: i,
        status: StageStatus.done,
      );
    }
  }

  test('chưa có đề ngày thì khóa (0/5)', () async {
    expect(await room.isPlayUnlocked(childId), isFalse);
    expect(await room.doneStageCount(childId), 0);
  });

  test('đề ngày chưa xong (0/5) thì khóa', () async {
    await createTodaySet();

    expect(await room.isPlayUnlocked(childId), isFalse);
    expect(await room.doneStageCount(childId), 0);
  });

  test('xong 4/5 chặng vẫn khóa', () async {
    final setId = await createTodaySet();
    await markDone(setId, 4);

    expect(await room.isPlayUnlocked(childId), isFalse);
    expect(await room.doneStageCount(childId), 4);
  });

  test('xong cả 5 chặng thì mở', () async {
    final setId = await createTodaySet();
    await markDone(setId, 5);

    expect(await room.isPlayUnlocked(childId), isTrue);
    expect(await room.doneStageCount(childId), 5);
  });

  test('qua ngày mới (đề mới chưa xong) khóa lại', () async {
    final setId = await createTodaySet();
    await markDone(setId, 5);
    expect(await room.isPlayUnlocked(childId), isTrue);

    clock.advance(const Duration(days: 1));

    expect(await room.isPlayUnlocked(childId), isFalse);
    expect(await room.doneStageCount(childId), 0);
  });

  test('qua ngày mới xong đề mới thì mở lại', () async {
    final setId = await createTodaySet();
    await markDone(setId, 5);
    clock.advance(const Duration(days: 1));

    final newSetId = await createTodaySet();
    expect(newSetId, isNot(setId));
    await markDone(newSetId, 5);

    expect(await room.isPlayUnlocked(childId), isTrue);
    expect(await room.doneStageCount(childId), 5);
  });
}
