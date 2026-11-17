import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/main.dart' as app;

/// Integration test đầu tiên: mở app thật trên máy ảo, vào thẳng màn
/// Thị trấn, chụp màn hình. Chạy bằng `flutter drive` (xem workflow
/// integration-test.yml và test_driver/integration_test.dart).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mở app vào thẳng màn Thị trấn', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('town-screen')), findsOneWidget);
    expect(find.text('Thị trấn Diệu Kỳ'), findsOneWidget);

    // Trên Android phải convert surface trước rồi mới chụp được.
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    final bytes = await binding.takeScreenshot('town');
    expect(bytes.isNotEmpty, isTrue);
  });
}
