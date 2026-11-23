import 'package:material_ui/material_ui.dart';

import '../test_build.dart';

/// Nhãn nhỏ "BẢN THỬ" ở góc màn hình, chỉ hiện khi bản build bật cờ
/// [TestUnlocks.enabled] để phân biệt với bản chính thức. Không chặn
/// chạm.
class TestBuildBadge extends StatelessWidget {
  const TestBuildBadge({super.key});

  @override
  Widget build(BuildContext context) {
    if (!TestUnlocks.enabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: Container(
        key: const Key('test-build-badge'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xCCD32F2F),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'BẢN THỬ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
