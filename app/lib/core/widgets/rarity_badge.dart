/// Nhãn độ hiếm lấp lánh nhỏ ở góc thẻ trang phục và pet (chủ dự án
/// chốt 24/11): "Hiếm" xanh có 1 sao lấp lánh, "Siêu hiếm" tím-vàng có
/// 3 sao lấp lánh. Món thường không có nhãn.
///
/// Sao lấp lánh lặp vô hạn nên chỉ chạy khi [AnimationGate.enabled]
/// (test tĩnh, `pumpAndSettle` dừng được).
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../features/pet/pet_config.dart';
import '../animation/animation_gate.dart';

class RarityBadge extends StatefulWidget {
  const RarityBadge({
    super.key,
    required this.rarity,
    this.compact = false,
    this.tilted = false,
  });

  /// Độ hiếm; [PetRarity.common] thì không vẽ gì.
  final PetRarity rarity;

  /// Bản nhỏ (chữ ~8–9 px) để đè chéo lên góc khung ảnh.
  final bool compact;

  /// Xoay chéo ~ -14° như nhãn dán ở góc (góp ý 24/11).
  final bool tilted;

  @override
  State<RarityBadge> createState() => _RarityBadgeState();
}

class _RarityBadgeState extends State<RarityBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (AnimationGate.enabled && widget.rarity != PetRarity.common) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rarity == PetRarity.common) return const SizedBox.shrink();
    final epic = widget.rarity == PetRarity.epic;
    final fontSize = widget.compact ? 10.5 : 12.0;
    final colors = epic
        ? const [Color(0xFFB57BFF), Color(0xFFFF8FD8), Color(0xFFFFC93C)]
        : const [Color(0xFF5BB8FF), Color(0xFF8FD8FF)];
    // Vị trí sao (theo tỉ lệ khung nhãn) và lệch pha nhấp nháy.
    final stars = epic
        ? const [(0.06, 0.05, 0.0), (0.93, 0.15, 0.35), (0.55, 0.92, 0.7)]
        : const [(0.92, 0.1, 0.0)];
    final badge = Stack(
      key: Key('rarity-${widget.rarity.name}'),
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 6 : 8,
            vertical: widget.compact ? 1 : 2,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white,
              width: widget.compact ? 1.5 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.55),
                blurRadius: epic ? 8 : 5,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                epic ? Icons.auto_awesome : Icons.star_rounded,
                size: fontSize + 2,
                color: Colors.white,
              ),
              const SizedBox(width: 2),
              Text(
                widget.rarity.label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: const [
                    Shadow(color: Color(0x99000000), blurRadius: 2),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _SparklePainter(
                  t: AnimationGate.enabled ? _c.value : 0.25,
                  stars: stars,
                  size: widget.compact ? 5 : 7,
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return widget.tilted ? Transform.rotate(angle: -0.25, child: badge) : badge;
  }
}

/// Vẽ các sao 4 cánh nhấp nháy quanh nhãn.
class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.t, required this.stars, required this.size});

  final double t;
  final List<(double, double, double)> stars;
  final double size;

  @override
  void paint(Canvas canvas, Size box) {
    final paint = Paint()..color = Colors.white;
    for (final (fx, fy, phase) in stars) {
      final k = math.sin(((t + phase) % 1.0) * math.pi); // 0 → 1 → 0
      if (k < 0.05) continue;
      final r = size * k;
      final c = Offset(fx * box.width, fy * box.height);
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
        ..close();
      paint.color = Colors.white.withValues(alpha: 0.6 + 0.4 * k);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t;
}
