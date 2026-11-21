/// Widget test cho màn Phòng (T2-04): khóa/mở theo đề ngày, nút
/// Thị trấn / Tủ đồ / Cửa hàng, phản ứng pet và nội thất.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/features/character/kid_sprite.dart';

import '../../helpers/kid_images.dart';

import 'package:timokid/core/animation/animation_gate.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/character/character_bounce.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/onboarding/egg_service.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/room/coming_soon_screen.dart';
import 'package:timokid/features/room/room_assets.dart';
import 'package:timokid/features/room/room_screen.dart';
import 'package:timokid/features/shop/shop_screen.dart';
import 'package:timokid/features/town/town_screen.dart';

AppDatabase openMemoryDb({Clock? clock}) => AppDatabase(
  executor: NativeDatabase.memory(),
  clock: clock ?? const SystemClock(),
);

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late String setId;

  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 18, 8, 0));
    db = openMemoryDb(clock: clock);
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
    final set = await service.getOrCreateTodaySet(childId: childId);
    setId = set.id;
  });

  Future<void> pumpRoom(
    WidgetTester tester, {
    Size size = const Size(800, 360),
    bool settle = true,
    bool clean = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Router mới mỗi test (không dùng router tĩnh của app để trạng
    // thái điều hướng không rò sang test khác), cùng 3 route như app.
    final router = GoRouter(
      initialLocation: RoomScreen.route,
      routes: [
        GoRoute(
          path: RoomScreen.route,
          builder: (context, state) => RoomScreen(cleanBackground: clean),
        ),
        GoRoute(
          path: TownScreen.route,
          builder: (context, state) => const TownScreen(),
        ),
        GoRoute(
          path: ShopScreen.route,
          builder: (context, state) => const ShopScreen(),
        ),
        GoRoute(
          path: ComingSoonScreen.route,
          builder: (context, state) =>
              ComingSoonScreen(args: state.extra as ComingSoonArgs),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    if (!settle) {
      // Hiệu ứng lặp bật thì pumpAndSettle không dừng: bơm từng khung.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      return;
    }
    await tester.pumpAndSettle();
  }

  Future<void> completeOnboardingGirl({String egg = 'dog'}) async {
    await OnboardingService(db: db).completeOnboarding(
      childId: childId,
      profile: CharacterProfile.defaults().copyWith(
        hairColor: 0xFFA9715C,
        dress: 'girl_top_02',
        name: 'An',
      ),
      eggSpecies: egg,
    );
  }

  Future<void> markAllDone() async {
    for (var i = 0; i < 5; i++) {
      await db.dailySetsDao.updateStageStatus(
        id: setId,
        stageIndex: i,
        status: StageStatus.done,
      );
    }
  }

  Future<void> hatchEgg() async {
    await EggService(db: db).noteStageCompleted(childId);
    await EggService(db: db).consumeHatchCelebration(childId);
  }

  testWidgets('chưa có hồ sơ thì không hiện nhân vật/trứng, vẫn khóa', (
    tester,
  ) async {
    await pumpRoom(tester);

    expect(find.byKey(const Key('room-screen')), findsOneWidget);
    expect(find.byKey(const Key('room-character')), findsNothing);
    expect(find.byKey(const Key('room-egg')), findsNothing);
    expect(find.byKey(const Key('room-locked-banner')), findsOneWidget);
    expect(find.text('0/5'), findsOneWidget);
  });

  testWidgets('đã tạo nhân vật nữ + trứng chó thì hiện nhân vật + trứng', (
    tester,
  ) async {
    await completeOnboardingGirl();
    await pumpRoom(tester, size: const Size(640, 320));

    expect(find.byKey(const Key('room-character')), findsOneWidget);
    expect(find.text('An'), findsOneWidget);
    expect(find.byKey(const Key('room-egg')), findsOneWidget);
    expect(find.byKey(const Key('room-pet')), findsNothing);
    expect(find.byKey(const Key('room-locked-banner')), findsOneWidget);
  });

  testWidgets('khóa: chưa xong đề ngày thì Tủ đồ/Cửa hàng có ổ khóa', (
    tester,
  ) async {
    await completeOnboardingGirl();
    await pumpRoom(tester);

    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2));
    expect(find.byKey(const Key('room-town-button')), findsOneWidget);
    expect(find.text('5/5'), findsNothing);
  });

  testWidgets('bấm Tủ đồ khi khóa thì hiện SnackBar + ra Thị trấn được', (
    tester,
  ) async {
    await completeOnboardingGirl();
    await pumpRoom(tester);

    await tester.tap(find.byKey(const Key('room-wardrobe-button')));
    // SnackBar trượt từ dưới lên trong 250 ms: khung đầu chèn nó
    // vào overlay (hoạt cảnh mới bắt đầu, giá trị 0), khung sau
    // mới trượt xong — một `pump()` duy nhất thì nó còn ở dưới
    // màn hình, bấm hành động hụt.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Tủ đồ mở khi xong đề ngày nhé!'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Ra Thị trấn'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('town-screen')), findsOneWidget);
  });

  testWidgets('bấm nút Ra Thị trấn ở banner thì sang Thị trấn', (tester) async {
    await completeOnboardingGirl();
    await pumpRoom(tester);

    await tester.tap(find.byKey(const Key('room-goto-town-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('town-screen')), findsOneWidget);
  });

  testWidgets('nút Thị trấn sang Thị trấn, nút Phòng quay lại Phòng', (
    tester,
  ) async {
    await completeOnboardingGirl();
    await pumpRoom(tester);

    await tester.tap(find.byKey(const Key('room-town-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('town-screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('town-room-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-screen')), findsOneWidget);
  });

  testWidgets('xong đề ngày thì mở: hết banner, Tủ đồ đổi được đồ', (
    tester,
  ) async {
    await completeOnboardingGirl();
    await markAllDone();
    // Bé đã mua bộ 3, mũ, kính, balo (Cửa hàng) nên mặc thử được.
    for (final id in ['girl_top_03', 'head_hat', 'glasses', 'backpack']) {
      await db.inventoryDao.grant(childId: childId, itemId: id, source: 'shop');
    }
    await pumpRoom(tester);

    expect(find.byKey(const Key('room-locked-banner')), findsNothing);
    expect(find.text('5/5'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
    // Hồ sơ lưu váy tím (bộ 2).
    expect(find.byKey(const Key('kid-full-girl-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('room-wardrobe-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-wardrobe-sheet')), findsOneWidget);

    // Chọn bộ 3 + mũ: nhân vật trong phòng đổi ngay và được lưu lại.
    await tester.tap(find.byKey(const Key('room-wardrobe-outfit-3')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('room-wardrobe-accessory-hat')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room-wardrobe-accessory-hat')));
    await tester.pumpAndSettle();
    final profile = await OnboardingService(db: db).loadProfile(childId);
    expect(profile!.dress, 'girl_top_03');
    expect(
      await db.settingsDao.getValue(
        childId: childId,
        key: 'kid_head_accessory',
      ),
      'hat',
    );
    await tester.ensureVisible(find.byKey(const Key('room-wardrobe-glasses')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room-wardrobe-glasses')));
    await tester.pumpAndSettle();
    expect(
      await db.settingsDao.getValue(childId: childId, key: 'kid_glasses'),
      'true',
    );
    await tester.tap(find.byKey(const Key('room-wardrobe-backpack')));
    await tester.pumpAndSettle();
    expect(
      await db.settingsDao.getValue(childId: childId, key: 'kid_backpack'),
      'true',
    );
    await tester.tapAt(const Offset(400, 20));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kid-full-girl-3-backpack')), findsOneWidget);
    expect(
      find.byKey(const Key('kid-overlay-girl_glasses_01.png')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('room-character')),
        matching: find.byKey(const Key('kid-accessory')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('chạm sàn thì nhân vật đi tới, pet đi theo', (tester) async {
    await completeOnboardingGirl();
    await hatchEgg();
    await pumpRoom(tester);

    final scene = find.byKey(const Key('room-floor'));
    final box = tester.getRect(scene);
    Offset frameToScreen(Offset f) => Offset(
      box.left + f.dx / 1600 * box.width,
      box.top + f.dy / 900 * box.height,
    );
    final before = tester.getRect(find.byKey(const Key('room-character')));
    // Chạm sàn phía phải thảm (khung 1600x900).
    await tester.tapAt(frameToScreen(const Offset(1000, 840)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final after = tester.getRect(find.byKey(const Key('room-character')));
    expect(after.center.dx, greaterThan(before.center.dx + 50));
    // Đứng gần hơn (chân y 840 > 810) thì to hơn.
    expect(after.height, greaterThan(before.height));
    final pet = tester.getRect(find.byKey(const Key('room-pet')));
    expect((pet.center.dx - after.center.dx).abs(), lessThan(box.width * 0.2));
  });

  testWidgets('xong đề ngày thì Cửa hàng mở màn /shop, quay lại về Phòng', (
    tester,
  ) async {
    await completeOnboardingGirl();
    await markAllDone();
    await pumpRoom(tester);

    await tester.tap(find.byKey(const Key('room-shop-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shop-screen')), findsOneWidget);
    expect(find.byKey(const Key('coming-soon-screen')), findsNothing);

    await tester.tap(find.byKey(const Key('shop-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-screen')), findsOneWidget);
  });

  testWidgets('Tủ đồ: món chưa mua có ổ khóa + giá, bấm thì mở Cửa hàng', (
    tester,
  ) async {
    await completeOnboardingGirl();
    await markAllDone();
    await pumpRoom(tester);

    await tester.tap(find.byKey(const Key('room-wardrobe-button')));
    await tester.pumpAndSettle();

    // Bé đang mặc váy tím (bộ 2) nên đã có; bộ 1 và 3 chưa mua.
    expect(
      find.byKey(const Key('room-wardrobe-lock-girl_top_02')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('room-wardrobe-lock-girl_top_01')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('room-wardrobe-lock-girl_top_03')),
      findsOneWidget,
    );
    expect(find.text('Váy hồng\n80 xu'), findsOneWidget);
    expect(
      find.byKey(const Key('room-wardrobe-lock-head_hat')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('room-wardrobe-glasses')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-wardrobe-lock-glasses')), findsOneWidget);

    // Bấm bộ chưa mua: KHÔNG đổi đồ, mở Cửa hàng.
    await tester.ensureVisible(find.byKey(const Key('room-wardrobe-outfit-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room-wardrobe-outfit-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop-screen')), findsOneWidget);
    final profile = await OnboardingService(db: db).loadProfile(childId);
    expect(profile!.dress, 'girl_top_02');
  });

  testWidgets('Tủ đồ: không mặc được kính chưa mua, mua xong mặc được', (
    tester,
  ) async {
    await completeOnboardingGirl();
    await markAllDone();
    await db.walletDao.addEntry(
      childId: childId,
      currency: 'xu',
      amount: 100,
      reason: 'test',
    );
    await pumpRoom(tester);

    await tester.tap(find.byKey(const Key('room-wardrobe-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('room-wardrobe-glasses')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room-wardrobe-glasses')));
    await tester.pumpAndSettle();
    expect(
      await db.settingsDao.getValue(childId: childId, key: 'kid_glasses'),
      isNot('true'),
    );
    // Đang ở Cửa hàng: mua kính.
    expect(find.byKey(const Key('shop-screen')), findsOneWidget);
    await tester.tap(find.byKey(const Key('shop-tab-accessories')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop-buy-glasses')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop-confirm-buy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop-back-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('room-wardrobe-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-wardrobe-lock-glasses')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('room-wardrobe-glasses')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room-wardrobe-glasses')));
    await tester.pumpAndSettle();
    expect(
      await db.settingsDao.getValue(childId: childId, key: 'kid_glasses'),
      'true',
    );
  });

  testWidgets('chạm trứng chưa nở thì hiện bong bóng rồi tự ẩn', (
    tester,
  ) async {
    await completeOnboardingGirl();
    await pumpRoom(tester);

    await tester.tap(find.byKey(const Key('room-egg')));
    await tester.pump();

    expect(find.byKey(const Key('room-reaction-bubble')), findsOneWidget);
    expect(find.text('Trứng sẽ nở sau chặng đầu tiên nhé!'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('room-reaction-bubble')), findsNothing);
  });

  testWidgets('hiệu ứng thật: đi từng bước rồi dừng, đổi hướng, vẫy tay', (
    tester,
  ) async {
    await completeOnboardingGirl();
    await hatchEgg();
    AnimationGate.enabled = true;
    addTearDown(() => AnimationGate.enabled = false);
    // Phòng với hiệu ứng bật (thở, chớp mắt, nhún bước).
    await pumpRoom(tester, settle: false);

    final scene = find.byKey(const Key('room-floor'));
    final box = tester.getRect(scene);
    Offset frameToScreen(Offset f) => Offset(
      box.left + f.dx / 1600 * box.width,
      box.top + f.dy / 900 * box.height,
    );
    final start = tester.getRect(find.byKey(const Key('room-character')));
    // Đi sang trái (chạm trước tủ đầu giường → vòng trước tủ).
    await tester.tapAt(frameToScreen(const Offset(120, 860)));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final mid = tester.getRect(find.byKey(const Key('room-character')));
    expect(mid.center.dx, lessThan(start.center.dx));
    // Bé gái có khung đi bộ thật (lô 4): bộ 2, đi xuống/ngang → `dr`.
    expect(
      assetNameOf(
        tester.widget<Image>(find.byKey(const Key('kid-walk-frame'))).image,
      ),
      startsWith('assets/images/character/girl/girl_full_02_walk_dr_'),
    );
    expect(
      tester.widget<KidSprite>(find.byKey(const Key('room-character'))),
      isA<KidSprite>()
          .having((k) => k.walking, 'walking', isTrue)
          .having((k) => k.facingLeft, 'facingLeft', isTrue),
    );
    // Đi hết đường (tốc độ 120 px/giây, ~8 giây) rồi đứng lại.
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final kid = tester.widget<KidSprite>(
      find.byKey(const Key('room-character')),
    );
    expect(kid.walking, isFalse);
    final end = tester.getRect(find.byKey(const Key('room-character')));
    expect(end.center.dx, lessThan(mid.center.dx));

    // Bấm vào nhân vật thì vẫy tay, 1,4 giây sau thôi vẫy.
    await tester.tap(find.byKey(const Key('room-character')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      tester.widget<KidSprite>(find.byKey(const Key('room-character'))).waving,
      isTrue,
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      tester.widget<KidSprite>(find.byKey(const Key('room-character'))).waving,
      isFalse,
    );
    // Gỡ cây widget (dừng hiệu ứng lặp) trước khi test kết thúc.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bé trai đi bằng khung đi bộ thật, đứng lại thì về ảnh đứng', (
    tester,
  ) async {
    await OnboardingService(db: db).completeOnboarding(
      childId: childId,
      profile: CharacterProfile.defaults().copyWith(
        gender: 'boy',
        dress: 'boy_outfit_02',
        name: 'Bình',
      ),
      eggSpecies: 'cat',
    );
    AnimationGate.enabled = true;
    addTearDown(() => AnimationGate.enabled = false);
    await pumpRoom(tester, settle: false);
    final box = tester.getRect(find.byKey(const Key('room-floor')));
    // Chạm xa về phía trước bên phải: đi xuống-phải (khung `dr`).
    await tester.tapAt(
      Offset(
        box.left + 1300 / 1600 * box.width,
        box.top + 860 / 900 * box.height,
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final frame = tester.widget<Image>(find.byKey(const Key('kid-walk-frame')));
    expect(
      assetNameOf(frame.image),
      startsWith('assets/images/character/boy/boy_full_02_walk_dr_'),
    );
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('kid-walk-frame')), findsNothing);
    // Ảnh đứng bộ 2 (có thể đang tự vẫy tay khi đứng lâu).
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('kid-full-boy-2'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('chạm pet khi khóa thì nhắc xong đề ngày', (tester) async {
    await completeOnboardingGirl();
    await hatchEgg();
    await pumpRoom(tester);

    expect(find.byKey(const Key('room-pet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('room-pet')));
    await tester.pump();

    expect(find.text('Chơi với tớ cần xong đề ngày đã nhé!'), findsOneWidget);
  });

  testWidgets('chạm pet khi mở thì pet vui', (tester) async {
    await completeOnboardingGirl();
    await hatchEgg();
    await markAllDone();
    await pumpRoom(tester);

    await tester.tap(find.byKey(const Key('room-pet')));
    await tester.pump();

    expect(find.textContaining('Gâu gâu! Chơi với tớ nhé!'), findsOneWidget);
    // 1 ngày xong đề: còn 2 ngày nữa pet lớn.
    expect(find.textContaining('Còn 2 ngày học nữa'), findsOneWidget);
  });

  testWidgets('chạm nội thất thì hiện bong bóng', (tester) async {
    await completeOnboardingGirl();
    await pumpRoom(tester);

    await tester.tap(find.byKey(const Key('room-furniture-gau-bong')));
    await tester.pump();
    expect(find.text('Gấu bông ôm thích lắm!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('room-furniture-den-sao')));
    await tester.pump();
    expect(find.text('Đèn sao sáng rồi, đọc sách thôi!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('room-furniture-chau-cay')));
    await tester.pump();
    expect(find.text('Cây lớn nhanh nhé!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('room-furniture-coc-sao')));
    await tester.pump();
    expect(find.text('Cốc bút đựng bút chì gọn quá!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('room-furniture-binh-hoa')));
    await tester.pump();
    expect(find.text('Hoa thơm quá!'), findsOneWidget);
  });

  testWidgets('qua ngày mới khóa lại', (tester) async {
    await completeOnboardingGirl();
    await markAllDone();
    await pumpRoom(tester);
    expect(find.byKey(const Key('room-locked-banner')), findsNothing);

    clock.advance(const Duration(days: 1));
    await pumpRoom(tester);

    expect(find.byKey(const Key('room-locked-banner')), findsOneWidget);
    expect(find.text('0/5'), findsOneWidget);
  });

  testWidgets('trứng ở Phòng là PNG thật (PR #21), không còn SVG tạm', (
    tester,
  ) async {
    await completeOnboardingGirl();
    await pumpRoom(tester);

    final eggImage = find.descendant(
      of: find.byKey(const Key('room-egg')),
      matching: find.byType(Image),
    );
    expect(eggImage, findsOneWidget);
    final provider = tester.widget<Image>(eggImage).image;
    expect(provider, isA<AssetImage>());
    expect(
      (provider as AssetImage).assetName,
      'assets/images/pets/dog_egg.png',
    );
    // Ô trứng không còn SVG (từ A1, nền + nội thất Phòng cũng là
    // PNG thật, không còn SVG tạm nào trong màn Phòng).
    expect(
      find.descendant(
        of: find.byKey(const Key('room-egg')),
        matching: find.byType(SvgPicture),
      ),
      findsNothing,
    );
  });

  testWidgets('nền cũ đã có sẵn 5 món: không vẽ PNG rời đè lên, không SVG', (
    tester,
  ) async {
    await completeOnboardingGirl();
    await pumpRoom(tester);

    final assetNames = tester
        .widgetList<Image>(find.byType(Image))
        .map((w) => w.image)
        .whereType<AssetImage>()
        .map((p) => p.assetName)
        .toList();
    expect(assetNames, contains('assets/images/backgrounds/room_v3.png'));
    expect(assetNames, isNot(contains(roomCleanBackgroundAsset)));
    // Góp ý 22/11: PNG rời đè lên món vẽ sẵn trong nền gây hình đôi.
    expect(assetNames.where((n) => n.contains('furniture/')), isEmpty);
    // Vùng chạm vẫn có đủ 5 khóa, đặt đúng hộp món trong nền.
    final floor = tester.getRect(find.byKey(const Key('room-floor')));
    for (final item in roomFurniture) {
      final r = tester.getRect(find.byKey(Key(item.key)));
      expect(
        r.left,
        closeTo(floor.left + item.bakedRect.left / 1600 * floor.width, 0.6),
      );
      expect(
        r.top,
        closeTo(floor.top + item.bakedRect.top / 900 * floor.height, 0.6),
      );
      expect(r.width, closeTo(item.bakedRect.width / 1600 * floor.width, 0.6));
      expect(
        r.height,
        closeTo(item.bakedRect.height / 900 * floor.height, 0.6),
      );
    }
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('có nền sạch (cờ bật): dùng room_v3_clean + vẽ lại 5 PNG rời', (
    tester,
  ) async {
    await completeOnboardingGirl();
    await pumpRoom(tester, clean: true);
    // Chưa có file room_v3_clean.png trong repo nên ảnh nền báo lỗi
    // nạp; bỏ qua ngoại lệ đó, chỉ kiểm cây widget.
    tester.takeException();

    final assetNames = tester
        .widgetList<Image>(find.byType(Image))
        .map((w) => w.image)
        .whereType<AssetImage>()
        .map((p) => p.assetName)
        .toList();
    expect(assetNames, contains(roomCleanBackgroundAsset));
    expect(
      assetNames,
      isNot(contains('assets/images/backgrounds/room_v3.png')),
    );
    for (final name in [
      'gau_bong_v3',
      'den_sao_v3',
      'chau_cay_v3',
      'binh_hoa_v3',
      'coc_sao_v3',
    ]) {
      expect(assetNames, contains('assets/images/furniture/$name.png'));
    }
  });

  testWidgets('chạm món trong nền: bong bóng + nháy sao pop rồi tắt', (
    tester,
  ) async {
    await completeOnboardingGirl();
    AnimationGate.enabled = true;
    addTearDown(() => AnimationGate.enabled = false);
    await pumpRoom(tester, settle: false);

    expect(find.byKey(const Key('room-furniture-binh-hoa-pop')), findsNothing);
    await tester.tap(find.byKey(const Key('room-furniture-binh-hoa')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Hoa thơm quá!'), findsOneWidget);
    expect(
      find.byKey(const Key('room-furniture-binh-hoa-pop')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const Key('room-furniture-binh-hoa-pop')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pet đã nở ở Phòng là PNG thật (PR #21)', (tester) async {
    await completeOnboardingGirl();
    await markAllDone();
    await hatchEgg();
    await pumpRoom(tester);

    final petImage = find.descendant(
      of: find.byKey(const Key('room-pet')),
      matching: find.byType(Image),
    );
    expect(petImage, findsOneWidget);
    final provider = tester.widget<Image>(petImage).image;
    expect(provider, isA<AssetImage>());
    expect(
      (provider as AssetImage).assetName,
      'assets/images/pets/dog_newborn.png',
    );
  });

  testWidgets('nhân vật ở Phòng bọc trong CharacterBounce (kiểu game)', (
    tester,
  ) async {
    await completeOnboardingGirl();
    await pumpRoom(tester);

    expect(
      find.ancestor(
        of: find.byKey(const Key('room-character')),
        matching: find.byType(CharacterBounce),
      ),
      findsOneWidget,
    );
  });
}
