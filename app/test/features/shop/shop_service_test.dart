/// Unit test ShopService (T2-06): không âm, không mua trùng, trừ đúng
/// giá, ledger + inventory cùng một transaction, giữ đồ đang mặc.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/features/character/kid_look_service.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
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

  Future<void> giveXu(int amount) => db.walletDao.addEntry(
    childId: childId,
    currency: Currency.xu,
    amount: amount,
    reason: 'test',
  );

  Future<int> xu() => shop.xuBalance(childId);

  Future<int> shopLedgerRows() async =>
      (await db.walletDao.getEntries(childId))
          .where((e) => e.reason == shopBuyReason)
          .length;

  group('danh mục', () {
    test(
      'mỗi dáng có bộ đồ để mua (3 cơ bản + bộ 04–06) + 5 phụ kiện đúng giá',
      () {
        for (final g in ['girl', 'boy']) {
          final items = shopItemsFor(g);
          expect(
            items.where((i) => i.category == ShopCategory.outfits),
            hasLength(6),
          );
          expect(
            items.firstWhere((i) => i.id == glassesItemId).priceXu,
            glassesPriceXu,
          );
          expect(items.firstWhere((i) => i.id == 'head_hat').priceXu, 40);
          expect(items.firstWhere((i) => i.id == 'head_bow').priceXu, 40);
          expect(items.firstWhere((i) => i.id == whiteShoesItemId).priceXu, 30);
          expect(items.firstWhere((i) => i.id == backpackItemId).priceXu, 60);
          expect(
            items
                .where((i) => i.kind == ShopItemKind.outfit)
                .map((i) => i.priceXu),
            [80, 80, 80, 150, 300, 600],
          );
        }
      },
    );

    test('chỉ hiện món đúng dáng', () {
      expect(
        shopItemsFor('girl').where((i) => i.id.startsWith('boy_')),
        isEmpty,
      );
      expect(
        shopItemsFor('boy').where((i) => i.id.startsWith('girl_')),
        isEmpty,
      );
      expect(shopItemById('boy', 'girl_top_01'), isNull);
    });
  });

  group('mua', () {
    test('đủ xu: trừ đúng giá, ghi ledger âm + kho trong một lần', () async {
      await giveXu(100);
      final result = await shop.buy(
        childId: childId,
        gender: 'girl',
        itemId: 'girl_top_02',
      );
      expect(result, BuyResult.bought);
      expect(await xu(), 100 - outfitPriceXu);
      expect(await shop.owned(childId), {'girl_top_02'});
      final entries = await db.walletDao.getEntries(childId);
      final buy = entries.singleWhere((e) => e.reason == shopBuyReason);
      expect(buy.amount, -outfitPriceXu);
      expect(buy.currency, Currency.xu);
      expect(buy.refId, 'girl_top_02');
      final row = (await db.inventoryDao.getAll(childId)).single;
      expect(row.source, InventorySource.shop);
    });

    test('đúng bằng giá thì mua được, số dư về 0', () async {
      await giveXu(glassesPriceXu);
      expect(
        await shop.buy(childId: childId, gender: 'boy', itemId: glassesItemId),
        BuyResult.bought,
      );
      expect(await xu(), 0);
    });

    test('không đủ xu: không mua, không ghi gì, số dư không âm', () async {
      await giveXu(outfitPriceXu - 1);
      final result = await shop.buy(
        childId: childId,
        gender: 'girl',
        itemId: 'girl_top_02',
      );
      expect(result, BuyResult.insufficient);
      expect(await xu(), outfitPriceXu - 1);
      expect(await shopLedgerRows(), 0);
      expect(await shop.owned(childId), isEmpty);
    });

    test('ví rỗng: mọi món đều từ chối, không bao giờ âm', () async {
      for (final item in shopItemsFor('girl')) {
        expect(
          await shop.buy(childId: childId, gender: 'girl', itemId: item.id),
          BuyResult.insufficient,
        );
      }
      expect(await xu(), 0);
    });

    test('mua liên tiếp tới hết xu thì dừng, không âm', () async {
      await giveXu(100);
      expect(
        await shop.buy(childId: childId, gender: 'girl', itemId: 'backpack'),
        BuyResult.bought,
      ); // 60 → còn 40
      expect(
        await shop.buy(childId: childId, gender: 'girl', itemId: 'head_hat'),
        BuyResult.bought,
      ); // 40 → còn 0
      expect(
        await shop.buy(childId: childId, gender: 'girl', itemId: 'glasses'),
        BuyResult.insufficient,
      );
      expect(await xu(), 0);
    });

    test('không mua trùng món đã có (kể cả đủ xu)', () async {
      await giveXu(500);
      await shop.buy(childId: childId, gender: 'girl', itemId: 'girl_top_03');
      final after = await xu();
      final again = await shop.buy(
        childId: childId,
        gender: 'girl',
        itemId: 'girl_top_03',
      );
      expect(again, BuyResult.alreadyOwned);
      expect(await xu(), after);
      expect(await shopLedgerRows(), 1);
      expect(await db.inventoryDao.getAll(childId), hasLength(1));
    });

    test('món được cho sẵn (starter) cũng không mua lại được', () async {
      await giveXu(500);
      await shop.grantStarter(childId, 'girl_top_01', 'girl');
      expect(
        await shop.buy(childId: childId, gender: 'girl', itemId: 'girl_top_01'),
        BuyResult.alreadyOwned,
      );
      expect(await xu(), 500);
    });

    test('mã món lạ hoặc món khác dáng bị từ chối', () async {
      await giveXu(500);
      expect(
        await shop.buy(childId: childId, gender: 'girl', itemId: 'nope'),
        BuyResult.unknownItem,
      );
      expect(
        await shop.buy(
          childId: childId,
          gender: 'girl',
          itemId: 'boy_outfit_02',
        ),
        BuyResult.unknownItem,
      );
      expect(await xu(), 500);
    });

    test('hai lần mua chồng nhau cùng một món chỉ trừ xu một lần', () async {
      await giveXu(500);
      final results = await Future.wait([
        shop.buy(childId: childId, gender: 'girl', itemId: 'backpack'),
        shop.buy(childId: childId, gender: 'girl', itemId: 'backpack'),
      ]);
      expect(results.where((r) => r == BuyResult.bought), hasLength(1));
      expect(await xu(), 500 - backpackPriceXu);
      expect(await shopLedgerRows(), 1);
    });

    test(
      'ledger + inventory nguyên tử: lỗi giữa chừng thì không ghi gì',
      () async {
        await giveXu(100);
        final failing = ShopService(
          db: db,
          afterLedgerWrite: () async => throw StateError('hỏng giữa chừng'),
        );
        await expectLater(
          failing.buy(childId: childId, gender: 'girl', itemId: 'glasses'),
          throwsStateError,
        );
        expect(await xu(), 100);
        expect(await shopLedgerRows(), 0);
        expect(await shop.owned(childId), isEmpty);
        // Sau lỗi vẫn mua lại bình thường.
        expect(
          await shop.buy(childId: childId, gender: 'girl', itemId: 'glasses'),
          BuyResult.bought,
        );
        expect(await xu(), 100 - glassesPriceXu);
      },
    );

    test('kim cương không bị đụng tới khi mua bằng xu', () async {
      await giveXu(100);
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.gem,
        amount: 3,
        reason: 'test',
      );
      await shop.buy(childId: childId, gender: 'girl', itemId: 'glasses');
      expect((await shop.balances(childId))[Currency.gem], 3);
    });
  });

  group('giữ đồ cho máy cũ (grandfather)', () {
    Future<void> onboardOldInstall({
      String? dress,
      String gender = 'girl',
    }) async {
      // Máy cài trước bản có cửa hàng: hồ sơ có sẵn nhưng kho trống.
      await db.settingsDao.setValue(
        childId: childId,
        key: OnboardingService.profileKey,
        value: _profileJson(dress: dress, gender: gender),
      );
    }

    test('giữ bộ đồ đang mặc và phụ kiện đang đeo', () async {
      await onboardOldInstall(dress: 'girl_top_03');
      final looks = KidLookService(db: db);
      await looks.setHeadAccessory(childId, 'bow');
      await looks.setGlasses(childId, true);
      await looks.setWhiteShoes(childId, true);
      await looks.setBackpack(childId, true);

      await shop.grandfather(childId);

      expect(await shop.owned(childId), {
        'girl_top_03',
        'head_bow',
        glassesItemId,
        whiteShoesItemId,
        backpackItemId,
      });
      expect(
        (await db.inventoryDao.getAll(childId)).map((r) => r.source).toSet(),
        {InventorySource.grandfather},
      );
    });

    test('không đeo gì thì chỉ giữ bộ đồ (null = bộ 1)', () async {
      await onboardOldInstall(dress: null, gender: 'boy');
      await shop.grandfather(childId);
      expect(await shop.owned(childId), {'boy_outfit_01'});
    });

    test('idempotent: gọi lại không thêm dòng, không đổi nguồn', () async {
      await onboardOldInstall(dress: 'girl_top_02');
      await KidLookService(db: db).setGlasses(childId, true);
      await shop.grandfather(childId);
      final first = await db.inventoryDao.getAll(childId);
      await shop.grandfather(childId);
      await shop.grandfather(childId);
      final again = await db.inventoryDao.getAll(childId);
      expect(again.map((r) => r.id), first.map((r) => r.id));
      expect(again, hasLength(2));
    });

    test('không động tới ví: giữ đồ cũ không tốn xu', () async {
      await giveXu(10);
      await onboardOldInstall(dress: 'girl_top_02');
      await shop.grandfather(childId);
      expect(await xu(), 10);
    });

    test('chưa xong mở đầu (chưa có hồ sơ) thì không làm gì', () async {
      await shop.grandfather(childId);
      expect(await shop.owned(childId), isEmpty);
    });

    test('hoàn tất mở đầu cho bộ đồ đã chọn là starter', () async {
      await OnboardingService(db: db).completeOnboarding(
        childId: childId,
        profile: CharacterProfile.defaults().copyWith(
          dress: 'girl_top_02',
          name: 'An',
        ),
        eggSpecies: 'dog',
      );
      final rows = await db.inventoryDao.getAll(childId);
      expect(rows.single.itemId, 'girl_top_02');
      expect(rows.single.source, InventorySource.starter);
      // Grandfather sau đó không đổi nguồn của bộ đồ này.
      await shop.grandfather(childId);
      expect(
        (await db.inventoryDao.getAll(childId)).single.source,
        InventorySource.starter,
      );
    });
  });
}

String _profileJson({String? dress, required String gender}) {
  final profile = CharacterProfile.defaults().copyWith(
    gender: gender,
    name: 'Bé',
    dress: dress,
  );
  return jsonEncode(profile.toJson());
}
