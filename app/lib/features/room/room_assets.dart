/// Hình thật và vị trí đồ rời của màn Phòng (D, phong cách v3b).
///
/// Nền phòng là PNG `room_v3.png` (1600x900, phối cảnh 1 điểm tụ);
/// 5 món nội thất là PNG trong suốt 512x512 ở
/// `app/assets/images/furniture/` (xem `docs/ASSETS.md` mục "Phòng v3b"
/// và `docs/D_IMAGES.md`). Ảnh cũ v2 (`room_v2.png` + 8 món) không
/// dùng nữa nhưng vẫn còn file + dòng manifest (như tiền lệ
/// `town_v2.png` — xem mục "Thị trấn v3b" trong `docs/ASSETS.md`).
library;

import 'dart:ui';

/// Đường dẫn asset PNG nền phòng v3b.
const String roomBackgroundAsset = 'assets/images/backgrounds/room_v3.png';

/// Nền phòng SẠCH (không có gấu bông, đèn sao, bình hoa, cốc bút,
/// chậu cây vẽ sẵn) — Muse đang vẽ `room_v3_clean.png`.
const String roomCleanBackgroundAsset =
    'assets/images/backgrounds/room_v3_clean.png';

/// Đã có nền sạch chưa. `false` (hiện tại): nền `room_v3.png` đã VẼ
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

  /// Hộp bao món VẼ SẴN trong nền `room_v3.png` (khung 1600x900, đo
  /// bằng PIL trên ảnh thật 22/11). Khi [roomCleanBackgroundReady]
  /// còn `false` đây là vùng chạm vô hình của món.
  final Rect bakedRect;

  /// Món vẫn còn vẽ trong nền sạch `room_v3_clean.png` (lô 8C chỉ xoá
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
    asset: 'assets/images/furniture/gau_bong_v3.png',
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
    asset: 'assets/images/furniture/den_sao_v3.png',
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
    asset: 'assets/images/furniture/chau_cay_v3.png',
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
    asset: 'assets/images/furniture/binh_hoa_v3.png',
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
    asset: 'assets/images/furniture/coc_sao_v3.png',
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
/// `assets/images/furniture/<mã>.png` (512x512). CHỈ vẽ khi
/// `furnitureShopArtReady` (Muse đang vẽ hình).
///
/// Ô đặt TẠM, đo bằng mắt trên `room_v3_clean.png` — dễ chỉnh: mỗi món
/// chỉ cần sửa [RoomFurniture.placeX]/[placeY]/[placeSize] (góc trên-trái
/// + cỡ ảnh 512x512), [RoomFurniture.anchor] (điểm đáy: bóng đổ + thứ tự
/// vẽ theo chân y so với nhân vật/pet) và [RoomFurniture.footprint]
/// (dải đáy chặn đường đi). Khi hình thật về, nhìn lại và chỉnh các số
/// này; test `room_shop_furniture_test.dart` chỉ khóa các ràng buộc
/// (trong khung, dấu chân nằm trên sàn, không chặn chỗ đứng mặc định).
const List<RoomFurniture> roomShopFurniture = [
  RoomFurniture(
    key: 'room-furniture-noi_nha_pet',
    asset: 'assets/images/furniture/noi_nha_pet.png',
    label: 'Nhà cho pet',
    reaction: 'Nhà của pet ấm áp quá!',
    placeX: 1059,
    placeY: 557,
    placeSize: 282,
    anchor: Offset(1200, 800),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(1130, 776, 1270, 800),
  ),
  RoomFurniture(
    key: 'room-furniture-noi_ke_sach',
    asset: 'assets/images/furniture/noi_ke_sach.png',
    label: 'Kệ sách',
    reaction: 'Nhiều sách hay quá!',
    placeX: 179,
    placeY: 587,
    placeSize: 282,
    anchor: Offset(320, 830),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(265, 806, 375, 830),
  ),
  RoomFurniture(
    key: 'room-furniture-noi_be_ca',
    asset: 'assets/images/furniture/noi_be_ca.png',
    label: 'Bể cá',
    reaction: 'Cá bơi lội vui quá!',
    placeX: 579,
    placeY: 457,
    placeSize: 282,
    anchor: Offset(720, 700),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(671, 676, 769, 700),
  ),
  RoomFurniture(
    key: 'room-furniture-noi_cay_cao',
    asset: 'assets/images/furniture/noi_cay_cao.png',
    label: 'Chậu cây lá to',
    reaction: 'Cây lá to xanh mướt!',
    placeX: 796,
    placeY: 530,
    placeSize: 307,
    anchor: Offset(950, 795),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(886, 771, 1014, 795),
  ),
  RoomFurniture(
    key: 'room-furniture-noi_ghe_luoi',
    asset: 'assets/images/furniture/noi_ghe_luoi.png',
    label: 'Ghế lười',
    reaction: 'Ghế lười êm ơi là êm!',
    placeX: 19,
    placeY: 602,
    placeSize: 282,
    anchor: Offset(160, 845),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(100, 821, 220, 845),
  ),
  RoomFurniture(
    key: 'room-furniture-noi_leu',
    asset: 'assets/images/furniture/noi_leu.png',
    label: 'Lều đồ chơi',
    reaction: 'Chui vào lều chơi nào!',
    placeX: 1216,
    placeY: 519,
    placeSize: 384,
    anchor: Offset(1409, 850),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(1304, 826, 1514, 850),
  ),
  // Món trên tường / mặt bàn / mặt tủ (`wall`: không bóng, không chặn
  // đường). Chỗ đặt theo tấm ghép Muse lô 10 (22/11).
  RoomFurniture(
    key: 'room-furniture-noi_den_trang',
    asset: 'assets/images/furniture/noi_den_trang.png',
    label: 'Đèn mặt trăng',
    reaction: 'Đèn mặt trăng sáng dịu ghê!',
    placeX: 590,
    placeY: 324,
    placeSize: 179,
    anchor: Offset(680, 478),
    bakedRect: Rect.zero,
    wall: true,
  ),
  RoomFurniture(
    key: 'room-furniture-noi_tranh',
    asset: 'assets/images/furniture/noi_tranh.png',
    label: 'Tranh cầu vồng',
    reaction: 'Cầu vồng đẹp quá!',
    placeX: 232,
    placeY: 110,
    placeSize: 256,
    anchor: Offset(360, 330),
    bakedRect: Rect.zero,
    wall: true,
  ),
];

/// Mã món cửa hàng của một ô nội thất mua (khóa `room-furniture-<mã>`).
String roomShopFurnitureId(RoomFurniture f) =>
    f.key.substring('room-furniture-'.length);

/// Câu pet vui khi bé chơi với pet (đã mở khóa).
const Map<String, String> petHappyLines = <String, String>{
  'dog': 'Gâu gâu! Chơi với tớ nhé!',
  'cat': 'Meo meo! Tớ vui lắm!',
  'rabbit': 'Nhảy nhảy! Vui quá!',
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
