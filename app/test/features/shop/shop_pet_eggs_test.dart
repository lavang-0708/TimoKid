/// Test Cửa hàng tab Pet (D): trứng sóc 20 / capybara 60 / rồng con 150
/// kim cương, cờ hình theo loài (chưa có hình → "Sắp có", không mua
/// được), mua một transaction, số dư không âm, mỗi loài một lần.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/pet/pet_config.dart';
import 'package:timokid/features/pet/pet_service.dart';
import 'package:timokid/features/shop/shop_catalog.dart';
import 'package:timokid/features/shop/shop_screen.dart';
import 'package:timokid/features/shop/shop_service.dart';

void main() {
  late AppDatabase db;
  late String childId;

  const allReady = {'squirrel': true, 'capybara': true, 'dragon': true};

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    await OnboardingService(db: db).completeOnboarding(
      childId: childId,
      profile: CharacterProfile.defaults().copyWith(
        dress: 'girl_top_01',
        name: 'An',
      ),
      eggSpecies: 'dog',
    );
  });

  Future<void> gems(int amount) => db.walletDao.addEntry(
    childId: childId,
    currency: Currency.gem,
    amount: amount,
    reason: 'test',
  );

  Future<int> gemBalance() =>
      db.walletDao.balance(childId: childId, currency: Currency.gem);

  group('cấu hình + danh mục', () {
    test('giá và độ hiếm theo spec; mọi cờ hình đang tắt', () {
      expect(
        {for (final s in petShopSpecies) s.species: s.priceGems},
        {'squirrel': 20, 'capybara': 60, 'dragon': 150},
      );
      expect(petShopSpeciesById('squirrel')!.rarity, PetRarity.common);
      expect(petShopSpeciesById('capybara')!.rarity, PetRarity.rare);
      expect(petShopSpeciesById('dragon')!.rarity, PetRarity.epic);
      expect(newPetArtReady, {
        'squirrel': true,
        'capybara': true,
        'dragon': true,
      });
      expect(isPetSpeciesBuyable('squirrel'), isTrue);
      expect(isPetSpeciesBuyable('capybara'), isTrue);
      expect(isPetSpeciesBuyable('dragon'), isTrue);
      expect(petUiArtReady, isTrue); // lô 13 đã về (24/11)
      final items = shopPetEggItems();
      expect(items.map((i) => i.priceGems), [20, 60, 150]);
      expect(items.every((i) => i.usesGems), isTrue);
    });
  });

  group('ShopService.buyPetEgg', () {
    test('cờ hình tắt: Sắp có, không trừ kim cương, không tạo pet', () async {
      await gems(500);
      final shop = ShopService(
        db: db,
        petArtReady: const {
          'squirrel': true,
          'capybara': true,
          'dragon': false,
        },
      );
      expect(
        await shop.buyPetEgg(childId: childId, species: 'dragon'),
        BuyResult.comingSoon,
      );
      expect(await PetService(db: db).owns(childId, 'dragon'), isFalse);
      expect(await gemBalance(), 500);
    });

    test('cờ mặc định: sóc mua được với 20 kim cương', () async {
      await gems(100);
      final shop = ShopService(db: db);
      expect(
        await shop.buyPetEgg(childId: childId, species: 'squirrel'),
        BuyResult.bought,
      );
      expect(await gemBalance(), 80);
      expect(await PetService(db: db).owns(childId, 'squirrel'), isTrue);
    });

    test('cờ mặc định: capybara mua được với 60 kim cương', () async {
      await gems(100);
      final shop = ShopService(db: db);
      expect(
        await shop.buyPetEgg(childId: childId, species: 'capybara'),
        BuyResult.bought,
      );
      expect(await gemBalance(), 40);
      expect(await PetService(db: db).owns(childId, 'capybara'), isTrue);
    });

    test(
      'mua được khi có hình: trừ đúng giá, thêm trứng, mỗi loài một lần',
      () async {
        await gems(100);
        final shop = ShopService(db: db, petArtReady: allReady);
        expect(
          await shop.buyPetEgg(childId: childId, species: 'squirrel'),
          BuyResult.bought,
        );
        expect(await gemBalance(), 80);
        final pets = PetService(db: db);
        expect(await pets.owns(childId, 'squirrel'), isTrue);
        // Bé đã có pet đi theo (chó): trứng mua về nằm chờ, không giành chỗ.
        expect((await pets.active(childId))!.species, 'dog');
        expect((await pets.pets(childId)).where((p) => p.active), hasLength(1));
        // Không mua trùng loài.
        expect(
          await shop.buyPetEgg(childId: childId, species: 'squirrel'),
          BuyResult.alreadyOwned,
        );
        expect(await gemBalance(), 80);
      },
    );

    test('không đủ kim cương: không mua, số dư không âm', () async {
      await gems(59);
      final shop = ShopService(db: db, petArtReady: allReady);
      expect(
        await shop.buyPetEgg(childId: childId, species: 'capybara'),
        BuyResult.insufficient,
      );
      expect(await gemBalance(), 59);
      expect(
        await shop.buyPetEgg(childId: childId, species: 'dragon'),
        BuyResult.insufficient,
      );
      expect(await gemBalance(), 59);
      await gems(1);
      expect(
        await shop.buyPetEgg(childId: childId, species: 'capybara'),
        BuyResult.bought,
      );
      expect(await gemBalance(), 0);
    });

    test(
      'mã loài lạ → unknownItem; lỗi giữa chừng hoàn tác cả ví lẫn pet',
      () async {
        await gems(50);
        final shop = ShopService(db: db, petArtReady: allReady);
        expect(
          await shop.buyPetEgg(childId: childId, species: 'dog'),
          BuyResult.unknownItem,
        );
        final failing = ShopService(
          db: db,
          petArtReady: allReady,
          afterLedgerWrite: () async => throw StateError('lỗi giữa chừng'),
        );
        await expectLater(
          failing.buyPetEgg(childId: childId, species: 'squirrel'),
          throwsStateError,
        );
        expect(await gemBalance(), 50);
        expect(await PetService(db: db).owns(childId, 'squirrel'), isFalse);
      },
    );

    test('chưa có pet nào thì trứng mua về đi theo ngay', () async {
      final other = (await db.childrenDao.createChild(name: 'Em')).id;
      await db.walletDao.addEntry(
        childId: other,
        currency: Currency.gem,
        amount: 20,
        reason: 'test',
      );
      final shop = ShopService(db: db, petArtReady: allReady);
      expect(
        await shop.buyPetEgg(childId: other, species: 'squirrel'),
        BuyResult.bought,
      );
      expect((await PetService(db: db).active(other))!.species, 'squirrel');
    });
  });

  group('tab Pet trên màn Cửa hàng', () {
    Future<void> pumpShop(
      WidgetTester tester, {
      Map<String, bool> ready = newPetArtReady,
    }) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '${ShopScreen.route}?tab=pets',
        routes: [
          GoRoute(
            path: ShopScreen.route,
            builder: (context, state) => ShopScreen(petArtReady: ready),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('chưa có hình: 3 thẻ ghi Sắp có + độ hiếm, không có nút Mua', (
      tester,
    ) async {
      await gems(500);
      await pumpShop(
        tester,
        ready: const {'squirrel': false, 'capybara': false, 'dragon': false},
      );
      for (final s in ['squirrel', 'capybara', 'dragon']) {
        expect(find.byKey(Key('shop-item-pet_egg_$s')), findsOneWidget);
        expect(find.byKey(Key('shop-soon-pet_egg_$s')), findsOneWidget);
        expect(find.byKey(Key('shop-buy-pet_egg_$s')), findsNothing);
      }
      // Pet thường không có nhãn (chỉ Hiếm / Siêu hiếm lấp lánh, 24/11).
      expect(find.text('Thường'), findsNothing);
      expect(find.text('Hiếm'), findsOneWidget);
      expect(find.text('Siêu hiếm'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
    });

    testWidgets('có hình: mua sóc bằng kim cương qua hộp xác nhận', (
      tester,
    ) async {
      await gems(25);
      await pumpShop(tester, ready: allReady);
      // Đủ tiền mua sóc; capybara/rồng báo còn thiếu và không bấm được.
      expect(
        find.byKey(const Key('shop-buy-pet_egg_squirrel')),
        findsOneWidget,
      );
      expect(find.textContaining('Còn thiếu'), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('shop-buy-pet_egg_squirrel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shop-confirm-dialog')), findsOneWidget);
      await tester.tap(find.text('Mua').last);
      await tester.pumpAndSettle();
      expect(await gemBalance(), 5);
      expect(await PetService(db: db).owns(childId, 'squirrel'), isTrue);
      expect(
        find.byKey(const Key('shop-owned-pet_egg_squirrel')),
        findsOneWidget,
      );
    });
  });
}
