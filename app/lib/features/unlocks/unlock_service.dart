/// Mở khóa theo số dạng bài thành thạo (T4-04).
///
/// Trạng thái mở khóa SUY RA từ số dạng thành thạo (`skill_progress`) nên
/// không có dữ liệu riêng cần đồng bộ; chỉ có hai thứ được ghi:
/// - món quà Phòng: một dòng `inventory` (nguồn `unlock`, cấp một lần);
/// - cờ "đã chúc mừng" `unlock_seen.<mã mốc>` trong `settings` của bé.
library;

import '../../core/database/app_database.dart';
import 'unlock_config.dart';

/// Nguồn của món trong kho đồ do mở khóa tặng.
const String unlockInventorySource = 'unlock';

const String _seenPrefix = 'unlock_seen.';

class UnlockService {
  UnlockService({required this.db});

  final AppDatabase db;

  /// Lời thoại đặc biệt đã mở chưa, theo số dạng thành thạo [count].
  static bool specialDialogueUnlocked(int count) =>
      count >= UnlockConfig.specialDialogueThreshold;

  /// Các mốc đã mở khi bé thành thạo [count] dạng.
  static List<UnlockTier> unlockedTiers(int count) => [
    for (final t in UnlockConfig.tiers)
      if (count >= t.threshold) t,
  ];

  /// Mốc kế tiếp chưa mở; null nếu đã mở hết.
  static UnlockTier? nextTier(int count) {
    for (final t in UnlockConfig.tiers) {
      if (count < t.threshold) return t;
    }
    return null;
  }

  /// Dòng tiến độ: "Còn N dạng nữa để mở ..." hoặc lời chúc khi đã mở hết.
  static String progressText(int count) {
    final next = nextTier(count);
    if (next == null) return 'Bé đã mở hết mọi phần thưởng thành thạo!';
    return 'Còn ${next.threshold - count} dạng nữa để mở ${next.name}';
  }

  /// Số dạng bài bé đã thành thạo.
  Future<int> masteredCount(String childId) async =>
      (await db.skillProgressDao.getMasteredForms(childId)).length;

  /// Cấp phần thưởng đã tới mốc (hiện chỉ có quà Phòng; cấp lại không có
  /// tác dụng). Trả true nếu vừa cấp món mới.
  Future<bool> grantRewards(String childId) async {
    final count = await masteredCount(childId);
    var granted = false;
    for (final t in unlockedTiers(count)) {
      if (t.has(UnlockReward.roomGift)) {
        final added = await db.inventoryDao.grant(
          childId: childId,
          itemId: UnlockConfig.roomGiftItemId,
          source: unlockInventorySource,
        );
        granted = granted || added;
      }
    }
    return granted;
  }

  /// Các mốc đã mở mà bé chưa được chúc mừng.
  Future<List<UnlockTier>> pendingCelebrations(String childId) async {
    final count = await masteredCount(childId);
    final result = <UnlockTier>[];
    for (final t in unlockedTiers(count)) {
      final seen = await db.settingsDao.getValue(
        childId: childId,
        key: '$_seenPrefix${t.id}',
      );
      if (seen == null) result.add(t);
    }
    return result;
  }

  /// Đánh dấu đã chúc mừng.
  Future<void> markSeen(String childId, Iterable<UnlockTier> tiers) async {
    for (final t in tiers) {
      await db.settingsDao.setValue(
        childId: childId,
        key: '$_seenPrefix${t.id}',
        value: '1',
      );
    }
  }
}
