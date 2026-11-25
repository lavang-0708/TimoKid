/// Bộ phòng chủ đề (lô 15): chỉ bán khi đã có hình; Tết/Ngân hà bằng xu,
/// Rồng bằng kim cương; mua cả bộ hoặc món lẻ; bộ rẻ hơn tổng món lẻ;
/// đủ món lẻ tặng nền; có bộ thì món lẻ coi như đã có.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/features/pet/pet_config.dart';
import 'package:timokid/features/room/room_assets.dart';
import 'package:timokid/features/room/room_themes.dart';
import 'package:timokid/features/room/room_variants.dart';
import 'package:timokid/features/shop/shop_catalog.dart';
import 'package:timokid/features/shop/shop_service.dart';

/// Món có biến thể ở chủ đề [theme] (7 món lớn/vừa; Rồng thêm 8 món cửa hàng).
List<RoomPlaceable> _variants(String theme) => [
  for (final p in roomPlaceables)
    if (p.hasVariant(theme)) p,
];

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

  Iterable<ShopItem> roomItems(
    String theme, {
    Map<String, bool> ready = allReady,
  }) => shopItemsFor('girl', roomThemesReady: ready).where(
    (i) => i.kind == ShopItemKind.roomThemeItem && i.roomThemeId == theme,
  );

  test('chưa có hình thì không bán bộ lẫn món lẻ nào', () {
    final themes = shopItemsFor('girl', roomThemesReady: const {}).where(
      (i) =>
          i.kind == ShopItemKind.roomTheme ||
          i.kind == ShopItemKind.roomThemeItem,
    );
    expect(themes, isEmpty);
  });

  test('Phòng Rồng đã có hình (cờ const): bộ + 15 món lẻ lên Cửa hàng', () {
    expect(roomThemeArtReady['rong'], isTrue);
    expect(roomThemeArtReady['tet'], isFalse);
    expect(roomThemeArtReady['ngan_ha'], isFalse);
    final all = shopItemsFor('girl'); // dùng cờ const của app
    final sets = all.where((i) => i.kind == ShopItemKind.roomTheme).toList();
    expect(sets.map((i) => i.id), ['room_theme_rong']);
    expect(sets.single.priceGems, 120);
    final items = all
        .where((i) => i.kind == ShopItemKind.roomThemeItem)
        .toList();
    // 7 món lớn/vừa + 8 món cửa hàng, toàn bộ của Rồng.
    expect(items, hasLength(15));
    expect(items.every((i) => i.roomThemeId == 'rong'), isTrue);
    expect(items.every((i) => i.usesGems), isTrue);
    // Món lớn có ô cắt (ảnh 1024x1024 viền trong suốt) để hiện đúng cỡ.
    final bed = items.firstWhere((i) => i.placeableId == 'noi_giuong');
    expect(bed.assetCrop, isNotNull);
    expect(bed.asset, 'assets/images/furniture/rong_giuong.webp');
  });

  test('chỉ chủ đề đã có hình mới có món lẻ', () {
    const only = {'tet': true};
    expect(roomItems('tet', ready: only), hasLength(_variants('tet').length));
    expect(roomItems('ngan_ha', ready: only), isEmpty);
    expect(roomItems('rong', ready: only), isEmpty);
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
    expect(themes.map((i) => i.priceXu), [2000, 2500, 0]);
    expect(themes.map((i) => i.priceGems), [0, 0, 120]);
    expect(themes.map((i) => i.rarity), [
      PetRarity.rare,
      PetRarity.rare,
      PetRarity.epic,
    ]);
    expect(themes.every((i) => i.category == ShopCategory.furniture), isTrue);
  });

  test('mua Phòng Rồng bằng 120 kim cương, mua lại báo đã có', () async {
    final shop = ShopService(db: db, roomThemesReady: allReady);
    await give(150, currency: Currency.gem);
    final id = roomThemeItemId('rong');
    expect(
      await shop.buy(childId: childId, gender: 'girl', itemId: id),
      BuyResult.bought,
    );
    expect(
      await db.walletDao.balance(childId: childId, currency: Currency.gem),
      30,
    );
    expect(await shop.isOwned(childId, id), isTrue);
    expect(
      await shop.buy(childId: childId, gender: 'girl', itemId: id),
      BuyResult.alreadyOwned,
    );
  });

  group('món lẻ', () {
    test('mỗi món đồ một món lẻ mỗi chủ đề, mã room_item_<chủ đề>_<món>', () {
      for (final t in roomThemes) {
        final items = roomItems(t.id).toList();
        expect(items.map((i) => i.placeableId), [
          for (final p in _variants(t.id)) p.id,
        ]);
        expect(items.every((i) => i.id.startsWith('room_item_${t.id}_')), true);
        expect(items.every((i) => i.rarity == t.rarity), isTrue);
        expect(items.every((i) => i.category == ShopCategory.furniture), true);
        expect(
          items.map((i) => i.id).toSet(),
          hasLength(_variants(t.id).length),
        );
      }
    });

    test(
      'bảng giá theo cỡ: Tết vừa/lớn 220/300, Ngân hà 280/350, Rồng 8/12/15',
      () {
        int priceOf(String theme, String placeableId) =>
            roomItems(theme)
                .firstWhere((i) => i.placeableId == placeableId)
                .price;
        // 7 món lớn/vừa có ở cả 3 chủ đề: vừa = ghế, lớn = giường.
        expect(
          [
            for (final id in ['noi_ghe', 'noi_giuong']) priceOf('tet', id),
          ],
          [220, 300],
        );
        expect(
          [
            for (final id in ['noi_ghe', 'noi_giuong']) priceOf('ngan_ha', id),
          ],
          [280, 350],
        );
        // Rồng có thêm 8 món cửa hàng (nhỏ/vừa/lớn).
        expect(
          [
            for (final id in ['noi_tranh', 'noi_cay_cao', 'noi_giuong'])
              priceOf('rong', id),
          ],
          [8, 12, 15],
        );
        // Loại tiền: Tết/Ngân hà xu, Rồng kim cương.
        expect(roomItems('tet').every((i) => !i.usesGems), isTrue);
        expect(roomItems('ngan_ha').every((i) => !i.usesGems), isTrue);
        expect(
          roomItems('rong').every((i) => i.usesGems && i.priceXu == 0),
          true,
        );
      },
    );

    test('khoảng giá nằm trong yêu cầu của từng chủ đề', () {
      final ranges = {
        'tet': (150, 300),
        'ngan_ha': (200, 350),
        'rong': (8, 15),
      };
      for (final e in ranges.entries) {
        for (final i in roomItems(e.key)) {
          expect(
            i.price,
            inInclusiveRange(e.value.$1, e.value.$2),
            reason: i.id,
          );
        }
      }
    });

    test('giá bộ so với tổng món lẻ bán ra (số liệu thực, báo Muse/PM)', () {
      // Chỉ 7 món lớn/vừa có biến thể ở Tết/Ngân hà nên bộ đắt hơn tổng
      // món lẻ (+7,5% / +11,6%); Rồng 15 món: bộ rẻ hơn 36,8%. Giá bộ chưa
      // đổi — cần quyết định sản phẩm; test này ghim số hiện tại.
      final expected = {
        'tet': (2000, 1860),
        'ngan_ha': (2500, 2240),
        'rong': (120, 190),
      };
      for (final t in roomThemes) {
        final set = shopItemsFor(
          'girl',
          roomThemesReady: allReady,
        ).firstWhere((i) => i.id == roomThemeItemId(t.id));
        final sum = roomItems(t.id).fold<int>(0, (a, i) => a + i.price);
        expect((set.price, sum), expected[t.id], reason: t.id);
        expect(set.currency, roomItems(t.id).first.currency);
      }
    });

    test('mua món lẻ: trừ tiền, mua lại báo đã có', () async {
      final shop = ShopService(db: db, roomThemesReady: allReady);
      await give(1000);
      final id = roomThemeVariantItemId('tet', 'noi_giuong');
      expect(
        await shop.buy(childId: childId, gender: 'girl', itemId: id),
        BuyResult.bought,
      );
      expect(
        await db.walletDao.balance(childId: childId, currency: Currency.xu),
        700,
      );
      expect(
        await shop.buy(childId: childId, gender: 'girl', itemId: id),
        BuyResult.alreadyOwned,
      );
      final own = await shop.roomOwnership(childId);
      expect(own.hasItemVariant('tet', 'noi_giuong'), isTrue);
      expect(own.hasBackground('tet'), isFalse);
    });

    test('đủ mọi món lẻ của chủ đề thì tặng nền, bộ thành đã có', () async {
      final shop = ShopService(db: db, roomThemesReady: allReady);
      await give(100000);
      final ids = [for (final p in _variants('tet')) p.id];
      for (var n = 0; n < ids.length; n++) {
        expect(
          (await shop.roomOwnership(childId)).hasBackground('tet'),
          isFalse,
          reason: 'mới có $n món',
        );
        await shop.buy(
          childId: childId,
          gender: 'girl',
          itemId: roomThemeVariantItemId('tet', ids[n]),
        );
      }
      final own = await shop.roomOwnership(childId);
      expect(own.hasBackground('tet'), isTrue);
      expect(own.setComplete('tet'), isTrue);
      expect(own.hasBackground('ngan_ha'), isFalse);
      // Bộ không mua lại được (đã có nền + mọi món), không bị trừ tiền.
      final before = await db.walletDao.balance(
        childId: childId,
        currency: Currency.xu,
      );
      expect(
        await shop.buy(
          childId: childId,
          gender: 'girl',
          itemId: roomThemeItemId('tet'),
        ),
        BuyResult.alreadyOwned,
      );
      expect(
        await db.walletDao.balance(childId: childId, currency: Currency.xu),
        before,
      );
    });

    test('đã có bộ thì món lẻ của chủ đề đó không mua được', () async {
      final shop = ShopService(db: db, roomThemesReady: allReady);
      await give(10000);
      expect(
        await shop.buy(
          childId: childId,
          gender: 'girl',
          itemId: roomThemeItemId('tet'),
        ),
        BuyResult.bought,
      );
      expect(
        await db.walletDao.balance(childId: childId, currency: Currency.xu),
        8000,
      );
      final own = await shop.roomOwnership(childId);
      for (final p in _variants('tet')) {
        expect(own.hasItemVariant('tet', p.id), isTrue);
      }
      expect(
        await shop.buy(
          childId: childId,
          gender: 'girl',
          itemId: roomThemeVariantItemId('tet', 'noi_giuong'),
        ),
        BuyResult.alreadyOwned,
      );
      // Món lẻ chủ đề KHÁC vẫn mua được.
      expect(
        await shop.buy(
          childId: childId,
          gender: 'girl',
          itemId: roomThemeVariantItemId('ngan_ha', 'noi_giuong'),
        ),
        BuyResult.bought,
      );
    });

    test('mua lẻ một số món rồi mua bộ: bộ giữ nguyên giá', () async {
      final shop = ShopService(db: db, roomThemesReady: allReady);
      await give(10000);
      await shop.buy(
        childId: childId,
        gender: 'girl',
        itemId: roomThemeVariantItemId('tet', 'noi_giuong'),
      );
      expect(
        await shop.buy(
          childId: childId,
          gender: 'girl',
          itemId: roomThemeItemId('tet'),
        ),
        BuyResult.bought,
      );
      expect(
        await db.walletDao.balance(childId: childId, currency: Currency.xu),
        10000 - 300 - 2000,
      );
    });

    test('chưa đủ tiền / chủ đề chưa có hình', () async {
      final shop = ShopService(db: db, roomThemesReady: const {'tet': true});
      await give(100);
      expect(
        await shop.buy(
          childId: childId,
          gender: 'girl',
          itemId: roomThemeVariantItemId('tet', 'noi_giuong'),
        ),
        BuyResult.insufficient,
      );
      expect(
        await shop.buy(
          childId: childId,
          gender: 'girl',
          itemId: roomThemeVariantItemId('rong', 'noi_giuong'),
        ),
        BuyResult.unknownItem,
      );
    });
  });
}
