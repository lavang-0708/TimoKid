/// MusicHost (PLAN T2-08): đổi nhạc theo router và lifecycle thật.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/math/math_screen.dart';
import 'package:timokid/features/room/room_screen.dart';
import 'package:timokid/features/sound/music_host.dart';
import 'package:timokid/features/sound/music_service.dart';
import 'package:timokid/features/town/town_screen.dart';

import 'music_service_test.dart' show FakeMusicPlayer;

void main() {
  testWidgets('router + lifecycle điều khiển nhạc', (tester) async {
    final db = AppDatabase(
      executor: NativeDatabase.memory(),
      clock: const SystemClock(),
    );
    addTearDown(db.close);
    await db.ensureSeeded();
    final fake = FakeMusicPlayer();
    final router = GoRouter(
      initialLocation: TownScreen.route,
      routes: [
        for (final p in [TownScreen.route, RoomScreen.route, MathScreen.route])
          GoRoute(path: p, builder: (_, _) => const SizedBox()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          musicPlayerProvider.overrideWithValue(fake),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MusicHost(router: router, child: child!),
        ),
      ),
    );
    // Hàng đợi tương lai của service có fade 500 ms thật: bơm thời gian.
    Future<void> settle() async {
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    await settle();
    expect(fake.actions, ['play:sounds/music_town.ogg']);

    router.go(RoomScreen.route);
    await settle();
    expect(fake.actions.last, 'play:sounds/music_room.ogg');

    router.go(MathScreen.route);
    await settle();
    expect(fake.actions.last, 'pause');

    router.go(RoomScreen.route);
    await settle();
    expect(fake.actions.last, 'resume');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settle();
    expect(fake.actions.last, 'pause');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle();
    expect(fake.actions.last, 'resume');

    // Gỡ widget: không còn nghe router.
    await tester.pumpWidget(const SizedBox());
  });
}
