/// Bộ phòng chủ đề (lô 15 của Muse, chủ chương trình chốt 25/11): MỘT
/// phòng duy nhất; nền và từng món đồ (mọi [RoomPlaceable]) chọn riêng
/// một BIẾN THỂ: `classic` (gốc) hoặc mã chủ đề (`tet`, `ngan_ha`,
/// `rong`).
///
/// Mua ở Cửa hàng (tab Nội thất) hai cách: cả bộ (`room_theme_<id>`, mở
/// nền + MỌI món của chủ đề) hoặc món lẻ (`room_item_<chủ đề>_<món>`, mở
/// biến thể của một món; có đủ mọi món lẻ thì tặng luôn nền). Trong Phòng,
/// nút "Phong cách" = "Thay cả bộ"; ở chế độ Sắp xếp chạm một món để đổi
/// biến thể riêng món đó. Chủ đề chưa có hình (cờ [roomThemeArtReady])
/// thì ẩn khỏi Cửa hàng và Phòng.
///
/// Ảnh biến thể: nền `backgrounds/room_<chủ đề>.webp`, món
/// `furniture/<chủ đề>_<hậu tố>.webp` (xem [roomThemeFurnitureAsset]);
/// thiếu ảnh thì tự về ảnh gốc.
library;

import '../pet/pet_config.dart';

class RoomTheme {
  const RoomTheme({
    required this.id,
    required this.name,
    required this.rarity,
    this.priceXu = 0,
    this.priceGems = 0,
    this.itemPrices = const {},
  });

  /// Mã chủ đề, cũng là tiền tố tên file (`tet`, `ngan_ha`, `rong`).
  final String id;
  final String name;
  final PetRarity rarity;
  final int priceXu;
  final int priceGems;

  /// Giá một món lẻ theo cỡ; cùng loại tiền với bộ (xu hoặc kim cương).
  final Map<RoomItemTier, int> itemPrices;

  /// Tên ngắn (bỏ chữ "Phòng"), dùng đặt tên món lẻ.
  String get shortName => name.replaceFirst('Phòng ', '');

  /// Bộ tính bằng kim cương.
  bool get usesGems => priceGems > 0;

  /// Giá món lẻ cỡ [tier] (xu hoặc kim cương theo [usesGems]).
  int itemPrice(RoomItemTier tier) => itemPrices[tier] ?? 0;
}

/// Cỡ món (quyết định giá món lẻ: đồ to đắt hơn).
enum RoomItemTier { small, medium, large }

/// Chủ đề bán ở Cửa hàng, giá tăng theo độ hiếm (hợp bộ đồ 09/10/11).
/// Giá bộ luôn rẻ hơn tổng giá mọi món lẻ (có test khóa).
const List<RoomTheme> roomThemes = <RoomTheme>[
  RoomTheme(
    id: 'tet',
    name: 'Phòng Tết',
    rarity: PetRarity.rare,
    priceXu: 2000,
    itemPrices: {
      RoomItemTier.small: 150,
      RoomItemTier.medium: 220,
      RoomItemTier.large: 300,
    },
  ),
  RoomTheme(
    id: 'ngan_ha',
    name: 'Phòng Ngân hà',
    rarity: PetRarity.rare,
    priceXu: 2500,
    itemPrices: {
      RoomItemTier.small: 200,
      RoomItemTier.medium: 280,
      RoomItemTier.large: 350,
    },
  ),
  RoomTheme(
    id: 'rong',
    name: 'Phòng Rồng',
    rarity: PetRarity.epic,
    priceGems: 120,
    itemPrices: {
      RoomItemTier.small: 8,
      RoomItemTier.medium: 12,
      RoomItemTier.large: 15,
    },
  ),
];

/// Đã có hình (nền + 8 món) của từng chủ đề chưa. Bật khi decode xong
/// lô 15 của chủ đề đó.
const Map<String, bool> roomThemeArtReady = <String, bool>{
  'tet': false,
  'ngan_ha': false,
  'rong': true,
};

/// Mã phòng gốc (luôn có, không bán).
const String roomThemeClassic = 'classic';

/// Khóa settings (theo bé) CŨ lưu chủ đề đang dùng (mỗi chủ đề một
/// phòng). Chỉ còn đọc để chuyển sang [roomBackgroundSettingsKey].
const String roomThemeSettingsKey = 'room_theme';

/// Khóa settings (theo bé) lưu biến thể của NỀN phòng (`classic`/mã chủ đề).
const String roomBackgroundSettingsKey = 'room_background';

/// Khóa settings (theo bé) lưu biến thể từng món: JSON mã món -> biến thể.
const String roomVariantsSettingsKey = 'room_variants';

/// Mã món trong Cửa hàng / kho đồ của chủ đề [id].
String roomThemeItemId(String id) => 'room_theme_$id';

/// Nền phòng của chủ đề [id].
String roomThemeBackground(String id) =>
    'assets/images/backgrounds/room_$id.webp';

/// Ảnh biến thể [themeId] của món mã [baseId]: món Cửa hàng `noi_<chỗ>`
/// -> `<chủ đề>_<chỗ>.webp`; món khác (mã `gau-bong`, `giuong`...) ->
/// `<chủ đề>_<mã, gạch ngang đổi gạch dưới>.webp`. Biến thể gốc
/// ([roomThemeClassic]) giữ ảnh gốc `<baseId>.webp` (món có ảnh gốc khác
/// tên thì [RoomPlaceable.assetFor] dùng `item.asset`).
String roomThemeFurnitureAsset(String themeId, String baseId) {
  if (themeId == roomThemeClassic) {
    return 'assets/images/furniture/$baseId.webp';
  }
  final stem = baseId.startsWith('noi_')
      ? baseId.substring(4)
      : baseId.replaceAll('-', '_');
  return 'assets/images/furniture/${themeId}_$stem.webp';
}

/// Chủ đề theo mã; null nếu không có.
RoomTheme? roomThemeById(String id) {
  for (final t in roomThemes) {
    if (t.id == id) return t;
  }
  return null;
}

/// Chủ đề dùng được: đã có hình ([ready], mặc định theo cờ).
bool isRoomThemeReady(
  String id, {
  Map<String, bool> ready = roomThemeArtReady,
}) => ready[id] ?? false;
