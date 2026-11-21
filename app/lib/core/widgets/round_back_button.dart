/// Nút Trở về tròn về Thị trấn (PR (B)); từ góp ý 21/11 là nút tròn
/// nổi khối kiểu game ([GameRoundButton]) có mũi tên, thay nút trắng chữ.
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
import 'game_ui.dart';

class RoundBackButton extends StatelessWidget {
  const RoundBackButton({
    super.key,
    this.onPressed,
    this.size = 56,
    this.tooltip = 'Về Thị trấn',
  });

  /// Bấm thì làm gì; mặc định về Thị trấn.
  final VoidCallback? onPressed;
  final double size;

  /// Chú thích khi giữ nút (đổi khi nút về chỗ khác Thị trấn).
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return GameRoundButton(
      icon: Icons.arrow_back_rounded,
      color: const Color(0xFFFF8FB1),
      image: '$uiArt/ui_btn_back.png',
      size: size,
      tooltip: tooltip,
      onPressed: onPressed ?? () => context.go(TownScreen.route),
    );
  }
}
