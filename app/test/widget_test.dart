import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/main.dart';

void main() {
  testWidgets('mở app vào thẳng màn Thị trấn', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TimoKidApp()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('town-screen')), findsOneWidget);
    expect(find.text('Thị trấn Diệu Kỳ'), findsOneWidget);
    expect(find.byKey(const Key('town-math-button')), findsOneWidget);
    expect(find.byKey(const Key('town-result-button')), findsOneWidget);
  });

  testWidgets('bấm Làm toán thì sang màn Làm toán, bấm về thì quay lại', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TimoKidApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('town-math-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('math-screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('math-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('town-screen')), findsOneWidget);
  });

  testWidgets('bấm Kết quả chặng thì sang màn Kết quả chặng', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TimoKidApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('town-result-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stage-result-screen')), findsOneWidget);
  });
}
