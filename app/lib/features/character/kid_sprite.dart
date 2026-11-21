/// Nhân vật toàn thân (E): một ảnh PNG đủ người cho mỗi bộ đồ, thay
/// cho cách chồng lớp cũ ([CharacterView]) vốn vỡ hình khi cắt lớp.
///
/// - Thở: co giãn nhẹ quanh chân (chân không rời đất).
/// - Chớp mắt: hiện miếng vá mắt nhắm ~0,25 giây mỗi ~3,6 giây.
/// - Vẫy tay: [waving] = true thì đổi sang ảnh vẫy của cùng bộ.
/// - Đi bộ: [walking] = true thì nhún bước (nảy + nghiêng nhẹ) đến khi
///   có khung đi bộ của Muse (lô 4) thì thay bằng khung thật.
/// - Hướng: [facingLeft] lật ngang ảnh.
///
/// Cổng [AnimationGate] tắt mọi hiệu ứng lặp khi chạy test để
/// `pumpAndSettle` dừng được và ảnh golden xác định.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/animation/animation_gate.dart';
import 'kid_assets.dart';

class KidSprite extends StatefulWidget {
  const KidSprite({
    super.key,
    required this.gender,
    required this.outfit,
    this.headAccessory,
    this.waving = false,
    this.walking = false,
    this.facingLeft = false,
    this.animationsEnabled = true,
    this.width,
  });

  /// `girl` hoặc `boy`.
  final String gender;

  /// Bộ đồ 1–3.
  final int outfit;

  /// Phụ kiện đầu: `hat`, `bow` hoặc null.
  final String? headAccessory;

  final bool waving;
  final bool walking;
  final bool facingLeft;
  final bool animationsEnabled;

  /// Bề ngang khung (null = theo cha). Cao = ngang × 1536/1024.
  final double? width;

  @override
  State<KidSprite> createState() => _KidSpriteState();
}

class _KidSpriteState extends State<KidSprite> with TickerProviderStateMixin {
  AnimationController? _breath;
  AnimationController? _blink;
  AnimationController? _step;

  bool get _on => widget.animationsEnabled && AnimationGate.enabled;

  @override
  void initState() {
    super.initState();
    if (!_on) return;
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
    _step = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    if (widget.walking) _step!.repeat();
  }

  @override
  void didUpdateWidget(KidSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    final step = _step;
    if (step == null) return;
    if (widget.walking && !step.isAnimating) {
      step.repeat();
    } else if (!widget.walking && step.isAnimating) {
      step.stop();
      step.value = 0;
    }
  }

  @override
  void dispose() {
    _breath?.dispose();
    _blink?.dispose();
    _step?.dispose();
    super.dispose();
  }

  Widget _frameImage(String asset, Key key) => Image.asset(
    asset,
    key: key,
    fit: BoxFit.fill,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );

  @override
  Widget build(BuildContext context) {
    final gender = kidGender(widget.gender);
    final outfit = widget.outfit.clamp(1, 3);
    final wave = widget.waving;
    final patch = kidEyePatch(gender, outfit, wave: wave);
    final accessory = kidHeadAccessoryAsset(gender, widget.headAccessory);

    Widget body = LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = w * kidFrameHeight / kidFrameWidth;
        final k = w / kidFrameWidth;
        final eyes = Positioned(
          left: patch.rect.left * k,
          top: patch.rect.top * k,
          width: patch.rect.width * k,
          height: patch.rect.height * k,
          child: _frameImage(patch.asset, const Key('kid-eyes-closed')),
        );
        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              Positioned.fill(
                child: _frameImage(
                  kidFullAsset(gender, outfit, wave: wave),
                  Key('kid-full-$gender-$outfit${wave ? '-wave' : ''}'),
                ),
              ),
              if (_blink != null)
                AnimatedBuilder(
                  animation: _blink!,
                  builder: (context, child) =>
                      _blink!.value > 0.93 ? child! : const SizedBox.shrink(),
                  child: eyes,
                ),
              if (accessory != null)
                Positioned.fill(
                  child: _frameImage(accessory, const Key('kid-accessory')),
                ),
            ],
          ),
        );
      },
    );

    if (widget.facingLeft) {
      body = Transform.flip(flipX: true, child: body);
    }

    if (_on) {
      body = AnimatedBuilder(
        animation: Listenable.merge([_breath, _step]),
        builder: (context, child) {
          final b = Curves.easeInOut.transform(_breath!.value);
          final sy = 0.99 + 0.035 * b;
          final sx = 1.01 - 0.025 * b;
          final s = _step!.value;
          // Nhún bước: nảy lên 2 lần mỗi chu kỳ (2 bước), nghiêng theo bước.
          final hop = widget.walking ? (math.sin(s * 2 * math.pi)).abs() : 0.0;
          final tilt = widget.walking ? math.sin(s * 2 * math.pi) * 0.05 : 0.0;
          return FractionalTranslation(
            translation: Offset(0, -0.025 * hop),
            child: Transform.rotate(
              angle: tilt,
              alignment: const Alignment(0, 0.86),
              child: Transform(
                alignment: const Alignment(0, 0.86),
                transform: Matrix4.diagonal3Values(sx, sy, 1),
                child: child,
              ),
            ),
          );
        },
        child: body,
      );
    }

    return SizedBox(
      key: const Key('kid-sprite'),
      width: widget.width,
      child: AspectRatio(
        aspectRatio: kidFrameWidth / kidFrameHeight,
        child: body,
      ),
    );
  }
}
