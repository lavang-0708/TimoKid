/// Danh mục Cửa hàng (T2-06): món bé mua được bằng xu, chỉ dùng hình
/// ĐÃ CÓ (bộ đồ + phụ kiện của nhân vật toàn thân, xem `kid_assets.dart`).
///
/// Mã món (`id`) cũng là `item_id` trong bảng `inventory`: bộ đồ dùng
/// luôn mã bộ đồ (`girl_top_02`, `boy_outfit_03`), phụ kiện dùng
/// `head_hat`, `head_bow`, `glasses`, `white_shoes`, `backpack`.
/// Giá là hằng số có tên bên dưới; đổi giá chỉ sửa ở đây.
///
/// Chưa có "Đồ hiếm" (kim cương) vì chưa có hình; không có hộp quà may
/// rủi, không mua bằng tiền thật (PLAN T2-06).
library;

import '../character/kid_assets.dart';

/// Giá (xu).
const int outfitPriceXu = 80;
const int headAccessoryPriceXu = 40;
const int glassesPriceXu = 30;
const int whiteShoesPriceXu = 30;
const int backpackPriceXu = 60;

/// Mã phụ kiện không phải bộ đồ.
const String glassesItemId = 'glasses';
const String whiteShoesItemId = 'white_shoes';
const String backpackItemId = 'backpack';

/// Mã món cho phụ kiện đầu (`hat`/`bow`).
String headItemId(String accessory) => 'head_$accessory';

/// Nhóm hàng trong Cửa hàng.
enum ShopCategory {
  outfits('outfits', 'Quần áo'),
  accessories('accessories', 'Phụ kiện');

  const ShopCategory(this.key, this.label);

  /// Dùng làm phần cuối của key widget (`shop-tab-<key>`).
  final String key;
  final String label;
}

/// Loại món (quyết định cách mặc và cách vẽ hình).
enum ShopItemKind { outfit, headAccessory, glasses, whiteShoes, backpack }

class ShopItem {
  const ShopItem({
    required this.id,
    required this.category,
    required this.kind,
    required this.name,
    required this.priceXu,
    this.outfit,
    this.accessory,
  });

  final String id;
  final ShopCategory category;
  final ShopItemKind kind;
  final String name;
  final int priceXu;

  /// Số bộ đồ 1–3 (chỉ với [ShopItemKind.outfit]).
  final int? outfit;

  /// `hat`/`bow` (chỉ với [ShopItemKind.headAccessory]).
  final String? accessory;
}

/// Toàn bộ món bán cho một dáng (`girl`/`boy`); giá trị lạ coi như `girl`.
List<ShopItem> shopItemsFor(String gender) {
  final g = kidGender(gender);
  final heads = kidHeadAccessories[g]!;
  return <ShopItem>[
    for (var n = 1; n <= 3; n++)
      ShopItem(
        id: kidOutfitIds[g]![n - 1],
        category: ShopCategory.outfits,
        kind: ShopItemKind.outfit,
        name: kidOutfitNames[kidOutfitIds[g]![n - 1]]!,
        priceXu: outfitPriceXu,
        outfit: n,
      ),
    for (final entry in heads.entries)
      ShopItem(
        id: headItemId(entry.key),
        category: ShopCategory.accessories,
        kind: ShopItemKind.headAccessory,
        name: entry.value.$1,
        priceXu: headAccessoryPriceXu,
        accessory: entry.key,
      ),
    const ShopItem(
      id: glassesItemId,
      category: ShopCategory.accessories,
      kind: ShopItemKind.glasses,
      name: 'Kính tròn',
      priceXu: glassesPriceXu,
    ),
    const ShopItem(
      id: whiteShoesItemId,
      category: ShopCategory.accessories,
      kind: ShopItemKind.whiteShoes,
      name: 'Giày trắng',
      priceXu: whiteShoesPriceXu,
    ),
    const ShopItem(
      id: backpackItemId,
      category: ShopCategory.accessories,
      kind: ShopItemKind.backpack,
      name: 'Balo',
      priceXu: backpackPriceXu,
    ),
  ];
}

/// Tìm món theo mã trong danh mục của một dáng; null nếu không bán.
ShopItem? shopItemById(String gender, String itemId) {
  for (final item in shopItemsFor(gender)) {
    if (item.id == itemId) return item;
  }
  return null;
}
