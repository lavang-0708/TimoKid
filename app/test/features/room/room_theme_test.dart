/// Phòng một-phòng nhiều-biến-thể: "Thay cả bộ" (nút Phong cách), "Phòng
/// gốc", bảng chọn biến thể từng món ở chế độ Sắp xếp, ảnh về gốc khi
/// thiếu ảnh chủ đề, lưu + chuyển dữ liệu từ bản cũ.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/animation/animation_gate.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/onboarding/egg_service.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/room/pet_growth.dart';
import 'package:timokid/features/room/room_assets.dart';
import 'package:timokid/features/room/room_screen.dart';
import 'package:timokid/features/room/room_variants.dart';
import 'package:timokid/features/room/room_themes.dart';
import 'package:timokid/features/shop/shop_service.dart';

RoomPlaceable _p(String id) => roomPlaceables.firstWhere((p) => p.id == id);

List<RoomPlaceable> _variantsIn(String theme) => [
  for (final p in roomPlaceables)
    if (p.hasVariant(theme)) p,
];

void main() {
  late AppDatabase db;
  late String childId;
  late String setId;

  setUp(() async {
    final clock = FakeClock(DateTime(2026, 11, 18, 8, 0));
    db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    final service = DailySetService(
      dailySetsDao: db.dailySetsDao,
      reviewQueueDao: db.reviewQueueDao,
      ladderService: LadderService(
        attemptsDao: db.attemptsDao,
        skillProgressDao: db.skillProgressDao,
      ),
      clock: clock,
    );
    setId = (await service.getOrCreateTodaySet(childId: childId)).id;
  });

  Future<void> setUpPet(String species, {int xp = 0}) async {
    await OnboardingService(db: db).completeOnboarding(
      childId: childId,
      profile: CharacterProfile.defaults().copyWith(
        dress: 'girl_top_02',
        name: 'An',
      ),
      eggSpecies: 'dog',
    );
    for (var i = 0; i < 5; i++) {
      await db.dailySetsDao.updateStageStatus(
        id: setId,
        stageIndex: i,
        status: StageStatus.done,
      );
    }
    await EggService(db: db).noteStageCompleted(childId);
    await EggService(db: db).consumeHatchCelebration(childId);
    final pet = await db.petsDao.getActive(childId);
    await db.petsDao.updatePet(
      pet!.id,
      PetsCompanion(
        xp: Value(xp),
        species: Value(species),
        // Đã thấy giai đoạn này: không hiện màn ăn mừng lớn lên.
        stageSeen: Value(petStageForXp(xp).name),
      ),
    );
  }

  Future<void> pumpRoom(
    WidgetTester tester, {
    bool animate = false,
    Map<String, bool> ready = const {'tet': true, 'ngan_ha': true},
  }) async {
    AnimationGate.enabled = animate;
    addTearDown(() => AnimationGate.enabled = false);
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: RoomScreen.route,
      routes: [
        GoRoute(
          path: RoomScreen.route,
          builder: (context, state) => RoomScreen(roomThemesReady: ready),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    if (animate) {
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> teardown(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  Image? bg(WidgetTester tester) {
    final finder = find.descendant(
      of: find.byKey(const Key('room-floor')),
      matching: find.byType(Image),
    );
    return tester.widgetList<Image>(finder).first;
  }

  String assetOf(Image img) => (img.image as AssetImage).assetName;

  Future<void> grant(String id) => db.inventoryDao.grant(
    childId: childId,
    itemId: id,
    source: InventorySource.shop,
  );

  Future<String?> setting(String key) =>
      db.settingsDao.getValue(childId: childId, key: key);

  /// Ảnh (theo tên asset) của ô món [placeableId] trong cảnh.
  List<String> slotAssets(WidgetTester tester, String placeableId) {
    final p = roomPlaceables.firstWhere((p) => p.id == placeableId);
    return tester
        .widgetList<Image>(
          find.descendant(
            of: find.byKey(Key(p.item.key)),
            matching: find.byType(Image),
          ),
        )
        .map((i) => (i.image as AssetImage).assetName)
        .toList();
  }

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('room-theme-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('chưa mua gì: không có nút Phong cách, nền phòng gốc', (
    tester,
  ) async {
    await setUpPet('dog', xp: 100);
    await pumpRoom(tester);
    expect(find.byKey(const Key('room-theme-button')), findsNothing);
    expect(assetOf(bg(tester)!), isNot(contains('room_tet')));
    await teardown(tester);
  });

  testWidgets('Thay cả bộ: đổi nền + mọi món đã có biến thể, lưu lại', (
    tester,
  ) async {
    await setUpPet('dog', xp: 100);
    await grant(roomThemeItemId('tet'));
    await grant('noi_nha_pet');
    await pumpRoom(tester);
    await openPicker(tester);
    expect(find.text('Thay\ncả bộ'), findsOneWidget);
    await tester.tap(find.byKey(const Key('room-theme-tet')));
    await tester.pumpAndSettle();
    expect(assetOf(bg(tester)!), roomThemeBackground('tet'));
    expect(await setting(roomBackgroundSettingsKey), 'tet');
    final variants = decodeRoomVariants(await setting(roomVariantsSettingsKey));
    // Có bộ => 7 món lớn/vừa có biến thể Tết; món nhỏ không có biến thể.
    expect(variants.length, _variantsIn('tet').length);
    expect(variants.length, 7);
    expect(variants.values.toSet(), {'tet'});
    expect(variants.containsKey('gau-bong'), isFalse);
    // Món nhỏ vẫn vẽ (nền chủ đề không "nướng" món nào).
    expect(find.byKey(const Key('room-furniture-gau-bong')), findsOneWidget);
    expect(slotAssets(tester, 'gau-bong').first, _p('gau-bong').item.asset);
    expect(slotAssets(tester, 'noi_giuong').first, contains('tet_giuong'));
    // Nhà cho pet chưa có bản Tết: vẫn ảnh gốc.
    expect(
      slotAssets(tester, 'noi_nha_pet').first,
      _p('noi_nha_pet').item.asset,
    );
    await teardown(tester);
  });

  testWidgets('Thay cả bộ: món chưa có biến thể giữ nguyên biến thể hiện tại', (
    tester,
  ) async {
    await setUpPet('dog', xp: 100);
    // Bộ Ngân hà (đủ nền) chỉ qua đủ món lẻ; Tết chỉ mua 1 món + nền qua bộ.
    for (final p in _variantsIn('ngan_ha')) {
      await grant(roomThemeVariantItemId('ngan_ha', p.id));
    }
    await grant(roomThemeVariantItemId('tet', 'noi_giuong'));
    await db.settingsDao.setValue(
      childId: childId,
      key: roomVariantsSettingsKey,
      value: encodeRoomVariants({'noi_giuong': 'tet'}),
    );
    await pumpRoom(tester);
    await openPicker(tester);
    // Đủ mọi món lẻ Ngân hà => tặng nền => có thẻ Ngân hà.
    expect(find.byKey(const Key('room-theme-ngan_ha')), findsOneWidget);
    expect(find.byKey(const Key('room-theme-tet')), findsNothing);
    await tester.tap(find.byKey(const Key('room-theme-ngan_ha')));
    await tester.pumpAndSettle();
    expect(assetOf(bg(tester)!), roomThemeBackground('ngan_ha'));
    final variants = decodeRoomVariants(await setting(roomVariantsSettingsKey));
    expect(variants['noi_giuong'], 'ngan_ha');
    expect(variants.length, _variantsIn('ngan_ha').length);
    expect(variants.containsKey('gau-bong'), isFalse);
    await teardown(tester);
  });

  testWidgets('Phòng gốc: nền và mọi món về gốc, vị trí giữ nguyên', (
    tester,
  ) async {
    await setUpPet('dog', xp: 100);
    await grant(roomThemeItemId('tet'));
    await db.settingsDao.setValue(
      childId: childId,
      key: roomBackgroundSettingsKey,
      value: 'tet',
    );
    await db.settingsDao.setValue(
      childId: childId,
      key: roomVariantsSettingsKey,
      value: encodeRoomVariants({'noi_giuong': 'tet', 'noi_tu_ao': 'tet'}),
    );
    await db.settingsDao.setValue(
      childId: childId,
      key: roomLayoutSettingsKey,
      value: encodeRoomLayout({'noi_tu_ao': _p('noi_tu_ao').defaultPos}),
    );
    await pumpRoom(tester);
    expect(assetOf(bg(tester)!), roomThemeBackground('tet'));
    expect(slotAssets(tester, 'noi_giuong').first, contains('tet_giuong'));
    final posBefore = tester.getTopLeft(
      find.byKey(const Key('room-furniture-noi_tu_ao')),
    );

    await openPicker(tester);
    await tester.tap(find.byKey(const Key('room-theme-classic')));
    await tester.pumpAndSettle();
    expect(assetOf(bg(tester)!), roomClassicBackgroundAsset);
    expect(await setting(roomBackgroundSettingsKey), 'classic');
    expect(decodeRoomVariants(await setting(roomVariantsSettingsKey)), isEmpty);
    expect(slotAssets(tester, 'noi_giuong').first, _p('noi_giuong').item.asset);
    expect(
      tester.getTopLeft(find.byKey(const Key('room-furniture-noi_tu_ao'))),
      posBefore,
    );
    await teardown(tester);
  });

  testWidgets('Sắp xếp: chạm món mở bảng biến thể, chỉ đổi món đó', (
    tester,
  ) async {
    await setUpPet('dog', xp: 100);
    await grant(roomThemeVariantItemId('tet', 'noi_tu_ao'));
    await pumpRoom(tester);
    await tester.tap(find.byKey(const Key('room-arrange-button')));
    await tester.pumpAndSettle();
    // Món chưa có biến thể nào thì chạm không mở bảng.
    await tester.tap(find.byKey(const Key('room-furniture-den-sao')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-variant-sheet')), findsNothing);

    await tester.tap(find.byKey(const Key('room-furniture-noi_tu_ao')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-variant-sheet')), findsOneWidget);
    expect(find.byKey(const Key('room-variant-classic')), findsOneWidget);
    expect(find.byKey(const Key('room-variant-tet')), findsOneWidget);
    expect(find.byKey(const Key('room-variant-ngan_ha')), findsNothing);

    await tester.tap(find.byKey(const Key('room-variant-tet')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-variant-sheet')), findsNothing);
    expect(decodeRoomVariants(await setting(roomVariantsSettingsKey)), {
      'noi_tu_ao': 'tet',
    });
    // Nền không đổi.
    expect(assetOf(bg(tester)!), roomClassicBackgroundAsset);
    expect(slotAssets(tester, 'noi_tu_ao').first, contains('tet_tu_ao'));

    // Chọn lại gốc.
    await tester.tap(find.byKey(const Key('room-furniture-noi_tu_ao')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room-variant-classic')));
    await tester.pumpAndSettle();
    expect(decodeRoomVariants(await setting(roomVariantsSettingsKey)), isEmpty);
    expect(slotAssets(tester, 'noi_tu_ao').first, _p('noi_tu_ao').item.asset);
    await teardown(tester);
  });

  testWidgets('kệ lớn đổi sang bản Rồng (đứng sàn): vị trí lưu kẹp lại', (
    tester,
  ) async {
    await setUpPet('dog', xp: 100);
    await grant(roomThemeVariantItemId('rong', 'noi_ke_lon'));
    // Bé đã đặt kệ ở chỗ treo tường (vị trí lưu = góc trên-trái bản gốc).
    await db.settingsDao.setValue(
      childId: childId,
      key: roomLayoutSettingsKey,
      value: encodeRoomLayout({'noi_ke_lon': _p('noi_ke_lon').defaultPos}),
    );
    await pumpRoom(
      tester,
      ready: const {'tet': true, 'ngan_ha': true, 'rong': true},
    );
    final shelf = _p('noi_ke_lon');
    expect(shelf.kindFor(roomThemeClassic), RoomPlaceKind.wall);
    expect(shelf.kindFor('rong'), RoomPlaceKind.floor);
    await tester.tap(find.byKey(const Key('room-arrange-button')));
    await tester.pumpAndSettle();
    // Chạm phần dưới kệ treo tường (phần trên bị thanh nút che) (khung 1600x900 -> màn hình).
    final floor = tester.getRect(find.byKey(const Key('room-floor')));
    await tester.tapAt(
      Offset(
        floor.left + 1125 / 1600 * floor.width,
        floor.top + 360 / 900 * floor.height,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room-variant-rong')));
    await tester.pumpAndSettle();
    expect(decodeRoomVariants(await setting(roomVariantsSettingsKey)), {
      'noi_ke_lon': 'rong',
    });
    // Treo tường -> đứng sàn: chân kệ phải nằm trên sàn, đỉnh trong khung.
    final saved = decodeRoomLayout(
      await setting(roomLayoutSettingsKey),
    )['noi_ke_lon'];
    expect(saved, isNotNull);
    expect(saved, roomClampPlaceable(shelf, shelf.defaultPos, variant: 'rong'));
    expect(roomPointInFloor(saved! + shelf.anchorOffset), isTrue);
    expect(shelf.boxAt('rong', saved).top, greaterThanOrEqualTo(19.999));
    await teardown(tester);
  });

  testWidgets('thiếu ảnh biến thể: về ảnh gốc của món', (tester) async {
    await setUpPet('dog', xp: 100);
    await grant(roomThemeVariantItemId('tet', 'noi_tu_ao'));
    await db.settingsDao.setValue(
      childId: childId,
      key: roomVariantsSettingsKey,
      value: encodeRoomVariants({'noi_tu_ao': 'tet'}),
    );
    await pumpRoom(tester);
    final assets = slotAssets(tester, 'noi_tu_ao');
    // Thử ảnh Tết (chưa có file), lỗi thì vẽ ảnh gốc.
    expect(assets.first, 'assets/images/furniture/tet_tu_ao.webp');
    expect(assets, contains(_p('noi_tu_ao').item.asset));
    await teardown(tester);
  });

  testWidgets('biến thể đã lưu mà chưa sở hữu: về gốc', (tester) async {
    await setUpPet('dog', xp: 100);
    await db.settingsDao.setValue(
      childId: childId,
      key: roomBackgroundSettingsKey,
      value: 'tet',
    );
    await db.settingsDao.setValue(
      childId: childId,
      key: roomVariantsSettingsKey,
      value: encodeRoomVariants({'noi_tu_ao': 'tet'}),
    );
    await pumpRoom(tester);
    expect(assetOf(bg(tester)!), roomClassicBackgroundAsset);
    expect(slotAssets(tester, 'noi_tu_ao'), [_p('noi_tu_ao').item.asset]);
    await teardown(tester);
  });

  testWidgets('máy cũ (room_theme + room_layout_<chủ đề>) được chuyển sang', (
    tester,
  ) async {
    await setUpPet('dog', xp: 100);
    await grant(roomThemeItemId('tet'));
    await grant('noi_nha_pet');
    await db.settingsDao.setValue(
      childId: childId,
      key: roomThemeSettingsKey,
      value: 'tet',
    );
    await db.settingsDao.setValue(
      childId: childId,
      key: 'room_layout_tet',
      value: encodeRoomLayout({'noi_nha_pet': const Offset(500, 700)}),
    );
    await pumpRoom(tester);
    expect(assetOf(bg(tester)!), roomThemeBackground('tet'));
    // Tết chưa có bản vẽ riêng cho món cửa hàng: vẫn ảnh gốc.
    expect(
      slotAssets(tester, 'noi_nha_pet').first,
      _p('noi_nha_pet').item.asset,
    );
    expect(await setting(roomBackgroundSettingsKey), 'tet');
    expect(
      decodeRoomLayout(await setting(roomLayoutSettingsKey))['noi_nha_pet'],
      const Offset(500, 700),
    );
    await teardown(tester);
  });

  test('ảnh nội thất theo chủ đề', () {
    expect(
      roomThemeFurnitureAsset('tet', 'noi_nha_pet'),
      'assets/images/furniture/tet_nha_pet.webp',
    );
    expect(
      roomThemeFurnitureAsset('ngan_ha', 'gau-bong'),
      'assets/images/furniture/ngan_ha_gau_bong.webp',
    );
    expect(
      roomThemeFurnitureAsset(roomThemeClassic, 'noi_nha_pet'),
      'assets/images/furniture/noi_nha_pet.webp',
    );
    // Món nhỏ không có biến thể: mọi chủ đề đều ra ảnh gốc.
    final bear = _p('gau-bong');
    expect(bear.assetFor(roomThemeClassic), bear.item.asset);
    expect(bear.assetFor('rong'), bear.item.asset);
    expect(bear.hasVariant('rong'), isFalse);
    // Món lớn: ảnh theo chủ đề; món cửa hàng chỉ có Rồng.
    expect(
      _p('noi_giuong').assetFor('rong'),
      'assets/images/furniture/rong_giuong.webp',
    );
    expect(_p('noi_nha_pet').hasVariant('rong'), isTrue);
    expect(_p('noi_nha_pet').hasVariant('tet'), isFalse);
  });
}
