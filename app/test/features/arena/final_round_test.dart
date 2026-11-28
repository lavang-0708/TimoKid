/// Test vòng Chung kết của Đấu trường (T2-10 bổ sung): ngưỡng huy chương
/// theo 30 câu, luật mở khóa, thưởng một lần mỗi ngày MỖI VÒNG, điểm
/// hạng tuần tính cả bài Chung kết, và widget: thẻ chọn vòng khóa/mở,
/// vào thi Chung kết thấy 30 câu + đồng hồ 120:00, không tràn màn.
library;

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/arena/arena_config.dart';
import 'package:timokid/features/arena/arena_exam.dart';
import 'package:timokid/features/arena/arena_exam_screen.dart';
import 'package:timokid/features/arena/arena_lobby_screen.dart';
import 'package:timokid/features/arena/arena_result_screen.dart';
import 'package:timokid/features/arena/arena_service.dart';
import 'package:timokid/features/arena/arena_session.dart';
import 'package:timokid/features/arena/league_service.dart';

ArenaScore _score(ArenaFormat format, int correct) => ArenaScore(
  correct: correct,
  total: format.totalQuestions,
  sectionCorrect: List.filled(format.sections, 0),
  sectionTotal: format.questionsPerSection,
  points: correct * format.pointsPerQuestion,
  maxPoints: format.maxScore,
  medal: format.medalFor(correct),
);

void main() {
  group('ngưỡng huy chương Chung kết (30 câu)', () {
    test('Vàng từ 25, Bạc từ 19, Đồng từ 13', () {
      const f = ArenaFormat.finalRound;
      expect(f.medalFor(0), ArenaMedal.participant);
      expect(f.medalFor(12), ArenaMedal.participant);
      expect(f.medalFor(13), ArenaMedal.bronze);
      expect(f.medalFor(18), ArenaMedal.bronze);
      expect(f.medalFor(19), ArenaMedal.silver);
      expect(f.medalFor(24), ArenaMedal.silver);
      expect(f.medalFor(25), ArenaMedal.gold);
      expect(f.medalFor(30), ArenaMedal.gold);
    });

    test('tỉ lệ ngưỡng tương đương vòng loại (+-2%)', () {
      for (final (heat, fin) in [
        (ArenaFormat.heat.goldMin, ArenaFormat.finalRound.goldMin),
        (ArenaFormat.heat.silverMin, ArenaFormat.finalRound.silverMin),
        (ArenaFormat.heat.bronzeMin, ArenaFormat.finalRound.bronzeMin),
      ]) {
        expect(fin / 30, closeTo(heat / 25, 0.02));
      }
    });

    test('kim cương Chung kết 8 / 5 / 3 / 2, cao hơn vòng loại', () {
      const f = ArenaFormat.finalRound;
      expect(f.gemsFor(ArenaMedal.gold), 8);
      expect(f.gemsFor(ArenaMedal.silver), 5);
      expect(f.gemsFor(ArenaMedal.bronze), 3);
      expect(f.gemsFor(ArenaMedal.participant), 2);
      for (final m in ArenaMedal.values) {
        expect(f.gemsFor(m), greaterThan(ArenaFormat.heat.gemsFor(m)));
      }
    });

    test('vòng loại giữ nguyên 21 / 16 / 11 và 5 / 3 / 2 / 1', () {
      expect(arenaMedalFor(21), ArenaMedal.gold);
      expect(arenaMedalFor(20), ArenaMedal.silver);
      expect(arenaMedalFor(11), ArenaMedal.bronze);
      expect(ArenaMedal.gold.gems, 5);
      expect(ArenaFormat.fromCode('final'), ArenaFormat.finalRound);
      expect(ArenaFormat.fromCode('heat'), ArenaFormat.heat);
      expect(ArenaFormat.fromCode('lạ'), ArenaFormat.heat);
    });

    test('ArenaSession chấm theo vòng: 30 câu, 5 điểm/câu, 150 điểm', () {
      final s = ArenaSession(
        format: ArenaFormat.finalRound,
        questions: buildArenaExam(
          rungs: {for (final x in Strand.all) x: 2},
          random: Random(4),
          format: ArenaFormat.finalRound,
        ),
      );
      expect(s.total, 30);
      expect(s.score().maxPoints, 150);
      expect(s.score().total, 30);
    });
  });

  group('mở khóa và thưởng', () {
    late FakeClock clock;
    late AppDatabase db;
    late String childId;
    late ArenaService service;

    setUp(() async {
      clock = FakeClock(DateTime(2026, 11, 23, 9, 0)); // thứ Hai
      db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
      addTearDown(db.close);
      childId = await db.ensureSeeded();
      service = ArenaService(db: db);
    });

    Future<ArenaResult> submit(ArenaFormat f, int correct) => service.submit(
      childId: childId,
      score: _score(f, correct),
      duration: const Duration(minutes: 30),
      format: f,
    );

    Future<int> gems() async =>
        (await db.walletDao.balances(childId))[Currency.gem] ?? 0;

    test('chưa thi: Chung kết khóa', () async {
      expect(await service.isFinalUnlocked(childId), isFalse);
      expect((await service.summary(childId)).finalUnlocked, isFalse);
    });

    test('Đồng/Tham gia ở vòng loại chưa mở; Bạc trở lên mở', () async {
      await submit(ArenaFormat.heat, 3);
      await submit(ArenaFormat.heat, 14); // Đồng
      expect(await service.isFinalUnlocked(childId), isFalse);
      await submit(ArenaFormat.heat, 16); // Bạc
      expect(await service.isFinalUnlocked(childId), isTrue);
    });

    test('Vàng vòng loại cũng mở; huy chương Chung kết không tự mở', () async {
      await submit(
        ArenaFormat.finalRound,
        28,
      ); // (giả) bài final, vòng loại chưa
      expect(await service.isFinalUnlocked(childId), isFalse);
      await submit(ArenaFormat.heat, 22);
      expect(await service.isFinalUnlocked(childId), isTrue);
    });

    test('mở rồi thì giữ mở dù ngày sau thi vòng loại kém hơn', () async {
      await submit(ArenaFormat.heat, 17);
      clock.set(DateTime(2026, 11, 24, 9, 0));
      await submit(ArenaFormat.heat, 2);
      expect(await service.isFinalUnlocked(childId), isTrue);
    });

    test('lưu mode final, điểm 5/câu, thưởng theo bảng Chung kết', () async {
      final r = await submit(ArenaFormat.finalRound, 20); // Bạc
      expect(r.gemsAwarded, 5);
      expect(r.format, ArenaFormat.finalRound);
      final row = (await db.arenaAttemptsDao.getAll(childId)).single;
      expect(row.mode, 'final');
      expect(row.correctCount, 20);
      expect(row.score, 100);
      expect(row.medal, 'silver');
      expect(row.gemsAwarded, 5);
      expect(await gems(), 5);
    });

    test('thưởng một lần mỗi ngày MỖI VÒNG', () async {
      expect((await submit(ArenaFormat.heat, 12)).gemsAwarded, 2);
      // Cùng ngày thi Chung kết: vẫn được thưởng riêng của Chung kết.
      expect((await submit(ArenaFormat.finalRound, 26)).gemsAwarded, 8);
      expect(await gems(), 10);
      // Thi lại cả hai vòng trong ngày: không thưởng nữa.
      final again1 = await submit(ArenaFormat.heat, 25);
      final again2 = await submit(ArenaFormat.finalRound, 30);
      expect(again1.gemsAwarded, 0);
      expect(again1.alreadyRewardedToday, isTrue);
      expect(again2.gemsAwarded, 0);
      expect(again2.alreadyRewardedToday, isTrue);
      expect(await gems(), 10);
      final entries = await db.walletDao.getEntries(childId);
      expect(entries.where((e) => e.reason == 'arena_reward'), hasLength(2));
      // Sáng hôm sau thưởng lại.
      clock.set(DateTime(2026, 11, 24, 8, 0));
      expect((await submit(ArenaFormat.finalRound, 13)).gemsAwarded, 3);
    });

    test('summary tách điểm cao nhất và thưởng theo vòng', () async {
      await submit(ArenaFormat.heat, 18);
      await submit(ArenaFormat.finalRound, 22);
      final s = await service.summary(childId);
      expect(s.bestScore, 72);
      expect(s.bestMedal, ArenaMedal.silver);
      expect(s.rewardedToday, isTrue);
      expect(s.finalBestScore, 110);
      expect(s.finalBestCorrect, 22);
      expect(s.finalBestMedal, ArenaMedal.silver);
      expect(s.finalRewardedToday, isTrue);
      expect(s.finalUnlocked, isTrue);
      expect(s.attemptsToday, 2);
    });

    test('hạng tuần: bài Chung kết tính, mỗi ngày lấy bài tốt nhất', () async {
      final league = LeagueService(db: db);
      await submit(ArenaFormat.heat, 20);
      await submit(ArenaFormat.finalRound, 27); // ngày 23: tốt nhất = 27
      clock.set(DateTime(2026, 11, 24, 9, 0));
      await submit(ArenaFormat.heat, 10);
      await submit(ArenaFormat.finalRound, 5); // ngày 24: tốt nhất = 10
      final w = await league.week(childId);
      expect(w.points, 27 + 10);
      expect(w.attempts, 2);
    });
  });

  group('widget', () {
    late FakeClock clock;
    late AppDatabase db;
    late String childId;

    setUp(() async {
      clock = FakeClock(DateTime(2026, 11, 23, 9, 0));
      db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
      addTearDown(db.close);
      childId = await db.ensureSeeded();
    });

    Future<void> pumpApp(
      WidgetTester tester, {
      String initial = ArenaLobbyScreen.route,
      Size size = const Size(800, 360),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(
            path: ArenaLobbyScreen.route,
            builder: (context, state) => const ArenaLobbyScreen(),
          ),
          GoRoute(
            path: ArenaExamScreen.route,
            builder: (context, state) => ArenaExamScreen(
              format: state.extra is ArenaFormat
                  ? state.extra! as ArenaFormat
                  : ArenaFormat.heat,
            ),
          ),
          GoRoute(
            path: ArenaResultScreen.route,
            builder: (context, state) =>
                ArenaResultScreen(result: state.extra as ArenaResult?),
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

    Future<void> unlockFinal() => ArenaService(db: db).submit(
      childId: childId,
      score: _score(ArenaFormat.heat, 17),
      duration: const Duration(minutes: 40),
    );

    testWidgets('thẻ chọn vòng: Chung kết khóa, có ổ khóa và gợi ý', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.byKey(const Key('arena-round-chooser')), findsOneWidget);
      expect(find.text('Vòng loại'), findsOneWidget);
      expect(find.text('Chung kết'), findsOneWidget);
      expect(find.text('25 câu · 90 phút'), findsOneWidget);
      expect(find.text('30 câu · 120 phút'), findsOneWidget);
      expect(find.byKey(const Key('arena-round-final-lock')), findsOneWidget);
      expect(find.text('Cần huy chương Bạc ở Vòng loại.'), findsOneWidget);
      // Chọn Chung kết khi khóa: nút Bắt đầu thi bị vô hiệu.
      await tester.tap(find.byKey(const Key('arena-round-final')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('arena-start-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('arena-lobby-screen')), findsOneWidget);
      expect(find.byKey(const Key('arena-exam-screen')), findsNothing);
    });

    testWidgets('mở khóa sau Bạc: hết ổ khóa, luật Chung kết, thưởng 8/5/3/2', (
      tester,
    ) async {
      await unlockFinal();
      await pumpApp(tester);
      expect(find.byKey(const Key('arena-round-final-lock')), findsNothing);
      await tester.tap(find.byKey(const Key('arena-round-final')));
      await tester.pumpAndSettle();
      expect(find.textContaining('30 câu, chia 5 phần'), findsOneWidget);
      expect(find.textContaining('120 phút, đồng hồ'), findsOneWidget);
      expect(
        find.textContaining('Vàng 8, Bạc 5, Đồng 3, Tham gia 2'),
        findsOneWidget,
      );
      expect(find.text('Bé chưa thi lần nào'), findsOneWidget);
    });

    testWidgets('bắt đầu thi Chung kết: 30 câu, đồng hồ 120:00', (
      tester,
    ) async {
      await unlockFinal();
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('arena-round-final')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('arena-start-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('arena-exam-screen')), findsOneWidget);
      expect(find.text('Câu 1/30'), findsOneWidget);
      expect(find.text('120:00'), findsOneWidget);
      expect(find.text('Phần 1/5 · Tư duy logic'), findsOneWidget);
      for (var i = 0; i < 30; i++) {
        expect(find.byKey(Key('arena-dot-$i-todo')), findsOneWidget);
      }
      expect(find.byKey(const Key('arena-dot-30-todo')), findsNothing);
    });

    testWidgets('vòng loại vẫn 25 câu, 90:00 khi chọn Vòng loại', (
      tester,
    ) async {
      await unlockFinal();
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('arena-round-final')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('arena-round-heat')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('arena-start-button')));
      await tester.pumpAndSettle();
      expect(find.text('Câu 1/25'), findsOneWidget);
      expect(find.text('90:00'), findsOneWidget);
    });

    testWidgets('nộp bài Chung kết lưu mode final, kết quả X/30', (
      tester,
    ) async {
      await unlockFinal();
      await pumpApp(tester, initial: ArenaExamScreen.route);
      // Màn tự dựng đề heat (extra rỗng); nộp trực tiếp bằng service
      // cho kết quả Chung kết rồi dựng màn kết quả.
      final result = await ArenaService(db: db).submit(
        childId: childId,
        score: _score(ArenaFormat.finalRound, 26),
        duration: const Duration(minutes: 90),
        format: ArenaFormat.finalRound,
      );
      final router = GoRouter.of(
        tester.element(find.byKey(const Key('arena-exam-screen'))),
      );
      router.go(ArenaResultScreen.route, extra: result);
      await tester.pumpAndSettle();
      expect(find.text('Đúng 26/30'), findsOneWidget);
      expect(find.text('130/150 điểm'), findsOneWidget);
      expect(find.text('Kết quả Chung kết'), findsOneWidget);
      expect(find.textContaining('Vàng'), findsWidgets);
    });

    for (final size in const [
      Size(608, 248),
      Size(640, 320),
      Size(800, 360),
      Size(1280, 800),
    ]) {
      final tag = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('không tràn $tag: sảnh khóa/mở, thi Chung kết', (
        tester,
      ) async {
        await pumpApp(tester, size: size);
        expect(tester.takeException(), isNull, reason: 'sảnh khóa $tag');
        await tester.tap(find.byKey(const Key('arena-round-final')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'chọn final khóa $tag');

        await unlockFinal();
        await pumpApp(tester, size: size);
        await tester.tap(find.byKey(const Key('arena-round-final')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'sảnh mở $tag');
        await tester.tap(find.byKey(const Key('arena-start-button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'thi final $tag');
        expect(find.text('Câu 1/30'), findsOneWidget);
        final session = find.byKey(const Key('arena-exam-screen'));
        expect(session, findsOneWidget);
        // Lướt qua vài chấm cuối của 30 chấm.
        await tester.tap(find.byKey(const Key('arena-dot-29')));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'câu 30 $tag');
        expect(find.text('Câu 30/30'), findsOneWidget);
      });
    }
  });
}
