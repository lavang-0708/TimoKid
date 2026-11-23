/// Widget test Nhiệm vụ ngày: nút + chấm đỏ trên HUD Thị trấn và Phòng,
/// bảng nhiệm vụ (3 hàng, nhận xu, thưởng đủ 3, chuỗi + rương), QA menu,
/// không tràn ở màn nhỏ.
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
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/qa/qa_menu_screen.dart';
import 'package:timokid/features/quests/quest_config.dart';
import 'package:timokid/features/quests/quest_service.dart';
import 'package:timokid/features/room/room_screen.dart';
import 'package:timokid/features/tower/tower_service.dart';
import 'package:timokid/features/town/town_screen.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;

  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 24, 8));
    db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    await DailySetService(
      dailySetsDao: db.dailySetsDao,
      reviewQueueDao: db.reviewQueueDao,
      ladderService: LadderService(
        attemptsDao: db.attemptsDao,
        skillProgressDao: db.skillProgressDao,
      ),
      clock: clock,
    ).getOrCreateTodaySet(childId: childId);
  });

  /// Làm xong mọi loại nhiệm vụ không cần pet (bé chưa có pet).
  Future<void> doEverything() async {
    for (final s in Strand.all) {
      for (var i = 0; i < 5; i++) {
        await db.attemptsDao.recordAttempt(
          childId: childId,
          formId: '$s.x',
          strand: s,
          level: 1,
          rung: 1,
          answerType: AnswerType.number,
          correctFirstTry: true,
          attemptsCount: 1,
          durationMs: 1000,
          isReview: i < 2,
        );
      }
    }
    final set = await db.dailySetsDao.getDailySet(childId, clock.today());
    for (var i = 0; i < 5; i++) {
      await db.dailySetsDao.updateStageStatus(
        id: set!.id,
        stageIndex: i,
        status: StageStatus.done,
      );
    }
    await TowerService(db: db).recordResult(
      childId: childId,
      strand: Strand.logic,
      floor: 1,
      firstTryCorrect: 5,
    );
    await db.arenaAttemptsDao.record(
      childId: childId,
      date: clock.today(),
      mode: 'heat',
      correctCount: 5,
      score: 20,
      medal: 'participant',
      durationSec: 600,
      gemsAwarded: 0,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    String route, {
    Size size = const Size(800, 360),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: route,
      routes: [
        GoRoute(
          path: TownScreen.route,
          builder: (context, state) => const TownScreen(),
        ),
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
    await tester.pumpAndSettle();
  }

  for (final hud in [
    ('Thị trấn', TownScreen.route, 'town-quest-button'),
    ('Phòng', RoomScreen.route, 'room-quest-button'),
  ]) {
    group('HUD ${hud.$1}', () {
      testWidgets('có nút nhiệm vụ, chưa có quà thì không chấm đỏ', (
        tester,
      ) async {
        await pump(tester, hud.$2);
        expect(find.byKey(Key(hud.$3)), findsOneWidget);
        expect(find.byKey(const Key('quest-red-dot')), findsNothing);
      });

      testWidgets('có nhiệm vụ xong chưa nhận thì hiện chấm đỏ', (
        tester,
      ) async {
        await doEverything();
        await pump(tester, hud.$2);
        expect(find.byKey(const Key('quest-red-dot')), findsOneWidget);
      });

      testWidgets('mở bảng, nhận hết thì chấm đỏ tắt và số dư đổi', (
        tester,
      ) async {
        await doEverything();
        await pump(tester, hud.$2);
        await tester.tap(find.byKey(Key(hud.$3)));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('quest-board-dialog')), findsOneWidget);
        final list = (await tester.runAsync(
          () => QuestService(db: db).questsFor(childId),
        ))!;
        expect(list.length, 3);
        for (final q in list) {
          expect(find.byKey(Key('quest-row-${q.id}')), findsOneWidget);
          await tester.tap(find.byKey(Key('quest-claim-${q.id}')));
          await tester.pumpAndSettle();
          expect(find.byKey(Key('quest-claim-${q.id}')), findsNothing);
        }
        expect(find.byKey(const Key('quest-claimed')), findsNWidgets(3));
        await tester.tap(find.byKey(const Key('quest-close')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('quest-red-dot')), findsNothing);
        final gems = await tester.runAsync(
          () => db.walletDao.balance(childId: childId, currency: Currency.gem),
        );
        expect(gems, QuestConfig.allClaimedGems);
      });
    });
  }

  testWidgets('bảng: tiến độ, nút khóa khi chưa xong, chuỗi 0', (tester) async {
    await pump(tester, TownScreen.route);
    await tester.tap(find.byKey(const Key('town-quest-button')));
    await tester.pumpAndSettle();
    expect(find.text('Nhiệm vụ hôm nay'), findsOneWidget);
    expect(find.byKey(const Key('quest-streak-count')), findsOneWidget);
    expect(find.text('Chuỗi 0 ngày'), findsOneWidget);
    expect(find.byKey(const Key('quest-bonus-row')), findsOneWidget);
    expect(find.text('Nhận ${QuestConfig.claimXu} xu'), findsNWidgets(3));
    expect(find.text('0/1'), findsWidgets);
    expect(find.byKey(const Key('quest-chest-claim')), findsNothing);
    // Nút nhận chưa bấm được: bấm không đổi gì.
    await tester.tap(find.text('Nhận ${QuestConfig.claimXu} xu').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quest-message')), findsNothing);
  });

  testWidgets('bảng: rương chuỗi hiện và nhận được 5 kim cương', (
    tester,
  ) async {
    // 6 ngày trước đã xong đủ, hôm nay làm nốt → ngày thứ 7.
    final quests = QuestService(db: db);
    final startDay = clock.now();
    for (var d = 6; d >= 1; d--) {
      clock.set(startDay.subtract(Duration(days: d)));
      await DailySetService(
        dailySetsDao: db.dailySetsDao,
        reviewQueueDao: db.reviewQueueDao,
        ladderService: LadderService(
          attemptsDao: db.attemptsDao,
          skillProgressDao: db.skillProgressDao,
        ),
        clock: clock,
      ).getOrCreateTodaySet(childId: childId);
      await quests.questsFor(childId);
      await doEverything();
    }
    clock.set(startDay);
    await doEverything();
    await pump(tester, RoomScreen.route);
    await tester.tap(find.byKey(const Key('room-quest-button')));
    await tester.pumpAndSettle();
    expect(find.text('Chuỗi 7 ngày'), findsOneWidget);
    expect(find.byKey(const Key('quest-chest-claim')), findsOneWidget);
    await tester.tap(find.byKey(const Key('quest-chest-claim')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quest-chest-claim')), findsNothing);
    expect(find.textContaining('Rương chuỗi'), findsOneWidget);
    final gems = await tester.runAsync(
      () => db.walletDao.balance(childId: childId, currency: Currency.gem),
    );
    expect(gems, QuestConfig.streakChestGems);
  });

  for (final size in const [
    Size(608, 248),
    Size(640, 320),
    Size(800, 360),
    Size(1280, 800),
  ]) {
    testWidgets('không tràn: HUD + bảng ở ${size.width}x${size.height}', (
      tester,
    ) async {
      await doEverything();
      await pump(tester, TownScreen.route, size: size);
      await tester.tap(find.byKey(const Key('town-quest-button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('quest-close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('town-room-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('room-quest-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('room-quest-button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('QA menu hiện nhiệm vụ hôm nay và chuỗi', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: QaMenuScreen(db: db)),
      ),
    );
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.byKey(const Key('qa-quest-text')));
    expect(text.data, contains('Mã nhiệm vụ'));
    expect(text.data, contains('Chuỗi 0 ngày'));
  });
}
