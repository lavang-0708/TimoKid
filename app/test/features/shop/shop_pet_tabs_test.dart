/// Widget test Cửa hàng T2-06b: tab Đồ cho pet (thức ăn có số lượng,
/// đồ chơi một-lần), tab Nội thất (thẻ "Sắp có hàng mới!" khi cờ hình
/// tắt, liệt kê + mua được khi bật), bộ đồ cao cấp bằng kim cương.
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
import 'package:timokid/features/shop/shop_screen.dart';
import 'package:timokid/features/shop/shop_service.dart';

void main() {
  late AppDatabase db;
  late String childId;

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

  Future<void> give(int amount, {String currency = Currency.xu}) =>
      db.walletDao.addEntry(
        childId: childId,
        currency: currency,
        amount: amount,
        reason: 'test',
      );

  Future<void> pumpShop(
    WidgetTester tester, {
    Size size = const Size(800, 360),
    String location = ShopScreen.route,
    bool furnitureReady = false,
    bool premiumReady = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: ShopScreen.route,
          builder: (context, state) => ShopScreen(
            furnitureReady: furnitureReady,
            premiumOutfitsReady: premiumReady,
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key('shop-tab-$key')));
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('có đủ 4 tab, tab Đồ cho pet liệt kê 3 thức ăn + 3 đồ chơi', (
    tester,
  ) async {
    await pumpShop(tester);
    for (final k in ['outfits', 'accessories', 'pet', 'furniture']) {
      expect(find.byKey(Key('shop-tab-$k')), findsOneWidget, reason: k);
    }
    await openTab(tester, 'pet');
    for (final id in [
      'pet_food_bone',
      'pet_food_fish',
      'pet_food_carrot',
      'pet_toy_ball',
      'pet_toy_yarn',
      'pet_toy_plush',
    ]) {
      expect(find.byKey(Key('shop-item-$id')), findsOneWidget, reason: id);
    }
    expect(find.text('10'), findsNWidgets(3));
    expect(find.text('40'), findsNWidgets(3));
    // Thức ăn hiện "Có 0" lúc đầu; đồ chơi không có nhãn đếm.
    expect(find.text('Có 0'), findsNWidgets(3));
    expect(find.byKey(const Key('shop-count-pet_toy_ball')), findsNothing);
  });

  testWidgets('mua thức ăn nhiều lần: số lượng tăng, vẫn mua tiếp được', (
    tester,
  ) async {
    await give(25);
    await pumpShop(tester);
    await openTab(tester, 'pet');
    for (var i = 1; i <= 2; i++) {
      await tester.tap(find.byKey(const Key('shop-buy-pet_food_bone')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shop-confirm-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('shop-confirm-buy')));
      await tester.pumpAndSettle();
      expect(find.text('Có $i'), findsOneWidget);
      // Món dùng-một-lần không bao giờ ghi "Đã có".
      expect(find.byKey(const Key('shop-owned-pet_food_bone')), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    }
    expect(text(tester, 'shop-xu-balance'), '5');
    // Còn 5 xu: nút mờ "Còn thiếu 5 xu".
    expect(find.text('Còn thiếu 5 xu'), findsWidgets);
    expect(await ShopService(db: db).foodCount(childId, 'pet_food_bone'), 2);
  });

  testWidgets('đồ chơi mua một lần: xong ghi Đã có', (tester) async {
    await give(40);
    await pumpShop(tester);
    await openTab(tester, 'pet');
    await tester.tap(find.byKey(const Key('shop-buy-pet_toy_ball')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop-confirm-buy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop-owned-pet_toy_ball')), findsOneWidget);
    expect(find.byKey(const Key('shop-buy-pet_toy_ball')), findsNothing);
    expect(text(tester, 'shop-xu-balance'), '0');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('/shop?tab=pet mở thẳng tab Đồ cho pet', (tester) async {
    await pumpShop(tester, location: '${ShopScreen.route}?tab=pet');
    expect(find.byKey(const Key('shop-item-pet_food_bone')), findsOneWidget);
    expect(find.byKey(const Key('shop-item-girl_top_02')), findsNothing);
  });

  testWidgets('Nội thất khi cờ hình tắt: thẻ Sắp có hàng mới!', (tester) async {
    await pumpShop(tester);
    await openTab(tester, 'furniture');
    expect(find.byKey(const Key('shop-furniture-coming-soon')), findsOneWidget);
    expect(find.text('Sắp có hàng mới!'), findsOneWidget);
    expect(find.byKey(const Key('shop-item-noi_be_ca')), findsNothing);
    expect(find.byKey(const Key('shop-grid')), findsNothing);
  });

  testWidgets('Nội thất khi bật cờ: 8 món, mua được một lần', (tester) async {
    await give(130);
    await pumpShop(tester, furnitureReady: true);
    await openTab(tester, 'furniture');
    expect(find.byKey(const Key('shop-furniture-coming-soon')), findsNothing);
    for (final id in [
      'noi_be_ca',
      'noi_den_trang',
      'noi_ke_sach',
      'noi_ghe_luoi',
      'noi_nha_pet',
      'noi_cay_cao',
      'noi_leu',
      'noi_tranh',
    ]) {
      expect(find.byKey(Key('shop-item-$id')), findsOneWidget, reason: id);
    }
    await tester.tap(find.byKey(const Key('shop-buy-noi_be_ca')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop-confirm-buy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop-owned-noi_be_ca')), findsOneWidget);
    expect(text(tester, 'shop-xu-balance'), '10');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('bộ đồ cao cấp (bật cờ): giá xu và kim cương, mua bộ 07 bằng '
      'kim cương', (tester) async {
    await give(1000);
    await give(30, currency: Currency.gem);
    await pumpShop(tester, premiumReady: true);
    expect(find.byKey(const Key('shop-item-girl_top_07')), findsOneWidget);
    // Bộ 04–06 có thể ở dưới nếp gấp: cuộn tới.
    await tester.ensureVisible(find.byKey(const Key('shop-buy-girl_top_07')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop-buy-girl_top_07')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop-confirm-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('shop-confirm-buy')));
    await tester.pumpAndSettle();
    expect(text(tester, 'shop-gem-balance'), '0');
    expect(text(tester, 'shop-xu-balance'), '1000');
    expect(find.byKey(const Key('shop-owned-girl_top_07')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
    'bộ đồ kim cương thiếu kim cương: nút mờ báo còn thiếu kim cương',
    (tester) async {
      await give(5000);
      await give(20, currency: Currency.gem);
      await pumpShop(tester, premiumReady: true);
      await tester.ensureVisible(find.byKey(const Key('shop-buy-girl_top_07')));
      await tester.pumpAndSettle();
      expect(find.text('Còn thiếu 10 kim cương'), findsOneWidget);
      // Bộ 04 (150 xu) mua được dù kim cương ít.
      expect(find.byKey(const Key('shop-buy-girl_top_04')), findsOneWidget);
    },
  );

  testWidgets('cờ tắt: Quần áo có 3 bộ cơ bản + bộ 04, 05 đã có hình', (
    tester,
  ) async {
    await pumpShop(tester);
    expect(find.byKey(const Key('shop-item-girl_top_04')), findsOneWidget);
    expect(find.byKey(const Key('shop-item-girl_top_05')), findsOneWidget);
    expect(find.byKey(const Key('shop-item-girl_top_06')), findsNothing);
    expect(find.byKey(const Key('shop-item-girl_top_07')), findsNothing);
  });
}
