/// Hằng số cấu hình Hạng đấu trường theo tuần (spec tuần 23/11, mục B).
///
/// Mọi con số của hạng và rương cuối tuần nằm ở một chỗ này để chủ dự án
/// chỉnh sau. Tuần tính từ thứ Hai 00:00 đến Chủ nhật 23:59 giờ Việt Nam.
library;

/// Cờ nghệ thuật: false thì dùng icon Material cho huy hiệu hạng và rương;
/// true thì dùng ảnh `ui_league_<mã>.png`, `ui_chest_<mã>.png` khi họa sĩ
/// vẽ xong và ảnh được thêm vào `assets/images/ui/` (+ manifest).
const bool leagueArtReady = false;

/// Tiền tố khóa `settings` đánh dấu đã nhận rương tuần; đầy đủ là
/// `arena_week_claimed.<yyyy-mm-dd của thứ Hai>` (theo bé).
const String leagueClaimedKeyPrefix = 'arena_week_claimed.';

/// Hạng tuần.
enum LeagueTier {
  bronze('bronze', 'Đồng', 0, 2),
  silver('silver', 'Bạc', 40, 4),
  gold('gold', 'Vàng', 80, 7),
  diamond('diamond', 'Kim cương', 120, 12);

  const LeagueTier(this.code, this.label, this.minPoints, this.chestGems);

  /// Mã dùng cho tên ảnh.
  final String code;

  /// Tên hiển thị.
  final String label;

  /// Điểm tuần tối thiểu (số câu đúng cộng dồn). Đồng chỉ cần đã thi
  /// ít nhất 1 lần trong tuần, nên ngưỡng điểm là 0.
  final int minPoints;

  /// Số kim cương trong rương cuối tuần của hạng này (cố định).
  final int chestGems;

  /// Hạng kế tiếp; null nếu đã là cao nhất.
  LeagueTier? get next => index + 1 < LeagueTier.values.length
      ? LeagueTier.values[index + 1]
      : null;
}

/// Hạng theo điểm tuần và số lần thi trong tuần; null nếu tuần chưa thi.
LeagueTier? leagueTierFor({required int points, required int attempts}) {
  if (attempts < 1) return null;
  var tier = LeagueTier.bronze;
  for (final t in LeagueTier.values) {
    if (points >= t.minPoints) tier = t;
  }
  return tier;
}

/// Số ngày trong một tuần.
const int leagueWeekDays = 7;
