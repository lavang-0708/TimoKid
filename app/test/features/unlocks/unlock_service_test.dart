/// Mở khóa theo số dạng bài thành thạo (T4-04): ngưỡng, tiến độ, quà Phòng
/// cấp một lần, chúc mừng một lần.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/features/stickers/sticker_service.dart';
import 'package:timokid/features/unlocks/unlock_config.dart';
import 'package:timokid/features/unlocks/unlock_service.dart';

void main() {
  late AppDatabase db;
  late String childId;
  late UnlockService service;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    service = UnlockService(db: db);
  });

  Future<void> master(int n) async {
    for (final f in allFormIds.take(n)) {
      await db.skillProgressDao.setFormMastered(
        childId: childId,
        formId: f,
        mastered: true,
      );
    }
  }

  test('ngưỡng nằm một chỗ: 5 / 12 / 20 / 30, tăng dần, mỗi mốc có thưởng', () {
    expect(UnlockConfig.tiers.map((t) => t.threshold), [5, 12, 20, 30]);
    expect(UnlockConfig.goldFrameThreshold, 5);
    expect(UnlockConfig.specialDialogueThreshold, 5);
    expect(UnlockConfig.townDecorThreshold, 12);
    expect(UnlockConfig.titleThreshold, 30);
    for (final t in UnlockConfig.tiers) {
      expect(t.rewards, isNotEmpty);
      expect(t.name, isNotEmpty);
    }
    final ids = UnlockConfig.tiers.map((t) => t.id).toSet();
    expect(ids, hasLength(UnlockConfig.tiers.length));
  });

  test('unlockedTiers và nextTier theo số dạng thành thạo', () {
    expect(UnlockService.unlockedTiers(0), isEmpty);
    expect(UnlockService.unlockedTiers(4), isEmpty);
    expect(UnlockService.unlockedTiers(5).map((t) => t.id), ['gold_frame']);
    expect(UnlockService.unlockedTiers(11), hasLength(1));
    expect(UnlockService.unlockedTiers(12), hasLength(2));
    expect(UnlockService.unlockedTiers(20), hasLength(3));
    expect(UnlockService.unlockedTiers(29), hasLength(3));
    expect(UnlockService.unlockedTiers(30), hasLength(4));
    expect(UnlockService.nextTier(0)!.threshold, 5);
    expect(UnlockService.nextTier(5)!.threshold, 12);
    expect(UnlockService.nextTier(29)!.threshold, 30);
    expect(UnlockService.nextTier(30), isNull);
    expect(UnlockService.specialDialogueUnlocked(4), isFalse);
    expect(UnlockService.specialDialogueUnlocked(5), isTrue);
  });

  test('dòng tiến độ "Còn N dạng nữa để mở ..."', () {
    expect(
      UnlockService.progressText(2),
      'Còn 3 dạng nữa để mở khung vàng cho sổ sticker',
    );
    expect(
      UnlockService.progressText(5),
      'Còn 7 dạng nữa để mở đài phun nước ở Thị trấn',
    );
    expect(UnlockService.progressText(30), contains('mở hết'));
  });

  test('masteredCount đếm dạng thành thạo trong DB', () async {
    expect(await service.masteredCount(childId), 0);
    await master(7);
    expect(await service.masteredCount(childId), 7);
  });

  test('quà Phòng: chưa tới mốc không cấp; tới mốc cấp đúng một lần', () async {
    await master(19);
    expect(await service.grantRewards(childId), isFalse);
    expect(
      await db.inventoryDao.has(childId, UnlockConfig.roomGiftItemId),
      isFalse,
    );
    await master(20);
    expect(await service.grantRewards(childId), isTrue);
    expect(
      await db.inventoryDao.has(childId, UnlockConfig.roomGiftItemId),
      isTrue,
    );
    // Gọi lại: không cấp thêm, kho đồ vẫn một dòng.
    expect(await service.grantRewards(childId), isFalse);
    final owned = (await db.inventoryDao.getAll(childId))
        .where((i) => i.itemId == UnlockConfig.roomGiftItemId);
    expect(owned, hasLength(1));
    expect(owned.single.source, unlockInventorySource);
  });

  test('chúc mừng mốc: hiện một lần rồi hết', () async {
    await master(12);
    final first = await service.pendingCelebrations(childId);
    expect(first.map((t) => t.id), ['gold_frame', 'town_fountain']);
    await service.markSeen(childId, first);
    expect(await service.pendingCelebrations(childId), isEmpty);
    await master(20);
    expect((await service.pendingCelebrations(childId)).map((t) => t.id), [
      'room_gift',
    ]);
  });
}
