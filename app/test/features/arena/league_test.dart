/// Test Hạng tuần (spec tuần 23/11, mục B): ranh giới tuần giờ Việt Nam,
/// ngưỡng hạng, rương nhận một lần, không rương khi tuần trước không thi,
/// thẻ hạng ở sảnh và hộp thoại rương.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/arena/arena_lobby_screen.dart';
import 'package:timokid/features/arena/arena_service.dart';
import 'package:timokid/features/arena/league_config.dart';
import 'package:timokid/features/arena/league_service.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late LeagueService league;

  // 2026-11-23 là thứ Hai.
  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 23, 0, 0));
    db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    league = LeagueService(db: db);
  });

  Future<void> attempt(String date, int correct) => db.arenaAttemptsDao.record(
    childId: childId,
    date: date,
    mode: 'heat',
    correctCount: correct,
    score: correct * 4,
    medal: 'participant',
    durationSec: 600,
    gemsAwarded: 0,
  );

  test('tuần bắt đầu thứ Hai, Chủ nhật 23:59 vẫn thuộc tuần cũ', () {
    expect(leagueWeekStart('2026-11-23'), '2026-11-23');
    expect(leagueWeekStart('2026-11-29'), '2026-11-23');
    expect(leagueWeekStart('2026-11-30'), '2026-11-30');
    expect(leagueWeekStart('2026-03-01'), '2026-02-23'); // qua tháng
    expect(leagueAddDays('2026-12-30', 3), '2027-01-02');
    clock.set(DateTime(2026, 11, 29, 23, 59));
    expect(league.currentWeekStart(), '2026-11-23');
    clock.set(DateTime(2026, 11, 30, 0, 0));
    expect(league.currentWeekStart(), '2026-11-30');
  });

  test('số ngày còn lại: thứ Hai 7, Chủ nhật 1', () async {
    expect((await league.week(childId)).daysLeft, 7);
    clock.set(DateTime(2026, 11, 29, 23, 59));
    expect((await league.week(childId)).daysLeft, 1);
  });

  test('ngưỡng hạng', () {
    expect(leagueTierFor(points: 0, attempts: 0), isNull);
    expect(leagueTierFor(points: 0, attempts: 1), LeagueTier.bronze);
    expect(leagueTierFor(points: 39, attempts: 2), LeagueTier.bronze);
    expect(leagueTierFor(points: 40, attempts: 2), LeagueTier.silver);
    expect(leagueTierFor(points: 79, attempts: 4), LeagueTier.silver);
    expect(leagueTierFor(points: 80, attempts: 4), LeagueTier.gold);
    expect(leagueTierFor(points: 119, attempts: 6), LeagueTier.gold);
    expect(leagueTierFor(points: 120, attempts: 6), LeagueTier.diamond);
  });

  test(
    'điểm tuần cộng theo ngày, mỗi ngày tính bài tốt nhất, bỏ tuần khác',
    () async {
      await attempt('2026-11-22', 25); // Chủ nhật tuần trước
      await attempt('2026-11-23', 10);
      await attempt('2026-11-23', 20); // thi lại cùng ngày: chỉ tính 20
      await attempt('2026-11-24', 22);
      await attempt('2026-11-30', 25); // tuần sau
      final w = await league.week(childId);
      expect(w.points, 42);
      expect(w.attempts, 2);
      expect(w.tier, LeagueTier.silver);
      expect(w.nextTier, LeagueTier.gold);
      expect(w.pointsToNext, 38);
      expect(w.progress, closeTo(2 / 40, 1e-9));
    },
  );

  test('rương: không có khi tuần trước không thi', () async {
    await attempt('2026-11-23', 20); // tuần này
    expect(await league.pendingChest(childId), isNull);
    clock.set(DateTime(2026, 11, 30, 8, 0));
    final c = await league.pendingChest(childId);
    expect(c, isNotNull);
    clock.set(DateTime(2026, 12, 7, 8, 0)); // cách 2 tuần
    expect(await league.pendingChest(childId), isNull);
  });

  test('rương: nhận đúng số kim cương theo hạng, chỉ một lần', () async {
    await attempt('2026-11-23', 25);
    await attempt('2026-11-24', 25);
    await attempt('2026-11-25', 25);
    await attempt('2026-11-26', 25); // 100 điểm = Vàng
    clock.set(DateTime(2026, 11, 30, 0, 0)); // thứ Hai tuần sau
    final chest = await league.pendingChest(childId);
    expect(chest!.tier, LeagueTier.gold);
    expect(chest.gems, 7);
    expect(await league.claimChest(childId, weekStart: chest.weekStart), 7);
    expect(await league.claimChest(childId, weekStart: chest.weekStart), 0);
    expect(await league.pendingChest(childId), isNull);
    expect(
      await db.walletDao.balance(childId: childId, currency: Currency.gem),
      7,
    );
    expect(
      await db.settingsDao.getValue(
        childId: childId,
        key: 'arena_week_claimed.2026-11-23',
      ),
      isNotNull,
    );
  });

  test('rương: khóa ví chặn cộng đôi dù thiếu khóa settings', () async {
    await attempt('2026-11-23', 5);
    clock.set(DateTime(2026, 11, 30));
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.gem,
      amount: 2,
      reason: 'arena_week_chest',
      refId: LeagueService.chestRefId(
        childId: childId,
        weekStart: '2026-11-23',
      ),
    );
    expect(await league.claimChest(childId, weekStart: '2026-11-23'), 0);
  });

  test('didArenaToday', () async {
    final arena = ArenaService(db: db);
    expect(await arena.didArenaToday(childId), isFalse);
    await attempt('2026-11-23', 1);
    expect(await arena.didArenaToday(childId), isTrue);
  });

  group('sảnh', () {
    Future<void> pumpLobby(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: ArenaLobbyScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('hiện hạng, tiến độ, ngày còn lại', (tester) async {
      await tester.runAsync(() => attempt('2026-11-23', 20));
      await pumpLobby(tester);
      expect(find.byKey(const Key('league-card')), findsOneWidget);
      expect(find.text('Hạng tuần: Đồng'), findsOneWidget);
      expect(find.textContaining('Còn 20 câu đúng để lên Bạc'), findsOneWidget);
      expect(find.text('Còn 7 ngày trong tuần'), findsOneWidget);
      expect(find.byKey(const Key('league-chest-dialog')), findsNothing);
    });

    testWidgets('rương tuần trước: mở một lần rồi đóng', (tester) async {
      await tester.runAsync(() async {
        await attempt('2026-11-16', 25);
        await attempt('2026-11-17', 25);
        await attempt('2026-11-18', 25); // 75 = Bạc, 4 kim cương
      });
      await pumpLobby(tester);
      expect(find.byKey(const Key('league-chest-dialog')), findsOneWidget);
      expect(find.text('Rương tuần trước: hạng Bạc'), findsOneWidget);
      await tester.tap(find.byKey(const Key('league-chest-open')));
      await tester.pumpAndSettle();
      expect(find.text('+4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('league-chest-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('league-chest-dialog')), findsNothing);
      final gems = await tester.runAsync(
        () => db.walletDao.balance(childId: childId, currency: Currency.gem),
      );
      expect(gems, 4);
    });
  });
}
