/// Màn ăn mừng pet lớn lên (D): lớp phủ toàn màn trong Phòng, pháo giấy
/// vẽ bằng code ([PetConfettiPainter], vì ảnh `ui_celebrate_burst` chưa
/// có), pet cũ phóng to rồi biến thành pet mới, chữ "(tên) đã lớn
/// thành (giai đoạn)!" và nút "Tuyệt vời".
///
/// Hiệu ứng chạy một lần rồi pháo giấy rơi lặp; khi [AnimationGate]
/// tắt (test) thì hiện thẳng trạng thái cuối, không có bộ điều khiển
/// nào chạy để `pumpAndSettle` dừng được.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/animation/animation_gate.dart';
import '../../core/widgets/game_ui.dart';
import '../../core/widgets/press_bounce.dart';
import '../room/pet_growth.dart';
import 'pet_config.dart';

class PetGrowCelebration extends StatefulWidget {
  const PetGrowCelebration({
    super.key,
    required this.species,
    required this.from,
    required this.to,
    required this.onDone,
  });

  final String species;
  final PetStage from;
  final PetStage to;
  final VoidCallback onDone;

  @override
  State<PetGrowCelebration> createState() => _PetGrowCelebrationState();
}

class _PetGrowCelebrationState extends State<PetGrowCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: petConfettiMillis),
  );

  @override
  void initState() {
    super.initState();
    if (AnimationGate.enabled) _ctl.repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Widget _petImage(PetStage stage) => Image.asset(
    petAsset(widget.species, stage),
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => const FittedBox(
      child: Icon(Icons.pets_rounded, color: Color(0xFFB9A3E3)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final name = petDisplayName(widget.species);
    final stageName = petStageNames[widget.to]!;
    return Material(
      key: const Key('pet-celebration'),
      color: const Color(0xCC2A1B4D),
      child: Stack(
        children: [
          // Pháo giấy + tia sáng vẽ tay (Muse lô 13), xoay chậm + phóng
          // nhẹ theo hiệu ứng; dưới lớp hạt vẽ bằng code.
          if (petUiArtReady)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _ctl,
                  builder: (context, child) {
                    final t = AnimationGate.enabled ? _ctl.value : 1.0;
                    return Opacity(
                      opacity: (t * 3).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.85 + 0.25 * t,
                        child: child,
                      ),
                    );
                  },
                  child: Image.asset(
                    petCelebrateBurstAsset,
                    key: const Key('pet-celebration-burst'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _ctl,
                builder: (context, _) => CustomPaint(
                  key: const Key('pet-celebration-confetti'),
                  painter: PetConfettiPainter(
                    progress: AnimationGate.enabled ? _ctl.value : 0.5,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: _GrowPetPicture(
                        old: _petImage(widget.from),
                        grown: _petImage(widget.to),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '$name đã lớn thành $stageName!',
                        key: const Key('pet-celebration-text'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    PressBounce(
                      child: GestureDetector(
                        key: const Key('pet-celebration-ok'),
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onDone,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 160,
                            minHeight: 56,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF7BE0A8), Color(0xFF3FB27A)],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Text('Tuyệt vời', style: gameOutlinedText(22)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pet cũ phóng to rồi mờ đi, pet mới hiện ra từ lớn về cỡ thường (nảy).
/// Cổng animation tắt thì chỉ hiện pet mới.
class _GrowPetPicture extends StatefulWidget {
  const _GrowPetPicture({required this.old, required this.grown});

  final Widget old;
  final Widget grown;

  @override
  State<_GrowPetPicture> createState() => _GrowPetPictureState();
}

class _GrowPetPictureState extends State<_GrowPetPicture>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (AnimationGate.enabled) {
      _ctl.forward();
    } else {
      _ctl.value = 1;
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) {
        final t = _ctl.value;
        // 0–0.5: pet cũ phóng 1 → 1.5 và mờ dần; 0.4–1: pet mới 1.5 → 1.
        final oldScale =
            1 + 0.5 * Curves.easeIn.transform((t / 0.5).clamp(0, 1));
        final oldOpacity = (1 - ((t - 0.3) / 0.25)).clamp(0.0, 1.0);
        final newT = ((t - 0.4) / 0.6).clamp(0.0, 1.0);
        final newScale = 1 + 0.5 * (1 - Curves.elasticOut.transform(newT));
        return Stack(
          fit: StackFit.expand,
          children: [
            if (oldOpacity > 0)
              Opacity(
                opacity: oldOpacity,
                child: Transform.scale(scale: oldScale, child: widget.old),
              ),
            Opacity(
              opacity: newT,
              child: Transform.scale(
                key: const Key('pet-celebration-new'),
                scale: newScale,
                child: widget.grown,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Pháo giấy: [petConfettiCount] mảnh nhỏ rơi + xoay, vị trí/màu sinh
/// theo chỉ số mảnh (không ngẫu nhiên) nên vẽ lại ổn định.
class PetConfettiPainter extends CustomPainter {
  PetConfettiPainter({required this.progress});

  /// 0..1: vị trí trong một vòng rơi.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < petConfettiCount; i++) {
      final rnd = math.Random(i * 7919 + 13);
      final x0 = rnd.nextDouble();
      final speed = 0.6 + rnd.nextDouble() * 0.8;
      final phase = rnd.nextDouble();
      final sway = (rnd.nextDouble() - 0.5) * 0.18;
      final y = ((progress * speed + phase) % 1.0) * (size.height + 40) - 20;
      final x =
          (x0 + sway * math.sin((progress + phase) * math.pi * 4)) * size.width;
      final paint = Paint()
        ..color = Color(petConfettiColors[i % petConfettiColors.length]);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((progress * speed + phase) * math.pi * 6);
      final w = 6.0 + rnd.nextDouble() * 6;
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
  bool shouldRepaint(PetConfettiPainter old) => old.progress != progress;
}
