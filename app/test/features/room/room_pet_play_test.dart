/// Widget test Phòng T2-06b: nút Cho ăn / Chơi với pet, chọn thức ăn /
/// đồ chơi đã có, hiệu ứng (hiệu ứng bật, bơm từng khung), chưa có đồ
/// thì mở Cửa hàng tab Đồ cho pet. Chỉ để vui: không có đói/ốm/buồn.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/animation/animation_gate.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/onboarding/egg_service.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/room/room_screen.dart';
import 'package:timokid/features/shop/shop_screen.dart';
import 'package:timokid/features/shop/shop_service.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late String setId;
  late ShopService shop;

  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 18, 8, 0));
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
    shop = ShopService(db: db);
  });

  Future<void> setUpPlayable({
    bool hatched = true,
    bool unlocked = true,
  }) async {
    await OnboardingService(db: db).completeOnboarding(
      childId: childId,
      profile: CharacterProfile.defaults().copyWith(
        dress: 'girl_top_02',
        name: 'An',
      ),
      eggSpecies: 'dog',
    );
    if (unlocked) {
      for (var i = 0; i < 5; i++) {
        await db.dailySetsDao.updateStageStatus(
          id: setId,
          stageIndex: i,
          status: StageStatus.done,
        );
      }
    }
    if (hatched) {
      await EggService(db: db).noteStageCompleted(childId);
      await EggService(db: db).consumeHatchCelebration(childId);
    }
  }

  Future<void> give(int xu) => db.walletDao.addEntry(
    childId: childId,
    currency: Currency.xu,
    amount: xu,
    reason: 'test',
  );

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
        GoRoute(
          path: ShopScreen.route,
          builder: (context, state) => const ShopScreen(),
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
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    } else {
      await tester.pumpAndSettle();
    }
  }

  /// Bơm [ms] mili giây theo từng khung 50 ms.
  Future<void> advance(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Gỡ cây widget để dừng hẹn giờ/hiệu ứng lặp trước khi test kết thúc.
  Future<void> teardown(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  testWidgets('đã mở khóa + pet đã nở: có hai nút Cho ăn / Chơi', (
    tester,
  ) async {
    await setUpPlayable();
    await pumpRoom(tester);
    expect(find.byKey(const Key('room-pet-feed-button')), findsOneWidget);
    expect(find.byKey(const Key('room-pet-play-button')), findsOneWidget);
    expect(find.text('Cho ăn'), findsOneWidget);
    expect(find.text('Chơi'), findsOneWidget);
  });

  testWidgets('chưa mở khóa hoặc trứng chưa nở: không có nút', (tester) async {
    await setUpPlayable(unlocked: false);
    await pumpRoom(tester);
    expect(find.byKey(const Key('room-pet-feed-button')), findsNothing);
  });

  testWidgets('trứng chưa nở (đã mở khóa): không có nút', (tester) async {
    await setUpPlayable(hatched: false);
    await pumpRoom(tester);
    expect(find.byKey(const Key('room-pet-feed-button')), findsNothing);
    expect(find.byKey(const Key('room-pet-play-button')), findsNothing);
  });

  testWidgets('chưa có thức ăn: Cho ăn mở Cửa hàng tab Đồ cho pet', (
    tester,
  ) async {
    await setUpPlayable();
    await pumpRoom(tester);
    await tester.tap(find.byKey(const Key('room-pet-feed-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop-screen')), findsOneWidget);
    expect(find.byKey(const Key('shop-item-pet_food_bone')), findsOneWidget);
    expect(find.byKey(const Key('shop-item-girl_top_02')), findsNothing);
  });

  testWidgets('chưa có đồ chơi: Chơi mở Cửa hàng tab Đồ cho pet', (
    tester,
  ) async {
    await setUpPlayable();
    await pumpRoom(tester);
    await tester.tap(find.byKey(const Key('room-pet-play-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop-item-pet_toy_ball')), findsOneWidget);
  });

  testWidgets('cho ăn (hiệu ứng bật): thức ăn hiện, pet vui + tim, thức ăn '
      'co nhỏ rồi biến mất, số lượng giảm', (tester) async {
    await setUpPlayable();
    await give(30);
    for (var i = 0; i < 2; i++) {
      await shop.buy(childId: childId, gender: 'girl', itemId: 'pet_food_fish');
    }
    await pumpRoom(tester, animate: true);

    await tester.tap(find.byKey(const Key('room-pet-feed-button')));
    await tester.pump();
    // Bảng chọn: chỉ món có (cá ×2), không có xương.
    expect(find.byKey(const Key('room-pet-menu')), findsOneWidget);
    expect(find.text('Cá ×2'), findsOneWidget);
    expect(find.byKey(const Key('room-pet-food-pet_food_bone')), findsNothing);

    await tester.tap(find.byKey(const Key('room-pet-food-pet_food_fish')));
    await advance(tester, 300);
    expect(find.byKey(const Key('room-pet-menu')), findsNothing);
    expect(find.byKey(const Key('room-pet-prop-food')), findsOneWidget);
    expect(find.byKey(const Key('pet-hearts')), findsNothing);
    expect(await shop.foodCount(childId, 'pet_food_fish'), 1);
    expect(find.text('Ngon quá! Cảm ơn bé!'), findsOneWidget);
    final full = tester.getSize(find.byKey(const Key('room-pet-prop-food')));

    // Nửa sau: pet nhảy vui (tim) và thức ăn nhỏ dần.
    await advance(tester, 900);
    expect(find.byKey(const Key('pet-hearts')), findsOneWidget);
    final munching = tester.getSize(
      find.byKey(const Key('room-pet-prop-food')),
    );
    expect(munching.width, lessThan(full.width));

    await advance(tester, 1000);
    expect(find.byKey(const Key('room-pet-prop-food')), findsNothing);
    expect(await shop.foodCount(childId, 'pet_food_fish'), 1);
    await teardown(tester);
  });

  testWidgets('cho ăn hết thức ăn: lần sau mở Cửa hàng, số không âm', (
    tester,
  ) async {
    await setUpPlayable();
    await give(10);
    await shop.buy(childId: childId, gender: 'girl', itemId: 'pet_food_bone');
    await pumpRoom(tester);
    await tester.tap(find.byKey(const Key('room-pet-feed-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room-pet-food-pet_food_bone')));
    await tester.pumpAndSettle();
    expect(await shop.foodCount(childId, 'pet_food_bone'), 0);
    expect(find.byKey(const Key('room-pet-prop-food')), findsNothing);
    await tester.tap(find.byKey(const Key('room-pet-feed-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop-screen')), findsOneWidget);
    expect(await shop.foodCount(childId, 'pet_food_bone'), 0);
  });

  testWidgets('chơi (hiệu ứng bật): đồ chơi hiện, pet chạy tới, vui, đồ chơi '
      'mờ đi rồi mất; vẫn còn sở hữu', (tester) async {
    await setUpPlayable();
    await give(40);
    await shop.buy(childId: childId, gender: 'girl', itemId: 'pet_toy_ball');
    await pumpRoom(tester, animate: true);

    final petBefore = tester.getCenter(find.byKey(const Key('room-pet')));
    await tester.tap(find.byKey(const Key('room-pet-play-button')));
    await tester.pump();
    expect(find.text('Quả bóng'), findsOneWidget);
    await tester.tap(find.byKey(const Key('room-pet-toy-pet_toy_ball')));
    await advance(tester, 200);
    expect(find.byKey(const Key('room-pet-prop-toy')), findsOneWidget);

    await advance(tester, 1800);
    final petMid = tester.getCenter(find.byKey(const Key('room-pet')));
    expect((petMid - petBefore).distance, greaterThan(20));
    // Pet tới nơi: vui (tim) khi chơi.
    await advance(tester, 700);
    expect(find.byKey(const Key('pet-hearts')), findsOneWidget);

    await advance(tester, 1500);
    expect(find.byKey(const Key('room-pet-prop-toy')), findsNothing);
    expect(await shop.isOwned(childId, 'pet_toy_ball'), isTrue);
    // Không có chuyện đói/buồn: lời pet vẫn vui, không có trạng thái xấu.
    expect(find.textContaining('đói'), findsNothing);
    await teardown(tester);
  });

  testWidgets('đang chơi thì bấm Cho ăn không chồng hiệu ứng', (tester) async {
    await setUpPlayable();
    await give(50);
    await shop.buy(childId: childId, gender: 'girl', itemId: 'pet_toy_yarn');
    await shop.buy(childId: childId, gender: 'girl', itemId: 'pet_food_bone');
    await pumpRoom(tester, animate: true);
    await tester.tap(find.byKey(const Key('room-pet-play-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('room-pet-toy-pet_toy_yarn')));
    await advance(tester, 200);
    await tester.tap(find.byKey(const Key('room-pet-feed-button')));
    await advance(tester, 200);
    expect(find.byKey(const Key('room-pet-menu')), findsNothing);
    expect(await shop.foodCount(childId, 'pet_food_bone'), 1);
    await advance(tester, 4000);
    await teardown(tester);
  });

  testWidgets('hiệu ứng tắt (test thường): cho ăn/chơi vẫn chạy, '
      'pumpAndSettle dừng được', (tester) async {
    await setUpPlayable();
    await give(50);
    await shop.buy(childId: childId, gender: 'girl', itemId: 'pet_toy_plush');
    await shop.buy(childId: childId, gender: 'girl', itemId: 'pet_food_carrot');
    await pumpRoom(tester);
    await tester.tap(find.byKey(const Key('room-pet-play-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room-pet-toy-pet_toy_plush')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-pet-prop-toy')), findsNothing);
    await tester.tap(find.byKey(const Key('room-pet-feed-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room-pet-food-pet_food_carrot')));
    await tester.pumpAndSettle();
    expect(await shop.foodCount(childId, 'pet_food_carrot'), 0);
  });
}
