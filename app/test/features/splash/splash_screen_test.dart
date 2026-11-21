/// Test widget cho [SplashScreen]: hiện logo rồi tự sang màn kế tiếp.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/animation/animation_gate.dart';
import 'package:timokid/features/splash/splash_screen.dart';

void main() {
  GoRouter router() => GoRouter(
    initialLocation: SplashScreen.route,
    routes: [
      GoRoute(
        path: SplashScreen.route,
        builder: (_, _) => const SplashScreen(next: '/next'),
      ),
      GoRoute(
        path: '/next',
        builder: (_, _) =>
            const Scaffold(body: Text('màn kế', key: Key('next-screen'))),
      ),
    ],
  );

  testWidgets('hiệu ứng bật: hiện logo + thanh tải rồi sang màn kế', (
    tester,
  ) async {
    AnimationGate.enabled = true;
    addTearDown(() => AnimationGate.enabled = false);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router()));
    await tester.pump();

    expect(find.byKey(const Key('splash-title')), findsOneWidget);
    expect(find.byKey(const Key('splash-progress')), findsOneWidget);
    expect(find.byKey(const Key('next-screen')), findsNothing);

    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byKey(const Key('next-screen')), findsNothing);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(find.byKey(const Key('next-screen')), findsOneWidget);
  });

  testWidgets('cổng tắt (test): sang màn kế ngay', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('next-screen')), findsOneWidget);
  });
}
