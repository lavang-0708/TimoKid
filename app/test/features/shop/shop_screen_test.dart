/// Widget test màn Cửa hàng (T2-06): HUD, nhóm hàng, thẻ món, mua có
/// xác nhận, không đủ xu thì mờ + báo thiếu, món đã có, đúng dáng.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/animation/animation_gate.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/room/room_screen.dart';
import 'package:timokid/features/shop/shop_screen.dart';

void main() {
  late AppDatabase db;
  late String childId;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    childId = await db.ensureSeeded();
  });

  Future<void> onboard({String gender = 'girl', String? dress}) async {
    await OnboardingService(db: db).completeOnboarding(
      childId: childId,
      profile: CharacterProfile.defaults().copyWith(
        gender: gender,
        dress: dress ?? (gender == 'boy' ? 'boy_outfit_01' : 'girl_top_01'),
        name: 'An',
      ),
      eggSpecies: 'dog',
    );
  }

  Future<void> giveXu(int xu) => db.walletDao.addEntry(
    childId: childId,
    currency: Currency.xu,
    amount: xu,
    reason: 'test',
  );

  Future<void> pumpShop(
    WidgetTester tester, {
    Size size = const Size(800, 360),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: ShopScreen.route,
      routes: [
        GoRoute(
          path: ShopScreen.route,
          builder: (context, state) => const ShopScreen(),
        ),
        GoRoute(
          path: RoomScreen.route,
          builder: (context, state) =>
              const Scaffold(key: Key('fake-room'), body: SizedBox()),
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

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('HUD hiện xu và kim cương', (tester) async {
    await onboard();
    await giveXu(95);
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.gem,
      amount: 3,
      reason: 'test',
    );
    await pumpShop(tester);

    expect(find.byKey(const Key('shop-screen')), findsOneWidget);
    expect(text(tester, 'shop-xu-balance'), '95');
    expect(text(tester, 'shop-gem-balance'), '3');
    expect(find.byKey(const Key('shop-tab-outfits')), findsOneWidget);
    expect(find.byKey(const Key('shop-tab-accessories')), findsOneWidget);
  });

  testWidgets('Quần áo: bộ đang có ghi Đã có, cả 3 bộ giá 80', (tester) async {
    await onboard();
    await pumpShop(tester);

    expect(find.byKey(const Key('shop-owned-girl_top_01')), findsOneWidget);
    expect(find.text('Đã có ✓'), findsOneWidget);
    expect(find.byKey(const Key('shop-buy-girl_top_01')), findsNothing);
    expect(find.byKey(const Key('shop-buy-girl_top_02')), findsOneWidget);
    expect(find.byKey(const Key('shop-buy-girl_top_03')), findsOneWidget);
    expect(find.text('80'), findsNWidgets(3));
  });

  testWidgets('chỉ hiện món đúng dáng: bé trai thấy đồ trai', (tester) async {
    await onboard(gender: 'boy');
    await pumpShop(tester);
    expect(find.byKey(const Key('shop-item-boy_outfit_02')), findsOneWidget);
    expect(find.byKey(const Key('shop-item-boy_outfit_03')), findsOneWidget);
    expect(find.byKey(const Key('shop-item-girl_top_02')), findsNothing);
    await tester.tap(find.byKey(const Key('shop-tab-accessories')));
    await tester.pumpAndSettle();
    expect(find.text('Mũ lưỡi trai'), findsOneWidget);
    expect(find.text('Kẹp tóc ngôi sao'), findsOneWidget);
    expect(find.text('Mũ beret'), findsNothing);
  });

  testWidgets('Phụ kiện: đủ 5 món đúng giá', (tester) async {
    await onboard();
    await pumpShop(tester);
    await tester.tap(find.byKey(const Key('shop-tab-accessories')));
    await tester.pumpAndSettle();
    for (final id in [
      'head_hat',
      'head_bow',
      'glasses',
      'white_shoes',
      'backpack',
    ]) {
      expect(find.byKey(Key('shop-item-$id')), findsOneWidget, reason: id);
    }
    expect(find.byKey(const Key('shop-item-girl_top_02')), findsNothing);
    expect(find.text('40'), findsNWidgets(2));
    expect(find.text('30'), findsNWidgets(2));
    expect(find.text('60'), findsOneWidget);
  });

  testWidgets('không đủ xu: nút mờ, báo còn thiếu, bấm không mở hộp mua', (
    tester,
  ) async {
    await onboard();
    await giveXu(50);
    await pumpShop(tester);

    expect(find.text('Còn thiếu 30 xu'), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('shop-buy-girl_top_02')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop-confirm-dialog')), findsNothing);
    expect(text(tester, 'shop-xu-balance'), '50');
  });

  testWidgets('mua: xác nhận → trừ xu, Đã có ✓, băng Mua xong!', (
    tester,
  ) async {
    await onboard();
    await giveXu(100);
    await pumpShop(tester);

    await tester.tap(find.byKey(const Key('shop-buy-girl_top_02')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop-confirm-dialog')), findsOneWidget);
    expect(find.text('Mua Váy tím nhé?'), findsOneWidget);
    // Chưa xác nhận thì chưa trừ.
    expect(text(tester, 'shop-xu-balance'), '100');

    await tester.tap(find.byKey(const Key('shop-confirm-buy')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shop-confirm-dialog')), findsNothing);
    expect(text(tester, 'shop-xu-balance'), '20');
    expect(find.byKey(const Key('shop-owned-girl_top_02')), findsOneWidget);
    expect(find.byKey(const Key('shop-buy-girl_top_02')), findsNothing);
    expect(find.byKey(const Key('shop-bought-banner')), findsOneWidget);
    expect(find.text('Mua xong!'), findsOneWidget);
    // Đã ghi sổ: kho + ví.
    expect(await db.inventoryDao.has(childId, 'girl_top_02'), isTrue);
    expect(
      await db.walletDao.balance(childId: childId, currency: Currency.xu),
      20,
    );
    // Hết xu thì món còn lại mờ và báo thiếu.
    expect(find.text('Còn thiếu 60 xu'), findsOneWidget);
    // Băng tự tắt (hết hẹn giờ).
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('shop-bought-banner')), findsNothing);
  });

  testWidgets('bấm Thôi thì không mua', (tester) async {
    await onboard();
    await giveXu(100);
    await pumpShop(tester);

    await tester.tap(find.byKey(const Key('shop-buy-girl_top_02')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop-confirm-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shop-confirm-dialog')), findsNothing);
    expect(text(tester, 'shop-xu-balance'), '100');
    expect(await db.inventoryDao.has(childId, 'girl_top_02'), isFalse);
    expect(find.byKey(const Key('shop-bought-banner')), findsNothing);
  });

  testWidgets('mua phụ kiện ở tab Phụ kiện', (tester) async {
    await onboard();
    await giveXu(70);
    await pumpShop(tester);
    await tester.tap(find.byKey(const Key('shop-tab-accessories')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shop-buy-backpack')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop-confirm-buy')));
    await tester.pumpAndSettle();

    expect(text(tester, 'shop-xu-balance'), '10');
    expect(find.byKey(const Key('shop-owned-backpack')), findsOneWidget);
    expect(await db.inventoryDao.has(childId, 'backpack'), isTrue);
  });

  testWidgets('máy cũ: đồ đang đeo được giữ khi vào Cửa hàng', (tester) async {
    // Hồ sơ có từ bản cũ, kho trống, đang đeo kính.
    await OnboardingService(db: db).completeOnboarding(
      childId: childId,
      profile: CharacterProfile.defaults().copyWith(
        dress: 'girl_top_02',
        name: 'An',
      ),
      eggSpecies: 'dog',
    );
    await db.settingsDao.setValue(
      childId: childId,
      key: 'kid_glasses',
      value: 'true',
    );
    await pumpShop(tester);
    await tester.tap(find.byKey(const Key('shop-tab-accessories')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop-owned-glasses')), findsOneWidget);
    expect(find.byKey(const Key('shop-buy-glasses')), findsNothing);
  });

  testWidgets('nút Trở về: không có gì để pop thì về Phòng', (tester) async {
    await onboard();
    await pumpShop(tester);
    await tester.tap(find.byKey(const Key('shop-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fake-room')), findsOneWidget);
  });

  testWidgets('băng Mua xong! nảy một lần khi bật hiệu ứng, rồi lắng', (
    tester,
  ) async {
    await onboard();
    await giveXu(100);
    await pumpShop(tester);
    AnimationGate.enabled = true;
    addTearDown(() => AnimationGate.enabled = false);

    await tester.tap(find.byKey(const Key('shop-buy-girl_top_02')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop-confirm-buy')));
    // Bơm từng khung (không dùng pumpAndSettle khi bật hiệu ứng).
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('shop-bought-banner')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('shop-bought-banner')), findsNothing);
  });
}
