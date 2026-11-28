/// Cấu hình mở khóa theo số dạng bài bé đã THÀNH THẠO (T4-04): ngưỡng và
/// phần thưởng nằm hết ở file này (một chỗ duy nhất, chủ dự án chỉnh được).
///
/// Bốn mốc, mỗi mốc mở một thứ bé nhìn thấy được:
/// 1. [UnlockReward.goldFrame] + [UnlockReward.specialDialogue]: khung vàng
///    cho sổ sticker và lời thoại đặc biệt của cư dân.
/// 2. [UnlockReward.townDecor]: đài phun nước xuất hiện ở Thị trấn.
/// 3. [UnlockReward.roomGift]: quà cho Phòng (một món biến thể chủ đề).
/// 4. [UnlockReward.title]: danh hiệu cạnh tên nhân vật.
library;

import '../room/room_variants.dart';

/// Đã có hình cho phần thưởng mở khóa (khung vàng sổ sticker, đài phun
/// nước ở Thị trấn, huy hiệu danh hiệu) chưa. `false`: vẽ bằng code. Khi
/// Muse giao lô 17 (`docs/briefs/lot17_v04.md`): thêm
/// `assets/images/unlocks/` vào `pubspec.yaml` rồi đặt `true`.
const bool unlockArtReady = true;

/// Loại phần thưởng của một mốc.
enum UnlockReward { goldFrame, specialDialogue, townDecor, roomGift, title }

class UnlockTier {
  const UnlockTier({
    required this.id,
    required this.threshold,
    required this.rewards,
    required this.name,
    required this.description,
  });

  /// Mã mốc, dùng làm khóa `unlock_seen.<id>` (đã chúc mừng).
  final String id;

  /// Số dạng bài thành thạo để mở.
  final int threshold;
  final List<UnlockReward> rewards;

  /// Tên phần thưởng, đọc được sau "Còn N dạng nữa để mở ...".
  final String name;

  /// Lời mô tả ngắn khi chúc mừng.
  final String description;

  bool has(UnlockReward r) => rewards.contains(r);
}

class UnlockConfig {
  const UnlockConfig._();

  static const List<UnlockTier> tiers = [
    UnlockTier(
      id: 'gold_frame',
      threshold: 5,
      rewards: [UnlockReward.goldFrame, UnlockReward.specialDialogue],
      name: 'khung vàng cho sổ sticker',
      description: 'Các cư dân cũng có lời nói đặc biệt với bé.',
    ),
    UnlockTier(
      id: 'town_fountain',
      threshold: 12,
      rewards: [UnlockReward.townDecor],
      name: 'đài phun nước ở Thị trấn',
      description: 'Bé ghé Thị trấn xem nhé!',
    ),
    UnlockTier(
      id: 'room_gift',
      threshold: 20,
      rewards: [UnlockReward.roomGift],
      name: 'quà tặng cho Phòng',
      description: 'Bé nhận được gấu bông Tết để đặt vào Phòng.',
    ),
    UnlockTier(
      id: 'title_mathkid',
      threshold: 30,
      rewards: [UnlockReward.title],
      name: 'danh hiệu Nhà toán học nhí',
      description: 'Tên bé có thêm danh hiệu mới.',
    ),
  ];

  /// Ngưỡng của lời thoại đặc biệt (lấy từ mốc có [UnlockReward.specialDialogue]).
  static int get specialDialogueThreshold =>
      tiers.firstWhere((t) => t.has(UnlockReward.specialDialogue)).threshold;

  /// Ngưỡng của khung vàng sổ sticker.
  static int get goldFrameThreshold =>
      tiers.firstWhere((t) => t.has(UnlockReward.goldFrame)).threshold;

  /// Ngưỡng của đài phun nước.
  static int get townDecorThreshold =>
      tiers.firstWhere((t) => t.has(UnlockReward.townDecor)).threshold;

  /// Ngưỡng của danh hiệu.
  static int get titleThreshold =>
      tiers.firstWhere((t) => t.has(UnlockReward.title)).threshold;

  /// Danh hiệu hiện trên nhân vật.
  static const String titleText = 'Nhà toán học nhí';

  /// Món quà của mốc [UnlockReward.roomGift]: mã món trong kho đồ
  /// (`inventory`). Gấu bông chủ đề Tết, tặng một lần.
  static final String roomGiftItemId = roomThemeVariantItemId(
    'tet',
    'gau-bong',
  );

  /// Tên món quà (hiện khi chúc mừng).
  static const String roomGiftName = 'Gấu bông Tết';

  /// Ảnh khi [unlockArtReady] bật (xem brief lô 17).
  static const String goldFrameAsset =
      'assets/images/unlocks/sticker_book_gold_frame.webp';
  static const String fountainAsset =
      'assets/images/unlocks/town_fountain.webp';
  static const String titleBadgeAsset =
      'assets/images/unlocks/title_badge.webp';
}
