/// Bộ widget giao diện kiểu game dùng chung (góp ý 21/11 của chủ dự án:
/// bỏ các ô chữ trắng/nút thô, màn Phòng/Thị trấn phủ kín màn hình, chỉ
/// số là một dòng trên cùng như game).
///
/// - [GameCoverFrame]: vẽ cảnh theo khung cố định (1600x900) phủ KÍN màn
///   hình kiểu `BoxFit.cover`, cắt phần thừa theo [alignment]; con nhận
///   đúng kích thước khung đã phóng nên mọi toạ độ khung vẫn đúng.
/// - [GameHudBar], [GameStat]: thanh chỉ số trong mờ + ô chỉ số có icon.
/// - [GameRoundButton]: nút tròn nổi khối (gradient + gờ dưới) có icon,
///   chữ nhỏ bên dưới (tuỳ chọn), nảy khi bấm.
/// - [GameSign]: biển gỗ tên nhà (vẽ bằng code; đổi sang ảnh Muse vẽ khi
///   có `assets/images/ui/ui_sign_board.png`).
///
/// Icon dùng `Icons` của Material (font có trên máy thật; golden test nạp
/// font MaterialIcons khi có).
library;

import 'package:material_ui/material_ui.dart';

import 'press_bounce.dart';

/// Màu chữ đậm dùng chung (tím than như chữ đề).
const Color gameInk = Color(0xFF3B2E5A);

/// Chữ trắng viền tối dễ đọc trên nền ảnh.
TextStyle gameOutlinedText(double size, {Color color = Colors.white}) =>
    TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color,
      shadows: const [
        Shadow(color: Color(0xCC3B2E5A), offset: Offset(0, 1.5), blurRadius: 2),
        Shadow(color: Color(0x993B2E5A), offset: Offset(0, 0), blurRadius: 3),
      ],
    );

/// Vẽ cảnh theo khung [frameSize] phủ kín vùng cha (kiểu cover).
class GameCoverFrame extends StatelessWidget {
  const GameCoverFrame({
    super.key,
    required this.frameSize,
    required this.builder,
    this.alignment = Alignment.center,
  });

  final Size frameSize;

  /// Dựng cảnh với kích thước khung đã phóng (w, h).
  final Widget Function(BuildContext context, double w, double h) builder;

  /// Giữ phần nào khi phải cắt: (0, 1) giữ đáy, (0, -1) giữ đỉnh.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final s =
            (c.maxWidth / frameSize.width) > (c.maxHeight / frameSize.height)
            ? c.maxWidth / frameSize.width
            : c.maxHeight / frameSize.height;
        final w = frameSize.width * s;
        final h = frameSize.height * s;
        final dx = (c.maxWidth - w) * (alignment.x + 1) / 2;
        final dy = (c.maxHeight - h) * (alignment.y + 1) / 2;
        return ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: dx,
                top: dy,
                width: w,
                height: h,
                child: builder(context, w, h),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Thanh chỉ số trong mờ bo tròn ở trên cùng màn hình.
class GameHudBar extends StatelessWidget {
  const GameHudBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC7E63C9), Color(0xCC5B45A3)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x99FFFFFF), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Ô chỉ số: icon trong vòng tròn màu + số chữ trắng viền.
class GameStat extends StatelessWidget {
  const GameStat({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
    this.textKey,
  });

  final IconData icon;
  final Color color;
  final String text;

  /// Khoá của widget chữ (để test đọc số dư).
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.4),
                colors: [Color.lerp(color, Colors.white, 0.45)!, color],
              ),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 4),
          Text(text, key: textKey, style: gameOutlinedText(16)),
        ],
      ),
    );
  }
}

/// Nút tròn nổi khối kiểu game.
class GameRoundButton extends StatelessWidget {
  const GameRoundButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color = const Color(0xFFFF9EB5),
    this.size = 52,
    this.label,
    this.locked = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final double size;

  /// Chữ nhỏ dưới nút (vd "Tủ đồ").
  final String? label;

  /// Đang khoá: xám + ổ khoá nhỏ ở góc.
  final bool locked;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final base = locked ? const Color(0xFFB9B3C6) : color;
    final top = Color.lerp(base, Colors.white, 0.35)!;
    final edge = Color.lerp(base, Colors.black, 0.25)!;
    Widget circle = SizedBox(
      width: size,
      height: size + 4,
      child: Stack(
        children: [
          // Gờ dưới tạo khối 3D.
          Positioned(
            left: 0,
            right: 0,
            top: 4,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: edge),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [top, base],
                ),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: size * 0.52,
                  color: Colors.white,
                  shadows: const [
                    Shadow(color: Color(0x66000000), offset: Offset(0, 1.5)),
                  ],
                ),
              ),
            ),
          ),
          if (locked)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.38,
                height: size * 0.38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF6E6680),
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: size * 0.24,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
    Widget content = circle;
    if (label != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          circle,
          Text(label!, style: gameOutlinedText(12)),
        ],
      );
    }
    content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: content,
    );
    if (tooltip != null) content = Tooltip(message: tooltip!, child: content);
    return PressBounce(child: Semantics(button: true, child: content));
  }
}

/// Biển gỗ tên nhà: tấm gỗ bo tròn + 2 sợi dây treo, chữ trắng viền.
/// [badge] (tuỳ chọn) là nhãn trạng thái nhỏ đính góc dưới biển.
class GameSign extends StatelessWidget {
  const GameSign({
    super.key,
    required this.text,
    this.badge,
    this.badgeColor = const Color(0xFF7FB069),
    this.scale = 1.0,
    this.color = const Color(0xFFC98F5A),
  });

  final String text;
  final String? badge;
  final Color badgeColor;
  final double scale;

  /// Màu gỗ (có thể nhuộm theo màu khu).
  final Color color;

  @override
  Widget build(BuildContext context) {
    final light = Color.lerp(color, Colors.white, 0.30)!;
    final dark = Color.lerp(color, Colors.black, 0.30)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hai sợi dây treo.
        SizedBox(
          height: 8 * scale,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 2 * scale, color: dark),
              SizedBox(width: 48 * scale),
              Container(width: 2 * scale, color: dark),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 10 * scale,
                vertical: 4 * scale,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [light, color],
                ),
                borderRadius: BorderRadius.circular(10 * scale),
                border: Border.all(color: dark, width: 2 * scale),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                text,
                maxLines: 1,
                style: gameOutlinedText(13 * scale),
              ),
            ),
            if (badge != null)
              Positioned(
                right: -6 * scale,
                bottom: -8 * scale,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 5 * scale,
                    vertical: 1 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(8 * scale),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(badge!, style: gameOutlinedText(9 * scale)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
