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
import 'package:timokid/features/pet/dragon_fx_config.dart';
import 'package:timokid/features/pet/pet_config.dart';
import 'package:timokid/features/room/pet_growth.dart';
import 'package:timokid/features/room/room_screen.dart';

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
          builder: (context, state) => const RoomScreen(),
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

  Future<void> advance(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> teardown(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  const menuKeys = [
    Key('dragon-fx-fire'),
    Key('dragon-fx-water'),
    Key('dragon-fx-fly'),
  ];

  testWidgets('chạm rồng hiện 3 nút, chạm sàn thì ẩn', (tester) async {
    await setUpPet(dragonSpecies, xp: petAdultXp);
    await pumpRoom(tester);
    expect(find.byKey(const Key('dragon-fx-menu')), findsNothing);
    await tester.tap(find.byKey(const Key('room-pet')));
    await tester.pumpAndSettle();
    for (final k in menuKeys) {
      expect(find.byKey(k), findsOneWidget);
    }
    expect(find.byKey(const Key('dragon-aura-code')), findsOneWidget);
    await tester.tapAt(const Offset(60, 330)); // sàn
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dragon-fx-menu')), findsNothing);
  });

  testWidgets('pet khác rồng: chạm không có 3 nút, không có vầng sáng', (
    tester,
  ) async {
    await setUpPet('dog');
    await pumpRoom(tester);
    await tester.tap(find.byKey(const Key('room-pet')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dragon-fx-menu')), findsNothing);
    expect(find.byKey(const Key('dragon-aura-code')), findsNothing);
  });

  for (final key in menuKeys) {
    testWidgets('cổng tắt: ${(key as ValueKey).value} chạy xong ngay', (
      tester,
    ) async {
      await setUpPet(dragonSpecies, xp: petAdultXp);
      await pumpRoom(tester);
      await tester.tap(find.byKey(const Key('room-pet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dragon-fx-menu')), findsNothing);
      expect(find.byKey(const Key('room-pet')), findsOneWidget);
    });
  }

  testWidgets('hiệu ứng bật: Phun lửa chạy rồi xong, nút tự ẩn sau vài giây', (
    tester,
  ) async {
    await setUpPet(dragonSpecies, xp: petAdultXp);
    await pumpRoom(tester, animate: true);
    await tester.tap(find.byKey(const Key('room-pet')));
    await advance(tester, 300);
    expect(find.byKey(const Key('dragon-fx-fire')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dragon-fx-fire')));
    await advance(tester, 400);
    expect(find.byKey(const Key('dragon-fx-running-fire')), findsOneWidget);
    expect(find.byKey(const Key('dragon-breath-fire')), findsOneWidget);
    await advance(tester, dragonFireMs + 300);
    expect(find.byKey(const Key('dragon-fx-running-fire')), findsNothing);

    // Không chọn gì: tự ẩn sau dragonMenuHideMs.
    await tester.tap(find.byKey(const Key('room-pet')));
    await advance(tester, 300);
    expect(find.byKey(const Key('dragon-fx-menu')), findsOneWidget);
    await advance(tester, dragonMenuHideMs + 300);
    expect(find.byKey(const Key('dragon-fx-menu')), findsNothing);
    await teardown(tester);
  });

  testWidgets('hiệu ứng bật: Bay nâng rồng lên rồi hạ cánh', (tester) async {
    await setUpPet(dragonSpecies, xp: petAdultXp);
    await pumpRoom(tester, animate: true);
    await tester.tap(find.byKey(const Key('room-pet')));
    await advance(tester, 300);
    await tester.tap(find.byKey(const Key('dragon-fx-fly')));
    await advance(tester, 1200);
    expect(find.byKey(const Key('dragon-fx-running-fly')), findsOneWidget);
    await advance(tester, 2000);
    expect(find.byKey(const Key('dragon-fx-running-fly')), findsNothing);
    await teardown(tester);
  });

  testWidgets('rồng nhỏ: nhắc "lớn lên rồng sẽ phun lửa thật" đúng một lần', (
    tester,
  ) async {
    await setUpPet(dragonSpecies, xp: 0);
    await pumpRoom(tester);
    await tester.tap(find.byKey(const Key('room-pet')));
    await tester.pump();
    expect(find.text(dragonHintText), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.byKey(const Key('room-pet'))); // ẩn nút
    await tester.pump();
    await tester.tap(find.byKey(const Key('room-pet'))); // hiện lại
    await tester.pump();
    expect(find.text(dragonHintText), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('rồng nhỏ vẫn có 3 nút; bản nhỏ chạy xong', (tester) async {
    await setUpPet(dragonSpecies, xp: petTeenXp);
    await pumpRoom(tester, animate: true);
    await tester.tap(find.byKey(const Key('room-pet')));
    await advance(tester, 300);
    await tester.tap(find.byKey(const Key('dragon-fx-water')));
    await advance(tester, 400);
    expect(find.byKey(const Key('dragon-breath-water')), findsOneWidget);
    await advance(tester, dragonSmallMs + 300);
    expect(find.byKey(const Key('dragon-fx-running-water')), findsNothing);
    await teardown(tester);
  });

  testWidgets('rồng trưởng thành đi quãng dài thì bay rồi hạ cánh', (
    tester,
  ) async {
    await setUpPet(dragonSpecies, xp: petAdultXp);
    await pumpRoom(tester, animate: true);
    await tester.tapAt(const Offset(770, 330)); // sàn xa bên phải
    await advance(tester, 2500);
    expect(find.byKey(const Key('dragon-fx-cruising')), findsOneWidget);
    await advance(tester, 9000);
    expect(find.byKey(const Key('dragon-fx-cruising')), findsNothing);
    await teardown(tester);
  });

  testWidgets('rồng nhỏ đi quãng dài vẫn đi bộ (không bay)', (tester) async {
    await setUpPet(dragonSpecies, xp: petTeenXp);
    await pumpRoom(tester, animate: true);
    await tester.tapAt(const Offset(770, 330));
    await advance(tester, 2500);
    expect(find.byKey(const Key('dragon-fx-cruising')), findsNothing);
    await advance(tester, 9000);
    await teardown(tester);
  });
}
