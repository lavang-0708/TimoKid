/// Dịch vụ Cửa hàng (T2-06): mua đồ bằng xu, kho đồ của bé, giữ đồ
/// cho máy cài trước bản có cửa hàng.
///
/// Mua = MỘT transaction: dòng âm trong `wallet_ledger` (lý do
/// `shop_buy`, `refId` = mã món, loại tiền theo món: xu hoặc kim
/// cương) + dòng `inventory`. Kiểm tra đã có món và đủ tiền nằm trong
/// cùng transaction nên không mua trùng, số dư không bao giờ âm, và lỗi
/// giữa chừng thì không có gì được ghi.
///
/// Thức ăn pet là món DÙNG-MỘT-LẦN (T2-06b): mua nhiều lần, số lượng
/// lưu bằng bộ đếm trong `settings` (khóa [petFoodCountKey], riêng từng
/// bé) — không đụng bảng `inventory` (unique child+item chỉ cho một
/// dòng/món) nên không tăng schema. Mua = trừ ví + tăng bộ đếm trong
/// cùng một transaction; cho ăn ([consumeFood]) = giảm bộ đếm trong một
/// transaction, không bao giờ xuống dưới 0.
library;

import '../room/room_themes.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables.dart' show Currency;
import '../character/kid_assets.dart';
import '../character/kid_look_service.dart';
import '../onboarding/onboarding_service.dart';
import '../pet/pet_config.dart';
import '../pet/pet_service.dart';
import '../rewards/reward_config.dart';
import '../rewards/reward_service.dart';
import 'shop_catalog.dart';

/// Kết quả một lần mua.
enum BuyResult {
  /// Mua xong: đã trừ xu và thêm vào kho.
  bought,

  /// Bé đã có món này, không mua lại.
  alreadyOwned,

  /// Không đủ xu, không ghi gì.
  insufficient,

  /// Mã món không có trong danh mục của bé.
  unknownItem,

  /// Loài pet chưa có hình (`newPetArtReady` false): chưa bán.
  comingSoon,
}

/// Nguồn có món (cột `inventory.source`).
class InventorySource {
  static const shop = 'shop';
  static const starter = 'starter';
  static const grandfather = 'grandfather';
}

/// Lý do dòng trừ tiền trong `wallet_ledger`.
const String shopBuyReason = 'shop_buy';

/// Khóa `settings` (theo bé) giữ số thức ăn đang có của món [foodId].
String petFoodCountKey(String foodId) => 'pet_food_count.$foodId';

class ShopService {
  ShopService({
    required this.db,
    this.afterLedgerWrite,
    this.furnitureReady = furnitureShopArtReady,
    this.premiumOutfitsReady = premiumOutfitsArtReady,
    this.petArtReady = newPetArtReady,
    this.roomThemesReady = roomThemeArtReady,
  });

  /// Cờ hình phòng chủ đề; mặc định theo [roomThemeArtReady], chỉ test đổi.
  final Map<String, bool> roomThemesReady;

  final AppDatabase db;

  /// Cờ hình từng loài pet mới; mặc định theo [newPetArtReady], chỉ
  /// test đổi.
  final Map<String, bool> petArtReady;

  /// Cờ hình nội thất / bộ cao cấp; mặc định theo cờ const, chỉ test đổi.
  final bool furnitureReady;
  final bool premiumOutfitsReady;

  /// Chỉ test: chạy ngay sau khi ghi `wallet_ledger`, trước khi ghi
  /// `inventory` — ném lỗi ở đây để kiểm transaction hoàn tác cả hai.
  final Future<void> Function()? afterLedgerWrite;

  // Chỉ dùng để đọc số dư; bảng thưởng không liên quan.
  RewardService get _rewards =>
      RewardService(db: db, config: RewardConfig.defaults());

  /// Số dư xu của bé.
  Future<int> xuBalance(String childId) => _rewards.xuBalance(childId);

  /// Số dư xu và kim cương.
  Future<Map<String, int>> balances(String childId) =>
      _rewards.balances(childId);

  /// Mã mọi món bé đang có.
  Future<Set<String>> owned(String childId) async => {
    for (final row in await db.inventoryDao.getAll(childId)) row.itemId,
  };

  /// Bé có món này không.
  Future<bool> isOwned(String childId, String itemId) =>
      db.inventoryDao.has(childId, itemId);

  /// Số thức ăn [foodId] bé đang có (0 nếu chưa mua).
  Future<int> foodCount(String childId, String foodId) async {
    final raw = await db.settingsDao.getValue(
      childId: childId,
      key: petFoodCountKey(foodId),
    );
    final n = int.tryParse(raw ?? '') ?? 0;
    return n < 0 ? 0 : n;
  }

  /// Số lượng của cả 3 thức ăn (mã → số).
  Future<Map<String, int>> foodCounts(String childId) async => {
    for (final id in petFoods.keys) id: await foodCount(childId, id),
  };

  /// Cho ăn: giảm một phần thức ăn. Trả false (không đổi gì) nếu bé
  /// không còn; số lượng không bao giờ âm.
  Future<bool> consumeFood(String childId, String foodId) async {
    if (!petFoods.containsKey(foodId) && foodId != petMealId) return false;
    return db.transaction(() async {
      final n = await foodCount(childId, foodId);
      if (n <= 0) return false;
      await db.settingsDao.setValue(
        childId: childId,
        key: petFoodCountKey(foodId),
        value: '${n - 1}',
      );
      return true;
    });
  }

  /// Mua một món theo [itemId] (xem [shopItemsFor]) cho bé có dáng [gender].
  /// Thức ăn mua được nhiều lần (cộng bộ đếm); món khác chỉ mua một lần.
  Future<BuyResult> buy({
    required String childId,
    required String gender,
    required String itemId,
  }) async {
    final item = shopItemById(
      gender,
      itemId,
      furnitureReady: furnitureReady,
      premiumOutfitsReady: premiumOutfitsReady,
      roomThemesReady: roomThemesReady,
    );
    if (item == null) return BuyResult.unknownItem;
    return db.transaction(() async {
      if (!item.consumable && await db.inventoryDao.has(childId, itemId)) {
        return BuyResult.alreadyOwned;
      }
      final balance = await db.walletDao.balance(
        childId: childId,
        currency: item.currency,
      );
      if (balance < item.price) return BuyResult.insufficient;
      await db.walletDao.addEntry(
        childId: childId,
        currency: item.currency,
        amount: -item.price,
        reason: shopBuyReason,
        refId: itemId,
      );
      await afterLedgerWrite?.call();
      if (item.consumable) {
        await db.settingsDao.setValue(
          childId: childId,
          key: petFoodCountKey(itemId),
          value: '${await foodCount(childId, itemId) + 1}',
        );
      } else {
        await db.inventoryDao.grant(
          childId: childId,
          itemId: itemId,
          source: InventorySource.shop,
        );
      }
      return BuyResult.bought;
    });
  }

  /// Mua trứng pet [species] bằng kim cương (D). Một transaction: dòng
  /// âm `wallet_ledger` (loại `gem`, `shop_buy`, refId = [petEggItemId])
  /// + một pet-trứng mới. Mỗi loài mua một lần (đã có pet loài đó →
  /// [BuyResult.alreadyOwned]); loài chưa có hình → [BuyResult.comingSoon]
  /// và không ghi gì; không đủ kim cương → [BuyResult.insufficient]; số
  /// dư không bao giờ âm. Trứng mua về đi theo bé ngay nếu bé chưa có
  /// pet đi theo; còn không thì nằm trong "Pet của bé" để bé chọn đổi.
  Future<BuyResult> buyPetEgg({
    required String childId,
    required String species,
  }) async {
    final info = petShopSpeciesById(species);
    if (info == null) return BuyResult.unknownItem;
    if (!(petArtReady[species] ?? false)) return BuyResult.comingSoon;
    final pets = PetService(db: db);
    return db.transaction(() async {
      if (await pets.owns(childId, species)) return BuyResult.alreadyOwned;
      final balance = await db.walletDao.balance(
        childId: childId,
        currency: Currency.gem,
      );
      if (balance < info.priceGems) return BuyResult.insufficient;
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.gem,
        amount: -info.priceGems,
        reason: shopBuyReason,
        refId: petEggItemId(species),
      );
      await afterLedgerWrite?.call();
      final noActive = await pets.active(childId) == null;
      await pets.createEgg(
        childId: childId,
        species: species,
        makeActive: noActive,
      );
      return BuyResult.bought;
    });
  }

  /// Cho bé bộ đồ đã chọn ở mở đầu (nguồn `starter`).
  Future<void> grantStarter(String childId, String? dress, String gender) =>
      db.inventoryDao.grant(
        childId: childId,
        itemId: kidAllOutfitIds[kidGender(gender)]![kidOutfitNumber(dress) - 1],
        source: InventorySource.starter,
      );

  /// Giữ đồ cho máy đã cài trước bản có cửa hàng: bộ đồ đang mặc và mọi
  /// phụ kiện đang đeo được thêm vào kho (nguồn `grandfather`) để bé không
  /// mất đồ đang mặc. Gọi lại bao nhiêu lần cũng an toàn (món đã có thì
  /// bỏ qua); chưa xong mở đầu (chưa có hồ sơ) thì không làm gì.
  Future<void> grandfather(String childId) async {
    final profile = await OnboardingService(db: db).loadProfile(childId);
    if (profile == null) return;
    final gender = kidGender(profile.gender);
    final looks = KidLookService(db: db);
    final worn = <String>[
      kidAllOutfitIds[gender]![kidOutfitNumber(profile.dress) - 1],
      if (await looks.headAccessory(childId) case final head?) headItemId(head),
      if (await looks.glasses(childId)) glassesItemId,
      if (await looks.whiteShoes(childId)) whiteShoesItemId,
      if (await looks.backpack(childId)) backpackItemId,
    ];
    await db.transaction(() async {
      for (final id in worn) {
        await db.inventoryDao.grant(
          childId: childId,
          itemId: id,
          source: InventorySource.grandfather,
        );
      }
    });
  }
}
