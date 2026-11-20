/// Test widget cho màn Tòa nhà (PR (B)): hiện đúng thống kê theo
/// trạng thái chặng, nút Thử thách đi đúng chặng ngày / chặng tự
/// chọn, nút Trở về tròn về Thị trấn.
library;

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/building/building_screen.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/math/math_screen.dart';
import 'package:timokid/features/stage_result/stage_result_screen.dart';
import 'package:timokid/features/town/town_screen.dart';

import 'play_stage_helper.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late String setId;

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
      random: Random(42),
    );
    final set = await service.getOrCreateTodaySet(childId: childId);
    setId = set.id;
  });

  /// Bơm màn Tòa nhà chặng 0: mở ở `/building` với `extra` null nên
  /// màn mặc định chặng 0 (xem [BuildingScreen._stageIndex]).
  Future<void> pumpBuilding(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: BuildingScreen.route,
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

  Future<void> pumpBuildingAt(WidgetTester tester, int stageIndex) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    router.go(
      BuildingScreen.route,
      extra: BuildingScreenArgs(stageIndex: stageIndex),
    );
    await tester.pumpAndSettle();
  }

  Future<List<DailySetQuestion>> stageQuestions(int stageIndex) async {
    final set = await db.dailySetsDao.getDailySet(childId, clock.today());
    return db.dailySetsDao
        .readQuestions(set!)
        .sublist(stageIndex * 5, (stageIndex + 1) * 5);
  }

  testWidgets('chưa làm: hiện tên khu, trạng thái, bậc, nút Thử thách', (
    tester,
  ) async {
    await pumpBuilding(tester);

    expect(find.byKey(const Key('building-screen')), findsOneWidget);
    expect(find.text('Lâu đài Lôgic'), findsOneWidget);
    expect(find.byKey(const Key('building-status')), findsOneWidget);
    expect(find.text('Chưa làm'), findsOneWidget);
    expect(find.text('0/5'), findsOneWidget);
    expect(find.text('0 xu'), findsOneWidget);
    expect(find.text('Bậc 1/6'), findsOneWidget);
    expect(find.text('Chưa có chặng tự chọn hôm nay'), findsOneWidget);
    expect(find.byKey(const Key('building-challenge-button')), findsOneWidget);
    expect(find.text('Thử thách'), findsOneWidget);
    expect(find.text('Làm chặng hôm nay'), findsOneWidget);
  });

  testWidgets('bấm Thử thách khi chưa xong thì vào chặng ngày', (tester) async {
    await pumpBuilding(tester);

    await tester.tap(find.byKey(const Key('building-challenge-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('math-screen')), findsOneWidget);
    expect(find.text('Chặng 1 — Lôgic'), findsOneWidget);
  });

  testWidgets('chặng đã xong: Thử thách vào chặng tự chọn', (tester) async {
    await db.dailySetsDao.updateStageStatus(
      id: setId,
      stageIndex: 0,
      status: StageStatus.done,
    );
    await pumpBuilding(tester);

    expect(find.text('Xong ✓'), findsOneWidget);
    expect(find.text('Chặng ngày xong, làm chặng tự chọn'), findsOneWidget);

    await tester.tap(find.byKey(const Key('building-challenge-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('math-screen')), findsOneWidget);
    expect(find.text('Chặng tự chọn — Lôgic'), findsOneWidget);
  });

  testWidgets('đang làm: hiện Đúng X/5 + xu, Thử thách vào lại chặng', (
    tester,
  ) async {
    await playStagePartially(
      db: db,
      childId: childId,
      questions: await stageQuestions(0),
      count: 2,
      dailySetId: setId,
      stageIndex: 0,
    );
    await pumpBuilding(tester);

    expect(find.text('Đang làm'), findsOneWidget);
    expect(find.text('2/5'), findsOneWidget);
    expect(find.text('4 xu'), findsOneWidget);

    await tester.tap(find.byKey(const Key('building-challenge-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('math-screen')), findsOneWidget);
    expect(find.text('Chặng 1 — Lôgic'), findsOneWidget);
  });

  testWidgets('chặng tự chọn đã làm hiện số lượng', (tester) async {
    final service = DailySetService(
      dailySetsDao: db.dailySetsDao,
      reviewQueueDao: db.reviewQueueDao,
      ladderService: LadderService(
        attemptsDao: db.attemptsDao,
        skillProgressDao: db.skillProgressDao,
      ),
      clock: clock,
      random: Random(7),
    );
    final extra = await service.buildExtraStage(
      childId: childId,
      strand: 'logic',
    );
    await playStageCorrectly(db: db, childId: childId, questions: extra);
    await pumpBuilding(tester);

    expect(find.text('Tự chọn hôm nay: 1 đã xong'), findsOneWidget);
  });

  testWidgets('nút Trở về tròn về Thị trấn', (tester) async {
    await pumpBuilding(tester);

    await tester.tap(find.byKey(const Key('building-back-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('town-screen')), findsOneWidget);
  });

  testWidgets('mở đúng khu theo chặng (chặng 2: Tháp Con số)', (tester) async {
    await pumpBuildingAt(tester, 2);

    expect(find.byKey(const Key('building-screen')), findsOneWidget);
    expect(find.text('Tháp Con số'), findsOneWidget);

    await tester.tap(find.byKey(const Key('building-challenge-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('math-screen')), findsOneWidget);
    expect(find.text('Chặng 3 — Con số'), findsOneWidget);
  });
}
