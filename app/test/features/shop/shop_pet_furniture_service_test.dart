/// Unit test ShopService (T2-06b): thức ăn pet dùng-một-lần (mua nhiều,
/// đếm, cho ăn giảm, không âm), đồ chơi một-lần, nội thất sau cờ hình,
/// bộ đồ cao cấp tính bằng xu hoặc kim cương.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/features/character/kid_assets.dart';
import 'package:timokid/features/shop/shop_catalog.dart';
import 'package:timokid/features/shop/shop_service.dart';

void main() {
  late AppDatabase db;
  late String childId;
  late ShopService shop;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    shop = ShopService(db: db);
  });

  Future<void> give(int amount, {String currency = Currency.xu}) =>
      db.walletDao.addEntry(
        childId: childId,
        currency: currency,
        amount: amount,
        reason: 'test',
      );

  Future<int> gems() =>
      db.walletDao.balance(childId: childId, currency: Currency.gem);

  Future<BuyResult> buy(String id, {String gender = 'girl', ShopService? s}) =>
      (s ?? shop).buy(childId: childId, gender: gender, itemId: id);

  group('danh mục đồ pet', () {
    test('3 thức ăn 10 xu, 3 đồ chơi 40 xu, hình có thật', () {
      final items = shopItemsFor('girl')
          .where((i) => i.category == ShopCategory.pet)
          .toList();
      expect(items, hasLength(6));
      expect(
        items.where((i) => i.kind == ShopItemKind.petFood).map((i) => i.price),
        everyElement(10),
      );
      expect(
        items.where((i) => i.kind == ShopItemKind.petToy).map((i) => i.price),
        everyElement(40),
      );
      expect(items.where((i) => i.consumable), hasLength(3));
      for (final i in items) {
        expect(i.asset, isNotNull);
      }
    });
  });

  group('thức ăn (dùng-một-lần)', () {
    test('mua nhiều lần: mỗi lần trừ 10 xu và cộng 1', () async {
      await give(35);
      for (var i = 1; i <= 3; i++) {
        expect(await buy('pet_food_bone'), BuyResult.bought);
        expect(await shop.foodCount(childId, 'pet_food_bone'), i);
      }
      expect(await shop.xuBalance(childId), 5);
      // Không vào kho đồ (kho chỉ cho món một-lần).
      expect(await shop.isOwned(childId, 'pet_food_bone'), isFalse);
    });

    test('đếm riêng từng loại', () async {
      await give(100);
      await buy('pet_food_bone');
      await buy('pet_food_fish');
      await buy('pet_food_fish');
      expect(await shop.foodCounts(childId), {
        'pet_food_bone': 1,
        'pet_food_fish': 2,
        'pet_food_carrot': 0,
      });
    });

    test('không đủ xu: không mua, không đổi bộ đếm', () async {
      await give(9);
      expect(await buy('pet_food_carrot'), BuyResult.insufficient);
      expect(await shop.foodCount(childId, 'pet_food_carrot'), 0);
      expect(await shop.xuBalance(childId), 9);
    });

    test('cho ăn giảm 1, hết thì không xuống âm', () async {
      await give(20);
      await buy('pet_food_fish');
      await buy('pet_food_fish');
      expect(await shop.consumeFood(childId, 'pet_food_fish'), isTrue);
      expect(await shop.consumeFood(childId, 'pet_food_fish'), isTrue);
      expect(await shop.foodCount(childId, 'pet_food_fish'), 0);
      expect(await shop.consumeFood(childId, 'pet_food_fish'), isFalse);
      expect(await shop.consumeFood(childId, 'pet_food_fish'), isFalse);
      expect(await shop.foodCount(childId, 'pet_food_fish'), 0);
      // Mã lạ / chưa mua: false, không tạo bộ đếm âm.
      expect(await shop.consumeFood(childId, 'pet_food_bone'), isFalse);
      expect(await shop.consumeFood(childId, 'khong_co'), isFalse);
    });

    test('cho ăn hai lần chồng nhau chỉ trừ đúng số có', () async {
      await give(10);
      await buy('pet_food_bone');
      final results = await Future.wait([
        shop.consumeFood(childId, 'pet_food_bone'),
        shop.consumeFood(childId, 'pet_food_bone'),
      ]);
      expect(results.where((r) => r), hasLength(1));
      expect(await shop.foodCount(childId, 'pet_food_bone'), 0);
    });

    test('lỗi giữa chừng khi mua thì hoàn tác cả xu lẫn bộ đếm', () async {
      await give(50);
      final failing = ShopService(
        db: db,
        afterLedgerWrite: () async => throw StateError('hỏng giữa chừng'),
      );
      await expectLater(
        buy('pet_food_bone', s: failing),
        throwsA(isA<StateError>()),
      );
      expect(await shop.xuBalance(childId), 50);
      expect(await shop.foodCount(childId, 'pet_food_bone'), 0);
    });

    test('mỗi bé một bộ đếm riêng', () async {
      await give(10);
      await buy('pet_food_bone');
      expect(await shop.foodCount('be-khac', 'pet_food_bone'), 0);
    });
  });

  group('đồ chơi (một-lần)', () {
    test('mua được một lần, lần hai báo đã có và không trừ xu', () async {
      await give(100);
      expect(await buy('pet_toy_ball'), BuyResult.bought);
      expect(await shop.xuBalance(childId), 60);
      expect(await shop.isOwned(childId, 'pet_toy_ball'), isTrue);
      expect(await buy('pet_toy_ball'), BuyResult.alreadyOwned);
      expect(await shop.xuBalance(childId), 60);
    });

    test('không đủ xu: không ghi gì', () async {
      await give(39);
      expect(await buy('pet_toy_yarn'), BuyResult.insufficient);
      expect(await shop.isOwned(childId, 'pet_toy_yarn'), isFalse);
      expect(await shop.xuBalance(childId), 39);
    });
  });

  group('nội thất sau cờ hình', () {
    test('cờ const đã bật (Muse lô 10): 8 món có trong danh mục', () async {
      expect(furnitureShopArtReady, isTrue);
      expect(
        shopItemsFor('girl').where((i) => i.category == ShopCategory.furniture),
        hasLength(8),
      );
    });

    test('tắt cờ: không có trong danh mục, không mua được', () async {
      final off = ShopService(db: db, furnitureReady: false);
      await give(500);
      expect(
        await off.buy(childId: childId, gender: 'girl', itemId: 'noi_be_ca'),
        BuyResult.unknownItem,
      );
      expect(await off.xuBalance(childId), 500);
    });

    test('bật cờ: 8 món đúng giá, mua một lần', () async {
      final on = ShopService(db: db, furnitureReady: true);
      const prices = {
        'noi_be_ca': 120,
        'noi_den_trang': 80,
        'noi_ke_sach': 100,
        'noi_ghe_luoi': 90,
        'noi_nha_pet': 150,
        'noi_cay_cao': 60,
        'noi_leu': 200,
        'noi_tranh': 70,
      };
      final items = shopItemsFor(
        'boy',
        furnitureReady: true,
      ).where((i) => i.category == ShopCategory.furniture).toList();
      expect(items, hasLength(8));
      for (final i in items) {
        expect(i.priceXu, prices[i.id], reason: i.id);
        expect(i.asset, 'assets/images/furniture/${i.id}.png');
      }
      await give(130);
      expect(await buy('noi_be_ca', s: on), BuyResult.bought);
      expect(await on.xuBalance(childId), 10);
      expect(await buy('noi_be_ca', s: on), BuyResult.alreadyOwned);
      expect(await buy('noi_leu', s: on), BuyResult.insufficient);
      expect(await on.xuBalance(childId), 10);
    });
  });

  group('bộ đồ cao cấp (xu hoặc kim cương)', () {
    test('có đủ hình bộ 04–07: bán 7 bộ', () async {
      expect(premiumOutfitsArtReady, isFalse);
      expect(kidPremiumOutfitsDrawn, 4);
      expect(
        shopItemsFor('girl').where((i) => i.category == ShopCategory.outfits),
        hasLength(7),
      );
      expect(kidOutfitNumber('girl_top_04'), 4);
      expect(kidOutfitNumber('girl_top_05'), 5);
      expect(kidOutfitNumber('girl_top_06'), 6);
      expect(kidOutfitNumber('girl_top_07'), 7);
      await give(1000);
      await give(100, currency: Currency.gem);
      // Bộ 07 mua bằng kim cương (30), không trừ xu.
      expect(await buy('girl_top_07'), BuyResult.bought);
      expect(await gems(), 70);
    });

    test('bật cờ: 7 bộ mỗi dáng, giá 80/150/300/600 xu và 30 kim cương', () {
      for (final g in ['girl', 'boy']) {
        final outfits = shopItemsFor(
          g,
          premiumOutfitsReady: true,
        ).where((i) => i.category == ShopCategory.outfits).toList();
        // Lô 14 (24/11): thêm 08–11 khi đủ hình.
        expect(outfits, hasLength(11));
        expect(outfits.map((i) => i.priceXu), [
          80, 80, 80, 150, 300, 600, 0, 200, 450, 800, 0, //
        ]);
        expect(outfits.map((i) => i.priceGems), [
          0, 0, 0, 0, 0, 0, 30, 0, 0, 0, 50, //
        ]);
        expect(outfits[6].usesGems, isTrue);
        expect(outfits.last.usesGems, isTrue);
        expect(outfits.last.currency, Currency.gem);
        expect(outfits.first.currency, Currency.xu);
      }
      expect(kidOutfitNumber('boy_outfit_07', premiumReady: true), 7);
      expect(kidOutfitNumber('boy_outfit_11', premiumReady: true), 11);
      // Tên file 2 chữ số.
      expect(kidFullAsset('girl', 11), endsWith('girl_full_11.png'));
      expect(
        kidFullAsset('boy', 8, wave: true),
        endsWith('boy_full_08_wave.png'),
      );
    });

    test('mua bộ 04 bằng xu: trừ đúng 150 xu, không đụng kim cương', () async {
      final on = ShopService(db: db, premiumOutfitsReady: true);
      await give(200);
      await give(5, currency: Currency.gem);
      expect(await buy('girl_top_04', s: on), BuyResult.bought);
      expect(await on.xuBalance(childId), 50);
      expect(await gems(), 5);
      expect(await on.isOwned(childId, 'girl_top_04'), isTrue);
    });

    test('mua bộ 07 bằng kim cương: trừ 30 kim cương, không đụng xu', () async {
      final on = ShopService(db: db, premiumOutfitsReady: true);
      await give(1000);
      await give(35, currency: Currency.gem);
      expect(
        await buy('boy_outfit_07', gender: 'boy', s: on),
        BuyResult.bought,
      );
      expect(await gems(), 5);
      expect(await on.xuBalance(childId), 1000);
      final rows = (await db.walletDao.getEntries(childId))
          .where((e) => e.reason == shopBuyReason)
          .toList();
      expect(rows, hasLength(1));
      expect(rows.single.currency, Currency.gem);
      expect(rows.single.amount, -30);
      expect(rows.single.refId, 'boy_outfit_07');
    });

    test('thiếu kim cương: không mua dù dư xu, số dư không âm', () async {
      final on = ShopService(db: db, premiumOutfitsReady: true);
      await give(5000);
      await give(29, currency: Currency.gem);
      expect(await buy('girl_top_07', s: on), BuyResult.insufficient);
      expect(await gems(), 29);
      expect(await on.xuBalance(childId), 5000);
      expect(await on.isOwned(childId, 'girl_top_07'), isFalse);
    });

    test('không mua trùng bộ kim cương; lỗi giữa chừng hoàn tác', () async {
      final on = ShopService(db: db, premiumOutfitsReady: true);
      await give(100, currency: Currency.gem);
      final failing = ShopService(
        db: db,
        premiumOutfitsReady: true,
        afterLedgerWrite: () async => throw StateError('hỏng'),
      );
      await expectLater(
        buy('girl_top_07', s: failing),
        throwsA(isA<StateError>()),
      );
      expect(await gems(), 100);
      expect(await on.isOwned(childId, 'girl_top_07'), isFalse);
      expect(await buy('girl_top_07', s: on), BuyResult.bought);
      expect(await buy('girl_top_07', s: on), BuyResult.alreadyOwned);
      expect(await gems(), 70);
    });

    test('bộ 06 đúng 600 xu: 599 xu không đủ', () async {
      final on = ShopService(db: db, premiumOutfitsReady: true);
      await give(599);
      expect(await buy('girl_top_06', s: on), BuyResult.insufficient);
      await give(1);
      expect(await buy('girl_top_06', s: on), BuyResult.bought);
      expect(await on.xuBalance(childId), 0);
    });
  });

  group('kid_assets mở rộng 7 bộ', () {
    test('bộ 1–3 không đổi; tên đủ 14 mã', () {
      expect(kidOutfitIds['girl'], hasLength(3));
      expect(kidAllOutfitIds['girl'], hasLength(11)); // lô 14: 08–11
      expect(kidAllOutfitIds['boy']!.first, 'boy_outfit_01');
      for (final g in ['girl', 'boy']) {
        for (final id in kidAllOutfitIds[g]!) {
          expect(kidOutfitNames[id], isNotNull, reason: id);
        }
      }
      expect(kidOutfitNumber('girl_top_03'), 3);
      expect(kidOutfitNumber(null), 1);
    });

    test('khung đi bộ có đủ bộ 1–7', () {
      for (final g in ['girl', 'boy']) {
        for (var n = 1; n <= 7; n++) {
          expect(kidWalkFrames(g, n, up: false), hasLength(4));
        }
      }
    });

    test('mắt nhắm bộ 04–07 dùng lại miếng vá bộ 1', () {
      for (var n = 4; n <= 7; n++) {
        expect(kidEyePatch('girl', n).rect, kidEyePatch('girl', 1).rect);
        expect(kidEyePatch('boy', n).rect, kidEyePatch('boy', 1).rect);
        expect(
          kidEyePatch('boy', n, wave: true).asset,
          kidEyePatch('boy', 1, wave: true).asset,
        );
      }
    });
  });
}
