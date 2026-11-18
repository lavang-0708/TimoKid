/// Định nghĩa 5 khu của Thị trấn Diệu Kỳ (T1-12).
///
/// Tên khu theo DESIGN.md ("Phòng và thị trấn"); thứ tự khu = thứ tự
/// chặng trong đề ngày ([Strand.all]: Lôgic, Số học, Con số, Hình học,
/// Tổ hợp).
///
/// Hình khu là file SVG vẽ mới cùng phong cách pastel mềm, viền trắng
/// kiểu sticker (PLAN điểm (k)). Muse chưa cắt được hình từ các tấm
/// trong `assets/concept/` vì không tải được file PNG nhị phân qua MCP
/// (xem DECISIONS mục T1-12): các tấm đó vẫn là nguồn hình chính, việc
/// cắt/tách nền để Claude (hoặc bước sau, khi có file PNG) làm; icon
/// SVG ở đây vẽ theo đúng tông của các tấm đó để thay tạm.
library;

import '../../core/database/tables.dart';

/// Một khu trong Thị trấn: nút lớn trên màn Thị trấn dẫn vào chặng
/// tương ứng của đề ngày.
class TownArea {
  const TownArea({
    required this.strand,
    required this.name,
    required this.asset,
    required this.color,
  });

  /// Mảng của khu (cũng là mảng của chặng cùng vị trí trong đề ngày).
  final String strand;

  /// Tên khu, hiện trên nút.
  final String name;

  /// Đường dẫn asset SVG của biểu tượng khu.
  final String asset;

  /// Màu nền pastel của nút (giá trị màu ARGB).
  final int color;
}

/// 5 khu theo đúng thứ tự chặng của đề ngày.
const List<TownArea> townAreas = [
  TownArea(
    strand: Strand.logic,
    name: 'Lâu đài Lôgic',
    asset: 'assets/images/area_logic.svg',
    color: 0xFFC9B8F0,
  ),
  TownArea(
    strand: Strand.arith,
    name: 'Tiệm bánh Số học',
    asset: 'assets/images/area_arith.svg',
    color: 0xFFFFD9C0,
  ),
  TownArea(
    strand: Strand.number,
    name: 'Tháp Con số',
    asset: 'assets/images/area_number.svg',
    color: 0xFFBFE0F5,
  ),
  TownArea(
    strand: Strand.geo,
    name: 'Vườn Hình học',
    asset: 'assets/images/area_geo.svg',
    color: 0xFFBFE8CF,
  ),
  TownArea(
    strand: Strand.comb,
    name: 'Hội chợ Tổ hợp',
    asset: 'assets/images/area_comb.svg',
    color: 0xFFFFD166,
  ),
];
