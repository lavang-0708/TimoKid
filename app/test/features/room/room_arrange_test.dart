/// Chế độ Sắp xếp của Phòng: bé kéo thả đồ; chỉ kéo được khi đang sắp
/// xếp, vị trí kẹp vào vùng sàn/tường, lưu theo chủ đề, "Xếp lại như cũ".
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/features/shop/shop_service.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/room/room_assets.dart';
import 'package:timokid/features/room/room_screen.dart';
import 'package:timokid/features/room/room_themes.dart';

void main() {
  late AppDatabase db;
  late String childId;

  const house = Key('room-furniture-noi_nha_pet');
  const painting = Key('room-furniture-noi_tranh');
  const bear = Key('room-furniture-gau-bong');

  RoomPlaceable placeable(String id) =>
      roomPlaceables.firstWhere((p) => p.id == id);

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    await OnboardingService(db: db).completeOnboarding(
      childId: childId,
      profile: CharacterProfile.defaults().copyWith(
        dress: 'girl_top_02',
        name: 'An',
      ),
      eggSpecies: 'dog',
    );
    for (final id in ['noi_nha_pet', 'noi_tranh', 'noi_be_ca']) {
      await db.inventoryDao.grant(
        childId: childId,
        itemId: id,
        source: InventorySource.shop,
      );
    }
  });

  Future<void> pumpRoom(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: RoomScreen.route,
      routes: [
        GoRoute(
          path: RoomScreen.route,
          builder: (context, state) => const RoomScreen(
            cleanBackground: true,
            furnitureArtReady: true,
            roomThemesReady: {'tet': true},
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

  Future<void> reopen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await pumpRoom(tester);
  }

  /// Góc trên-trái của ô món trong khung 1600x900.
  Offset framePos(WidgetTester tester, Key key) {
    final floor = tester.getRect(find.byKey(const Key('room-floor')));
    final r = tester.getRect(find.byKey(key));
    return Offset(
      (r.left - floor.left) / floor.width * roomFrameWidth,
      (r.top - floor.top) / floor.height * roomFrameHeight,
    );
  }

  /// Điểm neo đáy món trong khung.
  Offset frameAnchor(WidgetTester tester, Key key, RoomPlaceable p) =>
      framePos(tester, key) + p.anchorOffset;

  Future<void> arrange(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('room-arrange-button')));
    await tester.pumpAndSettle();
  }

  Future<void> drag(WidgetTester tester, Key key, Offset by) async {
    await tester.drag(find.byKey(key), by);
    await tester.pumpAndSettle();
  }

  Future<String?> saved(String theme) => db.settingsDao.getValue(
    childId: childId,
    key: roomLayoutSettingsKey(theme),
  );

  testWidgets('nút Sắp xếp vào chế độ; Xong / Xếp lại như cũ; Xong thoát', (
    tester,
  ) async {
    await pumpRoom(tester);
    expect(find.byKey(const Key('room-arrange-button')), findsOneWidget);
    expect(find.text('Sắp xếp'), findsOneWidget);
    expect(find.byKey(const Key('room-arrange-done')), findsNothing);
    expect(find.byKey(const Key('room-arrange-reset')), findsNothing);
    expect(
      find.byKey(const Key('room-furniture-noi_nha_pet-outline')),
      findsNothing,
    );

    await arrange(tester);
    expect(find.byKey(const Key('room-arrange-done')), findsOneWidget);
    expect(find.text('Xong'), findsOneWidget);
    expect(find.byKey(const Key('room-arrange-reset')), findsOneWidget);
    expect(find.text('Xếp lại như cũ'), findsOneWidget);
    expect(find.byKey(const Key('room-arrange-button')), findsNothing);
    // Món có viền nổi.
    expect(
      find.byKey(const Key('room-furniture-noi_nha_pet-outline')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('room-furniture-gau-bong-outline')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('room-arrange-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-arrange-button')), findsOneWidget);
    expect(find.byKey(const Key('room-arrange-done')), findsNothing);
    expect(
      find.byKey(const Key('room-furniture-noi_nha_pet-outline')),
      findsNothing,
    );
  });

  testWidgets('ngoài chế độ Sắp xếp: kéo không làm gì, chạm vẫn ra bong bóng', (
    tester,
  ) async {
    await pumpRoom(tester);
    final before = framePos(tester, house);
    await drag(tester, house, const Offset(-120, -30));
    expect(framePos(tester, house), before);
    expect(await saved('classic'), isNull);

    await tester.tap(find.byKey(house));
    await tester.pump();
    expect(find.text('Nhà của pet ấm áp quá!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('đang Sắp xếp: chạm nhân vật, pet, món không ra bong bóng', (
    tester,
  ) async {
    await pumpRoom(tester);
    await arrange(tester);
    await tester.tap(find.byKey(const Key('room-character')));
    await tester.pump();
    expect(find.byKey(const Key('room-reaction-bubble')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('room-pet-slot')));
    await tester.pump();
    expect(find.byKey(const Key('room-reaction-bubble')), findsNothing);
    await tester.tap(find.byKey(bear));
    await tester.pump();
    expect(find.byKey(const Key('room-reaction-bubble')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('kéo món trong Sắp xếp: đổi vị trí, lưu, mở lại vẫn thế', (
    tester,
  ) async {
    await pumpRoom(tester);
    final before = framePos(tester, house);
    await arrange(tester);
    // 1280x720: 1 px màn hình = 1,25 đơn vị khung. Kéo trái 150 px, lên 30 px.
    await drag(tester, house, const Offset(-150, -30));
    final after = framePos(tester, house);
    expect(after.dx, lessThan(before.dx - 120));
    expect(after.dy, lessThan(before.dy - 20));

    final json = await saved('classic');
    expect(json, isNotNull);
    final stored = decodeRoomLayout(json);
    expect(stored.keys, ['noi_nha_pet']);
    expect((stored['noi_nha_pet']! - after).distance, lessThan(0.5));
    // Món khác không bị đụng.
    expect(framePos(tester, painting), placeable('noi_tranh').defaultPos);

    await reopen(tester);
    expect((framePos(tester, house) - after).distance, lessThan(0.5));
  });

  testWidgets('kéo xuống/phải quá: chân món sàn kẹp ở đáy sàn, mép phải', (
    tester,
  ) async {
    await pumpRoom(tester);
    await arrange(tester);
    final p = placeable('noi_nha_pet');
    await drag(tester, house, const Offset(3000, 3000));
    var a = frameAnchor(tester, house, p);
    expect(a.dy, closeTo(roomFloorFeetBottom, 0.5));
    expect(a.dx, closeTo(roomPlaceMaxX, 0.5));
    expect(roomPointInFloor(a), isTrue);

    // Kéo lên trên quá: chân dừng ở chân tường + khoảng đệm.
    await drag(tester, house, const Offset(-3000, -3000));
    a = frameAnchor(tester, house, p);
    expect(a.dx, closeTo(roomPlaceMinX, 0.5));
    expect(a.dy, closeTo(roomFloorTopAt(a.dx) + roomFloorFeetInset, 0.5));
    expect(roomPointInFloor(a), isTrue);
  });

  testWidgets('món gắn tường chỉ ở vùng tường, không xuống sàn', (
    tester,
  ) async {
    await pumpRoom(tester);
    await arrange(tester);
    final p = placeable('noi_tranh');
    await drag(tester, painting, const Offset(200, 3000));
    final a = frameAnchor(tester, painting, p);
    expect(a.dy, lessThanOrEqualTo(roomFloorTopAt(a.dx) - 4 + 0.5));
    expect(roomPointInFloor(a), isFalse);
    // Đã lưu đúng chỗ đã kẹp.
    final stored = decodeRoomLayout(await saved('classic'))['noi_tranh']!;
    expect((stored + p.anchorOffset - a).distance, lessThan(0.5));
  });

  testWidgets('món nhỏ (gấu bông) kéo được và lưu', (tester) async {
    await pumpRoom(tester);
    await arrange(tester);
    final before = framePos(tester, bear);
    await drag(tester, bear, const Offset(60, 60));
    expect(framePos(tester, bear), isNot(before));
    expect(decodeRoomLayout(await saved('classic')).keys, ['gau-bong']);
  });

  testWidgets('Xếp lại như cũ: về mặc định, xóa lưu, mở lại vẫn mặc định', (
    tester,
  ) async {
    await pumpRoom(tester);
    await arrange(tester);
    await drag(tester, house, const Offset(-150, -30));
    await drag(tester, painting, const Offset(100, 40));
    expect(await saved('classic'), isNotNull);

    await tester.tap(find.byKey(const Key('room-arrange-reset')));
    await tester.pumpAndSettle();
    for (final id in ['noi_nha_pet', 'noi_tranh']) {
      final p = placeable(id);
      expect(
        (framePos(tester, Key(p.item.key)) - p.defaultPos).distance,
        lessThan(0.5),
        reason: id,
      );
    }
    expect(await saved('classic'), isNull);

    await reopen(tester);
    expect(
      (framePos(tester, house) - placeable('noi_nha_pet').defaultPos).distance,
      lessThan(0.5),
    );
  });

  testWidgets('bố cục lưu riêng từng chủ đề phòng', (tester) async {
    await db.inventoryDao.grant(
      childId: childId,
      itemId: roomThemeItemId('tet'),
      source: InventorySource.shop,
    );
    await pumpRoom(tester);
    await arrange(tester);
    await drag(tester, house, const Offset(-150, -30));
    final classic = framePos(tester, house);
    await tester.tap(find.byKey(const Key('room-arrange-done')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('room-theme-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room-theme-tet')));
    await tester.pumpAndSettle();
    // Phòng Tết chưa sắp xếp: món về mặc định, phòng gốc vẫn giữ.
    expect(
      (framePos(tester, house) - placeable('noi_nha_pet').defaultPos).distance,
      lessThan(0.5),
    );
    await arrange(tester);
    await drag(tester, house, const Offset(100, 0));
    final tet = framePos(tester, house);
    expect(await saved('tet'), isNotNull);
    expect(await saved('classic'), isNotNull);
    expect(
      (decodeRoomLayout(await saved('classic'))['noi_nha_pet']! - classic)
          .distance,
      lessThan(0.5),
    );

    // Mở lại: phòng Tết (đang dùng) giữ vị trí của nó.
    await reopen(tester);
    expect((framePos(tester, house) - tet).distance, lessThan(0.5));
  });
}
