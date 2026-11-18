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
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/math/math_screen.dart';
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
    // thái điều hướng không rò sang test khác), cùng 3 route như app.
    final router = GoRouter(
      initialLocation: TownScreen.route,
      routes: [
        GoRoute(
          path: TownScreen.route,
          builder: (context, state) => const TownScreen(),
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
    expect(find.text('Thị trấn Diệu Kỳ'), findsOneWidget);
    for (final name in [
      'Lâu đài Lôgic',
      'Tiệm bánh Số học',
      'Tháp Con số',
      'Vườn Hình học',
      'Hội chợ Tổ hợp',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Chưa làm'), findsNWidgets(5));
    expect(find.text('Đề ngày: 0/5 chặng'), findsOneWidget);
    expect(find.text('0 xu'), findsOneWidget);
    expect(find.text('◆ 0'), findsOneWidget);
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
    expect(find.text('Chưa làm'), findsNWidgets(2));
    expect(find.text('Đề ngày: 2/5 chặng'), findsOneWidget);
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

    expect(find.text('120 xu'), findsOneWidget);
    expect(find.text('◆ 1'), findsOneWidget);
  });

  testWidgets('bấm nút khu thì sang màn làm toán đúng chặng', (tester) async {
    await pumpTown(tester);

    await tester.tap(find.byKey(const Key('town-stage-2-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('math-screen')), findsOneWidget);
    expect(find.text('Chặng 3 — Con số'), findsOneWidget);
  });

  testWidgets('xong cả 5 chặng thì hiện đã xong đề ngày', (tester) async {
    await setStatuses(List.filled(5, StageStatus.done));
    await pumpTown(tester);

    expect(find.text('Xong đề ngày hôm nay!'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('town-progress-bar')),
    );
    expect(bar.value, 1);
  });

  testWidgets('vào chặng rồi về thì nút khu hiện Đang làm', (tester) async {
    await pumpTown(tester);

    await tester.tap(find.byKey(const Key('town-stage-0-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('math-screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('math-back-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('town-screen')), findsOneWidget);
    expect(find.text('Đang làm'), findsOneWidget);
    expect(find.text('Đề ngày: 0/5 chặng'), findsOneWidget);
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
    expect(find.text('45 xu'), findsOneWidget);
  });
}
