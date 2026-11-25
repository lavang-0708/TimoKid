/// Phòng chủ đề (lô 15 của Muse, chủ dự án giao 24/11): đổi cả phong
/// cách phòng theo bộ đồ hiếm/siêu hiếm mới, không ăn theo phòng gốc.
///
/// Mỗi chủ đề là một nền 1600x900 cùng bố cục/phối cảnh `room_v3.webp`
/// (vùng đi lại, chỗ đặt đồ giữ nguyên) và đã vẽ sẵn món nhỏ theo chủ đề
/// trên bàn/kệ — nên khi bật chủ đề app KHÔNG vẽ 5 món nhỏ của phòng gốc.
/// 8 món nội thất bé đã mua (ô `roomShopFurniture`) đổi sang bản cùng chủ
/// đề `furniture/<chủ đề>_<chỗ>.webp` (chỗ = hậu tố của `noi_<chỗ>`).
///
/// Mua chủ đề ở Cửa hàng (tab Nội thất); đổi qua lại ở nút "Phong cách"
/// trong Phòng. Chủ đề chưa có hình (cờ [roomThemeArtReady]) thì ẩn.
library;

import '../pet/pet_config.dart';

class RoomTheme {
  const RoomTheme({
    required this.id,
    required this.name,
    required this.rarity,
    this.priceXu = 0,
    this.priceGems = 0,
  });

  /// Mã chủ đề, cũng là tiền tố tên file (`tet`, `ngan_ha`, `rong`).
  final String id;
  final String name;
  final PetRarity rarity;
  final int priceXu;
  final int priceGems;
}

/// Chủ đề bán ở Cửa hàng, giá tăng theo độ hiếm (hợp bộ đồ 09/10/11).
const List<RoomTheme> roomThemes = <RoomTheme>[
  RoomTheme(
    id: 'tet',
    name: 'Phòng Tết',
    rarity: PetRarity.rare,
    priceXu: 1200,
  ),
  RoomTheme(
    id: 'ngan_ha',
    name: 'Phòng Ngân hà',
    rarity: PetRarity.rare,
    priceXu: 1800,
  ),
  RoomTheme(
    id: 'rong',
    name: 'Phòng Rồng',
    rarity: PetRarity.epic,
    priceGems: 80,
  ),
];

/// Đã có hình (nền + 8 món) của từng chủ đề chưa. Bật khi decode xong
/// lô 15 của chủ đề đó.
const Map<String, bool> roomThemeArtReady = <String, bool>{
  'tet': false,
  'ngan_ha': false,
  'rong': false,
};

/// Mã phòng gốc (luôn có, không bán).
const String roomThemeClassic = 'classic';

/// Khóa settings (theo bé) lưu chủ đề đang dùng.
const String roomThemeSettingsKey = 'room_theme';

/// Mã món trong Cửa hàng / kho đồ của chủ đề [id].
String roomThemeItemId(String id) => 'room_theme_$id';

/// Nền phòng của chủ đề [id].
String roomThemeBackground(String id) =>
    'assets/images/backgrounds/room_$id.webp';

/// Ảnh món nội thất [baseId] (`noi_<chỗ>`) theo chủ đề [themeId]; phòng
/// gốc thì giữ ảnh gốc.
String roomThemeFurnitureAsset(String themeId, String baseId) {
  if (themeId == roomThemeClassic || !baseId.startsWith('noi_')) {
    return 'assets/images/furniture/$baseId.webp';
  }
  return 'assets/images/furniture/${themeId}_${baseId.substring(4)}.webp';
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
