/// Widget test cho màn Thị trấn (T1-12): 5 nút khu, trạng thái chặng,
/// thanh tiến độ đề ngày, số dư xu/kim cương, điều hướng vào chặng.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/building/building_screen.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/math/math_screen.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/room/room_screen.dart';
import 'package:timokid/features/stage_result/stage_result_screen.dart';
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

  Future<void> pumpTown(
    WidgetTester tester, {
    Size size = const Size(800, 360),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Router mới mỗi test (không dùng router tĩnh của app để trạng
    // thái điều hướng không rò sang test khác), cùng 5 route như app.
    final router = GoRouter(
      initialLocation: TownScreen.route,
      routes: [
        GoRoute(
          path: TownScreen.route,
          builder: (context, state) => const TownScreen(),
        ),
        GoRoute(
          path: BuildingScreen.route,
          builder: (context, state) =>
              BuildingScreen(args: state.extra as BuildingScreenArgs?),
        ),
        GoRoute(
          path: MathScreen.route,
          builder: (context, state) =>
              MathScreen(args: state.extra as MathScreenArgs?),
        ),
        GoRoute(
          path: RoomScreen.route,
          builder: (context, state) => const RoomScreen(),
        ),
        GoRoute(
          path: StageResultScreen.route,
          builder: (context, state) =>
              StageResultScreen(result: state.extra as StageResultArgs?),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> setStatuses(List<String> statuses) async {
    for (var i = 0; i < statuses.length; i++) {
      await db.dailySetsDao.updateStageStatus(
        id: setId,
        stageIndex: i,
        status: statuses[i],
      );
    }
  }

  testWidgets('đề mới: 5 nút khu đều chưa làm, tiến độ 0/5, số dư 0', (
    tester,
  ) async {
    await pumpTown(tester);

    expect(find.byKey(const Key('town-screen')), findsOneWidget);
    for (final name in [
      'Lâu đài Lôgic',
      'Tiệm bánh Số học',
      'Tháp Con số',
      'Vườn Hình học',
      'Hội chợ Tổ hợp',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Đang làm'), findsNothing);
    expect(find.text('Xong ✓'), findsNothing);
    expect(find.text('0/5'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('town-xu-balance'))).data,
      '0',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('town-gem-balance'))).data,
      '0',
    );
    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('town-progress-bar')),
    );
    expect(bar.value, 0);
  });

  testWidgets('trạng thái đang làm/xong và thanh tiến độ 2/5', (tester) async {
    await setStatuses([
      StageStatus.done,
      StageStatus.inProgress,
      StageStatus.notStarted,
      StageStatus.done,
      StageStatus.notStarted,
    ]);
    await pumpTown(tester);

    expect(find.text('Xong ✓'), findsNWidgets(2));
    expect(find.text('Đang làm'), findsOneWidget);
    expect(find.text('2/5'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('town-progress-bar')),
    );
    expect(bar.value, closeTo(0.4, 0.001));
  });

  testWidgets('số dư xu và kim cương đọc từ wallet_ledger', (tester) async {
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: 120,
      reason: 'test',
    );
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.gem,
      amount: 1,
      reason: 'test',
    );
    await pumpTown(tester);

    expect(
      tester.widget<Text>(find.byKey(const Key('town-xu-balance'))).data,
      '120',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('town-gem-balance'))).data,
      '1',
    );
  });

  testWidgets('bấm nút khu thì sang màn tòa nhà rồi làm toán đúng chặng', (
    tester,
  ) async {
    await pumpTown(tester);

    await tester.tap(find.byKey(const Key('town-stage-2-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('building-screen')), findsOneWidget);
    expect(find.text('Tháp Con số'), findsOneWidget);

    await tester.tap(find.byKey(const Key('building-challenge-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('math-screen')), findsOneWidget);
    expect(find.text('Chặng 3 — Con số'), findsOneWidget);
  });

  testWidgets('bấm nhà hồng thì về Phòng', (tester) async {
    await pumpTown(tester);

    await tester.tap(find.byKey(const Key('town-room-house-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('room-screen')), findsOneWidget);
  });

  testWidgets('xong cả 5 chặng thì hiện đã xong đề ngày', (tester) async {
    await setStatuses(List.filled(5, StageStatus.done));
    await pumpTown(tester);

    expect(find.text('5/5'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('town-progress-bar')),
    );
    expect(bar.value, 1);
  });

  testWidgets('vào chặng rồi về thì nút khu hiện Đang làm', (tester) async {
    await pumpTown(tester);

    await tester.tap(find.byKey(const Key('town-stage-0-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('building-screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('building-challenge-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('math-screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('math-back-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('town-screen')), findsOneWidget);
    expect(find.text('Đang làm'), findsOneWidget);
    expect(find.text('0/5'), findsOneWidget);
  });

  testWidgets('bố cục vừa ở 640x320', (tester) async {
    await setStatuses([
      StageStatus.done,
      StageStatus.inProgress,
      StageStatus.notStarted,
      StageStatus.notStarted,
      StageStatus.notStarted,
    ]);
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: 45,
      reason: 'test',
    );
    await pumpTown(tester, size: const Size(640, 320));

    expect(find.byKey(const Key('town-screen')), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(Key('town-stage-$i-button')), findsOneWidget);
    }
    expect(
      tester.widget<Text>(find.byKey(const Key('town-xu-balance'))).data,
      '45',
    );
  });

  testWidgets('chưa có hồ sơ thì không hiện nhân vật', (tester) async {
    await pumpTown(tester);

    expect(find.byKey(const Key('town-character')), findsNothing);
    expect(find.byKey(const Key('town-character-name')), findsNothing);
  });

  testWidgets('đã tạo nhân vật nữ thì hiện tên trên thanh chỉ số (640x320)', (
    tester,
  ) async {
    await OnboardingService(db: db).completeOnboarding(
      childId: childId,
      profile: CharacterProfile.defaults().copyWith(
        hairColor: 0xFFA9715C,
        dress: 'girl_top_02',
        name: 'An',
      ),
      eggSpecies: 'dog',
    );
    await pumpTown(tester, size: const Size(640, 320));

    // Thị trấn toàn màn: không còn nhân vật cạnh bản đồ, chỉ tên
    // trên thanh chỉ số.
    expect(find.byKey(const Key('town-character')), findsNothing);
    expect(find.byKey(const Key('town-character-name')), findsOneWidget);
    expect(find.text('An'), findsOneWidget);
  });

  testWidgets('đã tạo nhân vật nam thì hiện tên, không có ảnh cạnh bản đồ', (
    tester,
  ) async {
    await OnboardingService(db: db).completeOnboarding(
      childId: childId,
      profile: CharacterProfile.defaults().copyWith(
        gender: 'boy',
        name: 'Bình',
      ),
      eggSpecies: 'cat',
    );
    await pumpTown(tester);

    expect(find.byKey(const Key('town-character')), findsNothing);
    expect(find.text('Bình'), findsOneWidget);
  });
}
