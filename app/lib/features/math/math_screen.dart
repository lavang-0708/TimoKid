import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../town/town_screen.dart';

/// Màn Làm toán — màn trống ở T1-02, làm thật ở T1-09.
class MathScreen extends StatelessWidget {
  const MathScreen({super.key});

  static const String route = '/math';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('math-screen'),
      appBar: AppBar(title: const Text('Làm toán')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Màn làm toán (trống — làm ở T1-09).'),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('math-back-button'),
              onPressed: () => context.go(TownScreen.route),
              child: const Text('Về Thị trấn'),
            ),
          ],
        ),
      ),
    );
  }
}
