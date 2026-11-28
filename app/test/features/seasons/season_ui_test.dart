/// Test giao diện mùa (T5-02): biển ở Thị trấn, tab Bộ sưu tập mùa + ruy
/// băng + giá giảm ở Cửa hàng, "Giả lập mùa" ở menu QA; không tràn màn ở
/// cỡ nhỏ; ngoài mùa không có gì.
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
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/qa/qa_menu_screen.dart';
import 'package:timokid/features/room/room_screen.dart';
import 'package:timokid/features/seasons/season_service.dart';
import 'package:timokid/features/shop/shop_screen.dart';
import 'package:timokid/features/town/town_screen.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;

  setUp(() async {
    SeasonService.debugDisabled = false;
    SeasonService.forcedSeasonId = null;
    clock = FakeClock(DateTime(2027, 2, 6, 9));
    db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    await OnboardingService(db: db).completeOnboarding(
      childId: childId,
      profile: CharacterProfile.defaults().copyWith(
        gender: 'girl',
        dress: 'girl_top_01',
        name: 'An',
      ),
      eggSpecies: 'dog',
    );
  });
  tearDown(() {
    SeasonService.debugDisabled = true;
    SeasonService.forcedSeasonId = null;
  });

  Future<void> pump(
    WidgetTester tester,
    Widget Function() screen, {
    Size size = const Size(800, 360),
    String route = '/',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: route,
      routes: [
        GoRoute(path: route, builder: (_, _) => screen()),
        GoRoute(
          path: RoomScreen.route,
          builder: (_, _) => const Scaffold(body: SizedBox()),
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

  Future<void> giveXu(int xu) => db.walletDao.addEntry(
    childId: childId,
    currency: Currency.xu,
    amount: xu,
    reason: 'test',
  );

  group('Thị trấn', () {
    testWidgets('trong mùa Tết có biển "Mùa Tết!"', (tester) async {
      await pump(tester, () => const TownScreen());
      expect(find.byKey(const Key('season-banner')), findsOneWidget);
      expect(find.text('Mùa Tết!'), findsOneWidget);
    });

    testWidgets('ngoài mùa không có biển', (tester) async {
      clock.set(DateTime(2027, 5, 1, 9));
      await pump(tester, () => const TownScreen());
      expect(find.byKey(const Key('season-banner')), findsNothing);
    });

    testWidgets('Giáng sinh và Trung thu có biển của mùa mình', (tester) async {
      clock.set(DateTime(2026, 12, 20, 9));
      await pump(tester, () => const TownScreen());
      expect(find.text('Mùa Giáng sinh!'), findsOneWidget);
      clock.set(DateTime(2027, 9, 15, 9));
      await pump(tester, () => const TownScreen());
      expect(find.text('Mùa Trung thu!'), findsOneWidget);
    });

    for (final size in const [
      Size(608, 248),
      Size(640, 320),
      Size(1280, 800),
    ]) {
      testWidgets(
        'biển không tràn ở ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          await pump(tester, () => const TownScreen(), size: size);
          expect(find.byKey(const Key('season-banner')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('Cửa hàng', () {
    testWidgets('trong mùa có tab Bộ sưu tập mùa với món Tết giảm giá', (
      tester,
    ) async {
      await giveXu(5000);
      await pump(tester, () => const ShopScreen(), route: ShopScreen.route);
      expect(find.byKey(const Key('shop-tab-seasonal')), findsOneWidget);
      await tester.tap(find.byKey(const Key('shop-tab-seasonal')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shop-item-girl_top_09')), findsOneWidget);
      expect(find.byKey(const Key('shop-item-room_theme_tet')), findsOneWidget);
      // Chỉ món Tết, không có váy thường.
      expect(find.byKey(const Key('shop-item-girl_top_02')), findsNothing);
      expect(
        find.byKey(const Key('shop-season-ribbon-girl_top_09')),
        findsOneWidget,
      );
      expect(find.text('Mùa Tết'), findsWidgets);
      final price = tester.widget<Text>(
        find.byKey(const Key('shop-price-girl_top_09')),
      );
      final list = tester.widget<Text>(
        find.byKey(const Key('shop-list-price-girl_top_09')),
      );
      expect(list.data, '450');
      expect(price.data, '360');
    });

    testWidgets('bộ đồ 09 ở tab Quần áo cũng có ruy băng và giá giảm', (
      tester,
    ) async {
      await pump(tester, () => const ShopScreen(), route: ShopScreen.route);
      await tester.ensureVisible(
        find.byKey(const Key('shop-item-girl_top_09')),
      );
      expect(
        find.byKey(const Key('shop-season-ribbon-girl_top_09')),
        findsOneWidget,
      );
      // Món thường không có ruy băng.
      expect(
        find.byKey(const Key('shop-season-ribbon-girl_top_02')),
        findsNothing,
      );
    });

    testWidgets('ngoài mùa: không có tab mùa, không ruy băng, giá thường', (
      tester,
    ) async {
      clock.set(DateTime(2027, 5, 1, 9));
      await pump(tester, () => const ShopScreen(), route: ShopScreen.route);
      expect(find.byKey(const Key('shop-tab-seasonal')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('shop-item-girl_top_09')),
      );
      expect(
        find.byKey(const Key('shop-season-ribbon-girl_top_09')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('shop-list-price-girl_top_09')),
        findsNothing,
      );
      final price = tester.widget<Text>(
        find.byKey(const Key('shop-price-girl_top_09')),
      );
      expect(price.data, '450');
    });

    testWidgets('mùa Giáng sinh chưa có món: hiện thẻ báo, không lỗi', (
      tester,
    ) async {
      clock.set(DateTime(2026, 12, 20, 9));
      await pump(tester, () => const ShopScreen(), route: ShopScreen.route);
      await tester.tap(find.byKey(const Key('shop-tab-seasonal')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shop-season-empty')), findsOneWidget);
    });

    testWidgets('mua trong mùa trừ đúng giá giảm', (tester) async {
      await giveXu(400);
      await pump(tester, () => const ShopScreen(), route: ShopScreen.route);
      await tester.tap(find.byKey(const Key('shop-tab-seasonal')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('shop-buy-girl_top_09')));
      await tester.tap(find.byKey(const Key('shop-buy-girl_top_09')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mua').last);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(await db.inventoryDao.has(childId, 'girl_top_09'), isTrue);
      expect(
        await db.walletDao.balance(childId: childId, currency: Currency.xu),
        40,
      );
    });

    for (final size in const [Size(608, 248), Size(640, 320), Size(360, 640)]) {
      testWidgets(
        'tab mùa không tràn ở ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          await giveXu(5000);
          await pump(
            tester,
            () => const ShopScreen(),
            route: ShopScreen.route,
            size: size,
          );
          await tester.tap(find.byKey(const Key('shop-tab-seasonal')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('QA: Giả lập mùa', () {
    testWidgets('ép mùa rồi bỏ ép', (tester) async {
      clock.set(DateTime(2027, 5, 1, 9));
      await pump(
        tester,
        () => QaMenuScreen(db: db),
        route: QaMenuScreen.route,
        size: const Size(800, 1200),
      );
      await tester.ensureVisible(find.byKey(const Key('qa-season-giang_sinh')));
      await tester.tap(find.byKey(const Key('qa-season-giang_sinh')));
      await tester.pumpAndSettle();
      expect(SeasonService.forcedSeasonId, 'giang_sinh');
      expect(SeasonService.active(clock)?.id, 'giang_sinh');
      await tester.ensureVisible(find.byKey(const Key('qa-season-none')));
      await tester.tap(find.byKey(const Key('qa-season-none')));
      await tester.pumpAndSettle();
      expect(SeasonService.forcedSeasonId, isNull);
      expect(SeasonService.active(clock), isNull);
    });
  });
}
