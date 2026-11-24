/// Hằng số cấu hình của Tháp nhiều tầng + boss (tuần 23/11, mục A).
///
/// Mọi con số của tháp nằm ở đúng một chỗ này — không viết cứng rải
/// rác trong service, màn hình hay test. Đổi luật chỉ cần sửa file này.
///
/// Luật:
/// - Mỗi tòa nhà (mảng) có [floorsPerTower] tầng. Chặng ngày giữ
///   nguyên; xong chặng ngày của tòa thì nút "Thử thách" thành
///   "Leo tầng N".
/// - Tầng n gồm [questionsPerFloor] câu của mảng, bậc
///   `min(maxRung, 1 + (n-1) ~/ floorsPerRung)` (xem [rungForFloor]).
/// - Tầng boss (chia hết cho [bossEvery]): bậc +1 (tối đa [maxRung]),
///   cần đúng ngay lần đầu [bossPassNeeded]/5; tầng thường cần
///   [normalPassNeeded]/5. Trượt thì thử lại ngay, câu mới.
/// - Thưởng chỉ ở lần qua đầu tiên của mỗi tầng; xu từng câu vẫn
///   tính như chặng thường.
library;

/// Cờ ảnh tháp: `ui_tower_lock`, `ui_tower_boss` chưa có (Muse đang
/// vẽ lô 13). Tắt thì màn Tòa nhà dùng icon Material tạm. Khi ảnh về:
/// thêm file vào `assets/` + `manifest.json`, đặt cờ `true`.
const bool towerArtReady = true;

/// Toàn bộ hằng số của tháp, ở một chỗ duy nhất.
class TowerConfig {
  const TowerConfig._();

  /// Ảnh ổ khóa / huy hiệu boss, chỉ dùng khi [towerArtReady].
  static const String lockAsset = 'assets/images/ui/ui_tower_lock.png';
  static const String bossAsset = 'assets/images/ui/ui_tower_boss.png';

  /// Số tầng của mỗi tháp (mỗi mảng một tháp).
  static const int floorsPerTower = 30;

  /// Số câu mỗi tầng.
  static const int questionsPerFloor = 5;

  /// Cứ bấy nhiêu tầng thì tăng một bậc (tầng 1–5 bậc 1, 6–10 bậc 2…).
  static const int floorsPerRung = 5;

  /// Bậc thấp nhất / cao nhất của thang ải.
  static const int minRung = 1;
  static const int maxRung = 6;

  /// Tầng chia hết cho số này là tầng boss.
  static const int bossEvery = 5;

  /// Số câu đúng ngay lần đầu (trên [questionsPerFloor]) để qua tầng
  /// thường / tầng boss.
  static const int normalPassNeeded = 3;
  static const int bossPassNeeded = 4;

  /// Thưởng lần qua đầu tiên: tầng thường.
  static const int normalFirstClearXu = 10;

  /// Thưởng lần qua đầu tiên: tầng boss.
  static const int bossFirstClearXu = 20;
  static const int bossFirstClearGems = 1;

  /// Tầng đỉnh (tầng cuối): kim cương THAY cho kim cương tầng boss
  /// (tầng 30 vốn cũng là tầng boss); xu vẫn theo tầng boss.
  static const int summitFirstClearGems = 3;

  /// Khóa `settings` (theo bé) lưu tầng cao nhất đã qua của một mảng.
  static String settingsKey(String strand) => 'tower_floor.$strand';

  /// Khóa `settings` (theo bé) đếm số lượt qua tầng trong một ngày
  /// (giờ Việt Nam) — cho nhiệm vụ ngày "leo qua 1 tầng tháp".
  static String clearsKey(String date) => 'tower_clears.$date';

  /// `refId` của dòng ví thưởng lần đầu — chống cộng trùng.
  static String rewardRefId({
    required String childId,
    required String strand,
    required int floor,
  }) => 'tower:$childId:$strand:$floor';

  /// Tầng [floor] có phải tầng boss không.
  static bool isBoss(int floor) => floor % bossEvery == 0;

  /// Tầng [floor] có phải tầng đỉnh không.
  static bool isSummit(int floor) => floor == floorsPerTower;

  /// Bậc của câu ở tầng [floor] (1–[floorsPerTower]); boss +1, kẹp
  /// tối đa [maxRung].
  static int rungForFloor(int floor) {
    assert(floor >= 1 && floor <= floorsPerTower, 'Tầng ngoài 1–30: $floor');
    final base = 1 + (floor - 1) ~/ floorsPerRung;
    final rung = isBoss(floor) ? base + 1 : base;
    return rung.clamp(minRung, maxRung);
  }

  /// Số câu đúng ngay lần đầu cần để qua tầng [floor].
  static int passNeeded(int floor) =>
      isBoss(floor) ? bossPassNeeded : normalPassNeeded;

  /// Xu thưởng lần qua đầu tiên của tầng [floor].
  static int firstClearXu(int floor) =>
      isBoss(floor) ? bossFirstClearXu : normalFirstClearXu;

  /// Kim cương thưởng lần qua đầu tiên của tầng [floor].
  static int firstClearGems(int floor) {
    if (isSummit(floor)) return summitFirstClearGems;
    return isBoss(floor) ? bossFirstClearGems : 0;
  }
}
