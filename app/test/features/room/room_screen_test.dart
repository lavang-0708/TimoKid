/// Widget test cho màn Phòng (T2-04): khóa/mở theo đề ngày, nút
/// Thị trấn / Tủ đồ / Cửa hàng, phản ứng pet và nội thất.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
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
import 'package:timokid/features/room/room_screen.dart';
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
          builder: (context, state) => const RoomScreen(),
        ),
        GoRoute(
          path: TownScreen.route,
          builder: (context, state) => const TownScreen(),
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
    expect(find.text('Đề ngày: 0/5 chặng'), findsOneWidget);
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

    expect(find.byIcon(Icons.lock_outlined), findsNWidgets(2));
    expect(find.byKey(const Key('room-town-button')), findsOneWidget);
    expect(find.text('Xong đề ngày hôm nay!'), findsNothing);
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

  testWidgets('xong đề ngày thì mở: hết banner, Tủ đồ sang màn chờ', (
    tester,
  ) async {
    await completeOnboardingGirl();
    await markAllDone();
    await pumpRoom(tester);

    expect(find.byKey(const Key('room-locked-banner')), findsNothing);
    expect(find.text('Xong đề ngày hôm nay!'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outlined), findsNothing);

    await tester.tap(find.byKey(const Key('room-wardrobe-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('coming-soon-screen')), findsOneWidget);
    expect(
      find.text('Tủ đồ sắp mở ở bản sau nhé! Xong đề ngày là được thay đồ.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('coming-soon-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-screen')), findsOneWidget);
  });

  testWidgets('xong đề ngày thì Cửa hàng sang màn chờ', (tester) async {
    await completeOnboardingGirl();
    await markAllDone();
    await pumpRoom(tester);

    await tester.tap(find.byKey(const Key('room-shop-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('coming-soon-screen')), findsOneWidget);
    expect(
      find.text('Cửa hàng sắp mở ở bản sau nhé! Xong đề ngày là được mua đồ.'),
      findsOneWidget,
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

    expect(find.text('Gâu gâu! Chơi với tớ nhé!'), findsOneWidget);
  });

  testWidgets('chạm nội thất thì hiện bong bóng', (tester) async {
    await completeOnboardingGirl();
    await pumpRoom(tester);

    await tester.tap(find.byKey(const Key('room-furniture-bed')));
    await tester.pump();
    expect(find.text('Giường êm quá, ngủ ngon lắm!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('room-furniture-shelf')));
    await tester.pump();
    expect(find.text('Sách toán hay nhất ở đây!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('room-furniture-lamp')));
    await tester.pump();
    expect(find.text('Đèn sáng rồi, đọc sách thôi!'), findsOneWidget);
  });

  testWidgets('qua ngày mới khóa lại', (tester) async {
    await completeOnboardingGirl();
    await markAllDone();
    await pumpRoom(tester);
    expect(find.byKey(const Key('room-locked-banner')), findsNothing);

    clock.advance(const Duration(days: 1));
    await pumpRoom(tester);

    expect(find.byKey(const Key('room-locked-banner')), findsOneWidget);
    expect(find.text('Đề ngày: 0/5 chặng'), findsOneWidget);
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
    // Ô trứng không còn SVG (nền + nội thất Phòng vẫn là SVG tạm).
    expect(
      find.descendant(
        of: find.byKey(const Key('room-egg')),
        matching: find.byType(SvgPicture),
      ),
      findsNothing,
    );
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
