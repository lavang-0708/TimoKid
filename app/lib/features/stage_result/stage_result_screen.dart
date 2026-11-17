import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../town/town_screen.dart';

/// Màn Kết quả chặng — màn trống ở T1-02, làm thật ở T1-09.
class StageResultScreen extends StatelessWidget {
  const StageResultScreen({super.key});

  static const String route = '/stage-result';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('stage-result-screen'),
      appBar: AppBar(title: const Text('Kết quả chặng')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Màn kết quả chặng (trống — làm ở T1-09).'),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('stage-result-back-button'),
              onPressed: () => context.go(TownScreen.route),
              child: const Text('Về Thị trấn'),
            ),
          ],
        ),
      ),
    );
  }
}
