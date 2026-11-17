import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../math/math_screen.dart';
import '../stage_result/stage_result_screen.dart';

/// Màn Thị trấn — màn chính của bản 0.1 (màn tạm, T1-12).
/// Bản 0.1 mở app vào thẳng màn này.
class TownScreen extends StatelessWidget {
  const TownScreen({super.key});

  static const String route = '/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('town-screen'),
      appBar: AppBar(title: const Text('Thị trấn Diệu Kỳ')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Chào mừng đến với Thị trấn Diệu Kỳ!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  key: const Key('town-math-button'),
                  onPressed: () => context.go(MathScreen.route),
                  child: const Text('Làm toán'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  key: const Key('town-result-button'),
                  onPressed: () => context.go(StageResultScreen.route),
                  child: const Text('Kết quả chặng'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
