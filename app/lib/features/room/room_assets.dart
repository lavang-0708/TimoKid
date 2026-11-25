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

/// Phòng gốc v4 (lô 15, 25/11): nền TRỐNG `room_v4.webp` + 7 món lớn
/// (giường, tủ đầu giường, tủ áo, bàn học, ghế, kệ lớn, thảm) là sprite
/// rời `noi_*.webp` kéo thả được, kèm 5 món nhỏ + 8 món Cửa hàng xếp lại
/// theo bố cục mặc định của Muse. `false`: về phòng v3 (nền
/// `room_v3_clean.webp`, đồ lớn vẽ sẵn trong nền).
const bool roomV4Ready = true;

/// Nền phòng gốc v4 (trống, 1600x900, cùng phối cảnh room_v3).
const String roomV4BackgroundAsset = 'assets/images/backgrounds/room_v4.webp';

/// Nền của biến thể phòng gốc (`classic`) đang dùng khi có nền sạch.
const String roomClassicBackgroundAsset = roomV4Ready
    ? roomV4BackgroundAsset
    : roomCleanBackgroundAsset;

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
    this.placeHeight,
    this.crop = roomFullCrop,
  });

  /// Món lớn (lô 15): sprite 1024x1024 có viền trong suốt rất rộng nên chỉ
  /// hiện phần hộp bao nhìn thấy [crop] (tỉ lệ 0..1 trên ảnh), đặt đáy-giữa
  /// hộp tại ([anchorX], [anchorY]); [width]x[height] là cỡ hiển thị của
  /// hộp đó trong khung 1600x900. Dấu chân sàn: [footHalfWidth] mỗi bên,
  /// sâu [footDepth] lên từ điểm neo (0 = không chặn đường đi).
  factory RoomFurniture.trimmed({
    required String key,
    required String asset,
    required String label,
    required String reaction,
    required double anchorX,
    required double anchorY,
    required double width,
    required double height,
    required Rect crop,
    double footHalfWidth = 0,
    double footDepth = 0,
    bool wall = false,
  }) => RoomFurniture(
    key: key,
    asset: asset,
    label: label,
    reaction: reaction,
    placeX: anchorX - width / 2,
    placeY: anchorY - height,
    placeSize: width,
    placeHeight: height,
    anchor: Offset(anchorX, anchorY),
    bakedRect: Rect.zero,
    crop: crop,
    wall: wall,
    footprint: footHalfWidth > 0
        ? Rect.fromLTRB(
            anchorX - footHalfWidth,
            anchorY - footDepth,
            anchorX + footHalfWidth,
            anchorY,
          )
        : null,
  );

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

  /// Cỡ hiển thị (bề rộng) của ảnh 512x512 (vuông, khung 1600x900); món
  /// lớn cắt theo [crop] thì là bề rộng của hộp đã cắt.
  final double placeSize;

  /// Chiều cao hiển thị khi KHÔNG vuông (món lớn cắt theo [crop]); null =
  /// [placeSize] (ô vuông).
  final double? placeHeight;

  /// Phần ảnh được hiện (tỉ lệ 0..1 trên ảnh gốc); mặc định cả ảnh.
  final Rect crop;

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

/// Hộp bao đầy đủ của ảnh (không cắt).
const Rect roomFullCrop = Rect.fromLTWH(0, 0, 1, 1);

/// Loại chỗ đặt của một món kéo thả được.
enum RoomPlaceKind {
  /// Đứng trên sàn: chân (đáy giữa) phải nằm trong vùng sàn.
  floor,

  /// Gắn tường: nằm trong vùng tường (trên đường chân tường, dưới trần).
  wall,

  /// Món nhỏ: đặt trên mặt giường/tủ đầu giường/bàn học HOẶC trên sàn.
  surface,
}

/// Hình + ràng buộc của MỘT biến thể của món: cỡ hộp, điểm neo (đáy-giữa),
/// phần ảnh được hiện, loại chỗ đặt và dấu chân. Biến thể không khai báo
/// thì dùng hình của phòng gốc (xem [RoomPlaceable.artFor]). Điểm neo của
/// mọi biến thể trùng nhau khi bé đổi biến thể (món không "nhảy chỗ"): chỉ
/// góc trên-trái dời theo cỡ hộp.
class RoomArt {
  const RoomArt({
    required this.width,
    required this.height,
    required this.anchor,
    this.crop = roomFullCrop,
    this.kind,
    this.footprint,
    this.defaultAnchor,
  });

  /// Hộp cắt theo [crop], neo ở đáy-giữa hộp.
  factory RoomArt.trimmed({
    required double width,
    required double height,
    required Rect crop,
    RoomPlaceKind? kind,
    Rect? footprint,
    Offset? defaultAnchor,
  }) => RoomArt(
    width: width,
    height: height,
    anchor: Offset(width / 2, height),
    crop: crop,
    kind: kind,
    footprint: footprint,
    defaultAnchor: defaultAnchor,
  );

  /// Cỡ hiển thị của hộp (khung 1600x900).
  final double width;
  final double height;

  /// Điểm neo đáy so với góc trên-trái của hộp.
  final Offset anchor;

  /// Phần ảnh được hiện (tỉ lệ 0..1 trên ảnh gốc).
  final Rect crop;

  /// Loại chỗ đặt riêng của biến thể (null = như món gốc). Ví dụ kệ lớn
  /// phòng gốc TREO TƯỜNG còn kệ lớn phòng Rồng ĐỨNG SÀN.
  final RoomPlaceKind? kind;

  /// Dấu chân chặn đường đi, tính TỪ điểm neo (null = không chặn).
  final Rect? footprint;

  /// Điểm neo mặc định (khung 1600x900) khi bé chưa kéo món này; null =
  /// như món gốc. Dùng khi loại chỗ đặt khác nên chỗ gốc không hợp.
  final Offset? defaultAnchor;

  /// Ảnh có bị cắt không (hộp bao thay vì cả ô vuông 512x512).
  bool get cropped => crop != roomFullCrop;

  /// Chiều cao phần nhìn thấy (đáy tới đỉnh).
  double get visibleHeight =>
      cropped ? anchor.dy : anchor.dy - roomImageTopInset * height;

  /// Nửa bề rộng hộp nếu ảnh cắt (kẹp để hộp không ra khỏi khung), 0 nếu
  /// là ô vuông 512x512 (rìa trong suốt nên cho ra sát mép).
  double get halfWidth => cropped ? width / 2 : 0;
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
    this.variantArt = const {},
    this.flat = false,
    this.drawAfter,
    this.variantThemes,
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

  /// Hình/ràng buộc riêng từng biến thể chủ đề (mã chủ đề -> [RoomArt]);
  /// thiếu thì dùng hình phòng gốc.
  final Map<String, RoomArt> variantArt;

  /// Món PHẲNG nằm sát sàn (thảm): luôn vẽ dưới mọi đồ và nhân vật/pet,
  /// không bóng đổ, không chặn đường đi.
  final bool flat;

  /// Mã món mà món này luôn vẽ SAU (ví dụ ghế kê ở bàn học: vẽ sau bàn dù
  /// chân y nhỏ hơn).
  final String? drawAfter;

  /// Các chủ đề CÓ biến thể của món này (null = mọi chủ đề). Món Muse dùng
  /// lại nguyên bản ở phòng chủ đề (đèn sao, cốc bút ở Ngân hà; 5 món nhỏ
  /// ở Rồng) không có biến thể nên không bán lẻ.
  final Set<String>? variantThemes;

  bool get wall => kind == RoomPlaceKind.wall;

  /// Món này có biến thể chủ đề [themeId] không.
  bool hasVariant(String themeId) =>
      variantThemes == null || variantThemes!.contains(themeId);

  /// Góc trên-trái mặc định (khung 1600x900).
  Offset get defaultPos => Offset(item.placeX, item.placeY);

  double get size => item.placeSize;

  /// Điểm neo đáy so với góc trên-trái (phòng gốc).
  Offset get anchorOffset => item.anchor - defaultPos;

  /// Hình của phòng gốc.
  RoomArt get classicArt => RoomArt(
    width: item.placeSize,
    height: item.placeHeight ?? item.placeSize,
    anchor: anchorOffset,
    crop: item.crop,
    footprint: item.footprint?.shift(-item.anchor),
  );

  /// Hình + ràng buộc của biến thể [variant] (thiếu thì như phòng gốc).
  RoomArt artFor(String variant) => variant == roomThemeClassic
      ? classicArt
      : (variantArt[variant] ?? classicArt);

  /// Loại chỗ đặt ở biến thể [variant].
  RoomPlaceKind kindFor(String variant) => artFor(variant).kind ?? kind;

  /// Ảnh của món ở biến thể [variant] (`classic` hoặc mã chủ đề). Chủ đề
  /// mà món không có biến thể thì dùng ảnh gốc.
  String assetFor(String variant) =>
      variant == roomThemeClassic || !hasVariant(variant)
      ? item.asset
      : roomThemeFurnitureAsset(variant, shopId ?? id);

  /// Góc trên-trái của hộp ở biến thể [variant] khi bé lưu vị trí [pos]
  /// (góc trên-trái của phòng gốc): điểm neo giữ nguyên giữa các biến thể.
  Offset topLeftFor(String variant, Offset pos) =>
      pos + anchorOffset - artFor(variant).anchor;

  /// Hộp của món (khung 1600x900) ở biến thể [variant], vị trí lưu [pos].
  Rect boxAt(String variant, Offset pos) {
    final art = artFor(variant);
    return topLeftFor(variant, pos) & Size(art.width, art.height);
  }

  /// Vị trí lưu mặc định (góc trên-trái phòng gốc) ở biến thể [variant].
  Offset defaultPosFor(String variant) {
    final d = artFor(variant).defaultAnchor;
    return d == null ? defaultPos : d - anchorOffset;
  }

  /// Dấu chân chặn đường đi khi món nằm với vị trí lưu [pos] (góc
  /// trên-trái phòng gốc), ở biến thể [variant].
  Rect? footprintAt(Offset pos, {String variant = roomThemeClassic}) =>
      artFor(variant).footprint?.shift(pos + anchorOffset);
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

// ---------------------------------------------------------------------
// Phòng gốc v4 (lô 15): dữ liệu bố cục mặc định của Muse
// (docs/E_IMAGES.md "Lô 15 — Phòng gốc v4" / "Phòng Rồng"), đo từ ảnh
// thật. Mọi đồ đặt theo ĐIỂM NEO = đáy-giữa hộp bao nhìn thấy.
// ---------------------------------------------------------------------

/// 7 món lớn của phòng gốc v4 (sprite 1024x1024, thảm 1024x512, cắt theo
/// hộp bao alpha). Kệ lớn là kệ TREO TƯỜNG (neo = mép dưới kệ).
final List<RoomFurniture> roomBigFurniture = [
  RoomFurniture.trimmed(
    key: 'room-furniture-noi_tham',
    asset: 'assets/images/furniture/noi_tham.webp',
    label: 'Thảm',
    reaction: 'Thảm mềm mịn, nằm lăn thích ghê!',
    anchorX: 705,
    anchorY: 855,
    width: 590,
    height: 160,
    crop: Rect.fromLTRB(38 / 1024, 254 / 512, 987 / 1024, 511 / 512),
  ),
  RoomFurniture.trimmed(
    key: 'room-furniture-noi_ke_lon',
    asset: 'assets/images/furniture/noi_ke_lon.webp',
    label: 'Kệ sách lớn',
    reaction: 'Kệ sách lớn nhiều sách hay quá!',
    anchorX: 1125,
    anchorY: 390,
    width: 270,
    height: 360,
    crop: Rect.fromLTRB(138 / 1024, 24 / 1024, 887 / 1024, 1),
    wall: true,
  ),
  RoomFurniture.trimmed(
    key: 'room-furniture-noi_giuong',
    asset: 'assets/images/furniture/noi_giuong.webp',
    label: 'Giường',
    reaction: 'Giường êm quá, buồn ngủ rồi!',
    anchorX: 455,
    anchorY: 715,
    width: 500,
    height: 340,
    crop: Rect.fromLTRB(262 / 1024, 684 / 1024, 762 / 1024, 1),
    footHalfWidth: 200,
    footDepth: 40,
  ),
  RoomFurniture.trimmed(
    key: 'room-furniture-noi_tu_dau_giuong',
    asset: 'assets/images/furniture/noi_tu_dau_giuong.webp',
    label: 'Tủ đầu giường',
    reaction: 'Tủ đầu giường gọn gàng ghê!',
    anchorX: 138,
    anchorY: 780,
    width: 194,
    height: 190,
    crop: Rect.fromLTRB(414 / 1024, 834 / 1024, 608 / 1024, 1),
    footHalfWidth: 80,
    footDepth: 24,
  ),
  RoomFurniture.trimmed(
    key: 'room-furniture-noi_ban_hoc',
    asset: 'assets/images/furniture/noi_ban_hoc.webp',
    label: 'Bàn học',
    reaction: 'Bàn học sạch sẽ, học bài thôi!',
    anchorX: 1140,
    anchorY: 775,
    width: 320,
    height: 269,
    crop: Rect.fromLTRB(62 / 1024, 268 / 1024, 962 / 1024, 1),
    footHalfWidth: 128,
    footDepth: 30,
  ),
  RoomFurniture.trimmed(
    key: 'room-furniture-noi_ghe',
    asset: 'assets/images/furniture/noi_ghe.webp',
    label: 'Ghế',
    reaction: 'Ghế ngồi thoải mái ghê!',
    anchorX: 1000,
    anchorY: 745,
    width: 160,
    height: 240,
    crop: Rect.fromLTRB(182 / 1024, 34 / 1024, 842 / 1024, 1),
    footHalfWidth: 60,
    footDepth: 24,
  ),
  RoomFurniture.trimmed(
    key: 'room-furniture-noi_tu_ao',
    asset: 'assets/images/furniture/noi_tu_ao.webp',
    label: 'Tủ áo',
    reaction: 'Tủ áo to đùng, đầy quần áo xinh!',
    anchorX: 1440,
    anchorY: 885,
    width: 320,
    height: 820,
    crop: Rect.fromLTRB(352 / 1024, 204 / 1024, 672 / 1024, 1),
    footHalfWidth: 144,
    footDepth: 40,
  ),
];

/// Cỡ 7 món lớn (đồ to đắt hơn): lớn cho giường, tủ áo, kệ lớn, bàn học;
/// vừa cho tủ đầu giường, ghế, thảm.
const Map<String, RoomItemTier> roomBigFurnitureTier = {
  'noi_giuong': RoomItemTier.large,
  'noi_tu_ao': RoomItemTier.large,
  'noi_ke_lon': RoomItemTier.large,
  'noi_ban_hoc': RoomItemTier.large,
  'noi_tu_dau_giuong': RoomItemTier.medium,
  'noi_ghe': RoomItemTier.medium,
  'noi_tham': RoomItemTier.medium,
};

/// Hình riêng từng biến thể (phòng Rồng, Tết, Ngân hà; cỡ theo doc lô 15) của
/// 7 món lớn, 8 món Cửa hàng và các món nhỏ có bản theo chủ đề (khóa = mã
/// món). Kệ lớn Rồng ĐỨNG SÀN (khác kệ treo tường của phòng gốc): neo =
/// chân sàn.
final Map<String, Map<String, RoomArt>> roomVariantArt = {
  'noi_tham': {
    'rong': RoomArt.trimmed(
      width: 590,
      height: 160,
      crop: Rect.fromLTRB(218 / 1024, 352 / 512, 807 / 1024, 1),
    ),
    'ngan_ha': RoomArt.trimmed(
      width: 590,
      height: 160,
      crop: Rect.fromLTRB(38 / 1024, 255 / 512, 987 / 1024, 511 / 512),
    ),
    'tet': RoomArt.trimmed(
      width: 590,
      height: 160,
      crop: Rect.fromLTRB(37 / 1024, 255 / 512, 987 / 1024, 512 / 512),
    ),
  },
  'noi_ke_lon': {
    'rong': RoomArt.trimmed(
      width: 240,
      height: 712,
      crop: Rect.fromLTRB(377 / 1024, 224 / 1024, 647 / 1024, 1),
      kind: RoomPlaceKind.floor,
      footprint: Rect.fromLTRB(-96, -30, 96, 0),
      defaultAnchor: Offset(1190, 762),
    ),
    'ngan_ha': RoomArt.trimmed(
      width: 270,
      height: 360,
      crop: Rect.fromLTRB(137 / 1024, 24 / 1024, 887 / 1024, 1024 / 1024),
    ),
    'tet': RoomArt.trimmed(
      width: 270,
      height: 386,
      crop: Rect.fromLTRB(162 / 1024, 24 / 1024, 862 / 1024, 1024 / 1024),
      defaultAnchor: Offset(1270, 640),
    ),
  },
  'noi_giuong': {
    'rong': RoomArt.trimmed(
      width: 560,
      height: 380,
      crop: Rect.fromLTRB(262 / 1024, 684 / 1024, 762 / 1024, 1),
      footprint: Rect.fromLTRB(-224, -40, 224, 0),
    ),
    'ngan_ha': RoomArt.trimmed(
      width: 500,
      height: 340,
      crop: Rect.fromLTRB(262 / 1024, 683 / 1024, 762 / 1024, 1024 / 1024),
      footprint: Rect.fromLTRB(-200, -40, 200, 0),
    ),
    'tet': RoomArt.trimmed(
      width: 500,
      height: 339,
      crop: Rect.fromLTRB(262 / 1024, 685 / 1024, 762 / 1024, 1024 / 1024),
      footprint: Rect.fromLTRB(-200, -40, 200, 0),
    ),
  },
  'noi_tu_dau_giuong': {
    'rong': RoomArt.trimmed(
      width: 195,
      height: 199,
      crop: Rect.fromLTRB(415 / 1024, 825 / 1024, 610 / 1024, 1),
      footprint: Rect.fromLTRB(-78, -24, 78, 0),
    ),
    'ngan_ha': RoomArt.trimmed(
      width: 194,
      height: 190,
      crop: Rect.fromLTRB(414 / 1024, 835 / 1024, 608 / 1024, 1024 / 1024),
      footprint: Rect.fromLTRB(-80, -24, 80, 0),
    ),
    'tet': RoomArt.trimmed(
      width: 194,
      height: 189,
      crop: Rect.fromLTRB(415 / 1024, 835 / 1024, 609 / 1024, 1024 / 1024),
      footprint: Rect.fromLTRB(-80, -24, 80, 0),
    ),
  },
  'noi_ban_hoc': {
    'rong': RoomArt.trimmed(
      width: 320,
      height: 262,
      crop: Rect.fromLTRB(352 / 1024, 762 / 1024, 672 / 1024, 1),
      footprint: Rect.fromLTRB(-128, -30, 128, 0),
    ),
    'ngan_ha': RoomArt.trimmed(
      width: 320,
      height: 269,
      crop: Rect.fromLTRB(62 / 1024, 269 / 1024, 962 / 1024, 1024 / 1024),
      footprint: Rect.fromLTRB(-128, -30, 128, 0),
    ),
    'tet': RoomArt.trimmed(
      width: 320,
      height: 256,
      crop: Rect.fromLTRB(63 / 1024, 305 / 1024, 962 / 1024, 1024 / 1024),
      footprint: Rect.fromLTRB(-128, -30, 128, 0),
    ),
  },
  'noi_ghe': {
    'rong': RoomArt.trimmed(
      width: 160,
      height: 240,
      crop: Rect.fromLTRB(432 / 1024, 784 / 1024, 592 / 1024, 1),
      footprint: Rect.fromLTRB(-60, -24, 60, 0),
    ),
    'ngan_ha': RoomArt.trimmed(
      width: 160,
      height: 240,
      crop: Rect.fromLTRB(182 / 1024, 34 / 1024, 842 / 1024, 1024 / 1024),
      footprint: Rect.fromLTRB(-60, -24, 60, 0),
    ),
    'tet': RoomArt.trimmed(
      width: 160,
      height: 241,
      crop: Rect.fromLTRB(182 / 1024, 33 / 1024, 841 / 1024, 1024 / 1024),
      footprint: Rect.fromLTRB(-60, -24, 60, 0),
    ),
  },
  'noi_tu_ao': {
    'rong': RoomArt.trimmed(
      width: 320,
      height: 820,
      crop: Rect.fromLTRB(352 / 1024, 204 / 1024, 672 / 1024, 1),
      footprint: Rect.fromLTRB(-144, -40, 144, 0),
    ),
    'ngan_ha': RoomArt.trimmed(
      width: 320,
      height: 820,
      crop: Rect.fromLTRB(352 / 1024, 205 / 1024, 672 / 1024, 1024 / 1024),
      footprint: Rect.fromLTRB(-144, -40, 144, 0),
    ),
    'tet': RoomArt.trimmed(
      width: 320,
      height: 817,
      crop: Rect.fromLTRB(352 / 1024, 204 / 1024, 673 / 1024, 1024 / 1024),
      footprint: Rect.fromLTRB(-144, -40, 144, 0),
    ),
  },
  // 8 món Cửa hàng: Rồng vẽ cùng ô 512x512, chỉ khác cỡ/điểm neo.
  'noi_nha_pet': {
    'rong': RoomArt(
      width: 281.6,
      height: 281.6,
      anchor: Offset(141.35, 242.55),
      footprint: Rect.fromLTRB(-63, -24, 63, 0),
    ),
    'ngan_ha': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.65, 198),
      footprint: Rect.fromLTRB(-57, -24, 57, 0),
    ),
    'tet': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.88, 198),
      footprint: Rect.fromLTRB(-57, -24, 57, 0),
    ),
  },
  'noi_ke_sach': {
    'rong': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.42, 198.45),
      footprint: Rect.fromLTRB(-62, -24, 62, 0),
    ),
    'ngan_ha': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.2, 198.45),
      footprint: Rect.fromLTRB(-62, -24, 62, 0),
    ),
    'tet': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.2, 198.45),
      footprint: Rect.fromLTRB(-62, -24, 62, 0),
    ),
  },
  'noi_be_ca': {
    'rong': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.42, 198.45),
      footprint: Rect.fromLTRB(-49, -24, 49, 0),
    ),
    'ngan_ha': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.42, 198.45),
      footprint: Rect.fromLTRB(-53, -24, 53, 0),
    ),
    'tet': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.65, 198.45),
      footprint: Rect.fromLTRB(-53, -24, 53, 0),
    ),
  },
  'noi_cay_cao': {
    'rong': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.42, 198.45),
      footprint: Rect.fromLTRB(-43, -24, 43, 0),
    ),
    'ngan_ha': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.65, 198.45),
      footprint: Rect.fromLTRB(-48, -24, 48, 0),
    ),
    'tet': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.65, 198.45),
      footprint: Rect.fromLTRB(-48, -24, 48, 0),
    ),
  },
  'noi_ghe_luoi': {
    'rong': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.65, 198.45),
      footprint: Rect.fromLTRB(-38, -24, 38, 0),
    ),
    'ngan_ha': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.88, 198.45),
      footprint: Rect.fromLTRB(-49, -24, 49, 0),
    ),
    'tet': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.88, 198.45),
      footprint: Rect.fromLTRB(-49, -24, 49, 0),
    ),
  },
  'noi_leu': {
    'rong': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.42, 198.45),
      footprint: Rect.fromLTRB(-59, -24, 59, 0),
    ),
    'ngan_ha': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.65, 198),
      footprint: Rect.fromLTRB(-63, -24, 63, 0),
    ),
    'tet': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.65, 198.45),
      footprint: Rect.fromLTRB(-63, -24, 63, 0),
    ),
  },
  'noi_den_trang': {
    'rong': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(114.98, 198.45),
    ),
    'ngan_ha': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.2, 198.45),
      defaultAnchor: Offset(880, 465),
    ),
    'tet': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.2, 198.45),
      defaultAnchor: Offset(840, 465),
    ),
  },
  'noi_tranh': {
    'rong': RoomArt(width: 230.4, height: 230.4, anchor: Offset(115.2, 198.45)),
    'ngan_ha': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.42, 198.45),
      defaultAnchor: Offset(410, 300),
    ),
    'tet': RoomArt(
      width: 230.4,
      height: 230.4,
      anchor: Offset(115.2, 198.45),
      defaultAnchor: Offset(160, 192),
    ),
  },
  'gau-bong': {
    'ngan_ha': RoomArt(
      width: 238.59,
      height: 238.59,
      anchor: Offset(119.76, 206.9),
    ),
    'tet': RoomArt(
      width: 238.59,
      height: 238.59,
      anchor: Offset(119.76, 207.37),
    ),
  },
  'den-sao': {
    'tet': RoomArt(width: 196.1, height: 196.1, anchor: Offset(98.82, 172.35)),
  },
  'chau-cay': {
    'ngan_ha': RoomArt(
      width: 358.4,
      height: 358.4,
      anchor: Offset(165.55, 308.7),
      footprint: Rect.fromLTRB(-77, -24, 77, 0),
    ),
    'tet': RoomArt(
      width: 358.4,
      height: 358.4,
      anchor: Offset(165.55, 308.7),
      footprint: Rect.fromLTRB(-77, -24, 77, 0),
    ),
  },
  'binh-hoa': {
    'ngan_ha': RoomArt(
      width: 202.24,
      height: 202.24,
      anchor: Offset(102.11, 169.46),
    ),
    'tet': RoomArt(
      width: 202.24,
      height: 202.24,
      anchor: Offset(101.91, 169.85),
    ),
  },
  'coc-sao': {
    'tet': RoomArt(
      width: 161.28,
      height: 161.28,
      anchor: Offset(71.66, 136.71),
      defaultAnchor: Offset(700, 465),
    ),
  },
};

/// 5 món nhỏ của phòng v4 (gấu, đèn sao, bình hoa, cốc bút đặt trên giường/
/// tủ/bàn/bậu cửa; chậu cây đứng sàn — nay kéo thả được).
const List<RoomFurniture> roomFurnitureV4 = [
  RoomFurniture(
    key: 'room-furniture-gau-bong',
    asset: 'assets/images/furniture/gau_bong_v3.webp',
    label: 'Gấu bông',
    reaction: 'Gấu bông ôm thích lắm!',
    placeX: 325.24,
    placeY: 340.63,
    placeSize: 238.59,
    anchor: Offset(445, 548),
    bakedRect: Rect.zero,
  ),
  RoomFurniture(
    key: 'room-furniture-den-sao',
    asset: 'assets/images/furniture/den_sao_v3.webp',
    label: 'Đèn sao',
    reaction: 'Đèn sao sáng rồi, đọc sách thôi!',
    placeX: 39.38,
    placeY: 431.65,
    placeSize: 196.1,
    anchor: Offset(138, 604),
    bakedRect: Rect.zero,
  ),
  RoomFurniture(
    key: 'room-furniture-chau-cay',
    asset: 'assets/images/furniture/chau_cay_v3.webp',
    label: 'Chậu cây',
    reaction: 'Cây lớn nhanh nhé!',
    placeX: 678.45,
    placeY: 377.3,
    placeSize: 358.4,
    anchor: Offset(844, 686),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(767, 662, 921, 686),
  ),
  RoomFurniture(
    key: 'room-furniture-binh-hoa',
    asset: 'assets/images/furniture/binh_hoa_v3.webp',
    label: 'Bình hoa',
    reaction: 'Hoa thơm quá!',
    placeX: 1122.89,
    placeY: 414.15,
    placeSize: 202.24,
    anchor: Offset(1225, 584),
    bakedRect: Rect.zero,
  ),
  RoomFurniture(
    key: 'room-furniture-coc-sao',
    asset: 'assets/images/furniture/coc_sao_v3.webp',
    label: 'Cốc bút',
    reaction: 'Cốc bút đựng bút chì gọn quá!',
    placeX: 1069.36,
    placeY: 443.29,
    placeSize: 161.28,
    anchor: Offset(1150, 580),
    bakedRect: Rect.zero,
  ),
];

/// 8 món Cửa hàng của phòng v4 (bố cục mặc định Muse, tỉ lệ 0,45).
const List<RoomFurniture> roomShopFurnitureV4 = [
  RoomFurniture(
    key: 'room-furniture-noi_nha_pet',
    asset: 'assets/images/furniture/noi_nha_pet.webp',
    label: 'Nhà cho pet',
    reaction: 'Nhà của pet ấm áp quá!',
    placeX: 792.35,
    placeY: 681.55,
    placeSize: 230.4,
    anchor: Offset(908, 880),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(851, 856, 965, 880),
  ),
  RoomFurniture(
    key: 'room-furniture-noi_ke_sach',
    asset: 'assets/images/furniture/noi_ke_sach.webp',
    label: 'Kệ sách',
    reaction: 'Nhiều sách hay quá!',
    placeX: 269.57,
    placeY: 676.55,
    placeSize: 230.4,
    anchor: Offset(385, 875),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(323, 851, 447, 875),
  ),
  RoomFurniture(
    key: 'room-furniture-noi_be_ca',
    asset: 'assets/images/furniture/noi_be_ca.webp',
    label: 'Bể cá',
    reaction: 'Cá bơi lội vui quá!',
    placeX: 1044.35,
    placeY: 682.55,
    placeSize: 230.4,
    anchor: Offset(1160, 881),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(1107, 857, 1213, 881),
  ),
  RoomFurniture(
    key: 'room-furniture-noi_cay_cao',
    asset: 'assets/images/furniture/noi_cay_cao.webp',
    label: 'Chậu cây lá to',
    reaction: 'Cây lá to xanh mướt!',
    placeX: 628.35,
    placeY: 546.55,
    placeSize: 230.4,
    anchor: Offset(744, 745),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(696, 721, 792, 745),
  ),
  RoomFurniture(
    key: 'room-furniture-noi_ghe_luoi',
    asset: 'assets/images/furniture/noi_ghe_luoi.webp',
    label: 'Ghế lười',
    reaction: 'Ghế lười êm ơi là êm!',
    placeX: 147.35,
    placeY: 664.55,
    placeSize: 230.4,
    anchor: Offset(263, 863),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(214, 839, 312, 863),
  ),
  RoomFurniture(
    key: 'room-furniture-noi_leu',
    asset: 'assets/images/furniture/noi_leu.webp',
    label: 'Lều đồ chơi',
    reaction: 'Chui vào lều chơi nào!',
    placeX: -25.65,
    placeY: 694.55,
    placeSize: 230.4,
    anchor: Offset(90, 893),
    bakedRect: Rect.zero,
    footprint: Rect.fromLTRB(27, 869, 153, 893),
  ),
  RoomFurniture(
    key: 'room-furniture-noi_den_trang',
    asset: 'assets/images/furniture/noi_den_trang.webp',
    label: 'Đèn mặt trăng',
    reaction: 'Đèn mặt trăng sáng dịu ghê!',
    placeX: 974.58,
    placeY: 181.55,
    placeSize: 230.4,
    anchor: Offset(1090, 380),
    bakedRect: Rect.zero,
    wall: true,
  ),
  RoomFurniture(
    key: 'room-furniture-noi_tranh',
    asset: 'assets/images/furniture/noi_tranh.webp',
    label: 'Tranh cầu vồng',
    reaction: 'Cầu vồng đẹp quá!',
    placeX: 276.57,
    placeY: 101.55,
    placeSize: 230.4,
    anchor: Offset(392, 300),
    bakedRect: Rect.zero,
    wall: true,
  ),
];

/// Chủ đề có biến thể của từng món nhỏ (mã món -> chủ đề). Phòng Rồng dùng
/// lại nguyên bản `*_v3` nên không có biến thể; Ngân hà vẽ riêng gấu, chậu
/// cây, bình hoa (đèn sao, cốc bút dùng lại `_v3`); Tết vẽ riêng cả 5 món.
const Map<String, Set<String>> _smallThemeVariants = <String, Set<String>>{
  'gau-bong': {'tet', 'ngan_ha'},
  'den-sao': {'tet'},
  'chau-cay': {'tet', 'ngan_ha'},
  'binh-hoa': {'tet', 'ngan_ha'},
  'coc-sao': {'tet'},
};

/// 8 món Cửa hàng có biến thể ở cả 3 phòng chủ đề.
const Set<String> _shopThemeVariants = <String>{'rong', 'tet', 'ngan_ha'};

/// Món kéo thả của phòng v4: 7 món lớn + 5 món nhỏ + 8 món Cửa hàng.
List<RoomPlaceable> _roomPlaceablesV4() => [
  for (final f in roomBigFurniture)
    RoomPlaceable(
      id: roomShopFurnitureId(f),
      item: f,
      kind: f.wall ? RoomPlaceKind.wall : RoomPlaceKind.floor,
      tier: roomBigFurnitureTier[roomShopFurnitureId(f)] ?? RoomItemTier.large,
      variantArt: roomVariantArt[roomShopFurnitureId(f)] ?? const {},
      flat: f.key == 'room-furniture-noi_tham',
      drawAfter: f.key == 'room-furniture-noi_ghe' ? 'noi_ban_hoc' : null,
    ),
  for (final f in roomFurnitureV4)
    RoomPlaceable(
      id: f.key.substring('room-furniture-'.length),
      item: f,
      kind: f.key == 'room-furniture-chau-cay'
          ? RoomPlaceKind.floor
          : RoomPlaceKind.surface,
      variantArt:
          roomVariantArt[f.key.substring('room-furniture-'.length)] ?? const {},
      variantThemes:
          _smallThemeVariants[f.key.substring('room-furniture-'.length)] ??
          const <String>{},
    ),
  for (final f in roomShopFurnitureV4)
    RoomPlaceable(
      id: roomShopFurnitureId(f),
      item: f,
      kind: f.wall ? RoomPlaceKind.wall : RoomPlaceKind.floor,
      shopId: roomShopFurnitureId(f),
      tier: roomShopFurnitureTier[roomShopFurnitureId(f)] ?? RoomItemTier.small,
      variantArt: roomVariantArt[roomShopFurnitureId(f)] ?? const {},
      variantThemes: _shopThemeVariants,
    ),
];

/// Món kéo thả của phòng v3 (cũ): 4 món nhỏ vẽ rời trên nền sạch (chậu cây
/// còn vẽ sẵn trong nền nên không kéo được) + 8 món Cửa hàng.
List<RoomPlaceable> _roomPlaceablesV3() => [
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
];

/// Mọi món kéo thả được. Phòng v4 ([roomV4Ready]): 7 món lớn + 5 món nhỏ +
/// 8 món Cửa hàng. Mỗi món có thể có biến thể theo chủ đề (xem
/// `room_variants.dart`).
final List<RoomPlaceable> roomPlaceables = List.unmodifiable(
  roomV4Ready ? _roomPlaceablesV4() : _roomPlaceablesV3(),
);

/// Món kéo thả theo mã; null nếu không có.
RoomPlaceable? roomPlaceableById(String id) {
  for (final p in roomPlaceables) {
    if (p.id == id) return p;
  }
  return null;
}

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

/// Đa giác sàn (nơi nhân vật + pet đứng), khung 1600x900. Đường chân
/// tường (mép trên sàn) đo lại 25/11 trên cả 2 nền v4 (`room_v4.webp`,
/// `room_rong.webp`) rồi lấy đường THẤP hơn của hai nền để món đứng đúng
/// sàn ở cả hai: giữa phòng y 660 (phòng gốc 598, phòng Rồng 660), hai
/// bên dốc cong xuống ~y 838 (trái) / ~862 (phải) ở mép khung.
const List<Offset> roomFloorPolygon = <Offset>[
  Offset(0, 838),
  Offset(50, 815),
  Offset(100, 787),
  Offset(150, 745),
  Offset(200, 712),
  Offset(250, 688),
  Offset(300, 660),
  Offset(1070, 660),
  Offset(1100, 682),
  Offset(1150, 718),
  Offset(1200, 740),
  Offset(1250, 758),
  Offset(1300, 775),
  Offset(1350, 792),
  Offset(1400, 808),
  Offset(1450, 819),
  Offset(1500, 830),
  Offset(1550, 845),
  Offset(1600, 862),
  Offset(1600, 900),
  Offset(0, 900),
];

/// Số đỉnh đầu của [roomFloorPolygon] tạo đường chân tường (trái → phải).
const int _roomFloorTopCount = 19;

/// Mặt giường (nệm/chăn, nơi gấu ngồi) của phòng v3: gấu neo y = 550.
const Rect roomBedSurface = Rect.fromLTRB(155, 540, 760, 560);

/// Mặt tủ đầu giường của phòng v3: đèn neo y = 580.
const Rect roomNightstandSurface = Rect.fromLTRB(30, 575, 260, 585);

/// Mặt bàn học của phòng v3: bình neo y = 510, cốc neo y = 515.
const Rect roomDeskSurface = Rect.fromLTRB(1070, 490, 1470, 515);

/// Dấu chân trên sàn của đồ VẼ SẴN trong nền phòng v3 (vùng đi được = đa
/// giác sàn trừ các dấu chân này). Phòng v4 ([roomV4Ready]) không còn đồ
/// vẽ sẵn: dấu chân lấy từ từng món rời ([RoomPlaceable.footprintAt]).
const Map<String, Rect> roomObstacleFootprints = roomV4Ready
    ? <String, Rect>{}
    : <String, Rect>{
        'bed': Rect.fromLTRB(155, 645, 760, 700),
        'desk': Rect.fromLTRB(1070, 645, 1470, 790),
        'wardrobe': Rect.fromLTRB(1460, 645, 1600, 880),
        'nightstand': Rect.fromLTRB(30, 700, 260, 800),
      };

/// Ghế ở bàn học (phòng v3, cho tương tác ngồi ghế sau này).
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
// Vùng đặt đồ (kéo thả). Đo bằng PIL trên `room_v4.webp` và
// `room_rong.webp` 1600x900 (xem [roomFloorPolygon]): chân tường ở y 598
// (phòng gốc) / 660 (phòng Rồng) suốt đoạn giữa, rồi dốc cong xuống hai
// mép; sàn kéo tới sát đáy khung (y 900).
// ---------------------------------------------------------------------

/// Chân món trên sàn cách đường chân tường ít nhất bằng này (để dấu chân
/// 24 px của món vẫn nằm trong sàn).
const double roomFloorFeetInset = 24;

/// Chân món trên sàn thấp nhất (đáy khung 900, chừa 5 px).
const double roomFloorFeetBottom = 895;

/// Chân/điểm neo của món không ra sát mép trái/phải hơn mức này.
const double roomPlaceMinX = 20;
const double roomPlaceMaxX = 1580;

/// Đỉnh nhìn thấy của món (đồ cao) không cao quá mức này (cách mép trên
/// khung 20 px).
const double roomPlaceTopMargin = 20;

/// Đáy món gắn tường cách đường chân tường ít nhất bằng này: lấy theo nền
/// có chân tường CAO hơn (phòng gốc, y 598 so với y 660 của sàn dùng
/// chung) để món treo không đè lên sàn ở nền nào.
const double roomWallFloorGap = 66;

/// Vùng tường: dưới trần (đỉnh nhìn thấy của món y >= 30) và trên
/// đường chân tường (đáy y <= [roomFloorTopAt] - [roomWallFloorGap]); mép
/// trái/phải là [roomPlaceMinX]/[roomPlaceMaxX]. Phần bottom của Rect là
/// chân tường ở giữa phòng (y 660 - 66 = 594); hai mép phòng chân tường
/// thấp hơn nên đáy thật tính theo [roomClampWallAnchor].
const Rect roomWallRegion = Rect.fromLTRB(
  roomPlaceMinX,
  30,
  roomPlaceMaxX,
  594,
);

/// Ảnh 512x512 có phần trong suốt: đỉnh nhìn thấy của món nằm cách mép
/// trên ảnh khoảng 16% cỡ ảnh (đo trên 13 ảnh nội thất).
const double roomImageTopInset = 0.16;

/// Đường chân tường (đỉnh vùng sàn) tại hoành độ [x] (khung 1600x900):
/// nội suy tuyến tính theo các đỉnh đầu của [roomFloorPolygon].
double roomFloorTopAt(double x) {
  final p = roomFloorPolygon;
  if (x <= p.first.dx) return p.first.dy;
  if (x >= p[_roomFloorTopCount - 1].dx) return p[_roomFloorTopCount - 1].dy;
  for (var i = 1; i < _roomFloorTopCount; i++) {
    if (x <= p[i].dx) {
      final t = (x - p[i - 1].dx) / (p[i].dx - p[i - 1].dx);
      return p[i - 1].dy + (p[i].dy - p[i - 1].dy) * t;
    }
  }
  return p[_roomFloorTopCount - 1].dy;
}

/// Kẹp chân món sàn [feet] vào vùng sàn. [visibleHeight]: chiều cao phần
/// nhìn thấy của món (đồ cao như tủ áo không được thò quá mép trên khung);
/// [halfWidth]: nửa bề rộng hộp (hộp không ra khỏi mép trái/phải khung).
Offset roomClampFloorFeet(
  Offset feet, {
  double visibleHeight = 0,
  double halfWidth = 0,
}) {
  final minX = math.max(roomPlaceMinX, halfWidth);
  final maxX = math.max(
    minX,
    math.min(roomPlaceMaxX, roomFrameWidth - halfWidth),
  );
  final x = feet.dx.clamp(minX, maxX).toDouble();
  final minY = math.max(
    roomFloorTopAt(x) + roomFloorFeetInset,
    roomPlaceTopMargin + visibleHeight,
  );
  final y = feet.dy.clamp(minY, math.max(minY, roomFloorFeetBottom)).toDouble();
  return Offset(x, y);
}

/// Kẹp điểm neo đáy món gắn tường [anchor] vào vùng tường; [visibleHeight]
/// là chiều cao phần nhìn thấy của món (đáy tới đỉnh) để đỉnh không chạm
/// trần; [halfWidth] như [roomClampFloorFeet].
Offset roomClampWallAnchor(
  Offset anchor, {
  double visibleHeight = 0,
  double halfWidth = 0,
}) {
  final minX = math.max(roomWallRegion.left, halfWidth);
  final maxX = math.max(
    minX,
    math.min(roomWallRegion.right, roomFrameWidth - halfWidth),
  );
  final x = anchor.dx.clamp(minX, maxX);
  final bottom = roomFloorTopAt(x.toDouble()) - roomWallFloorGap;
  final top = math.min(roomWallRegion.top + visibleHeight, bottom);
  return Offset(x.toDouble(), anchor.dy.clamp(top, bottom).toDouble());
}

/// Một mặt phẳng của món lớn mà món nhỏ ([RoomPlaceKind.surface]) đặt lên
/// được, tính theo TỈ LỆ hộp của món chủ ([hostId]) nên đi theo món chủ khi
/// bé kéo nó (hoặc đổi biến thể).
class RoomSurfaceSpec {
  const RoomSurfaceSpec(
    this.hostId,
    this.left,
    this.top,
    this.right,
    this.bottom,
  );

  /// Mã món chủ (`noi_giuong`, `noi_tu_dau_giuong`, `noi_ban_hoc`).
  final String hostId;

  /// Mép mặt phẳng theo tỉ lệ (0..1) của hộp món chủ.
  final double left;
  final double top;
  final double right;
  final double bottom;

  /// Mặt phẳng khi hộp món chủ là [box].
  Rect within(Rect box) => Rect.fromLTRB(
    box.left + left * box.width,
    box.top + top * box.height,
    box.left + right * box.width,
    box.top + bottom * box.height,
  );
}

/// Mặt giường (nệm/chăn: gấu ngồi), mặt tủ đầu giường (đèn sao), mặt bàn
/// học (bình hoa) của phòng v4 theo hộp từng món.
const List<RoomSurfaceSpec> roomSurfaceSpecs = <RoomSurfaceSpec>[
  RoomSurfaceSpec('noi_giuong', 0.12, 0.46, 0.88, 0.58),
  RoomSurfaceSpec('noi_tu_dau_giuong', 0.15, 0.04, 0.85, 0.14),
  RoomSurfaceSpec('noi_ban_hoc', 0.26, 0.25, 0.88, 0.34),
];

/// Bậu cửa sổ (cố định theo nền, không đi theo món nào): cốc bút đặt ở đây.
const Rect roomWindowSillSurface = Rect.fromLTRB(640, 452, 900, 466);

/// Mọi mặt phẳng món nhỏ đặt lên được, khi hộp món chủ do [hostBox] cho
/// (null = món chủ không có/không vẽ thì bỏ mặt đó).
List<Rect> roomSurfacesFor(Rect? Function(String hostId) hostBox) => [
  for (final s in roomSurfaceSpecs)
    if (hostBox(s.hostId) case final box?) s.within(box),
  roomWindowSillSurface,
];

/// Các mặt phẳng ở bố cục MẶC ĐỊNH (phòng gốc).
final List<Rect> roomDefaultSurfaces = roomV4Ready
    ? List.unmodifiable(
        roomSurfacesFor(
          (id) =>
              roomPlaceableById(id)
                  ?.boxAt(roomThemeClassic, roomPlaceableById(id)!.defaultPos),
        ),
      )
    : const <Rect>[roomBedSurface, roomNightstandSurface, roomDeskSurface];

/// Các mặt phẳng món nhỏ ([RoomPlaceKind.surface]) đặt lên được ở bố cục
/// mặc định (khi bé dời món chủ thì dùng [roomSurfacesFor]).
List<Rect> get roomSurfaces => roomDefaultSurfaces;

/// Điểm gần [p] nhất thuộc hình chữ nhật [r].
Offset _nearestInRect(Rect r, Offset p) => Offset(
  p.dx.clamp(r.left, r.right).toDouble(),
  p.dy.clamp(r.top, r.bottom).toDouble(),
);

/// Kẹp điểm neo của món nhỏ: gần nhất giữa vùng sàn và các mặt phẳng
/// [surfaces] (mặc định [roomSurfaces]).
Offset roomClampSurfaceAnchor(Offset anchor, {List<Rect>? surfaces}) {
  var best = roomClampFloorFeet(anchor);
  var bestD = (best - anchor).distanceSquared;
  for (final r in surfaces ?? roomSurfaces) {
    final c = _nearestInRect(r, anchor);
    final d = (c - anchor).distanceSquared;
    if (d < bestD) {
      best = c;
      bestD = d;
    }
  }
  return best;
}

/// Mặt phẳng trong [surfaces] mà điểm neo [anchor] đang đứng trên (sai số
/// 2 px); null nếu món đứng trên sàn.
Rect? roomSurfaceUnder(Offset anchor, List<Rect> surfaces) {
  for (final r in surfaces) {
    if (r.inflate(2).contains(anchor)) return r;
  }
  return null;
}

/// Kẹp góc trên-trái [topLeft] (vị trí lưu, tức góc trên-trái của hộp
/// phòng gốc) của [p] sao cho điểm neo nằm trong vùng hợp lệ của loại món ở
/// biến thể [variant] (loại + cỡ có thể khác phòng gốc, ví dụ kệ lớn Rồng
/// đứng sàn); trả về góc trên-trái đã kẹp. [surfaces]: mặt phẳng hiện tại
/// của món nhỏ (mặc định theo bố cục mặc định).
Offset roomClampPlaceable(
  RoomPlaceable p,
  Offset topLeft, {
  String variant = roomThemeClassic,
  List<Rect>? surfaces,
}) {
  final off = p.anchorOffset;
  final anchor = topLeft + off;
  final art = p.artFor(variant);
  final clamped = switch (p.kindFor(variant)) {
    RoomPlaceKind.floor => roomClampFloorFeet(
      anchor,
      visibleHeight: art.cropped ? art.visibleHeight : 0,
      halfWidth: art.halfWidth,
    ),
    RoomPlaceKind.surface => roomClampSurfaceAnchor(anchor, surfaces: surfaces),
    RoomPlaceKind.wall => roomClampWallAnchor(
      anchor,
      visibleHeight: art.visibleHeight,
      halfWidth: art.halfWidth,
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
