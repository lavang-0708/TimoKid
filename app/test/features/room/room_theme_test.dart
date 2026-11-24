/// Phòng + rồng: chạm rồng hiện 3 nút (chỉ rồng), nút tự ẩn, mỗi
/// hành động chạy xong, rồng nhỏ có lời nhắc một lần; chạm sàn ẩn nút.
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
import 'package:timokid/features/room/room_screen.dart';
import 'package:timokid/features/room/room_themes.dart';
import 'package:timokid/features/shop/shop_service.dart';

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

  Future<void> pumpRoom(WidgetTester tester, {bool animate = false}) async {
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
          builder: (context, state) =>
              const RoomScreen(roomThemesReady: {'tet': true}),
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

  testWidgets('chưa mua chủ đề: không có nút Phong cách, nền phòng gốc', (
    tester,
  ) async {
    await setUpPet('dog', xp: 100);
    await pumpRoom(tester);
    expect(find.byKey(const Key('room-theme-button')), findsNothing);
    expect(assetOf(bg(tester)!), isNot(contains('room_tet')));
    await teardown(tester);
  });

  testWidgets('đã mua Phòng Tết: chọn chủ đề đổi nền và lưu lại', (
    tester,
  ) async {
    await setUpPet('dog', xp: 100);
    await db.inventoryDao.grant(
      childId: childId,
      itemId: roomThemeItemId('tet'),
      source: InventorySource.shop,
    );
    await pumpRoom(tester);
    expect(find.byKey(const Key('room-theme-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('room-theme-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room-theme-tet')));
    await tester.pumpAndSettle();
    expect(assetOf(bg(tester)!), roomThemeBackground('tet'));
    expect(
      await db.settingsDao.getValue(
        childId: childId,
        key: roomThemeSettingsKey,
      ),
      'tet',
    );
    // 5 món nhỏ của phòng gốc không còn.
    expect(find.byKey(const Key('room-furniture-gau-bong')), findsNothing);
    await teardown(tester);
  });

  test('ảnh nội thất theo chủ đề', () {
    expect(
      roomThemeFurnitureAsset('tet', 'noi_nha_pet'),
      'assets/images/furniture/tet_nha_pet.png',
    );
    expect(
      roomThemeFurnitureAsset(roomThemeClassic, 'noi_nha_pet'),
      'assets/images/furniture/noi_nha_pet.png',
    );
  });
}
