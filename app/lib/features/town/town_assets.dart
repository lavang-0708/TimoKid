/// Định nghĩa 5 khu của Thị trấn Diệu Kỳ (T1-12) + bản đồ v2 (A2)
/// + bản đồ v3b (C).
///
/// Tên khu theo DESIGN.md ("Phòng và thị trấn"); thứ tự khu = thứ tự
/// chặng trong đề ngày ([Strand.all]: Lôgic, Số học, Con số, Hình học,
/// Tổ hợp).
///
/// Hình khu là file SVG vẽ mới cùng phong cách pastel mềm, viền trắng
/// kiểu sticker (PLAN điểm (k)) — từ A2, màn Thị trấn dùng bản đồ
/// phong cách v2/v3b nên SVG không còn hiện trên màn (công trình trên
/// nền là hình nhận diện); 5 file SVG + dòng manifest giữ nguyên để
/// sau dùng lại nếu cần, không xóa.
///
/// Từ A2, mỗi khu gắn với MỘT công trình trên nền thị trấn
/// (khung 1600x900): vùng bấm là hình chữ nhật của công trình đó
/// (tọa độ tỉ lệ 0..1 so với khung nền, xem `docs/ASSETS.md`).
/// Nhà hồng là nhà của bé — bấm vào thì về Phòng, không phải một
/// khu toán.
///
/// Map mảng ↔ công trình (v3b, giữ nguyên như A2):
/// - Lôgic → Lâu đài Lôgic (xanh đá, có cờ);
///   Số học → Tiệm bánh Số học (vàng, biển bánh sừng bò);
///   Hình học → Vườn Hình học (bồn cây + đồ chơi khối).
/// - Con số → Tháp Con số (vàng, đồng hồ) và Tổ hợp → Hội chợ
///   Tổ hợp (lều sọc + vòng quay): ở v2 hai chỗ này là CHƯA CHẮC
///   (trong ảnh v2 không có tháp hay hội chợ nên tạm map Con số →
///   cửa hàng thú cưng, Tổ hợp → tiệm quần áo). Bản v3b đã vẽ
///   đúng 2 công trình này nên map trên là map trực tiếp theo tên
///   công trình — không còn là loại trừ nữa. Nếu chủ dự án đổi ý
///   thì đổi ở đây, không đổi code.
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

  /// Hình chữ nhật công trình trên nền thị trấn v3b, tọa độ tỉ lệ
  /// 0..1 so với khung nền 1600x900 (left, top, width, height).
  final Rect building;
}

/// 5 khu theo đúng thứ tự chặng của đề ngày.
///
/// Vùng bấm đo từ nền v3b thật (`docs/C_IMAGES.md`, khung 1600x900;
/// xem `docs/ASSETS.md` mục "Thị trấn v3b" về lý do cắt từng rect):
/// - Lâu đài giữ nguyên; Tiệm bánh giữ nguyên.
/// - Tháp Con số cắt trái 520→620 (khỏi che nhãn Lâu đài) và kéo
///   lên y=5 để bao cả thân tháp + đồng hồ + chóp.
/// - Vườn Hình học cắt trên 520→565 (khỏi che nhãn Tiệm bánh).
/// - Hội chợ Tổ hợp cắt trái 1020→1080 (khỏi che nhãn Tháp Con số).
/// - Nhà của bé cắt trên 525→565 và phải 490→480 (khỏi che nhãn
///   Tiệm bánh và Vườn Hình học).
const List<TownArea> townAreas = [
  TownArea(
    strand: Strand.logic,
    name: 'Lâu đài Lôgic',
    asset: 'assets/images/area_logic.svg',
    color: 0xFFC9B8F0,
    // Lâu đài xanh đá, có cờ (x 165–615, y 0–290).
    building: Rect.fromLTWH(165 / 1600, 0 / 900, 450 / 1600, 290 / 900),
  ),
  TownArea(
    strand: Strand.arith,
    name: 'Tiệm bánh Số học',
    asset: 'assets/images/area_arith.svg',
    color: 0xFFFFD9C0,
    // Tiệm bánh vàng, biển bánh sừng bò (x 290–640, y 305–560).
    building: Rect.fromLTWH(290 / 1600, 305 / 900, 350 / 1600, 255 / 900),
  ),
  TownArea(
    strand: Strand.number,
    name: 'Tháp Con số',
    asset: 'assets/images/area_number.svg',
    color: 0xFFBFE0F5,
    // Tháp vàng, đồng hồ mặt số (x 620–1080, y 5–390). V2 map
    // tạm sang cửa hàng thú cưng (CHƯA CHẮC); v3b có tháp thật
    // nên map trực tiếp — xem chú thích đầu file.
    building: Rect.fromLTWH(620 / 1600, 5 / 900, 460 / 1600, 385 / 900),
  ),
  TownArea(
    strand: Strand.geo,
    name: 'Vườn Hình học',
    asset: 'assets/images/area_geo.svg',
    color: 0xFFBFE8CF,
    // Vườn: bồn cây + đồ chơi khối lập phương/kim tự tháp/cầu
    // (x 480–925, y 565–745).
    building: Rect.fromLTWH(480 / 1600, 565 / 900, 445 / 1600, 180 / 900),
  ),
  TownArea(
    strand: Strand.comb,
    name: 'Hội chợ Tổ hợp',
    asset: 'assets/images/area_comb.svg',
    color: 0xFFFFD166,
    // Hội chợ: lều sọc + vòng quay ngựa gỗ (x 1080–1560, y 5–380).
    // V2 map tạm sang tiệm quần áo (CHƯA CHẮC); v3b có hội chợ
    // thật nên map trực tiếp — xem chú thích đầu file.
    building: Rect.fromLTWH(1080 / 1600, 5 / 900, 480 / 1600, 375 / 900),
  ),
];

/// Nhà hồng của bé trên nền thị trấn v3b (góc trái dưới, có hàng rào
/// trắng): bấm vào thì về Phòng. Tọa độ tỉ lệ 0..1 so với khung nền
/// 1600x900 (x 35–480, y 565–855).
const Rect roomBuildingRect = Rect.fromLTWH(
  35 / 1600,
  565 / 900,
  445 / 1600,
  290 / 900,
);

/// Đường dẫn asset PNG nền thị trấn v3b (C, 1600x900, đường + vỉa hè
/// TRỐNG — không vẽ sẵn xe/người; app vẽ lớp động chạy theo đường).
const String townBackgroundAsset = 'assets/images/backgrounds/town_v3.png';

/// Đường dẫn asset PNG 17 lớp động trên bản đồ thị trấn v3b (C):
/// mây ×3, xe ×4 (2 xe × 2 hướng dr/ur), người ×8 (2 người × 2
/// hướng × 2 khung bước chân a/b), cây ×2. Dùng để test golden nạp
/// trước ảnh (mẫu `room_golden_test.dart`) — phải khớp các spec
/// trong `town_map.dart`.
///
/// Xe/người chỉ hiện 1 biến thể tại một thời điểm (theo hướng đang
/// đi + khung bước chân); `ur` là góc nhìn từ sau — xem
/// `town_roads.dart`. Không còn đài phun nước (thị trấn v3b có ao,
/// không có đài phun); 4 file nhìn ngang cũ (car_01, car_02,
/// person_01, person_02) không dùng nữa — Claude git rm (xem
/// HANDOVER), town_v2.png + fountain.png giữ lại trong manifest
/// vì file vẫn còn (như tiền lệ town_01.jpg).
const List<String> townLayerAssets = [
  'assets/images/town/cloud_01.png',
  'assets/images/town/cloud_02.png',
  'assets/images/town/cloud_03.png',
  'assets/images/town/car_01_dr.png',
  'assets/images/town/car_01_ur.png',
  'assets/images/town/car_02_dr.png',
  'assets/images/town/car_02_ur.png',
  'assets/images/town/person_01_dr_a.png',
  'assets/images/town/person_01_dr_b.png',
  'assets/images/town/person_01_ur_a.png',
  'assets/images/town/person_01_ur_b.png',
  'assets/images/town/person_02_dr_a.png',
  'assets/images/town/person_02_dr_b.png',
  'assets/images/town/person_02_ur_a.png',
  'assets/images/town/person_02_ur_b.png',
  'assets/images/town/tree_01.png',
  'assets/images/town/tree_02.png',
];
