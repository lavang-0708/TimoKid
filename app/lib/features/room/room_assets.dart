/// Hình thật và vị trí đồ rời của màn Phòng (D, phong cách v3b).
///
/// Nền phòng là PNG `room_v3.webp` (1600x900, phối cảnh 1 điểm tụ);
/// 5 món nội thất là PNG trong suốt 512x512 ở
/// `app/assets/images/furniture/` (xem `docs/ASSETS.md` mục "Phòng v3b"
/// và `docs/D_IMAGES.md`). Ảnh cũ v2 (`room_v2.webp` + 8 món) không
/// dùng nữa nhưng vẫn còn file + dòng manifest (như tiền lệ
/// `town_v2.webp` — xem mục "Thị trấn v3b" trong `docs/ASSETS.md`).
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'room_themes.dart';

/// Đường dẫn asset PNG nền phòng v3b.
const String roomBackgroundAsset = 'assets/images/backgrounds/room_v3.webp';

/// Nền phòng SẠCH (không có gấu bông, đèn sao, bình hoa, cốc bút,
/// chậu cây vẽ sẵn) — Muse đang vẽ `room_v3_clean.webp`.
const String roomCleanBackgroundAsset =
    'assets/images/backgrounds/room_v3_clean.webp';

/// Đã có nền sạch chưa. `false` (hiện tại): nền `room_v3.webp` đã VẼ
/// SẴN 5 món (nhỏ hơn và lệch so với PNG rời) nên app KHÔNG vẽ PNG
/// rời đè lên (tránh hình đôi) mà chỉ đặt vùng chạm vô hình đúng chỗ
/// món trong nền ([RoomFurniture.bakedRect]). `true`: dùng nền sạch
/// và vẽ lại 5 PNG rời như thiết kế ban đầu.
const bool roomCleanBackgroundReady = true;

/// Khung nền 1600x900 — mọi tọa độ trong file này theo khung đó.
const double roomFrameWidth = 1600;
const double roomFrameHeight = 900;

/// Một món nội thất đặt đúng vị trí trong phòng v3b.
///
/// Khác bản v2 (A1): món không đặt ở ô vuông cố định mà đặt KHỚP món
/// vẽ sẵn trong nền — ảnh 512x512 đặt tại ([placeX], [placeY]) với
/// cỡ [placeSize] (khung nền); [anchor] là điểm đáy món (đáy ảnh vẽ
/// riêng) để app vẽ bóng đổ mềm ngay dưới đó. Vị trí đo từ PNG thật,
/// đã hiệu chỉnh bằng code ở giai đoạn 2 (xem `docs/D_IMAGES.md`
/// mục 8: gấu/đèn/bình dời xuống 2 px cho phủ khít món trong nền).
class RoomFurniture {
  const RoomFurniture({
    required this.key,
    required this.asset,
    required this.label,
    required this.reaction,
    required this.placeX,
    required this.placeY,
    required this.placeSize,
    required this.anchor,
    required this.bakedRect,
    this.inCleanBackground = false,
    this.footprint,
    this.wall = false,
  });

  /// Khóa widget của món (để test tìm).
  final String key;

  /// Đường dẫn asset PNG của món.
  final String asset;

  /// Tên món, hiện ở bong bóng phản ứng.
  final String label;

  /// Câu phản ứng khi bé chạm vào món.
  final String reaction;

  /// Góc trên-trái của ảnh 512x512 khi đặt lên nền (khung 1600x900).
  final double placeX;

  /// Góc trên-trái của ảnh 512x512 khi đặt lên nền (khung 1600x900).
  final double placeY;

  /// Cỡ hiển thị của ảnh 512x512 (vuông, khung 1600x900).
  final double placeSize;

  /// Điểm neo đáy món (khung 1600x900) — bóng đổ vẽ ngay dưới đó.
  final Offset anchor;

  /// Hộp bao món VẼ SẴN trong nền `room_v3.webp` (khung 1600x900, đo
  /// bằng PIL trên ảnh thật 22/11). Khi [roomCleanBackgroundReady]
  /// còn `false` đây là vùng chạm vô hình của món.
  final Rect bakedRect;

  /// Món vẫn còn vẽ trong nền sạch `room_v3_clean.webp` (lô 8C chỉ xoá
  /// gấu, đèn, bình hoa, cốc bút; chậu cây giữ nguyên) — khi đó không
  /// vẽ PNG rời mà vẫn dùng vùng chạm [bakedRect].
  final bool inCleanBackground;

  /// Dấu chân trên sàn (khung 1600x900) của nội thất mua ở Cửa hàng:
  /// vùng đi được trừ hình chữ nhật này (cùng cơ chế
  /// [roomObstacleFootprints]). Null với món gắn tường.
  final Rect? footprint;

  /// Món gắn tường (không bóng đổ, không chặn đường đi, vẽ dưới
  /// nhân vật/pet).
  final bool wall;
}

/// Nội thất v3b (5 món, đặt khớp món vẽ sẵn trong nền).
const List<RoomFurniture> roomFurniture = [
  RoomFurniture(
    key: 'room-furniture-gau-bong',
    asset: 'assets/images/furniture/gau_bong_v3.webp',
    label: 'Gấu bông',
    reaction: 'Gấu bông ôm thích lắm!',
    placeX: 296,
    placeY: 343,
    placeSize: 239,
    anchor: Offset(415, 550),
    bakedRect: Rect.fromLTRB(340, 440, 456, 548),
  ),
  RoomFurniture(
    key: 'room-furniture-den-sao',
    asset: 'assets/images/furniture/den_sao_v3.webp',
    label: 'Đèn sao',
    reaction: 'Đèn sao sáng rồi, đọc sách thôi!',
    placeX: 49,
    placeY: 408,
    placeSize: 196,
    anchor: Offset(150, 580),
    bakedRect: Rect.fromLTRB(92, 486, 210, 604),
  ),
  RoomFurniture(
    key: 'room-furniture-chau-cay',
    asset: 'assets/images/furniture/chau_cay_v3.webp',
    label: 'Chậu cây',
    reaction: 'Cây lớn nhanh nhé!',
    placeX: 678,
    placeY: 378,
    placeSize: 358,
    anchor: Offset(842, 686),
    bakedRect: Rect.fromLTRB(783, 538, 902, 684),
    inCleanBackground: true,
  ),
  RoomFurniture(
    key: 'room-furniture-binh-hoa',
    asset: 'assets/images/furniture/binh_hoa_v3.webp',
    label: 'Bình hoa',
    reaction: 'Hoa thơm quá!',
    placeX: 1162,
    placeY: 273,
    placeSize: 283,
    anchor: Offset(1305, 510),
    bakedRect: Rect.fromLTRB(1230, 396, 1357, 545),
  ),
  RoomFurniture(
    key: 'room-furniture-coc-sao',
    asset: 'assets/images/furniture/coc_sao_v3.webp',
    label: 'Cốc bút',
    reaction: 'Cốc bút đựng bút chì gọn quá!',
    placeX: 1027,
    placeY: 378,
    placeSize: 161,
    anchor: Offset(1099, 515),
    bakedRect: Rect.fromLTRB(1076, 441, 1144, 523),
  ),
];

/// Nội thất MUA Ở CỬA HÀNG (T2-06b), khóa món = mã trong
/// `shopFurniture` (`shop_catalog.dart`), hình
/// `assets/images/furniture/<mã>.webp` (512x512). CHỈ vẽ khi
/// `furnitureShopArtReady` (Muse đang vẽ hình).
///
/// Ô đặt MẶC ĐỊNH (bé kéo thả đổi được, xem [roomPlaceables]), xếp vào
/// chỗ trống của `room_v3_clean.webp` (không đè giường, tủ đầu giường,
/// bàn + ghế, kệ lớn, tủ áo, chậu cây vẽ sẵn; không đè 5 món nhỏ) — dễ chỉnh: mỗi món
/// chỉ cần sửa [RoomFurniture.placeX]/[placeY]/[placeSize] (góc trên-trái
/// + cỡ ảnh 512x512), [RoomFurniture.anchor] (điểm đáy: bóng đổ + thứ tự
/// vẽ theo chân y so với nhân vật/pet) và [RoomFurniture.footprint]
/// (dải đáy chặn đường đi). Khi hình thật về, nhìn lại và chỉnh các số
/// này; test `room_shop_furniture_test.dart` chỉ khóa các ràng buộc
/// (trong khung, dấu chân nằm trên sàn, không chặn chỗ đứng mặc định).
const List<RoomFurniture> roomShopFurniture = [
  RoomFurniture(
    key: 'room-furniture-noi_nha_pet',
    asset: 'assets/images/furniture/noi_nha_pet.webp',
    label: 'Nhà cho pet',
    reaction: 'Nhà của pet ấm áp quá!',
    placeX: 240,
    placeY: 735,
    placeSize: 180,
    anchor: Offset(330, 890),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(285, 866, 375, 890),
  ),
  RoomFurniture(
    key: 'room-furniture-noi_ke_sach',
    asset: 'assets/images/furniture/noi_ke_sach.webp',
    label: 'Kệ sách',
    reaction: 'Nhiều sách hay quá!',
    placeX: 655,
    placeY: 718,
    placeSize: 200,
    anchor: Offset(755, 890),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(701, 866, 809, 890),
  ),
  RoomFurniture(
    key: 'room-furniture-noi_be_ca',
    asset: 'assets/images/furniture/noi_be_ca.webp',
    label: 'Bể cá',
    reaction: 'Cá bơi lội vui quá!',
    placeX: 1170,
    placeY: 744,
    placeSize: 170,
    anchor: Offset(1255, 890),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(1215, 866, 1295, 890),
  ),
  RoomFurniture(
    key: 'room-furniture-noi_cay_cao',
    asset: 'assets/images/furniture/noi_cay_cao.webp',
    label: 'Chậu cây lá to',
    reaction: 'Cây lá to xanh mướt!',
    placeX: 780,
    placeY: 692,
    placeSize: 230,
    anchor: Offset(895, 890),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(847, 866, 943, 890),
  ),
  RoomFurniture(
    key: 'room-furniture-noi_ghe_luoi',
    asset: 'assets/images/furniture/noi_ghe_luoi.webp',
    label: 'Ghế lười',
    reaction: 'Ghế lười êm ơi là êm!',
    placeX: 40,
    placeY: 701,
    placeSize: 220,
    anchor: Offset(150, 890),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(103, 866, 197, 890),
  ),
  RoomFurniture(
    key: 'room-furniture-noi_leu',
    asset: 'assets/images/furniture/noi_leu.webp',
    label: 'Lều đồ chơi',
    reaction: 'Chui vào lều chơi nào!',
    placeX: 985,
    placeY: 718,
    placeSize: 200,
    anchor: Offset(1085, 890),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(1030, 866, 1140, 890),
  ),
  // Món trên tường / mặt bàn / mặt tủ (`wall`: không bóng, không chặn
  // đường). Chỗ đặt theo tấm ghép Muse lô 10 (22/11).
  RoomFurniture(
    key: 'room-furniture-noi_den_trang',
    asset: 'assets/images/furniture/noi_den_trang.webp',
    label: 'Đèn mặt trăng',
    reaction: 'Đèn mặt trăng sáng dịu ghê!',
    placeX: 300,
    placeY: 146,
    placeSize: 179,
    anchor: Offset(390, 300),
    bakedRect: Rect.zero,
    wall: true,
  ),
  RoomFurniture(
    key: 'room-furniture-noi_tranh',
    asset: 'assets/images/furniture/noi_tranh.webp',
    label: 'Tranh cầu vồng',
    reaction: 'Cầu vồng đẹp quá!',
    placeX: 10,
    placeY: 309,
    placeSize: 150,
    anchor: Offset(85, 438),
    bakedRect: Rect.zero,
    wall: true,
  ),
];

/// Loại chỗ đặt của một món kéo thả được.
enum RoomPlaceKind {
  /// Đứng trên sàn: chân (đáy giữa) phải nằm trong vùng sàn.
  floor,

  /// Gắn tường: nằm trong vùng tường (trên đường chân tường, dưới trần).
  wall,

  /// Món nhỏ: đặt trên mặt giường/tủ đầu giường/bàn học HOẶC trên sàn.
  surface,
}

/// Một món bé kéo thả được trong Phòng (dữ liệu, không code riêng từng
/// món). Muốn thêm món mới (giường/tủ/bàn bằng ảnh, nền trống mới...) chỉ
/// cần thêm một [RoomFurniture] + một dòng vào [roomPlaceables].
class RoomPlaceable {
  const RoomPlaceable({
    required this.id,
    required this.item,
    required this.kind,
    this.shopId,
    this.tier = RoomItemTier.small,
  });

  /// Mã ổn định, khóa lưu vị trí trong settings.
  final String id;

  /// Kích thước + vị trí mặc định + phản ứng khi chạm.
  final RoomFurniture item;
  final RoomPlaceKind kind;

  /// Mã món Cửa hàng (null: món có sẵn của phòng). Có thì chỉ vẽ khi bé
  /// đã mua, và ảnh đổi theo chủ đề ([roomThemeFurnitureAsset]).
  final String? shopId;

  /// Cỡ món: quyết định giá món lẻ của từng chủ đề.
  final RoomItemTier tier;

  bool get wall => kind == RoomPlaceKind.wall;

  /// Góc trên-trái mặc định (khung 1600x900).
  Offset get defaultPos => Offset(item.placeX, item.placeY);

  double get size => item.placeSize;

  /// Điểm neo đáy so với góc trên-trái.
  Offset get anchorOffset => item.anchor - defaultPos;

  /// Ảnh của món ở biến thể [variant] (`classic` hoặc mã chủ đề). Mọi món
  /// (cả 4 món nhỏ có sẵn) đều có thể có biến thể.
  String assetFor(String variant) => variant == roomThemeClassic
      ? item.asset
      : roomThemeFurnitureAsset(variant, shopId ?? id);

  /// Dấu chân chặn đường đi khi món nằm với góc trên-trái [pos].
  Rect? footprintAt(Offset pos) => item.footprint?.shift(pos - defaultPos);
}

/// Cỡ từng món Cửa hàng (món nhỏ có sẵn đều cỡ nhỏ). Món mới (giường, tủ,
/// bàn...) chỉ cần thêm dòng ở đây hoặc đặt `tier` khi tạo [RoomPlaceable].
const Map<String, RoomItemTier> roomShopFurnitureTier = {
  'noi_nha_pet': RoomItemTier.medium,
  'noi_ke_sach': RoomItemTier.large,
  'noi_be_ca': RoomItemTier.medium,
  'noi_cay_cao': RoomItemTier.medium,
  'noi_ghe_luoi': RoomItemTier.medium,
  'noi_leu': RoomItemTier.large,
  'noi_den_trang': RoomItemTier.small,
  'noi_tranh': RoomItemTier.small,
};

/// Mọi món kéo thả được: 4 món nhỏ vẽ bằng ảnh rời trên nền sạch (chậu
/// cây còn vẽ sẵn trong nền nên không kéo được) + 8 món Cửa hàng. Mỗi món
/// có thể có biến thể theo chủ đề (xem `room_variants.dart`).
final List<RoomPlaceable> roomPlaceables = List.unmodifiable([
  for (final f in roomFurniture)
    if (!f.inCleanBackground)
      RoomPlaceable(
        id: f.key.substring('room-furniture-'.length),
        item: f,
        kind: RoomPlaceKind.surface,
      ),
  for (final f in roomShopFurniture)
    RoomPlaceable(
      id: roomShopFurnitureId(f),
      item: f,
      kind: f.wall ? RoomPlaceKind.wall : RoomPlaceKind.floor,
      shopId: roomShopFurnitureId(f),
      tier: roomShopFurnitureTier[roomShopFurnitureId(f)] ?? RoomItemTier.small,
    ),
]);

/// Mã món cửa hàng của một ô nội thất mua (khóa `room-furniture-<mã>`).
String roomShopFurnitureId(RoomFurniture f) =>
    f.key.substring('room-furniture-'.length);

/// Câu pet vui khi bé chơi với pet (đã mở khóa).
const Map<String, String> petHappyLines = <String, String>{
  'dog': 'Gâu gâu! Chơi với tớ nhé!',
  'cat': 'Meo meo! Tớ vui lắm!',
  'rabbit': 'Nhảy nhảy! Vui quá!',
  'squirrel': 'Chít chít! Tớ vui lắm!',
  'capybara': 'Ọp ọp! Tớ vui lắm!',
  'dragon': 'Gràooo! Tớ là rồng con đây!',
};

/// Câu khi bé chạm vào pet mà phần chơi còn khóa.
const String petLockedLine = 'Học xong một chặng rồi mới vuốt ve tớ nhé!';

/// Đa giác sàn (nơi nhân vật + pet đứng), khung 1600x900.
/// Đã kiểm chứng bằng code trên nền thật (mẫu màu sàn gỗ).
const List<Offset> roomFloorPolygon = <Offset>[
  Offset(0, 795),
  Offset(400, 645),
  Offset(1200, 645),
  Offset(1600, 795),
  Offset(1600, 900),
  Offset(0, 900),
];

/// Mặt giường (nệm/chăn, nơi gấu ngồi): gấu neo y = 550.
const Rect roomBedSurface = Rect.fromLTRB(155, 540, 760, 560);

/// Mặt tủ đầu giường: đèn neo y = 580.
const Rect roomNightstandSurface = Rect.fromLTRB(30, 575, 260, 585);

/// Mặt bàn học: bình neo y = 510, cốc neo y = 515.
const Rect roomDeskSurface = Rect.fromLTRB(1070, 490, 1470, 515);

/// Dấu chân trên sàn (cho PR (G) — vùng đi được = đa giác sàn trừ
/// các dấu chân này). Kệ sách gắn tường nên không có dấu chân riêng:
/// hình chiếu xuống sàn trùng dấu chân bàn học.
const Map<String, Rect> roomObstacleFootprints = <String, Rect>{
  'bed': Rect.fromLTRB(155, 645, 760, 700),
  'desk': Rect.fromLTRB(1070, 645, 1470, 790),
  'wardrobe': Rect.fromLTRB(1460, 645, 1600, 880),
  'nightstand': Rect.fromLTRB(30, 700, 260, 800),
};

/// Ghế ở bàn học (cho PR (G) — tương tác ngồi ghế).
const Rect roomChairRect = Rect.fromLTRB(970, 490, 1240, 790);
const Rect roomChairSeat = Rect.fromLTRB(1000, 615, 1210, 660);
const Offset roomChairSeatCenter = Offset(1105, 640);

/// Hộp nhân vật trong khung nền: chân tại (630, 810), nhân vật cao
/// 360 px (đỉnh đầu ~y = 100 tới chân y = 1400 trong khung nhân vật
/// 1024x1536, tức ~2,25 lần mặt trước giường 160 px — đúng cỡ so
/// với giường/tủ/cửa sổ, xem `docs/ASSETS.md` mục "Phòng v3b").
/// Chân nằm ở 91,1% chiều cao hộp (đường đất y = 1400/1536).
///
/// Từ (E)/(G) Phòng KHÔNG vẽ theo hộp này nữa: nhân vật vẽ từ chân
/// (mặc định [roomCharacterFeet], đổi khi đi) với cỡ
/// `kidFrameHeight * 360 / kidBodyHeight` nhân tỉ lệ chiều sâu
/// (`room_walk.dart`). Giữ hằng này làm mốc cho test neo cũ.
const Rect roomCharacterBox = Rect.fromLTRB(488, 423, 772, 848);

/// Chân nhân vật (khung 1600x900).
const Offset roomCharacterFeet = Offset(630, 810);

/// Hộp pet/trứng trong khung nền: chân tại (420, 810), hộp vuông
/// 140 px (thân pet cao ~120 px); chân (đường đất y = 440/512) ở
/// 86% chiều cao hộp.
///
/// Từ (F) cỡ pet theo giai đoạn (`petBoxSize` trong `pet_growth.dart`);
/// hộp này chỉ còn là mốc cho test neo cũ.
const Rect roomPetBox = Rect.fromLTRB(350, 690, 490, 830);

/// Chân pet (khung 1600x900).
const Offset roomPetFeet = Offset(420, 810);

/// Điểm có nằm trong đa giác sàn không (thuật toán tia ngang,
/// logic thuần để test trực tiếp).
bool roomPointInFloor(Offset p) {
  var inside = false;
  final n = roomFloorPolygon.length;
  for (var i = 0; i < n; i++) {
    final a = roomFloorPolygon[i];
    final b = roomFloorPolygon[(i + 1) % n];
    if ((a.dy > p.dy) != (b.dy > p.dy)) {
      final xAtY = a.dx + (p.dy - a.dy) * (b.dx - a.dx) / (b.dy - a.dy);
      if (p.dx < xAtY) inside = !inside;
    }
  }
  return inside;
}

// ---------------------------------------------------------------------
// Vùng đặt đồ (kéo thả). Đo bằng PIL trên `room_v3_clean.webp` 1600x900:
// chân tường (viền chân tường sau lưng, nơi sàn gỗ bắt đầu) ở y ~ 645
// suốt đoạn giữa x 400..1200, rồi dốc xuống ~ 795 ở hai mép (cùng đa
// giác [roomFloorPolygon]); sàn kéo tới sát đáy khung (y 900).
// ---------------------------------------------------------------------

/// Chân món trên sàn cách đường chân tường ít nhất bằng này (để dấu chân
/// 24 px của món vẫn nằm trong sàn).
const double roomFloorFeetInset = 30;

/// Chân món trên sàn thấp nhất (đáy khung 900, chừa 5 px).
const double roomFloorFeetBottom = 895;

/// Chân/điểm neo của món không ra sát mép trái/phải hơn mức này.
const double roomPlaceMinX = 20;
const double roomPlaceMaxX = 1580;

/// Vùng tường: dưới trần (đỉnh nhìn thấy của món y >= 30) và trên
/// đường chân tường (đáy y <= [roomFloorTopAt] - 4); mép trái/phải là
/// [roomPlaceMinX]/[roomPlaceMaxX]. Phần bottom của Rect là chân tường
/// ở giữa phòng (y 645); hai mép phòng chân tường thấp hơn nên đáy thật
/// là [roomFloorTopAt] - 4 (xem [roomClampWallAnchor]).
const Rect roomWallRegion = Rect.fromLTRB(
  roomPlaceMinX,
  30,
  roomPlaceMaxX,
  645,
);

/// Ảnh 512x512 có phần trong suốt: đỉnh nhìn thấy của món nằm cách mép
/// trên ảnh khoảng 16% cỡ ảnh (đo trên 13 ảnh nội thất).
const double roomImageTopInset = 0.16;

/// Đường chân tường (đỉnh vùng sàn) tại hoành độ [x] (khung 1600x900).
double roomFloorTopAt(double x) {
  final p = roomFloorPolygon;
  // p[0]->p[1]: dốc trái; p[1]->p[2]: phẳng; p[2]->p[3]: dốc phải.
  if (x <= p[1].dx) {
    final t = (x - p[0].dx) / (p[1].dx - p[0].dx);
    return p[0].dy + (p[1].dy - p[0].dy) * t.clamp(0.0, 1.0);
  }
  if (x >= p[2].dx) {
    final t = (x - p[2].dx) / (p[3].dx - p[2].dx);
    return p[2].dy + (p[3].dy - p[2].dy) * t.clamp(0.0, 1.0);
  }
  return p[1].dy;
}

/// Kẹp chân món sàn [feet] vào vùng sàn.
Offset roomClampFloorFeet(Offset feet) {
  final x = feet.dx.clamp(roomPlaceMinX, roomPlaceMaxX).toDouble();
  final y = feet.dy
      .clamp(roomFloorTopAt(x) + roomFloorFeetInset, roomFloorFeetBottom)
      .toDouble();
  return Offset(x, y);
}

/// Kẹp điểm neo đáy món gắn tường [anchor] vào vùng tường; [visibleHeight]
/// là chiều cao phần nhìn thấy của món (đáy tới đỉnh) để đỉnh không chạm
/// trần.
Offset roomClampWallAnchor(Offset anchor, {double visibleHeight = 0}) {
  final x = anchor.dx.clamp(roomWallRegion.left, roomWallRegion.right);
  final bottom = roomFloorTopAt(x) - 4;
  final top = math.min(roomWallRegion.top + visibleHeight, bottom);
  return Offset(x.toDouble(), anchor.dy.clamp(top, bottom).toDouble());
}

/// Các mặt phẳng món nhỏ ([RoomPlaceKind.surface]) đặt lên được.
const List<Rect> roomSurfaces = <Rect>[
  roomBedSurface,
  roomNightstandSurface,
  roomDeskSurface,
];

/// Điểm gần [p] nhất thuộc hình chữ nhật [r].
Offset _nearestInRect(Rect r, Offset p) => Offset(
  p.dx.clamp(r.left, r.right).toDouble(),
  p.dy.clamp(r.top, r.bottom).toDouble(),
);

/// Kẹp điểm neo của món nhỏ: gần nhất giữa vùng sàn và các mặt phẳng.
Offset roomClampSurfaceAnchor(Offset anchor) {
  var best = roomClampFloorFeet(anchor);
  var bestD = (best - anchor).distanceSquared;
  for (final r in roomSurfaces) {
    final c = _nearestInRect(r, anchor);
    final d = (c - anchor).distanceSquared;
    if (d < bestD) {
      best = c;
      bestD = d;
    }
  }
  return best;
}

/// Kẹp góc trên-trái [topLeft] của [p] sao cho điểm neo nằm trong vùng
/// hợp lệ của loại món đó; trả về góc trên-trái đã kẹp.
Offset roomClampPlaceable(RoomPlaceable p, Offset topLeft) {
  final off = p.anchorOffset;
  final anchor = topLeft + off;
  final clamped = switch (p.kind) {
    RoomPlaceKind.floor => roomClampFloorFeet(anchor),
    RoomPlaceKind.surface => roomClampSurfaceAnchor(anchor),
    RoomPlaceKind.wall => roomClampWallAnchor(
      anchor,
      visibleHeight: off.dy - roomImageTopInset * p.size,
    ),
  };
  return clamped - off;
}

/// Khóa settings (theo bé) lưu vị trí đồ. MỘT bố cục chung: món giữ chỗ
/// khi đổi biến thể.
const String roomLayoutSettingsKey = 'room_layout';

/// Khóa CŨ: mỗi chủ đề phòng một bố cục (`room_layout_<chủ đề>`). Chỉ đọc
/// để chuyển sang [roomLayoutSettingsKey].
String roomLegacyLayoutSettingsKey(String themeId) => 'room_layout_$themeId';

/// Mã hóa vị trí (mã món -> góc trên-trái, khung 1600x900) thành JSON.
String encodeRoomLayout(Map<String, Offset> layout) => jsonEncode({
  for (final e in layout.entries) e.key: {'x': e.value.dx, 'y': e.value.dy},
});

/// Giải mã JSON vị trí; hỏng/thiếu thì bỏ qua món đó (dùng mặc định).
Map<String, Offset> decodeRoomLayout(String? json) {
  if (json == null || json.isEmpty) return const {};
  try {
    final raw = jsonDecode(json);
    if (raw is! Map) return const {};
    final out = <String, Offset>{};
    for (final e in raw.entries) {
      final v = e.value;
      if (e.key is String && v is Map && v['x'] is num && v['y'] is num) {
        final x = (v['x'] as num).toDouble();
        final y = (v['y'] as num).toDouble();
        if (x.isFinite && y.isFinite) out[e.key as String] = Offset(x, y);
      }
    }
    return out;
  } catch (_) {
    return const {};
  }
}
