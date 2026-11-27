/// Dụng cụ chung cho widget test đồng bộ/đăng nhập/thư: DB trong bộ nhớ,
/// Neon giả và kho phiên trong bộ nhớ, bơm một GoRouter tùy ý.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/sync/session_store.dart';
import 'package:timokid/core/sync/sync_providers.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/core/time/clock.dart';

import '../core/sync/fake_neon.dart';

class SyncHarness {
  SyncHarness() {
    db = AppDatabase(
      executor: NativeDatabase.memory(),
      clock: FakeClock(DateTime.utc(2026, 11, 28, 15)),
    );
  }

  late final AppDatabase db;
  final FakeNeon neon = FakeNeon();
  final MemorySessionStore store = MemorySessionStore();

  /// Đặt như đã đăng nhập (có cookie phiên).
  void signIn() {
    store.data['auth_cookie'] = 'neon-auth.session_token=abc123';
    store.data['auth_email'] = 'bo@example.com';
  }

  Future<ProviderContainer> pump(
    WidgetTester tester,
    GoRouter router, {
    Size size = const Size(800, 360),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        httpClientProvider.overrideWithValue(neon.client),
        sessionStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }
}

/// Màn giữ chỗ cho route đích.
GoRoute stubRoute(String path, [String key = 'stub']) => GoRoute(
  path: path,
  builder: (context, state) =>
      Scaffold(key: Key('$key$path'), body: Text(path)),
);

/// Router một màn gốc dựng bằng [build] (để lấy BuildContext mở hộp thoại).
GoRouter goRouterFor(Widget Function(BuildContext) build) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => Scaffold(body: Builder(builder: build)),
    ),
  ],
);
