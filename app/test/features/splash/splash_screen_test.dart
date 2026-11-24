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

  testWidgets(
    'khung đầu còn cỡ dọc (máy tính bảng): chỉ phủ màu, chưa đếm giờ',
    (tester) async {
      AnimationGate.enabled = true;
      addTearDown(() => AnimationGate.enabled = false);
      tester.view.physicalSize = const Size(1200, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router()));
      await tester.pump();
      expect(find.byKey(const Key('splash-title')), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const Key('next-screen')), findsNothing);

      // Màn xoay ngang xong: hiện logo rồi đếm 1,8 giây như thường.
      tester.view.physicalSize = const Size(1920, 1200);
      await tester.pump();
      expect(find.byKey(const Key('splash-title')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump();
      expect(find.byKey(const Key('next-screen')), findsOneWidget);
    },
  );

  testWidgets('máy tính bảng ngang: ảnh nền phủ kín cả bề ngang (24/11)', (
    tester,
  ) async {
    AnimationGate.enabled = true;
    addTearDown(() => AnimationGate.enabled = false);
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router()));
    await tester.pump();
    final bg = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).image != null,
    );
    expect(bg, findsOneWidget);
    expect(tester.getSize(bg), const Size(1920, 1200));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  });
}
