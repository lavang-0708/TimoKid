/// Pet đã nở trong Phòng, có động tác (góp ý 22/11: "pet chỉ là 1 ảnh
/// đi theo, không có động tác"). Cùng mẫu [KidSprite]: hiệu ứng dựng
/// bằng code trên ảnh đứng; khi Muse giao khung thật
/// ([petMotionArtReady] = true) thì đổi sang khung thật.
///
/// - Đi ([walking]): chạy nước kiệu, mỗi 600 ms hai nhịp nảy (dọc
///   lên xuống + nghiêng về phía trước luân phiên, nén lúc tiếp
///   đất), đồng bộ với bước đi; có khung thật thì 4 khung `walk_a..d`
///   mỗi 600 ms.
/// - Đứng yên: thở (co giãn dọc nhẹ) + lắc ngang nhỏ như vẫy đuôi.
/// - Thỉnh thoảng (6–12 giây một lần, chỉ khi đứng yên) tự làm một
///   động tác: nhảy nhỏ, quay một vòng nhìn bé, hoặc ngồi xuống vài
///   giây (có khung `sit` thật thì dùng).
/// - Bé chạm khi đã mở khóa ([happyTick] tăng): nhảy vui + vài
///   trái tim bay lên (khung `happy` thật nếu có).
///
/// Cổng [AnimationGate] tắt mọi hiệu ứng khi chạy test để
/// `pumpAndSettle` dừng được và ảnh golden xác định.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/animation/animation_gate.dart';
import 'pet_art.dart';
import 'pet_growth.dart';

/// Động tác ngẫu nhiên khi pet đứng yên.
enum PetIdleAction { jump, spin, sit }

class PetSprite extends StatefulWidget {
  const PetSprite({
    super.key,
    required this.species,
    required this.stage,
    this.walking = false,
    this.facingLeft = false,
    this.happyTick = 0,
  });

  final String species;

  /// Giai đoạn đã đổi trứng → mới nở (không nhận `PetStage.egg`).
  final PetStage stage;
  final bool walking;
  final bool facingLeft;

  /// Mỗi lần giá trị này tăng là pet nhảy vui + thả tim.
  final int happyTick;

  @override
  State<PetSprite> createState() => _PetSpriteState();
}

class _PetSpriteState extends State<PetSprite> with TickerProviderStateMixin {
  AnimationController? _idle;
  AnimationController? _walk;
  AnimationController? _action;
  AnimationController? _happy;
  Timer? _idleTimer;
  PetIdleAction? _current;
  final math.Random _rng = math.Random();

  bool get _on => AnimationGate.enabled;

  /// Chân pet ở 440/512 chiều cao ảnh → trục co giãn/xoay.
  static const Alignment _pivot = Alignment(0, 0.72);

  @override
  void initState() {
    super.initState();
    if (!_on) return;
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _walk = AnimationController(
      vsync: this,
      // 4 khung đi / 600 ms; mỗi 300 ms một nhịp nảy.
      duration: const Duration(milliseconds: 600),
    );
    if (widget.walking) _walk!.repeat();
    _action = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _current = null);
          _scheduleIdleAction();
        }
      });
    _happy = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scheduleIdleAction();
    if (petHasMotionArt(widget.species, widget.stage)) _precache();
  }

  void _precache() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final paths = <String>[
        ...petWalkAssets(widget.species, widget.stage),
        petHappyAsset(widget.species, widget.stage),
        petSitAsset(widget.species, widget.stage),
      ];
      for (final p in paths) {
        precacheImage(AssetImage(p), context, onError: (_, _) {});
      }
    });
  }

  /// Hẹn động tác ngẫu nhiên kế tiếp sau 6–12 giây.
  void _scheduleIdleAction() {
    _idleTimer?.cancel();
    if (!_on) return;
    _idleTimer = Timer(Duration(milliseconds: 6000 + _rng.nextInt(6001)), () {
      if (!mounted) return;
      final busy = widget.walking || (_happy?.isAnimating ?? false);
      if (busy) {
        _scheduleIdleAction();
        return;
      }
      final action =
          PetIdleAction.values[_rng.nextInt(PetIdleAction.values.length)];
      final ms = switch (action) {
        PetIdleAction.jump => 700,
        PetIdleAction.spin => 900,
        PetIdleAction.sit => 3200,
      };
      setState(() => _current = action);
      _action!
        ..duration = Duration(milliseconds: ms)
        ..forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(PetSprite old) {
    super.didUpdateWidget(old);
    final walk = _walk;
    if (walk == null) return;
    if (widget.walking && !old.walking) {
      // Bắt đầu đi: bỏ động tác đang làm.
      _action!.stop();
      _current = null;
      walk.repeat();
    } else if (!widget.walking && old.walking) {
      walk.stop();
      walk.value = 0;
      _scheduleIdleAction();
    }
    if (widget.happyTick != old.happyTick) {
      _action!.stop();
      _current = null;
      _happy!.forward(from: 0).whenCompleteOrCancel(() {
        if (mounted) _scheduleIdleAction();
      });
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _idle?.dispose();
    _walk?.dispose();
    _action?.dispose();
    _happy?.dispose();
    super.dispose();
  }

  /// Chọn ảnh theo trạng thái (khung thật khi [petMotionArtReady]).
  String _asset({required bool sitting}) {
    final base = petAsset(widget.species, widget.stage);
    if (!petHasMotionArt(widget.species, widget.stage) || !_on) return base;
    if (_happy!.isAnimating) return petHappyAsset(widget.species, widget.stage);
    if (sitting) return petSitAsset(widget.species, widget.stage);
    if (widget.walking) {
      final frames = petWalkAssets(widget.species, widget.stage);
      return frames[(_walk!.value * frames.length).floor() % frames.length];
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final idle = _idle;
    if (idle == null) return _picture(petAsset(widget.species, widget.stage));
    final dir = widget.facingLeft ? -1.0 : 1.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return AnimatedBuilder(
          animation: Listenable.merge([idle, _walk, _action, _happy]),
          builder: (context, _) {
            var sx = 1.0;
            var sy = 1.0;
            var dy = 0.0; // phần chiều cao, âm = lên
            var rot = 0.0;
            var sitting = false;
            final happyOn = _happy!.isAnimating;

            if (happyOn) {
              // Nhảy vui: nén lấy đà → bật cao → nén lúc tiếp đất.
              final a = _happy!.value;
              final air = math.sin(math.pi * a);
              dy = -0.30 * air;
              final crouch =
                  math.max(0.0, 1 - a * 8) + math.max(0.0, a * 8 - 7);
              sy = 1 - 0.14 * crouch + 0.10 * air;
              sx = 1 + 0.10 * crouch - 0.06 * air;
              rot = 0.10 * math.sin(a * 4 * math.pi) * dir;
            } else if (widget.walking) {
              // Nước kiệu: |sin| hai nhịp mỗi 600 ms; s = 0 là lúc
              // chạm đất (nén), s = 1 là đỉnh nhịp nảy.
              final p = _walk!.value * 2 * math.pi;
              final s = math.sin(p).abs();
              final landing = math.pow(1 - s, 4).toDouble();
              dy = -0.09 * s;
              rot = 0.06 * math.sin(p) * dir; // nghiêng về trước luân phiên
              sy = 1 - 0.08 * landing + 0.03 * s;
              sx = 1 + 0.06 * landing - 0.02 * s;
            } else {
              // Thở + lắc ngang nhỏ như vẫy đuôi.
              final t = idle.value * 2 * math.pi;
              final breath = math.sin(t);
              sy = 1 + 0.025 * breath;
              sx = 1 - 0.015 * breath;
              rot = 0.03 * math.sin(t * 3) * dir;
              final action = _current;
              if (action != null) {
                final a = _action!.value;
                switch (action) {
                  case PetIdleAction.jump:
                    final air = math.sin(math.pi * a);
                    dy = -0.20 * air;
                    final crouch =
                        math.max(0.0, 1 - a * 6) + math.max(0.0, a * 6 - 5);
                    sy *= 1 - 0.12 * crouch + 0.08 * air;
                    sx *= 1 + 0.08 * crouch - 0.04 * air;
                  case PetIdleAction.spin:
                    // Quay một vòng quanh trục dọc nhìn bé (co ngang
                    // theo cos), nảy nhẹ giữa vòng.
                    sx *= math.cos(2 * math.pi * a);
                    dy = -0.05 * math.sin(math.pi * a);
                  case PetIdleAction.sit:
                    // Ngồi xuống (nén dọc) giữ vài giây rồi đứng dậy.
                    final k = math.min(1.0, math.min(a / 0.1, (1 - a) / 0.1));
                    final e = Curves.easeInOut.transform(k.clamp(0.0, 1.0));
                    sy *= 1 - 0.18 * e;
                    sx *= 1 + 0.08 * e;
                    sitting = e > 0.5;
                }
              }
            }

            final hearts = happyOn ? _hearts(w, h, _happy!.value) : null;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: FractionalTranslation(
                    translation: Offset(0, dy),
                    child: Transform(
                      key: const Key('pet-sprite'),
                      alignment: _pivot,
                      transform:
                          Matrix4.rotationZ(rot) *
                          Matrix4.diagonal3Values(sx, sy, 1),
                      child: _picture(_asset(sitting: sitting)),
                    ),
                  ),
                ),
                if (_current != null)
                  SizedBox.shrink(key: Key('pet-action-${_current!.name}')),
                ?hearts,
              ],
            );
          },
        );
      },
    );
  }

  Widget _picture(String asset) {
    Widget picture = Image.asset(
      asset,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
    if (widget.facingLeft) {
      picture = Transform.flip(flipX: true, child: picture);
    }
    return picture;
  }

  /// 3 trái tim bay lên từ đầu pet, mờ dần (so le nhau).
  Widget _hearts(double w, double h, double a) {
    return IgnorePointer(
      key: const Key('pet-hearts'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < 3; i++)
            () {
              final t = ((a - i * 0.12) / 0.65).clamp(0.0, 1.0);
              final size = w * (i == 1 ? 0.16 : 0.12);
              return Positioned(
                left:
                    w * (0.30 + 0.20 * i) - size / 2 + 6 * math.sin(t * 6 + i),
                top: h * 0.18 - t * h * 0.32 - size / 2,
                child: Opacity(
                  opacity: t <= 0 ? 0 : 1 - t,
                  child: Icon(
                    Icons.favorite,
                    size: size,
                    color: const Color(0xFFFF6F91),
                  ),
                ),
              );
            }(),
        ],
      ),
    );
  }
}
