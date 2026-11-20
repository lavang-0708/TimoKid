/// Test cho CharacterBounce (PR ưu tiên sau v0.0.3): bấm vào thì
/// nhảy lên + lấp lánh, đổi popKey thì nảy 'pop', cổng tắt thì tĩnh.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/animation/animation_gate.dart';
import 'package:timokid/features/character/character_bounce.dart';

void main() {
  // Bật cổng hiệu ứng cho file này (testExecutable đã tắt cho mọi
  // file test); hiệu ứng ở đây đều một lần rồi dừng nên pumpAndSettle
  // vẫn qua được.
  setUpAll(() => AnimationGate.enabled = true);
  tearDownAll(() => AnimationGate.enabled = false);

  Future<void> pumpBounce(
    WidgetTester tester, {
    Object? popKey,
    bool animationsEnabled = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 150,
            child: CharacterBounce(
              animationsEnabled: animationsEnabled,
              popKey: popKey,
              child: Container(color: Colors.pink),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Độ nhảy theo trục dọc (âm = đang ở trên cao).
  double jumpDy(WidgetTester tester) {
    final t = tester.widget<Transform>(
      find.byKey(const Key('character-bounce-jump')),
    );
    return t.transform.storage[13];
  }

  /// Tỉ lệ nảy 'pop' (1.0 = lúc nghỉ).
  double popScale(WidgetTester tester) {
    final t = tester.widget<Transform>(
      find.byKey(const Key('character-bounce-pop')),
    );
    return t.transform.storage[0];
  }

  testWidgets('bấm vào thì nhảy lên + lấp lánh rồi về', (tester) async {
    await pumpBounce(tester);
    expect(find.byIcon(Icons.star), findsNothing);
    expect(jumpDy(tester), 0);

    await tester.tap(find.byType(CharacterBounce));
    // Bơm một khung để cử chỉ bấm được xử lý (onTap chạy) rồi mới
    // cho thời gian chạy: bơm thẳng 150 ms thì controller mới bắt
    // đầu ở cuối khung nên chưa thấy nhảy.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(jumpDy(tester), lessThan(0));
    expect(find.byIcon(Icons.star), findsWidgets);

    await tester.pumpAndSettle();
    expect(jumpDy(tester), 0);
    expect(find.byIcon(Icons.star), findsNothing);
  });

  testWidgets('đổi popKey thì nảy pop rồi về 1', (tester) async {
    await pumpBounce(tester, popKey: 'hong');
    expect(popScale(tester), 1.0);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 150,
            child: CharacterBounce(
              popKey: 'tim',
              child: Container(color: Colors.pink),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(popScale(tester), greaterThan(1.0));
    await tester.pumpAndSettle();
    expect(popScale(tester), 1.0);
  });

  testWidgets('tắt animation: bấm không nhảy, không có sao', (tester) async {
    await pumpBounce(tester, popKey: 'hong', animationsEnabled: false);
    expect(find.byKey(const Key('character-bounce-jump')), findsNothing);
    expect(find.byKey(const Key('character-bounce-pop')), findsNothing);
    await tester.tap(find.byType(CharacterBounce));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star), findsNothing);
  });

  testWidgets('cổng tắt: không có Transform nhảy/pop', (tester) async {
    AnimationGate.enabled = false;
    addTearDown(() => AnimationGate.enabled = true);
    await pumpBounce(tester);
    expect(find.byKey(const Key('character-bounce-jump')), findsNothing);
    expect(find.byKey(const Key('character-bounce-pop')), findsNothing);
  });
}
