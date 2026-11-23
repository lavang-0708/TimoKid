/// Widget test: cột tầng ở màn Tòa nhà + màn Kết quả khi leo tầng.
library;

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
import 'package:timokid/features/tower/tower_config.dart';
import 'package:timokid/features/tower/tower_service.dart';
import 'package:timokid/features/town/town_screen.dart';

void main() {
  late AppDatabase db;
  late String childId;
  late String setId;

  setUp(() async {
    db = AppDatabase(
      executor: NativeDatabase.memory(),
      clock: FakeClock(DateTime(2026, 11, 23, 8)),
    );
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    final set = await DailySetService(
      dailySetsDao: db.dailySetsDao,
      reviewQueueDao: db.reviewQueueDao,
      ladderService: LadderService(
        attemptsDao: db.attemptsDao,
        skillProgressDao: db.skillProgressDao,
      ),
      clock: db.clock,
    ).getOrCreateTodaySet(childId: childId);
    setId = set.id;
  });

  Future<void> pumpApp(
    WidgetTester tester,
    String initial, {
    Object? extra,
  }) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/', builder: (_, _) => const TownScreen()),
        GoRoute(
          path: BuildingScreen.route,
          builder: (_, state) =>
              BuildingScreen(args: state.extra as BuildingScreenArgs?),
        ),
        GoRoute(
          path: MathScreen.route,
          builder: (_, state) =>
              MathScreen(args: state.extra as MathScreenArgs?),
        ),
        GoRoute(
          path: StageResultScreen.route,
          builder: (_, state) =>
              StageResultScreen(result: extra as StageResultArgs?),
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

  Future<void> markDailyDone() => db.dailySetsDao.updateStageStatus(
    id: setId,
    stageIndex: 0,
    status: StageStatus.done,
  );

  testWidgets('cột tầng: tầng hiện tại + khóa, boss có huy hiệu', (t) async {
    await pumpApp(t, BuildingScreen.route);
    expect(find.byKey(const Key('building-tower')), findsOneWidget);
    expect(find.byKey(const Key('tower-floor-1')), findsOneWidget);
    expect(find.byKey(const Key('tower-boss-5')), findsOneWidget);
    expect(find.byIcon(Icons.shield), findsWidgets);
    // Chưa xong chặng ngày: nút vẫn là Thử thách.
    expect(find.text('Thử thách'), findsOneWidget);
  });

  testWidgets('đã qua 4 tầng: nút Leo tầng 5, nhắc boss 4/5', (t) async {
    await markDailyDone();
    await db.settingsDao.setValue(
      childId: childId,
      key: TowerConfig.settingsKey('logic'),
      value: '4',
    );
    await pumpApp(t, BuildingScreen.route);
    expect(find.text('Leo tầng 5'), findsOneWidget);
    expect(find.text('Tầng boss: đúng 4/5 câu'), findsOneWidget);
    await t.tap(find.byKey(const Key('building-challenge-button')));
    await t.pumpAndSettle();
    expect(find.text('Boss tầng 5 — Lôgic'), findsOneWidget);
  });

  testWidgets('lên đỉnh: nút khóa', (t) async {
    await markDailyDone();
    await db.settingsDao.setValue(
      childId: childId,
      key: TowerConfig.settingsKey('logic'),
      value: '30',
    );
    await pumpApp(t, BuildingScreen.route);
    expect(find.text('Đã lên đỉnh tháp'), findsOneWidget);
    final button = t.widget<ElevatedButton>(
      find.byKey(const Key('building-challenge-button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('kết quả qua tầng lần đầu: hiện thưởng + nút tầng kế', (t) async {
    final outcome = await TowerService(db: db).recordResult(
      childId: childId,
      strand: 'logic',
      floor: 1,
      firstTryCorrect: 4,
    );
    await pumpApp(
      t,
      StageResultScreen.route,
      extra: StageResultArgs(
        stageIndex: -1,
        strand: 'logic',
        correctCount: 4,
        firstTryCorrectCount: 4,
        totalQuestions: 5,
        xuEarned: 8 + outcome.rewardXu,
        tower: outcome,
      ),
    );
    expect(find.text('Qua tầng 1!'), findsOneWidget);
    expect(find.textContaining('10 xu'), findsWidgets);
    expect(find.byKey(const Key('tower-next-floor-button')), findsOneWidget);
    expect(find.text('Leo tầng 2'), findsOneWidget);
    expect(find.byKey(const Key('tower-retry-button')), findsNothing);
  });

  testWidgets('kết quả trượt tầng: nút Thử lại, vào lại ra câu mới', (t) async {
    final outcome = await TowerService(db: db).recordResult(
      childId: childId,
      strand: 'logic',
      floor: 1,
      firstTryCorrect: 1,
    );
    await pumpApp(
      t,
      StageResultScreen.route,
      extra: StageResultArgs(
        stageIndex: -1,
        strand: 'logic',
        correctCount: 2,
        firstTryCorrectCount: 1,
        totalQuestions: 5,
        xuEarned: 2,
        tower: outcome,
      ),
    );
    expect(find.text('Chưa qua tầng 1'), findsOneWidget);
    expect(find.byKey(const Key('tower-next-floor-button')), findsNothing);
    await t.tap(find.byKey(const Key('tower-retry-button')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('math-screen')), findsOneWidget);
    expect(find.text('Tầng 1 — Lôgic'), findsOneWidget);
  });
}
