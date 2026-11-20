/// Test cho PressBounce (PR ưu tiên sau v0.0.3): nhấn xuống thì nút
/// co lại, nhả ra thì về 1.0; cổng tắt thì không có Transform.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/animation/animation_gate.dart';
import 'package:timokid/core/widgets/press_bounce.dart';

void main() {
  // Bật cổng hiệu ứng cho file này (testExecutable đã tắt cho mọi
  // file test); hiệu ứng ở đây một lần rồi dừng nên pumpAndSettle
  // vẫn qua được.
  setUpAll(() => AnimationGate.enabled = true);
  tearDownAll(() => AnimationGate.enabled = false);

  var pressed = false;

  Future<void> pumpButton(WidgetTester tester) async {
    pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PressBounce(
            child: ElevatedButton(
              onPressed: () => pressed = true,
              child: const Text('Bấm'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double scale(WidgetTester tester) {
    final t = tester.widget<Transform>(
      find.byKey(const Key('press-bounce-scale')),
    );
    return t.transform.storage[0];
  }

  testWidgets('nhấn xuống co lại, nhả ra về 1.0, vẫn gọi onPressed', (
    tester,
  ) async {
    await pumpButton(tester);
    expect(scale(tester), 1.0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ElevatedButton)),
    );
    // Bơm một khung để cử chỉ nhấn được xử lý rồi mới cho thời gian
    // chạy (như character_bounce_test).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(scale(tester), lessThan(1.0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scale(tester), 1.0);
    expect(pressed, isTrue);
  });

  testWidgets('cổng tắt: không có Transform co giãn', (tester) async {
    AnimationGate.enabled = false;
    addTearDown(() => AnimationGate.enabled = true);
    await pumpButton(tester);
    expect(find.byKey(const Key('press-bounce-scale')), findsNothing);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(pressed, isTrue);
  });
}
