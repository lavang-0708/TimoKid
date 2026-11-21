/// Test widget cho [RoundBackButton] (PR (B)): nút tròn 56x56,
/// bấm thì về Thị trấn (mặc định) hoặc gọi `onPressed` riêng.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/widgets/round_back_button.dart';
import 'package:timokid/features/town/town_screen.dart';

void main() {
  testWidgets('bấm nút thì về Thị trấn', (tester) async {
    final router = GoRouter(
      initialLocation: '/trong-nha',
      routes: [
        GoRoute(
          path: TownScreen.route,
          builder: (context, state) =>
              const Scaffold(key: Key('town-screen'), body: Text('Thị trấn')),
        ),
        GoRoute(
          path: '/trong-nha',
          builder: (context, state) =>
              const Scaffold(body: Center(child: RoundBackButton())),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(RoundBackButton));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('town-screen')), findsOneWidget);
  });

  testWidgets('nút tròn, tối thiểu 56x56', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: RoundBackButton())),
      ),
    );
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(RoundBackButton));
    expect(size.width, greaterThanOrEqualTo(56));
    expect(size.height, greaterThanOrEqualTo(56));
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('onPressed riêng thì gọi hàm đó, không về Thị trấn', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: RoundBackButton(onPressed: () => pressed = true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(RoundBackButton));
    await tester.pumpAndSettle();

    expect(pressed, isTrue);
  });
}
