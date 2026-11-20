/// Định nghĩa 5 khu của Thị trấn Diệu Kỳ (T1-12) + bản đồ v2 (A2).
///
/// Tên khu theo DESIGN.md ("Phòng và thị trấn"); thứ tự khu = thứ tự
/// chặng trong đề ngày ([Strand.all]: Lôgic, Số học, Con số, Hình học,
/// Tổ hợp).
///
/// Hình khu là file SVG vẽ mới cùng phong cách pastel mềm, viền trắng
/// kiểu sticker (PLAN điểm (k)) — từ A2, màn Thị trấn dùng bản đồ
/// phong cách v2 nên SVG không còn hiện trên màn (công trình trên nền
/// là hình nhận diện); 5 file SVG + dòng manifest giữ nguyên để sau
/// dùng lại nếu cần, không xóa.
///
/// Từ A2, mỗi khu gắn với MỘT công trình trên nền thị trấn v2
/// (`town_v2.png`, khung 1600x900): vùng bấm là hình chữ nhật của
/// công trình đó (tọa độ tỉ lệ 0..1 so với khung nền, xem
/// `docs/ASSETS.md` mục "Thị trấn v2"). Nhà hồng là nhà của bé —
/// bấm vào thì về Phòng, không phải một khu toán.
///
/// Map khu vực ↔ công trình (A2):
/// - Lâu đài Lôgic → trường học (tòa nhà lớn nhất, có tháp chuông,
///   dáng như lâu đài); Tiệm bánh Số học → tiệm bánh (trùng tên);
///   Vườn Hình học → công viên (khu vườn có xích đu/cầu trượt).
/// - Tháp Con số → cửa hàng thú cưng và Hội chợ Tổ hợp → tiệm quần
///   áo là CHƯA CHẮC (chỉ là loại trừ: trong ảnh không có tháp hay
///   hội chợ; tổ hợp → tiệm quần áo vì kết hợp áo/quần/giày thành
///   bộ đồ; con số → cửa hàng thú cưng vì còn lại) — ghi rõ trong
///   thân PR A2 để Claude quyết, xem `docs/ASSETS.md` mục
///   "Thị trấn v2".
library;

import 'dart:ui';

import '../../core/database/tables.dart';

/// Một khu trong Thị trấn: công trình trên bản đồ dẫn vào chặng
/// tương ứng của đề ngày.
class TownArea {
  const TownArea({
    required this.strand,
    required this.name,
    required this.asset,
    required this.color,
    required this.building,
  });

  /// Mảng của khu (cũng là mảng của chặng cùng vị trí trong đề ngày).
  final String strand;

  /// Tên khu, hiện trên nhãn dán ở công trình.
  final String name;

  /// Đường dẫn asset SVG của biểu tượng khu (T1-12; từ A2 không còn
  /// hiện trên màn Thị trấn — công trình trên nền là hình nhận diện).
  final String asset;

  /// Màu pastel của khu (giá trị màu ARGB): dùng làm viền nhãn dán
  /// trên bản đồ.
  final int color;

  /// Hình chữ nhật công trình trên nền thị trấn v2, tọa độ tỉ lệ
  /// 0..1 so với khung nền 1600x900 (left, top, width, height).
  final Rect building;
}

/// 5 khu theo đúng thứ tự chặng của đề ngày.
const List<TownArea> townAreas = [
  TownArea(
    strand: Strand.logic,
    name: 'Lâu đài Lôgic',
    asset: 'assets/images/area_logic.svg',
    color: 0xFFC9B8F0,
    // Trường học xanh, tháp chuông (x 585–945, y 95–375).
    building: Rect.fromLTWH(585 / 1600, 95 / 900, 360 / 1600, 280 / 900),
  ),
  TownArea(
    strand: Strand.arith,
    name: 'Tiệm bánh Số học',
    asset: 'assets/images/area_arith.svg',
    color: 0xFFFFD9C0,
    // Tiệm bánh vàng, biển bánh sừng bò (x 315–670, y 320–565).
    building: Rect.fromLTWH(315 / 1600, 320 / 900, 355 / 1600, 245 / 900),
  ),
  TownArea(
    strand: Strand.number,
    name: 'Tháp Con số',
    asset: 'assets/images/area_number.svg',
    color: 0xFFBFE0F5,
    // Cửa hàng thú cưng xanh lá, biển dấu chân (x 1260–1550,
    // y 450–680). CHƯA CHẮC — xem chú thích đầu file.
    building: Rect.fromLTWH(1260 / 1600, 450 / 900, 290 / 1600, 230 / 900),
  ),
  TownArea(
    strand: Strand.geo,
    name: 'Vườn Hình học',
    asset: 'assets/images/area_geo.svg',
    color: 0xFFBFE8CF,
    // Công viên: xích đu, cầu trượt, cây anh đào — bóng dáng đo
    // được tới x = 1440, nhưng vùng bấm CẮT BỚT ở mép phải (x = 1260,
    // mép trái cửa hàng thú cưng) để không chồng lên vùng bấm thú
    // cưng: tâm vùng thú cưng (1405, 565) nằm trong rect cũ nên tap
    // chặng 2 rơi nhầm sang chặng 3 (bắt bằng test thị trấn).
    building: Rect.fromLTWH(860 / 1600, 300 / 900, 400 / 1600, 280 / 900),
  ),
  TownArea(
    strand: Strand.comb,
    name: 'Hội chợ Tổ hợp',
    asset: 'assets/images/area_comb.svg',
    color: 0xFFFFD166,
    // Tiệm quần áo tím, mái sọc hồng-trắng (x 660–990, y 490–730).
    // CHƯA CHẮC — xem chú thích đầu file.
    building: Rect.fromLTWH(660 / 1600, 490 / 900, 330 / 1600, 240 / 900),
  ),
];

/// Nhà hồng của bé trên nền thị trấn v2 (góc trái dưới, có hàng rào
/// trắng): bấm vào thì về Phòng. Tọa độ tỉ lệ 0..1 so với khung nền
/// 1600x900 (x 95–395, y 545–770).
const Rect roomBuildingRect = Rect.fromLTWH(
  95 / 1600,
  545 / 900,
  300 / 1600,
  225 / 900,
);

/// Đường dẫn asset PNG nền thị trấn v2 (A2).
const String townBackgroundAsset = 'assets/images/backgrounds/town_v2.png';

/// Đường dẫn asset PNG 10 lớp động trên bản đồ thị trấn v2 (A2):
/// mây ×3, xe ×2, đài phun nước, cây ×2, người ×2. Dùng để test
/// golden nạp trước ảnh (mẫu `room_golden_test.dart`) — phải khớp
/// các spec trong `town_map.dart`.
const List<String> townLayerAssets = [
  'assets/images/town/cloud_01.png',
  'assets/images/town/cloud_02.png',
  'assets/images/town/cloud_03.png',
  'assets/images/town/car_01.png',
  'assets/images/town/car_02.png',
  'assets/images/town/fountain.png',
  'assets/images/town/tree_01.png',
  'assets/images/town/tree_02.png',
  'assets/images/town/person_01.png',
  'assets/images/town/person_02.png',
];
