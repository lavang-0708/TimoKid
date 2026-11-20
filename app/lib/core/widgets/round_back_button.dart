/// Nút Trở về tròn về Thị trấn (PR (B)).
///
/// Dùng ở mọi màn trong nhà — màn Tòa nhà, Phòng, màn toán — thay cho
/// nút chữ "Thị trấn"/"Về Thị trấn" trước đây: nút tròn trắng 56x56 dp,
/// có bóng, bọc [PressBounce] (nảy nhẹ khi bấm như các nút khác).
///
/// Icon là ký tự chữ '←' thay vì `Icon` vì font MaterialIcons không
/// có trong môi trường test nên golden/widget test sẽ bị ô vuông
/// (cùng lý do màn toán dùng ký tự chữ ở AppBar — xem chú thích ở
/// `math_screen.dart`).
library;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/town/town_screen.dart';
import 'press_bounce.dart';

class RoundBackButton extends StatelessWidget {
  const RoundBackButton({super.key, this.onPressed});

  /// Bấm thì làm gì; mặc định về Thị trấn.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return PressBounce(
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed ?? () => context.go(TownScreen.route),
          child: Tooltip(
            message: 'Về Thị trấn',
            child: const SizedBox(
              width: 56,
              height: 56,
              child: Center(
                child: Text(
                  '←',
                  style: TextStyle(fontSize: 30, color: Color(0xFF3B2E5A)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
