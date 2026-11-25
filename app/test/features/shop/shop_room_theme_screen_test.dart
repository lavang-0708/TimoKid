/// Cửa hàng, tab Nội thất: bộ phòng + món lẻ theo chủ đề (chỉ khi đã có
/// hình); có bộ thì món lẻ hiện "Đã có"; đủ món lẻ thì bộ hiện "Đã có".
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/room/room_assets.dart';
import 'package:timokid/features/room/room_themes.dart';
import 'package:timokid/features/room/room_variants.dart';
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

  Future<void> grant(String id) => db.inventoryDao.grant(
    childId: childId,
    itemId: id,
    source: InventorySource.shop,
  );

  Future<void> pumpShop(WidgetTester tester, Map<String, bool> ready) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: ShopScreen.route,
      routes: [
        GoRoute(
          path: ShopScreen.route,
          builder: (context, state) => ShopScreen(roomThemesReady: ready),
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
    await tester.tap(find.byKey(const Key('shop-tab-furniture')));
    await tester.pumpAndSettle();
  }

  Finder card(String id) =>
      find.byKey(Key('shop-item-$id'), skipOffstage: false);
  Finder owned(String id) =>
      find.byKey(Key('shop-owned-$id'), skipOffstage: false);

  testWidgets('chưa có hình: không có bộ lẫn món lẻ', (tester) async {
    await pumpShop(tester, const {});
    expect(card(roomThemeItemId('tet')), findsNothing);
    expect(card(roomThemeVariantItemId('tet', 'noi_giuong')), findsNothing);
  });

  testWidgets('đủ hình: có bộ và món lẻ, chưa ai "Đã có"', (tester) async {
    await pumpShop(tester, const {'tet': true});
    expect(card(roomThemeItemId('tet')), findsOneWidget);
    expect(card(roomThemeVariantItemId('tet', 'noi_giuong')), findsOneWidget);
    expect(card(roomThemeItemId('ngan_ha')), findsNothing);
    expect(owned(roomThemeItemId('tet')), findsNothing);
  });

  testWidgets('có bộ: bộ và mọi món lẻ của chủ đề hiện "Đã có"', (
    tester,
  ) async {
    await grant(roomThemeItemId('tet'));
    await pumpShop(tester, const {'tet': true});
    expect(owned(roomThemeItemId('tet')), findsOneWidget);
    for (final p in roomPlaceables.where((p) => p.hasVariant('tet'))) {
      expect(owned(roomThemeVariantItemId('tet', p.id)), findsOneWidget);
    }
  });

  testWidgets('mua lẻ đủ mọi món: bộ hiện "Đã có"', (tester) async {
    for (final p in roomPlaceables.where((p) => p.hasVariant('tet'))) {
      await grant(roomThemeVariantItemId('tet', p.id));
    }
    await pumpShop(tester, const {'tet': true});
    expect(owned(roomThemeItemId('tet')), findsOneWidget);
  });

  testWidgets('mua lẻ một món: chỉ món đó "Đã có", bộ chưa', (tester) async {
    await grant(roomThemeVariantItemId('tet', 'noi_giuong'));
    await pumpShop(tester, const {'tet': true});
    expect(owned(roomThemeVariantItemId('tet', 'noi_giuong')), findsOneWidget);
    expect(owned(roomThemeVariantItemId('tet', 'noi_ghe')), findsNothing);
    expect(owned(roomThemeItemId('tet')), findsNothing);
  });
}
