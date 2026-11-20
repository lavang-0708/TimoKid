/// Màn chờ "sắp mở" cho Tủ đồ / Cửa hàng (T2-04).
///
/// Tủ đồ là T2-05, Cửa hàng là T2-06 nên hai nút ở màn Phòng chỉ dẫn
/// tới màn này (chưa có nội dung thật). Khi hai màn đó xong, đổi
/// điều hướng ở màn Phòng sang route thật của chúng.
library;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Tham số màn chờ: tiêu đề + lời nhắn.
class ComingSoonArgs {
  const ComingSoonArgs({required this.title, required this.message});

  final String title;
  final String message;
}

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.args});

  static const String route = '/coming-soon';

  final ComingSoonArgs args;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('coming-soon-screen'),
      appBar: AppBar(title: Text(args.title)),
      // Cuộn dọc khi màn thấp (608x248: chữ + nút cao hơn vùng còn
      // lại sau AppBar ~23 px); đủ chỗ thì căn giữa dọc như trước
      // nhờ ConstrainedBox minHeight = chiều cao vùng nhìn.
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      args.message,
                      key: const Key('coming-soon-message'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      key: const Key('coming-soon-back-button'),
                      onPressed: () => context.pop(),
                      child: const Text('Quay lại phòng'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
