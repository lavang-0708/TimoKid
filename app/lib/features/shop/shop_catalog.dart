/// Danh mục Cửa hàng (T2-06): món bé mua được bằng xu, chỉ dùng hình
/// ĐÃ CÓ (bộ đồ + phụ kiện của nhân vật toàn thân, xem `kid_assets.dart`).
///
/// Mã món (`id`) cũng là `item_id` trong bảng `inventory`: bộ đồ dùng
/// luôn mã bộ đồ (`girl_top_02`, `boy_outfit_03`), phụ kiện dùng
/// `head_hat`, `head_bow`, `glasses`, `white_shoes`, `backpack`.
/// Giá là hằng số có tên bên dưới; đổi giá chỉ sửa ở đây.
///
/// T2-06b: thêm "Đồ cho pet" (3 thức ăn dùng-một-lần 10 xu, 3 đồ chơi
/// 40 xu), "Nội thất" (8 món, ẩn sau [furnitureShopArtReady]) và bộ đồ
/// cao cấp 04–07 (xu hoặc kim cương, ẩn sau [premiumOutfitsArtReady]).
/// Không có hộp quà may rủi, không mua bằng tiền thật (PLAN T2-06).
library;

import '../../core/database/tables.dart';
import '../character/kid_assets.dart';
import '../pet/pet_config.dart';

export '../character/kid_assets.dart' show premiumOutfitsArtReady;

/// Đã có hình 8 món nội thất "noi_*" (Muse đang vẽ, 512x512 ở
/// `assets/images/furniture/`) chưa. `false`: tab Nội thất chỉ hiện thẻ
/// "Sắp có hàng mới!", Phòng không vẽ nội thất mua. `true`: bán được và
/// Phòng vẽ món đã mua ở ô cố định (`roomShopFurniture`).
const bool furnitureShopArtReady = true;

/// Giá (xu).
const int outfitPriceXu = 80;
const int headAccessoryPriceXu = 40;
const int glassesPriceXu = 30;
const int whiteShoesPriceXu = 30;
const int backpackPriceXu = 60;
const int petFoodPriceXu = 10;
const int petToyPriceXu = 40;

/// Giá bộ đồ cao cấp theo số bộ: (xu, kim cương); đúng một số khác 0.
/// Độ hiếm của bộ đồ (chủ dự án 24/11: nhãn lấp lánh ở góc thẻ).
/// Bộ thường (1–4) không có nhãn: 05, 06 Hiếm; 07 (mua bằng kim cương)
/// Siêu hiếm.
const Map<int, PetRarity> outfitRarity = <int, PetRarity>{
  5: PetRarity.rare,
  6: PetRarity.rare,
  7: PetRarity.epic,
};

/// Độ hiếm của bộ đồ số [n] (thường nếu không có trong [outfitRarity]).
PetRarity outfitRarityOf(int n) => outfitRarity[n] ?? PetRarity.common;

const Map<int, (int, int)> premiumOutfitPrices = <int, (int, int)>{
  4: (150, 0),
  5: (300, 0),
  6: (600, 0),
  7: (0, 30),
};

/// Mã phụ kiện không phải bộ đồ.
const String glassesItemId = 'glasses';
const String whiteShoesItemId = 'white_shoes';
const String backpackItemId = 'backpack';

/// Mã món cho phụ kiện đầu (`hat`/`bow`).
String headItemId(String accessory) => 'head_$accessory';

/// Nhóm hàng trong Cửa hàng.
enum ShopCategory {
  outfits('outfits', 'Quần áo'),
  accessories('accessories', 'Phụ kiện'),
  pet('pet', 'Đồ cho pet'),
  pets('pets', 'Pet'),
  furniture('furniture', 'Nội thất');

  const ShopCategory(this.key, this.label);

  /// Dùng làm phần cuối của key widget (`shop-tab-<key>`).
  final String key;
  final String label;
}

/// Loại món (quyết định cách mặc và cách vẽ hình).
enum ShopItemKind {
  outfit,
  headAccessory,
  glasses,
  whiteShoes,
  backpack,
  petFood,
  petToy,
  furniture,

  /// Trứng pet mua bằng kim cương (D).
  petEgg,
}

class ShopItem {
  const ShopItem({
    required this.id,
    required this.category,
    required this.kind,
    required this.name,
    this.priceXu = 0,
    this.priceGems = 0,
    this.outfit,
    this.accessory,
    this.asset,
    this.species,
    this.rarity,
  });

  /// Loài pet (chỉ với [ShopItemKind.petEgg]).
  final String? species;

  /// Độ hiếm (trứng pet và bộ đồ hiếm; null = không nhãn).
  final PetRarity? rarity;

  final String id;
  final ShopCategory category;
  final ShopItemKind kind;
  final String name;
  final int priceXu;

  /// Giá kim cương (bộ đồ cao cấp); > 0 thì món tính bằng kim cương và
  /// [priceXu] = 0.
  final int priceGems;

  /// Số bộ đồ 1–7 (chỉ với [ShopItemKind.outfit]).
  final int? outfit;

  /// Ảnh món (thức ăn/đồ chơi/nội thất); null với đồ mặc.
  final String? asset;

  /// Món tính bằng kim cương.
  bool get usesGems => priceGems > 0;

  /// Loại tiền trả (`Currency.xu`/`Currency.gem`, giá trị cột ví).
  String get currency => usesGems ? Currency.gem : Currency.xu;

  /// Giá theo loại tiền của món.
  int get price => usesGems ? priceGems : priceXu;

  /// Thức ăn: mua được nhiều lần, có số lượng (không phải một-lần).
  bool get consumable => kind == ShopItemKind.petFood;

  /// `hat`/`bow` (chỉ với [ShopItemKind.headAccessory]).
  final String? accessory;
}

/// Thức ăn cho pet: mã → (tên, đường dẫn ảnh).
const Map<String, (String, String)> petFoods = <String, (String, String)>{
  'pet_food_bone': ('Xương', 'assets/images/items/pet_food_bone.png'),
  'pet_food_fish': ('Cá', 'assets/images/items/pet_food_fish.png'),
  'pet_food_carrot': ('Cà rốt', 'assets/images/items/pet_food_carrot.png'),
};

/// Đồ chơi cho pet: mã → (tên, đường dẫn ảnh).
const Map<String, (String, String)> petToys = <String, (String, String)>{
  'pet_toy_ball': ('Quả bóng', 'assets/images/items/pet_toy_ball.png'),
  'pet_toy_yarn': ('Cuộn len', 'assets/images/items/pet_toy_yarn.png'),
  'pet_toy_plush': ('Thú bông', 'assets/images/items/pet_toy_plush.png'),
};

/// Nội thất bán: mã → (tên, giá xu). Ảnh `assets/images/furniture/<mã>.png`;
/// ô đặt trong phòng ở `roomShopFurniture` (`room_assets.dart`).
const Map<String, (String, int)> shopFurniture = <String, (String, int)>{
  'noi_be_ca': ('Bể cá', 120),
  'noi_den_trang': ('Đèn mặt trăng', 80),
  'noi_ke_sach': ('Kệ sách', 100),
  'noi_ghe_luoi': ('Ghế lười', 90),
  'noi_nha_pet': ('Nhà cho pet', 150),
  'noi_cay_cao': ('Chậu cây lá to', 60),
  'noi_leu': ('Lều đồ chơi', 200),
  'noi_tranh': ('Tranh cầu vồng', 70),
};

/// Mã món của trứng pet [species] (cũng là `refId` dòng trừ kim cương).
String petEggItemId(String species) => 'pet_egg_$species';

/// Trứng pet bán bằng kim cương (D): sóc 20, capybara 60, rồng con 150.
/// Hiện cả loài chưa có hình để thẻ ghi "Sắp có"; mua được hay chưa do
/// [isPetSpeciesBuyable] / `newPetArtReady` quyết định.
List<ShopItem> shopPetEggItems() => [
  for (final s in petShopSpecies)
    ShopItem(
      id: petEggItemId(s.species),
      category: ShopCategory.pets,
      kind: ShopItemKind.petEgg,
      name: 'Trứng ${s.name}',
      priceGems: s.priceGems,
      species: s.species,
      rarity: s.rarity,
    ),
];

/// Ảnh nội thất mua được.
String shopFurnitureAsset(String id) => 'assets/images/furniture/$id.png';

/// Toàn bộ món bán cho một dáng (`girl`/`boy`); giá trị lạ coi như `girl`.
/// [furnitureReady] / [premiumOutfitsReady] mặc định theo cờ const; chỉ
/// đặt khác trong test (cờ const không đổi được lúc chạy).
List<ShopItem> shopItemsFor(
  String gender, {
  bool furnitureReady = furnitureShopArtReady,
  bool premiumOutfitsReady = premiumOutfitsArtReady,
}) {
  final g = kidGender(gender);
  final heads = kidHeadAccessories[g]!;
  return <ShopItem>[
    for (var n = 1; n <= kidOutfitLimit(premiumReady: premiumOutfitsReady); n++)
      ShopItem(
        id: kidAllOutfitIds[g]![n - 1],
        category: ShopCategory.outfits,
        kind: ShopItemKind.outfit,
        name: kidOutfitNames[kidAllOutfitIds[g]![n - 1]]!,
        priceXu: n <= kidBasicOutfitCount
            ? outfitPriceXu
            : premiumOutfitPrices[n]!.$1,
        priceGems: n <= kidBasicOutfitCount ? 0 : premiumOutfitPrices[n]!.$2,
        outfit: n,
        rarity: outfitRarity[n],
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
    for (final e in petFoods.entries)
      ShopItem(
        id: e.key,
        category: ShopCategory.pet,
        kind: ShopItemKind.petFood,
        name: e.value.$1,
        priceXu: petFoodPriceXu,
        asset: e.value.$2,
      ),
    for (final e in petToys.entries)
      ShopItem(
        id: e.key,
        category: ShopCategory.pet,
        kind: ShopItemKind.petToy,
        name: e.value.$1,
        priceXu: petToyPriceXu,
        asset: e.value.$2,
      ),
    if (furnitureReady)
      for (final e in shopFurniture.entries)
        ShopItem(
          id: e.key,
          category: ShopCategory.furniture,
          kind: ShopItemKind.furniture,
          name: e.value.$1,
          priceXu: e.value.$2,
          asset: shopFurnitureAsset(e.key),
        ),
  ];
}

/// Tìm món theo mã trong danh mục của một dáng; null nếu không bán
/// (kể cả nội thất/bộ cao cấp khi cờ còn tắt).
ShopItem? shopItemById(
  String gender,
  String itemId, {
  bool furnitureReady = furnitureShopArtReady,
  bool premiumOutfitsReady = premiumOutfitsArtReady,
}) {
  for (final item in shopItemsFor(
    gender,
    furnitureReady: furnitureReady,
    premiumOutfitsReady: premiumOutfitsReady,
  )) {
    if (item.id == itemId) return item;
  }
  return null;
}
