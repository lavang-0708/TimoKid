/// Phòng chủ đề (lô 15, 24/11): chỉ bán khi đã có hình; Tết/Ngân hà
/// bằng xu, Rồng bằng kim cương; mua một lần.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/features/pet/pet_config.dart';
import 'package:timokid/features/room/room_themes.dart';
import 'package:timokid/features/shop/shop_catalog.dart';
import 'package:timokid/features/shop/shop_service.dart';

void main() {
  late AppDatabase db;
  late String childId;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    childId = await db.ensureSeeded();
  });

  Future<void> give(int amount, {String currency = Currency.xu}) =>
      db.walletDao.addEntry(
        childId: childId,
        currency: currency,
        amount: amount,
        reason: 'test',
      );

  const allReady = {'tet': true, 'ngan_ha': true, 'rong': true};

  test('chưa có hình thì không bán chủ đề nào', () {
    final themes = shopItemsFor('girl')
        .where((i) => i.kind == ShopItemKind.roomTheme);
    expect(themes, isEmpty);
  });

  test('đủ hình: 3 chủ đề, giá và độ hiếm theo spec', () {
    final themes = shopItemsFor(
      'boy',
      roomThemesReady: allReady,
    ).where((i) => i.kind == ShopItemKind.roomTheme).toList();
    expect(themes.map((i) => i.id), [
      'room_theme_tet',
      'room_theme_ngan_ha',
      'room_theme_rong',
    ]);
    expect(themes.map((i) => i.priceXu), [1200, 1800, 0]);
    expect(themes.map((i) => i.priceGems), [0, 0, 80]);
    expect(themes.map((i) => i.rarity), [
      PetRarity.rare,
      PetRarity.rare,
      PetRarity.epic,
    ]);
    expect(themes.every((i) => i.category == ShopCategory.furniture), isTrue);
  });

  test('mua Phòng Rồng bằng 80 kim cương, mua lại báo đã có', () async {
    final shop = ShopService(db: db, roomThemesReady: allReady);
    await give(100, currency: Currency.gem);
    final id = roomThemeItemId('rong');
    expect(
      await shop.buy(childId: childId, gender: 'girl', itemId: id),
      BuyResult.bought,
    );
    expect(
      await db.walletDao.balance(childId: childId, currency: Currency.gem),
      20,
    );
    expect(await shop.isOwned(childId, id), isTrue);
    expect(
      await shop.buy(childId: childId, gender: 'girl', itemId: id),
      BuyResult.alreadyOwned,
    );
  });
}
