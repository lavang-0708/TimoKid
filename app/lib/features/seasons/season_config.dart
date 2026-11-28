/// Cấu hình Bộ sưu tập theo mùa (T5-02): MỌI con số, ngày và danh sách
/// món của các mùa nằm ở file này (một chỗ duy nhất) để chủ dự án chỉnh.
///
/// Luật:
/// - Mùa có một hoặc nhiều khoảng ngày (tính theo GIỜ VIỆT NAM, cả hai đầu
///   đều tính), hoặc lặp hằng năm (Giáng sinh). Ngoài mùa thì app y như cũ.
/// - Trong mùa: Thị trấn có biển "Mùa Tết!"..., Cửa hàng có tab "Bộ sưu tập
///   mùa" (chỉ hiện trong mùa), món thuộc mùa được nhãn ruy băng và GIẢM
///   [SeasonConfig.discountPercent]% (món vẫn mua được quanh năm với giá
///   thường), và xu của đề ngày được cộng thêm [SeasonConfig.questBonusPercent]%.
/// - Ngày âm lịch được TÍNH SẴN (thuật toán Hồ Ngọc Đức, múi giờ UTC+7,
///   đối chiếu bằng thiên văn `ephem`) và ghi cứng dưới đây cho 2027–2030:
///   Tết Nguyên đán (mùng 1 tháng Giêng) và Trung thu (15/8 âm lịch).
///   Lưu ý 2030: Việt Nam đón Tết 2/2 (Trung Quốc 3/2) vì trăng mới rơi
///   lúc 23:07 giờ Việt Nam ngày 2/2.
/// - Mùa Tết: 7 ngày trước đến 6 ngày sau mùng 1 (đủ 14 ngày). Trung thu:
///   7 ngày trước đến 1 ngày sau rằm. Giáng sinh: 15/12 đến 31/12 mỗi năm.
library;

/// Một khoảng ngày của mùa, cả hai đầu đều tính. Ngày dạng `YYYY-MM-DD`
/// (so sánh chuỗi được vì cùng định dạng, khớp `Clock.today`).
class SeasonWindow {
  const SeasonWindow(this.start, this.end);

  final String start;
  final String end;

  bool contains(String date) =>
      date.compareTo(start) >= 0 && date.compareTo(end) <= 0;
}

/// Khoảng ngày lặp mỗi năm (tháng/ngày, cả hai đầu đều tính).
class SeasonYearly {
  const SeasonYearly(
    this.startMonth,
    this.startDay,
    this.endMonth,
    this.endDay,
  );

  final int startMonth;
  final int startDay;
  final int endMonth;
  final int endDay;

  bool contains(String date) {
    final md = date.substring(5); // MM-DD
    String two(int n) => n.toString().padLeft(2, '0');
    return md.compareTo('${two(startMonth)}-${two(startDay)}') >= 0 &&
        md.compareTo('${two(endMonth)}-${two(endDay)}') <= 0;
  }
}

/// Định nghĩa một mùa.
class SeasonDef {
  const SeasonDef({
    required this.id,
    required this.name,
    required this.bannerTitle,
    required this.bannerSubtitle,
    required this.ribbon,
    required this.colorValue,
    this.windows = const [],
    this.yearly,
    this.roomThemeIds = const {},
    this.outfitNumbers = const {},
    this.itemIds = const {},
  });

  /// Mã mùa (`tet`, `trung_thu`, `giang_sinh`), cũng là giá trị QA.
  final String id;

  /// Tên đầy đủ, hiện trong menu QA và tab Cửa hàng.
  final String name;

  /// Dòng lớn của biển ở Thị trấn.
  final String bannerTitle;

  /// Dòng phụ của biển (nói rõ ưu đãi).
  final String bannerSubtitle;

  /// Chữ trên ruy băng ở góc thẻ món thuộc mùa.
  final String ribbon;

  /// Màu chủ đạo (0xAARRGGBB) của biển và ruy băng.
  final int colorValue;

  /// Các khoảng ngày cố định (mùa theo âm lịch).
  final List<SeasonWindow> windows;

  /// Khoảng lặp hằng năm (mùa theo dương lịch).
  final SeasonYearly? yearly;

  /// Mã chủ đề phòng thuộc mùa (bộ + mọi món lẻ), xem `room_themes.dart`.
  final Set<String> roomThemeIds;

  /// Số bộ đồ (1–11) thuộc mùa, cho cả hai dáng bé.
  final Set<int> outfitNumbers;

  /// Mã món lẻ khác thuộc mùa (thêm khi có hình mới).
  final Set<String> itemIds;

  /// Ngày [date] (`YYYY-MM-DD`, giờ Việt Nam) có trong mùa không.
  bool isActiveOn(String date) =>
      windows.any((w) => w.contains(date)) || (yearly?.contains(date) ?? false);
}

/// Toàn bộ hằng số mùa, ở một chỗ duy nhất.
class SeasonConfig {
  const SeasonConfig._();

  /// Giảm giá món thuộc mùa trong mùa (%).
  static const int discountPercent = 20;

  /// Xu thưởng thêm cho đề ngày trong mùa (%): cộng thêm vào xu mỗi câu
  /// đúng, xu xong chặng và xu xong đề ngày. Ghi sổ ví lý do `season_bonus`.
  static const int questBonusPercent = 50;

  static const SeasonDef tet = SeasonDef(
    id: 'tet',
    name: 'Tết Nguyên đán',
    bannerTitle: 'Mùa Tết!',
    bannerSubtitle: 'Đồ Tết giảm 20%, xu đề ngày +50%',
    ribbon: 'Mùa Tết',
    colorValue: 0xFFE53935,
    windows: [
      // Mùng 1: 6/2/2027, 26/1/2028, 13/2/2029, 2/2/2030 (giờ Việt Nam).
      SeasonWindow('2027-01-30', '2027-02-12'),
      SeasonWindow('2028-01-19', '2028-02-01'),
      SeasonWindow('2029-02-06', '2029-02-19'),
      SeasonWindow('2030-01-26', '2030-02-08'),
    ],
    roomThemeIds: {'tet'},
    outfitNumbers: {9},
  );

  static const SeasonDef trungThu = SeasonDef(
    id: 'trung_thu',
    name: 'Tết Trung thu',
    bannerTitle: 'Mùa Trung thu!',
    bannerSubtitle: 'Xu đề ngày +50%',
    ribbon: 'Trung thu',
    colorValue: 0xFFF9A825,
    windows: [
      // Rằm tháng 8: 15/9/2027, 3/10/2028, 22/9/2029, 12/9/2030.
      SeasonWindow('2027-09-08', '2027-09-16'),
      SeasonWindow('2028-09-26', '2028-10-04'),
      SeasonWindow('2029-09-15', '2029-09-23'),
      SeasonWindow('2030-09-05', '2030-09-13'),
    ],
    // Chưa có hình riêng cho Trung thu: thêm mã món vào đây khi có.
  );

  static const SeasonDef giangSinh = SeasonDef(
    id: 'giang_sinh',
    name: 'Giáng sinh',
    bannerTitle: 'Mùa Giáng sinh!',
    bannerSubtitle: 'Xu đề ngày +50%',
    ribbon: 'Giáng sinh',
    colorValue: 0xFF2E7D32,
    yearly: SeasonYearly(12, 15, 12, 31),
    // Chưa có hình riêng cho Giáng sinh: thêm mã món vào đây khi có.
  );

  /// Mọi mùa, theo thứ tự ưu tiên khi hai mùa trùng ngày (không xảy ra
  /// với ngày hiện tại).
  static const List<SeasonDef> all = [tet, trungThu, giangSinh];

  /// Mùa theo mã; null nếu không có.
  static SeasonDef? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}
