/// Hạt hiệu ứng nhẹ vẽ bằng `CustomPainter` (T2-08): pháo giấy bung
/// ([ConfettiBurst]) và vệt sao bay về ví ([StarTrailPainter]).
///
/// Không dùng ảnh, không dùng gói ngoài; số hạt bị chặn trên
/// ([kConfettiMaxParticles], [kStarTrailMaxStars]) để máy yếu không
/// giật. Vị trí/màu mỗi hạt sinh từ chỉ số hạt (`Random` có seed) nên
/// vẽ lại ổn định. [ConfettiBurst] là hiệu ứng MỘT lần (tự dừng, nên
/// `pumpAndSettle` vẫn qua được) và không vẽ gì khi
/// [AnimationGate.enabled] tắt (test/golden).
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../animation/animation_gate.dart';

/// Số mảnh pháo giấy tối đa của một lần bung.
const int kConfettiMaxParticles = 48;

/// Số sao tối đa trong một vệt sao bay.
const int kStarTrailMaxStars = 5;

/// Thời gian một lần bung pháo giấy.
const Duration kConfettiDuration = Duration(milliseconds: 1800);

const List<Color> _confettiColors = [
  Color(0xFFFF6B8A),
  Color(0xFFFFC21A),
  Color(0xFF4CC38A),
  Color(0xFF3E8FD6),
  Color(0xFFA07BE0),
  Color(0xFFF08A3C),
];

/// Pháo giấy bung từ giữa phía trên rồi rơi xuống, phủ kín vùng cha.
/// Đặt trong `Stack` bằng `Positioned.fill`; không chặn cảm ứng.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.count = 40, this.seed = 7});

  /// Số mảnh (bị chặn ở [kConfettiMaxParticles]).
  final int count;

  /// Hạt giống sinh vị trí/màu.
  final int seed;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (AnimationGate.enabled) {
      _controller = AnimationController(
        vsync: this,
        duration: kConfettiDuration,
      )..forward();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: c,
        builder: (context, _) => c.isCompleted
            ? const SizedBox.shrink()
            : CustomPaint(
                key: const Key('confetti-burst'),
                size: Size.infinite,
                painter: ConfettiPainter(
                  progress: c.value,
                  count: math.min(widget.count, kConfettiMaxParticles),
                  seed: widget.seed,
                ),
              ),
      ),
    );
  }
}

/// Vẽ pháo giấy: mỗi mảnh bay theo đường parabol từ điểm bung, xoay,
/// mờ dần ở 30% cuối.
class ConfettiPainter extends CustomPainter {
  ConfettiPainter({
    required this.progress,
    required this.count,
    required this.seed,
  });

  /// 0..1 tiến độ của lần bung.
  final double progress;
  final int count;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.25);
    final t = progress;
    final fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0);
    for (var i = 0; i < count; i++) {
      final rnd = math.Random(seed * 1009 + i * 7919);
      final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 1.3;
      final speed = (0.35 + rnd.nextDouble() * 0.65) * size.width * 0.55;
      final dx = math.cos(angle) * speed * t;
      final dy = math.sin(angle) * speed * t + size.height * 0.9 * t * t;
      final paint = Paint()
        ..color = _confettiColors[i % _confettiColors.length].withValues(
          alpha: fade,
        );
      final w = 6.0 + rnd.nextDouble() * 6;
      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      canvas.rotate(rnd.nextDouble() * math.pi + t * math.pi * (3 + i % 4));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.55),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) =>
      old.progress != progress || old.count != count || old.seed != seed;
}

/// Đường vẽ ngôi sao 5 cánh bán kính [r] tại [c].
Path starPath(Offset c, double r) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final rad = i.isEven ? r : r * 0.45;
    final a = -math.pi / 2 + i * math.pi / 5;
    final p = Offset(c.dx + math.cos(a) * rad, c.dy + math.sin(a) * rad);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}

/// Vệt [stars] ngôi sao bay theo đường cong từ [start] tới [end], mỗi
/// sao trễ nhịp một chút so với sao trước; tới đích thì tắt dần.
class StarTrailPainter extends CustomPainter {
  StarTrailPainter({
    required this.t,
    required this.start,
    required this.end,
    this.stars = kStarTrailMaxStars,
  });

  /// 0..1 tiến độ chung của hiệu ứng.
  final double t;
  final Offset start;
  final Offset end;
  final int stars;

  Offset _bezier(double u) {
    final control = Offset(
      (start.dx + end.dx) / 2 + 40,
      (start.dy + end.dy) / 2 - 70,
    );
    final v = 1 - u;
    return Offset(
      v * v * start.dx + 2 * v * u * control.dx + u * u * end.dx,
      v * v * start.dy + 2 * v * u * control.dy + u * u * end.dy,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = math.min(stars, kStarTrailMaxStars);
    for (var i = 0; i < n; i++) {
      final u = ((t * 1.35) - i * 0.07).clamp(0.0, 1.0);
      if (u <= 0 || u >= 1) continue;
      final pos = _bezier(u);
      final paint = Paint()
        ..color = (i.isEven ? const Color(0xFFFFC21A) : const Color(0xFFFFE36B))
            .withValues(alpha: (1 - u * 0.5));
      canvas.drawPath(starPath(pos, 9 - i * 0.8), paint);
    }
  }

  @override
  bool shouldRepaint(StarTrailPainter old) =>
      old.t != t || old.start != start || old.end != end;
}
