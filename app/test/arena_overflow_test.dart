/// Hồi quy tràn màn của Đấu trường (T2-10) ở 608x248, 640x320, 800x360
/// và 1280x800: sảnh, màn thi (điền số, trắc nghiệm, câu có hình, hộp
/// xác nhận nộp bài/bỏ thi), màn kết quả (có và không có thưởng) và
/// Thị trấn với nút Đấu trường (mẫu `overflow_608x248_test.dart`).
/// Font test rộng hơn Nunito thật nên test này khắt khe hơn máy thật.
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
import 'package:timokid/features/arena/arena_exam.dart';
import 'package:timokid/features/arena/arena_exam_screen.dart';
import 'package:timokid/features/arena/arena_lobby_screen.dart';
import 'package:timokid/features/arena/arena_result_screen.dart';
import 'package:timokid/features/arena/arena_service.dart';
import 'package:timokid/features/arena/arena_session.dart';
import 'package:timokid/features/questions/question.dart';
import 'package:timokid/features/town/town_screen.dart';

const _sizes = <Size>[
  Size(608, 248),
  Size(640, 320),
  Size(800, 360),
  Size(1280, 800),
];

void _check(WidgetTester tester, String step) {
  final err = tester.takeException();
  expect(err, isNull, reason: 'tràn/lỗi ở $step: $err');
}

ArenaSession _session(int seed) => ArenaSession(
  questions: buildArenaExam(
    rungs: {for (final s in Strand.all) s: 4},
    random: Random(seed),
  ),
);

void main() {
  late FakeClock clock;
  late AppDatabase db;

  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 22, 9, 0));
    db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
    addTearDown(db.close);
    await db.ensureSeeded();
  });

  Future<void> pump(
    WidgetTester tester,
    Size size,
    String initial, {
    ArenaSession? session,
    ArenaResult? result,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: TownScreen.route,
          builder: (context, state) => const TownScreen(),
        ),
        GoRoute(
          path: ArenaLobbyScreen.route,
          builder: (context, state) => const ArenaLobbyScreen(),
        ),
        GoRoute(
          path: ArenaExamScreen.route,
          builder: (context, state) => ArenaExamScreen(session: session),
        ),
        GoRoute(
          path: ArenaResultScreen.route,
          builder: (context, state) => ArenaResultScreen(result: result),
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

  for (final size in _sizes) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('sảnh $tag (chưa thi và đã thi)', (tester) async {
      await pump(tester, size, ArenaLobbyScreen.route);
      _check(tester, 'sảnh chưa thi');
      expect(find.byKey(const Key('arena-start-button')), findsOneWidget);
      await ArenaService(db: db).submit(
        childId: (await db.childrenDao.getFirstChild())!.id,
        score: (_session(1)..goTo(0)).score(),
        duration: const Duration(minutes: 3),
      );
      await pump(tester, size, ArenaLobbyScreen.route);
      _check(tester, 'sảnh đã thi');
      expect(find.byKey(const Key('arena-today-status')), findsOneWidget);
    });

    testWidgets('màn thi $tag: điền số, 6 chữ số, hình, mọi phần', (
      tester,
    ) async {
      final session = _session(2);
      await pump(tester, size, ArenaExamScreen.route, session: session);
      _check(tester, 'màn thi câu 1');
      for (var i = 0; i < session.total; i++) {
        session.goTo(i);
        await tester.pump();
        _check(tester, 'câu ${i + 1}');
        if (session.current.displayType == AnswerType.number && i % 4 == 0) {
          for (var d = 0; d < 6; d++) {
            session.appendDigit('${(d + 5) % 10}');
          }
          await tester.pump();
          _check(tester, 'câu ${i + 1} gõ 6 chữ số');
        }
      }
      // Có ít nhất một câu có hình trong đề: đã duyệt qua ở trên.
      expect(
        session.resolved.any((q) => q.question.figure != null),
        isTrue,
        reason: 'đề mẫu cần có câu hình để kiểm tràn',
      );
    });

    testWidgets('màn thi $tag: câu trắc nghiệm choiceOnly', (tester) async {
      final base = _session(3);
      final specs = [
        const DailySetQuestion(
          formId: 'logic.weekday',
          strand: 'logic',
          level: 1,
          rung: 1,
          answerType: 'choice',
          seed: 21,
        ),
        for (var i = 1; i < 25; i++)
          DailySetQuestion(
            formId: base.resolved[i].spec.formId,
            strand: base.resolved[i].spec.strand,
            level: base.resolved[i].spec.level,
            rung: base.resolved[i].spec.rung,
            answerType: base.resolved[i].spec.answerType,
            seed: base.resolved[i].spec.seed,
          ),
      ];
      final session = ArenaSession(questions: specs);
      await pump(tester, size, ArenaExamScreen.route, session: session);
      _check(tester, 'trắc nghiệm');
      await tester.tap(find.byKey(const Key('choice-3')));
      await tester.pump();
      _check(tester, 'trắc nghiệm đã chọn');
    });

    testWidgets('màn thi $tag: hộp nộp bài và hộp bỏ thi', (tester) async {
      final session = _session(4);
      await pump(tester, size, ArenaExamScreen.route, session: session);
      await tester.tap(find.byKey(const Key('arena-submit-button')));
      await tester.pumpAndSettle();
      _check(tester, 'hộp nộp bài');
      await tester.tap(find.byKey(const Key('arena-submit-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('arena-back-button')));
      await tester.pumpAndSettle();
      _check(tester, 'hộp bỏ thi');
      expect(find.text('Bỏ thi?'), findsOneWidget);
    });

    testWidgets('kết quả $tag: có thưởng và không thưởng', (tester) async {
      final perfect = _session(5);
      for (var i = 0; i < 25; i++) {
        perfect.goTo(i);
        final q = perfect.current;
        for (final d in '${q.question.answer}'.split('')) {
          perfect.appendDigit(d);
        }
        if (q.displayType == AnswerType.choice) {
          perfect.selectChoice(q.correctDisplayIndex);
        }
      }
      for (final awarded in [5, 0]) {
        await pump(
          tester,
          size,
          ArenaResultScreen.route,
          result: ArenaResult(
            score: perfect.score(),
            durationSec: 4000,
            gemsAwarded: awarded,
            alreadyRewardedToday: awarded == 0,
          ),
        );
        _check(tester, 'kết quả thưởng $awarded');
        expect(find.byKey(const Key('arena-result-reward')), findsOneWidget);
      }
      await pump(tester, size, ArenaResultScreen.route);
      _check(tester, 'kết quả rỗng');
    });

    testWidgets('Thị trấn $tag có nút và khu Đấu trường', (tester) async {
      await pump(tester, size, TownScreen.route);
      _check(tester, 'Thị trấn');
      expect(find.byKey(const Key('town-arena-button')), findsOneWidget);
      expect(find.byKey(const Key('town-arena')), findsOneWidget);
    });
  }
}
