/// Giao diện cư dân (T4-02): chân dung, bong bóng lời thoại và hàng
/// "cư dân + bong bóng" dùng ở màn Tòa nhà và màn Kết quả chặng.
///
/// Khi [residentArtReady] tắt, chân dung là vòng tròn màu của khu với một
/// biểu tượng vẽ bằng code; bật thì dùng ảnh (thiếu ảnh nào tự về hình vẽ
/// bằng code).
library;

import 'package:material_ui/material_ui.dart';

import '../math/math_decor.dart';
import '../town/town_assets.dart';
import 'resident_config.dart';
import 'resident_content.dart';

/// Màu pastel của khu theo mảng.
Color strandColor(String strand) {
  for (final a in townAreas) {
    if (a.strand == strand) return Color(a.color);
  }
  return const Color(0xFFE0D7F2);
}

/// Màu đậm cùng tông (viền, chữ trên nền pastel của khu).
Color strandInk(String strand) =>
    Color.lerp(strandColor(strand), MathColors.questionText, 0.7)!;

IconData residentIcon(String residentId) => switch (residentId) {
  'hiep_si_sang' => Icons.shield_rounded,
  'co_bong' => Icons.bakery_dining_rounded,
  'cu_tron' => Icons.schedule_rounded,
  'bac_vuong' => Icons.yard_rounded,
  'chu_xoay' => Icons.celebration_rounded,
  _ => Icons.face_rounded,
};

/// Chân dung cư dân.
class ResidentPortrait extends StatelessWidget {
  const ResidentPortrait({
    super.key,
    required this.resident,
    this.size = 64,
    this.talking = false,
  });

  final Resident resident;
  final double size;

  /// Đang nói: dùng dáng nói khi có ảnh.
  final bool talking;

  @override
  Widget build(BuildContext context) {
    final color = strandColor(resident.strand);
    Widget placeholder() => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color.lerp(color, Colors.white, 0.45)!, color],
        ),
        border: Border.all(color: Colors.white, width: size >= 48 ? 3 : 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        residentIcon(resident.id),
        size: size * 0.52,
        color: strandInk(resident.strand),
      ),
    );
    final Widget child;
    if (residentArtReady) {
      child = Image.asset(
        talking
            ? ResidentConfig.talkAsset(resident.id)
            : ResidentConfig.portraitAsset(resident.id),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => placeholder(),
      );
    } else {
      child = placeholder();
    }
    return SizedBox(
      key: Key('resident-portrait-${resident.id}'),
      width: size,
      height: size,
      child: child,
    );
  }
}

/// Bong bóng lời thoại có đuôi nhọn chỉ về bên trái (phía cư dân).
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.text,
    this.borderColor = const Color(0xFFC9B8F0),
    this.fontSize = 15,
  });

  final String text;
  final Color borderColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const padV = 6.0;
        final lineHeight = fontSize * 1.25;
        // Số dòng theo chiều cao có sẵn: chữ dài thì cắt "..." thay vì
        // tràn (màn thấp 608x248).
        final lines = c.hasBoundedHeight
            ? ((c.maxHeight - 2 * padV - 4) / lineHeight).floor().clamp(1, 5)
            : 5;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: padV,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                maxLines: lines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: MathColors.questionText,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 14,
              child: CustomPaint(
                size: const Size(10, 16),
                painter: _BubbleTailPainter(borderColor),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter(this.border);

  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    final line = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(size.width, 1)
        ..lineTo(1, size.height / 2)
        ..lineTo(size.width, size.height - 1),
      line,
    );
  }

  @override
  bool shouldRepaint(_BubbleTailPainter old) => old.border != border;
}

/// Hàng "chân dung + bong bóng". Chiều cao lấy theo vùng cha (nếu có giới
/// hạn); chân dung co theo, tên cư dân chỉ hiện khi đủ cao.
class ResidentSpeech extends StatelessWidget {
  const ResidentSpeech({
    super.key,
    required this.resident,
    required this.text,
    this.bubbleKey,
    this.onTap,
    this.fontSize = 15,
  });

  final Resident resident;

  /// Cỡ chữ trong bong bóng.
  final double fontSize;
  final String text;
  final Key? bubbleKey;

  /// Bé chạm cư dân (nghe câu khác).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.hasBoundedHeight ? c.maxHeight : 80.0;
        final showName = h >= 76;
        final size = (h - (showName ? 18 : 0)).clamp(32.0, 72.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              key: Key('resident-tap-${resident.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: SizedBox(
                width: size + 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ResidentPortrait(
                      resident: resident,
                      size: size,
                      talking: true,
                    ),
                    if (showName)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          resident.name,
                          key: Key('resident-name-${resident.id}'),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: strandInk(resident.strand),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SizedBox(
                key: bubbleKey,
                height: c.hasBoundedHeight ? h : null,
                child: SpeechBubble(
                  text: text,
                  borderColor: strandColor(resident.strand),
                  fontSize: fontSize,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
