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

import 'dart:async';
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
    this.glasses = false,
    this.whiteShoes = false,
    this.backpack = false,
    this.waving = false,
    this.walkingUp = false,
    this.walking = false,
    this.facingLeft = false,
    this.animationsEnabled = true,
    this.width,
    this.idleWave = false,
  });

  /// Đứng yên lâu thì tự vẫy tay nhẹ (mỗi 9–15 giây, ~1,2 giây) như
  /// nhân vật game đang chờ bé.
  final bool idleWave;

  /// `girl` hoặc `boy`.
  final String gender;

  /// Bộ đồ 1–3.
  final int outfit;

  /// Phụ kiện đầu: `hat`, `bow` hoặc null.
  final String? headAccessory;

  /// Đeo kính tròn / đi giày trắng (lớp phủ cùng khung).
  final bool glasses;
  final bool whiteShoes;

  /// Đeo balo: đổi sang ảnh toàn thân có balo (không phải lớp phủ).
  final bool backpack;

  final bool waving;

  /// Đang đi lên (xa dần): dùng khung đi bộ `ur` thay vì `dr`.
  final bool walkingUp;
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
  AnimationController? _sway;
  Timer? _idleTimer;
  bool _autoWave = false;
  final math.Random _rng = math.Random();

  bool get _on => widget.animationsEnabled && AnimationGate.enabled;

  /// Đang dùng khung đi bộ thật (không cần nhún bằng ảnh đứng).
  bool get _hasWalkFrames =>
      !widget.glasses &&
      !widget.whiteShoes &&
      !widget.backpack &&
      widget.headAccessory == null &&
      kidWalkFrames(widget.gender, widget.outfit, up: false) != null;

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
      // 4 khung đi bộ mỗi 960 ms (240 ms/khung), khớp tốc độ đi chậm
      // [roomWalkSpeed] để chân không trượt.
      duration: const Duration(milliseconds: 960),
    );
    if (widget.walking) _step!.repeat();
    // Đứng yên: lắc lư người/đầu rất nhẹ quanh chân (chu kỳ 3,2 giây).
    _sway = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _scheduleIdleWave();
  }

  void _scheduleIdleWave() {
    _idleTimer?.cancel();
    if (!widget.idleWave || !_on) return;
    _idleTimer = Timer(Duration(milliseconds: 9000 + _rng.nextInt(6000)), () {
      if (!mounted) return;
      if (!widget.walking && !widget.waving) {
        setState(() => _autoWave = true);
        _idleTimer = Timer(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          setState(() => _autoWave = false);
          _scheduleIdleWave();
        });
      } else {
        _scheduleIdleWave();
      }
    });
  }

  @override
  void didUpdateWidget(KidSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    final step = _step;
    if (step == null) return;
    if (widget.walking && _autoWave) _autoWave = false;
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
    _sway?.dispose();
    _idleTimer?.cancel();
    super.dispose();
  }

  /// Ảnh khung 1024x1536 giải mã ở nửa cỡ ([kidImage]) để bộ nhớ đệm
  /// ảnh giữ đủ mọi khung đi bộ — tràn bộ đệm thì mỗi lần đổi khung
  /// phải giải mã lại, nhân vật đi bị giật (góp ý v0.0.13). Miếng vá
  /// mắt nhỏ nên giữ nguyên cỡ.
  Widget _frameImage(String asset, Key key, {bool fullFrame = true}) => Image(
    image: fullFrame ? kidImage(asset) : AssetImage(asset),
    key: key,
    fit: BoxFit.fill,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );

  @override
  Widget build(BuildContext context) {
    final gender = kidGender(widget.gender);
    final outfit = widget.outfit.clamp(1, 3);
    final wave = widget.waving || (_autoWave && !widget.walking);
    final patch = kidEyePatch(gender, outfit, wave: wave);
    final accessory = kidHeadAccessoryAsset(gender, widget.headAccessory);
    final overlays = <String>[
      if (widget.whiteShoes) kidWhiteShoesAsset(gender),
      if (widget.glasses) kidGlassesAsset(gender),
      ?accessory,
    ];
    // Khung đi bộ thật chỉ dùng khi không đeo lớp phủ nào (lớp phủ vẽ
    // theo dáng đứng, đặt lên khung đi bộ sẽ lệch); còn lại nhún bước
    // bằng ảnh đứng.
    final walkFrames = (widget.walking && _hasWalkFrames && _on)
        ? kidWalkFrames(gender, outfit, up: widget.walkingUp)
        : null;

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
          child: _frameImage(
            patch.asset,
            const Key('kid-eyes-closed'),
            fullFrame: false,
          ),
        );
        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              if (walkFrames != null)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _step!,
                    builder: (context, _) {
                      final i = (_step!.value * 4).floor().clamp(0, 3);
                      return _frameImage(
                        walkFrames[i],
                        const Key('kid-walk-frame'),
                      );
                    },
                  ),
                )
              else
                Positioned.fill(
                  child: _frameImage(
                    kidFullAsset(
                      gender,
                      outfit,
                      wave: wave,
                      backpack: widget.backpack,
                    ),
                    Key(
                      'kid-full-$gender-$outfit${wave ? '-wave' : ''}'
                      '${widget.backpack ? '-backpack' : ''}',
                    ),
                  ),
                ),
              if (_blink != null && walkFrames == null)
                AnimatedBuilder(
                  animation: _blink!,
                  builder: (context, child) =>
                      _blink!.value > 0.93 ? child! : const SizedBox.shrink(),
                  child: eyes,
                ),
              if (walkFrames == null)
                for (final o in overlays)
                  Positioned.fill(
                    child: _frameImage(
                      o,
                      o == accessory
                          ? const Key('kid-accessory')
                          : Key('kid-overlay-${o.split('/').last}'),
                    ),
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
        animation: Listenable.merge([_breath, _step, _sway]),
        builder: (context, child) {
          final b = Curves.easeInOut.transform(_breath!.value);
          final sy = 0.99 + 0.035 * b;
          final sx = 1.01 - 0.025 * b;
          final s = _step!.value;
          // Nhún bước: nảy lên 2 lần mỗi chu kỳ (2 bước), nghiêng theo bước.
          final bob = widget.walking && !_hasWalkFrames;
          final hop = bob ? (math.sin(s * 2 * math.pi)).abs() : 0.0;
          final idle = !widget.walking && !wave;
          final sway = idle
              ? (Curves.easeInOut.transform(_sway!.value) - 0.5) * 0.035
              : 0.0;
          final tilt = (bob ? math.sin(s * 2 * math.pi) * 0.05 : 0.0) + sway;
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
