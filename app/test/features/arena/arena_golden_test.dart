/// Golden test Đấu trường (T2-10) ở 800x360: sảnh (đã có điểm cao nhất),
/// màn thi (một câu đã trả lời) và màn kết quả (huy chương Bạc, +3).
/// Nền vẽ bằng code, huy chương là icon cúp (cờ `arenaArtReady` tắt).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/arena/arena_exam.dart';
import 'package:timokid/features/arena/arena_exam_screen.dart';
import 'package:timokid/features/arena/arena_lobby_screen.dart';
import 'package:timokid/features/arena/arena_result_screen.dart';
import 'package:timokid/features/arena/arena_service.dart';
import 'package:timokid/features/arena/arena_session.dart';

import '../../goldens/arena_golden_data.dart';

void _restoreGoldens() {
  const goldens = {
    'test/goldens/arena_lobby_800x360.png': arenaLobbyBase64,
    'test/goldens/arena_exam_800x360.png': arenaExamBase64,
    'test/goldens/arena_result_800x360.png': arenaResultBase64,
  };
  for (final entry in goldens.entries) {
    File(entry.key).writeAsBytesSync(base64Decode(entry.value));
  }
}

Future<void> _loadTestFonts() async {
  final bytes = File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')
      .readAsBytesSync();
  final loader = FontLoader('Nunito')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
  final testerExe = File(Platform.resolvedExecutable);
  final iconsFile = File(
    '${testerExe.parent.parent.parent.parent.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (await iconsFile.exists()) {
    final icons = FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.view(iconsFile.readAsBytesSync().buffer)));
    await icons.load();
  }
}

void main() {
  late AppDatabase db;
  late String childId;

  setUpAll(() async {
    await _loadTestFonts();
    _restoreGoldens();
  });

  setUp(() async {
    db = AppDatabase(
      executor: NativeDatabase.memory(),
      clock: FakeClock(DateTime(2026, 11, 22, 9, 0)),
    );
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: 120,
      reason: 'test',
    );
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.gem,
      amount: 7,
      reason: 'test',
    );
  });

  ArenaSession newSession() => ArenaSession(
    questions: buildArenaExam(
      rungs: {for (final s in Strand.all) s: 2},
      random: Random(3),
    ),
  );

  Future<void> pumpAt(
    WidgetTester tester,
    String initial, {
    ArenaSession? session,
    ArenaResult? result,
  }) async {
    tester.view.physicalSize = const Size(800, 360);
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
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Ảnh dùng trong sảnh (ui_gem, ui_coin, nút Trở về) nạp trước trong
  /// async thật để ảnh chụp có đủ ảnh (cùng lý do như golden Cửa hàng).
  Future<void> precache(WidgetTester tester, Finder screen) async {
    final context = tester.element(screen);
    await tester.runAsync(() async {
      for (final name in const [
        'ui_gem',
        'ui_coin',
        'ui_btn_back',
        'ui_sign_board',
      ]) {
        await precacheImage(AssetImage('assets/images/ui/$name.png'), context);
      }
    });
    await tester.pump();
  }

  testWidgets('Sảnh Đấu trường 800x360', (tester) async {
    final s = newSession();
    for (var i = 0; i < 18; i++) {
      s.goTo(i);
      final q = s.current;
      for (final d in '${q.question.answer}'.split('')) {
        s.appendDigit(d);
      }
      if (q.displayType.name == 'choice') s.selectChoice(q.correctDisplayIndex);
    }
    await ArenaService(db: db).submit(
      childId: childId,
      score: s.score(),
      duration: const Duration(minutes: 50),
    );
    // Hôm sau: có điểm cao nhất, chưa nhận thưởng hôm nay.
    (db.clock as FakeClock).set(DateTime(2026, 11, 23, 9, 0));
    await pumpAt(tester, ArenaLobbyScreen.route);
    await precache(tester, find.byKey(const Key('arena-lobby-screen')));
    await expectLater(
      find.byKey(const Key('arena-lobby-screen')),
      matchesGoldenFile('../../goldens/arena_lobby_800x360.png'),
    );
  });

  testWidgets('Màn thi Đấu trường 800x360', (tester) async {
    final session = newSession();
    await pumpAt(tester, ArenaExamScreen.route, session: session);
    for (var i = 0; i < 7; i++) {
      session.goTo(i);
      final q = session.current;
      for (final d in '${q.question.answer}'.split('')) {
        session.appendDigit(d);
      }
      if (q.displayType.name == 'choice') {
        session.selectChoice(q.correctDisplayIndex);
      }
    }
    session.goTo(6);
    await tester.pumpAndSettle();
    await precache(tester, find.byKey(const Key('arena-exam-screen')));
    await expectLater(
      find.byKey(const Key('arena-exam-screen')),
      matchesGoldenFile('../../goldens/arena_exam_800x360.png'),
    );
  });

  testWidgets('Kết quả Đấu trường 800x360 (Bạc, +3)', (tester) async {
    final s = newSession();
    for (var i = 0; i < 18; i++) {
      s.goTo(i);
      final q = s.current;
      for (final d in '${q.question.answer}'.split('')) {
        s.appendDigit(d);
      }
      if (q.displayType.name == 'choice') s.selectChoice(q.correctDisplayIndex);
    }
    await pumpAt(
      tester,
      ArenaResultScreen.route,
      result: ArenaResult(
        score: s.score(),
        durationSec: 3000,
        gemsAwarded: 3,
        alreadyRewardedToday: false,
      ),
    );
    await precache(tester, find.byKey(const Key('arena-result-screen')));
    await expectLater(
      find.byKey(const Key('arena-result-screen')),
      matchesGoldenFile('../../goldens/arena_result_800x360.png'),
    );
  });
}
