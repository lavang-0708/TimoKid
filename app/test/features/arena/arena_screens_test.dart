/// Widget test Đấu trường (T2-10): sảnh, luồng thi (trả lời, chuyển câu,
/// nộp bài có xác nhận), màn kết quả chỉ có số liệu tổng, thưởng kim
/// cương một lần mỗi ngày, hết giờ tự nộp, bỏ thi, lối vào từ Thị trấn.
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
import 'package:timokid/core/database/tables.dart' hide AnswerType;
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/arena/arena_config.dart';
import 'package:timokid/features/arena/arena_exam.dart';
import 'package:timokid/features/arena/arena_exam_screen.dart';
import 'package:timokid/features/arena/arena_lobby_screen.dart';
import 'package:timokid/features/arena/arena_result_screen.dart';
import 'package:timokid/features/arena/arena_service.dart';
import 'package:timokid/features/arena/arena_session.dart';
import 'package:timokid/features/questions/question.dart';
import 'package:timokid/features/town/town_screen.dart';

ArenaSession newSession({int rung = 2, int seed = 3}) => ArenaSession(
  questions: buildArenaExam(
    rungs: {for (final s in Strand.all) s: rung},
    random: Random(seed),
  ),
);

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late GoRouter router;
  late List<ArenaSession> sessions;

  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 22, 9, 0));
    db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    sessions = [];
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
    router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: TownScreen.route,
          builder: (context, state) =>
              const Scaffold(key: Key('fake-town'), body: SizedBox()),
        ),
        GoRoute(
          path: ArenaLobbyScreen.route,
          builder: (context, state) => const ArenaLobbyScreen(),
        ),
        GoRoute(
          path: ArenaExamScreen.route,
          builder: (context, state) => ArenaExamScreen(
            session: sessions.isEmpty ? null : sessions.removeAt(0),
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

  /// Điền đáp án của câu hiện tại theo [correct] (đúng) hoặc sai.
  Future<void> answerCurrent(
    WidgetTester tester,
    ArenaSession session, {
    bool correct = true,
  }) async {
    final q = session.current;
    if (q.displayType == AnswerType.choice) {
      final target = correct
          ? q.correctDisplayIndex
          : (q.correctDisplayIndex + 1) % q.choiceCount;
      await tester.tap(find.byKey(Key('choice-$target')));
    } else {
      final text = correct ? '${q.question.answer}' : '999999';
      for (final d in text.split('')) {
        await tester.tap(find.byKey(Key('keypad-$d')));
        await tester.pump();
      }
    }
    await tester.pump();
  }

  Future<int> gems() async =>
      (await db.walletDao.balances(childId))[Currency.gem]!;

  Future<void> submitFlow(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('arena-submit-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('arena-submit-confirm')));
    await tester.pumpAndSettle();
  }

  group('sảnh', () {
    testWidgets('hiện tên, luật, chưa thi; bấm Bắt đầu thi vào màn thi', (
      tester,
    ) async {
      sessions.add(newSession());
      await pumpApp(tester);
      expect(find.text('Đấu trường TIMO'), findsOneWidget);
      expect(find.byKey(const Key('arena-rules')), findsOneWidget);
      expect(find.textContaining('25 câu'), findsOneWidget);
      expect(find.textContaining('90 phút'), findsOneWidget);
      expect(find.textContaining('Không báo đúng sai'), findsOneWidget);
      expect(
        find.textContaining('Vàng 5, Bạc 3, Đồng 2, Tham gia 1'),
        findsOneWidget,
      );
      expect(find.text('Bé chưa thi lần nào'), findsOneWidget);
      expect(find.textContaining('chưa nhận kim cương'), findsOneWidget);
      expect(find.byKey(const Key('arena-gem-balance')), findsOneWidget);

      await tester.tap(find.byKey(const Key('arena-start-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('arena-exam-screen')), findsOneWidget);
    });

    testWidgets('hiện điểm cao nhất và "đã nhận thưởng" sau bài đầu', (
      tester,
    ) async {
      final s = newSession();
      for (var i = 0; i < 18; i++) {
        s.goTo(i);
        final q = s.current;
        if (q.displayType == AnswerType.choice) {
          s.selectChoice(q.correctDisplayIndex);
        } else {
          for (final d in '${q.question.answer}'.split('')) {
            s.appendDigit(d);
          }
        }
      }
      await ArenaService(db: db).submit(
        childId: childId,
        score: s.score(),
        duration: const Duration(minutes: 45),
      );
      await pumpApp(tester);
      expect(find.text('Điểm cao nhất: 72/100'), findsOneWidget);
      expect(
        find.text('Hôm nay đã nhận thưởng, thi tiếp để luyện tập'),
        findsOneWidget,
      );
      expect(find.text('3'), findsWidgets); // 3 kim cương trên HUD
    });

    testWidgets('nút Trở về về Thị trấn', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('arena-back-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-town')), findsOneWidget);
    });
  });

  group('luồng thi', () {
    testWidgets('đầu màn: Phần 1/5 · Tư duy logic, Câu 1/25, 90:00', (
      tester,
    ) async {
      sessions.add(newSession());
      await pumpApp(tester, initial: ArenaExamScreen.route);
      expect(find.text('Phần 1/5 · Tư duy logic'), findsOneWidget);
      expect(find.text('Câu 1/25'), findsOneWidget);
      expect(find.text('90:00'), findsOneWidget);
      // 25 chấm, chưa chấm nào đặc.
      for (var i = 0; i < 25; i++) {
        expect(find.byKey(Key('arena-dot-$i-todo')), findsOneWidget);
      }
    });

    testWidgets('trả lời, chuyển câu, nhảy qua chấm, tên 5 phần', (
      tester,
    ) async {
      final session = newSession();
      sessions.add(session);
      await pumpApp(tester, initial: ArenaExamScreen.route);

      await answerCurrent(tester, session);
      expect(find.byKey(const Key('arena-dot-0-done')), findsOneWidget);

      await tester.tap(find.byKey(const Key('arena-next-button')));
      await tester.pumpAndSettle();
      expect(find.text('Câu 2/25'), findsOneWidget);
      await tester.tap(find.byKey(const Key('arena-prev-button')));
      await tester.pumpAndSettle();
      expect(find.text('Câu 1/25'), findsOneWidget);

      const titles = [
        'Phần 1/5 · Tư duy logic',
        'Phần 2/5 · Số học',
        'Phần 3/5 · Lý thuyết số',
        'Phần 4/5 · Hình học',
        'Phần 5/5 · Tổ hợp',
      ];
      for (var sec = 0; sec < 5; sec++) {
        await tester.tap(find.byKey(Key('arena-dot-${sec * 5 + 2}')));
        await tester.pumpAndSettle();
        expect(find.text(titles[sec]), findsOneWidget);
        expect(find.text('Câu ${sec * 5 + 3}/25'), findsOneWidget);
      }
      // Câu 7 ở phần 2.
      await tester.tap(find.byKey(const Key('arena-dot-6')));
      await tester.pumpAndSettle();
      expect(find.text('Câu 7/25'), findsOneWidget);
      expect(find.text('Phần 2/5 · Số học'), findsOneWidget);
      // Quay về câu 1: đáp án còn nguyên (đã trả lời), sửa được.
      await tester.tap(find.byKey(const Key('arena-dot-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('arena-dot-0-done')), findsOneWidget);
      if (session.current.displayType == AnswerType.number) {
        await tester.tap(find.byKey(const Key('keypad-delete')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('keypad-clear')));
        await tester.pump();
        expect(find.byKey(const Key('arena-dot-0-todo')), findsOneWidget);
      }
    });

    testWidgets('không có phản hồi đúng/sai, gợi ý hay lời giải', (
      tester,
    ) async {
      final session = newSession();
      sessions.add(session);
      await pumpApp(tester, initial: ArenaExamScreen.route);
      await answerCurrent(tester, session, correct: false);
      for (final text in [
        'Đúng rồi',
        'Gần đúng',
        'Gợi ý',
        'Lời giải',
        'xu',
        'Xem kết quả',
      ]) {
        expect(find.textContaining(text), findsNothing, reason: text);
      }
      await answerCurrent(tester, session);
      expect(find.textContaining('Đúng rồi'), findsNothing);
      expect(find.byKey(const Key('math-hint-banner')), findsNothing);
    });

    testWidgets(
      'nộp bài: hộp xác nhận báo số câu chưa làm; làm tiếp giữ phiên',
      (tester) async {
        final session = newSession();
        sessions.add(session);
        await pumpApp(tester, initial: ArenaExamScreen.route);
        await answerCurrent(tester, session);

        await tester.tap(find.byKey(const Key('arena-submit-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('arena-submit-dialog')), findsOneWidget);
        expect(find.textContaining('còn 24 câu chưa trả lời'), findsOneWidget);

        await tester.tap(find.byKey(const Key('arena-submit-cancel')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('arena-exam-screen')), findsOneWidget);
        expect(find.byKey(const Key('arena-result-screen')), findsNothing);
        expect(await db.arenaAttemptsDao.getAll(childId), isEmpty);
      },
    );

    testWidgets('nộp bài: kết quả chỉ có số liệu tổng, thưởng 1 lần/ngày', (
      tester,
    ) async {
      final first = newSession(seed: 3);
      sessions.add(first);
      await pumpApp(tester, initial: ArenaExamScreen.route);
      // Đúng 3 câu đầu của phần 1, sai câu 4, bỏ trống còn lại.
      for (var i = 0; i < 3; i++) {
        await answerCurrent(tester, first);
        await tester.tap(find.byKey(const Key('arena-next-button')));
        await tester.pumpAndSettle();
      }
      await answerCurrent(tester, first, correct: false);
      await submitFlow(tester);

      expect(find.byKey(const Key('arena-result-screen')), findsOneWidget);
      expect(find.text('Đúng 3/25'), findsOneWidget);
      expect(find.text('12/100 điểm'), findsOneWidget);
      expect(find.text('Logic 3/5'), findsOneWidget);
      expect(find.text('Số học 0/5'), findsOneWidget);
      expect(find.text('Lý thuyết số 0/5'), findsOneWidget);
      expect(find.text('Hình học 0/5'), findsOneWidget);
      expect(find.text('Tổ hợp 0/5'), findsOneWidget);
      expect(find.text('Tham gia'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(await gems(), 1);
      // Không lộ câu hỏi/đáp án/câu nào đúng sai.
      expect(find.byKey(const Key('arena-question-text')), findsNothing);
      expect(find.textContaining('Câu '), findsNothing);
      expect(find.byType(TextField), findsNothing);

      // Bài thứ hai cùng ngày: không thưởng thêm.
      final second = newSession(seed: 4);
      sessions.add(second);
      await tester.tap(find.byKey(const Key('arena-result-retry-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('arena-exam-screen')), findsOneWidget);
      await submitFlow(tester);
      expect(find.text('Đúng 0/25'), findsOneWidget);
      expect(
        find.text('Hôm nay đã nhận thưởng, thi tiếp để luyện tập'),
        findsOneWidget,
      );
      expect(await gems(), 1);
      expect(await db.arenaAttemptsDao.getAll(childId), hasLength(2));

      // Sang ngày mới: thưởng lại.
      clock.set(DateTime(2026, 11, 23, 7, 0));
      sessions.add(newSession(seed: 5));
      await tester.tap(find.byKey(const Key('arena-result-retry-button')));
      await tester.pumpAndSettle();
      await submitFlow(tester);
      expect(find.text('+1'), findsOneWidget);
      expect(await gems(), 2);
    });

    testWidgets('làm đúng cả 25 câu: Vàng, 100 điểm, +5 kim cương', (
      tester,
    ) async {
      final session = newSession();
      sessions.add(session);
      await pumpApp(tester, initial: ArenaExamScreen.route);
      for (var i = 0; i < 25; i++) {
        await answerCurrent(tester, session);
        if (i < 24) {
          await tester.tap(find.byKey(const Key('arena-next-button')));
          await tester.pump();
        }
      }
      await tester.tap(find.byKey(const Key('arena-submit-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('đã trả lời hết 25 câu'), findsOneWidget);
      await tester.tap(find.byKey(const Key('arena-submit-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Đúng 25/25'), findsOneWidget);
      expect(find.text('100/100 điểm'), findsOneWidget);
      expect(find.text('Huy chương Vàng'), findsOneWidget);
      expect(find.text('Logic 5/5'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(await gems(), 5);
    });

    testWidgets('hết giờ tự nộp bài', (tester) async {
      final session = newSession();
      sessions.add(session);
      await pumpApp(tester, initial: ArenaExamScreen.route);
      await answerCurrent(tester, session);
      // Còn 1 giây: chưa nộp.
      clock.advance(const Duration(minutes: 89, seconds: 58));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byKey(const Key('arena-exam-screen')), findsOneWidget);
      // Hết giờ: tự nộp, không hỏi xác nhận.
      clock.advance(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('arena-result-screen')), findsOneWidget);
      expect(find.byKey(const Key('arena-submit-dialog')), findsNothing);
      final rows = await db.arenaAttemptsDao.getAll(childId);
      expect(rows, hasLength(1));
      expect(rows.single.durationSec, 90 * 60);
      expect(rows.single.gemsAwarded, 1);
    });

    testWidgets('đồng hồ đếm ngược theo đồng hồ app', (tester) async {
      final session = newSession();
      sessions.add(session);
      await pumpApp(tester, initial: ArenaExamScreen.route);
      clock.advance(const Duration(minutes: 30, seconds: 5));
      session.goTo(1); // ép vẽ lại
      await tester.pump();
      expect(find.text('59:55'), findsOneWidget);
    });

    testWidgets('bỏ thi: hỏi xác nhận, đồng ý thì không lưu, không thưởng', (
      tester,
    ) async {
      final session = newSession();
      sessions.add(session);
      await pumpApp(tester, initial: ArenaExamScreen.route);
      await answerCurrent(tester, session);

      await tester.tap(find.byKey(const Key('arena-back-button')));
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thi?'), findsOneWidget);
      expect(find.text('Bài sẽ không được tính.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('arena-exit-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('arena-exam-screen')), findsOneWidget);

      // Nút Back của hệ thống cũng hỏi.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thi?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('arena-exit-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('arena-lobby-screen')), findsOneWidget);
      expect(await db.arenaAttemptsDao.getAll(childId), isEmpty);
      expect(await gems(), 0);
    });

    testWidgets(
      'câu choiceOnly hiện 4 nút chọn, đổi được, không màu đúng/sai',
      (tester) async {
        final specs = buildArenaExam(
          rungs: {for (final s in Strand.all) s: 1},
          random: Random(0),
        );
        final session = ArenaSession(
          questions: [
            const DailySetQuestion(
              formId: 'logic.weekday',
              strand: 'logic',
              level: 1,
              rung: 1,
              answerType: 'choice',
              seed: 11,
            ),
            ...specs.skip(1),
          ],
        );
        sessions.add(session);
        await pumpApp(tester, initial: ArenaExamScreen.route);
        for (var i = 0; i < 4; i++) {
          expect(find.byKey(Key('choice-$i')), findsOneWidget);
        }
        await tester.tap(find.byKey(const Key('choice-1')));
        await tester.pump();
        expect(session.selectedAt(0), 1);
        expect(find.byKey(const Key('arena-dot-0-done')), findsOneWidget);
        await tester.tap(find.byKey(const Key('choice-2')));
        await tester.pump();
        expect(session.selectedAt(0), 2);
      },
    );
  });

  group('Thị trấn', () {
    testWidgets('khu Đấu trường và nút tròn đều vào sảnh', (tester) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final r = GoRouter(
        initialLocation: TownScreen.route,
        routes: [
          GoRoute(
            path: TownScreen.route,
            builder: (context, state) => const TownScreen(),
          ),
          GoRoute(
            path: ArenaLobbyScreen.route,
            builder: (context, state) =>
                const Scaffold(key: Key('fake-arena'), body: SizedBox()),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(routerConfig: r),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('town-arena')), findsOneWidget);
      expect(find.byKey(const Key('town-arena-sign')), findsOneWidget);
      expect(find.text('Đấu trường'), findsWidgets);

      await tester.tap(find.byKey(const Key('town-arena-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-arena')), findsOneWidget);

      r.go(TownScreen.route);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('town-arena')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-arena')), findsOneWidget);
      expect(arenaArtReady, isTrue);
    });
  });
}
