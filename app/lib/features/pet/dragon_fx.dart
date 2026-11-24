/// Hiệu ứng riêng của rồng (siêu hiếm): vầng sáng, phun lửa, phun nước,
/// bay. Số liệu ở `dragon_fx_config.dart`.
///
/// - [DragonAura]: vầng sáng sau rồng (Phòng, Cửa hàng, "Pet của bé").
///   Có hình (`dragonFxArtReady`) thì dùng `dragon_aura.png` nhịp thở
///   (co giãn + độ mờ); chưa có thì vẽ code: quầng xuyên tâm xanh bạc hà
///   - vàng + vài đốm lấp lánh.
/// - [DragonPetView]: rồng trong Phòng = vầng sáng + [PetSprite] + hiệu
///   ứng hành động do [DragonFxController] điều khiển. Rồng trưởng thành
///   chơi đủ bộ (4 khung hình thật hoặc hạt vẽ code); mới nở/nhỡ chỉ có
///   bản nhỏ (chút tia lửa / bong bóng, nhảy-vỗ cánh).
/// - [DragonActionMenu]: 3 nút tròn Phun lửa / Phun nước / Bay.
///
/// Mỗi hiệu ứng là MỘT CustomPainter (hạt tính theo công thức từ thời
/// gian, không cấp phát mỗi khung, số hạt có trần), controller đều được
/// dispose. Cổng [AnimationGate] tắt: hiệu ứng tĩnh/xong ngay (test).
/// Lửa/nước chỉ để vui, không làm hại gì.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/animation/animation_gate.dart';
import '../room/pet_growth.dart';
import '../room/pet_sprite.dart';
import 'dragon_fx_config.dart';

/// Hành động của rồng.
enum DragonAction { fire, water, fly }

/// Bản đầy đủ (trưởng thành) hay bản nhỏ (mới nở/nhỡ).
enum DragonFxMode { full, small }

// --- Hàm thuần (dễ test) ----------------------------------------------

/// Bản hiệu ứng theo giai đoạn: chỉ rồng trưởng thành mới có bản đầy đủ.
DragonFxMode dragonFxModeFor(PetStage stage) =>
    stage == PetStage.adult ? DragonFxMode.full : DragonFxMode.small;

/// Có dùng hình thật cho hiệu ứng không (cờ bật VÀ rồng trưởng thành).
bool dragonUsesArt(PetStage stage, {bool artReady = dragonFxArtReady}) =>
    artReady && stage == PetStage.adult;

/// Danh sách hình của [action] (bay: 4 khung lặp; lửa/nước: 4 khung).
List<String> dragonFxAssets(DragonAction action) => switch (action) {
  DragonAction.fire => dragonFireAssets,
  DragonAction.water => dragonWaterAssets,
  DragonAction.fly => dragonFlyAssets,
};

/// Tổng thời gian 4 khung phun (ms), có giữ thêm một khung.
int get dragonFxArtTotalMs => 4 * dragonFxFrameMs + dragonFxHoldExtraMs;

/// Khung phun (0..3) ở [ms] mili giây từ lúc bắt đầu; quá giờ → khung cuối.
int dragonFxArtFrameAt(int ms) {
  var acc = 0;
  for (var i = 0; i < 4; i++) {
    acc += dragonFxFrameMs + (i == dragonFxHoldFrame ? dragonFxHoldExtraMs : 0);
    if (ms < acc) return i;
  }
  return 3;
}

/// Thời gian chạy (ms) của [action] ở [stage].
int dragonActionMs(
  DragonAction action,
  PetStage stage, {
  bool artReady = dragonFxArtReady,
}) {
  final full = dragonFxModeFor(stage) == DragonFxMode.full;
  switch (action) {
    case DragonAction.fire:
    case DragonAction.water:
      if (dragonUsesArt(stage, artReady: artReady)) return dragonFxArtTotalMs;
      return full
          ? (action == DragonAction.fire ? dragonFireMs : dragonWaterMs)
          : dragonSmallMs;
    case DragonAction.fly:
      return full
          ? dragonFlyRiseMs + dragonFlyHoverMs + dragonFlyLandMs
          : dragonHopMs;
  }
}

/// Độ nâng chuẩn hóa 0..1 của hành động Bay ở tiến độ [t] (0..1):
/// bay lên, treo, hạ cánh.
double dragonFlyLiftAt(double t) {
  const total = dragonFlyRiseMs + dragonFlyHoverMs + dragonFlyLandMs;
  const rise = dragonFlyRiseMs / total;
  const land = 1 - dragonFlyLandMs / total;
  if (t <= 0 || t >= 1) return 0;
  if (t < rise) return Curves.easeOut.transform(t / rise);
  if (t > land) return 1 - Curves.easeIn.transform((t - land) / (1 - land));
  return 1;
}

/// Rồng có bay thay vì đi bộ không: chỉ loài rồng ở tuổi trưởng thành
/// và quãng đi dài hơn [threshold].
bool dragonShouldFlyWalk({
  required String species,
  required PetStage stage,
  required double length,
  double threshold = dragonFlyWalkThreshold,
}) => species == dragonSpecies && stage == PetStage.adult && length > threshold;

// --- Bộ điều khiển -------------------------------------------------------

/// Điều khiển hành động của rồng từ ngoài (Phòng / màn xem thử).
class DragonFxController extends ChangeNotifier {
  /// Hành động đang chạy (null khi rảnh). Cổng hiệu ứng tắt thì không
  /// bao giờ đặt (hành động xong ngay).
  DragonAction? action;

  /// Hành động bắt đầu gần nhất + số lần đã bắt đầu (test/QA).
  DragonAction? lastAction;
  int playCount = 0;

  /// Đang bay-đi (đường dài) hay không.
  bool cruising = false;

  /// Độ nâng hiện tại (tỉ lệ cạnh hộp pet) cho bóng đất co lại.
  final ValueNotifier<double> lift = ValueNotifier<double>(0);

  bool get busy => action != null;

  void play(DragonAction a) {
    if (busy) return;
    lastAction = a;
    playCount++;
    if (AnimationGate.enabled) action = a;
    notifyListeners();
  }

  /// Hành động chạy xong (do view gọi).
  void finish() {
    if (action == null) return;
    action = null;
    notifyListeners();
  }

  /// Hủy hành động đang chạy (bé chạm sàn đi chỗ khác).
  void cancel() => finish();

  void setCruising(bool value) {
    if (cruising == value) return;
    cruising = value;
    notifyListeners();
  }

  @override
  void dispose() {
    lift.dispose();
    super.dispose();
  }
}

// --- Vầng sáng ------------------------------------------------------------

/// Vầng sáng sau [child]; kích thước theo [child].
class DragonAura extends StatefulWidget {
  const DragonAura({
    super.key,
    required this.child,
    this.artReady = dragonFxArtReady,
  });

  final Widget child;
  final bool artReady;

  /// Bọc [child] bằng vầng sáng nếu [species] là rồng.
  static Widget wrapIf(String species, Widget child) =>
      species == dragonSpecies ? DragonAura(child: child) : child;

  @override
  State<DragonAura> createState() => _DragonAuraState();
}

class _DragonAuraState extends State<DragonAura>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (AnimationGate.enabled) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: dragonAuraPulseMs),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pulse = _pulse;
    final Widget layer;
    if (widget.artReady) {
      final art = Image.asset(
        dragonAuraAsset,
        key: const Key('dragon-aura-art'),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
      layer = pulse == null
          ? art
          : AnimatedBuilder(
              animation: pulse,
              child: art,
              builder: (context, child) {
                final s = math.sin(pulse.value * 2 * math.pi);
                return Opacity(
                  opacity:
                      dragonAuraMinOpacity +
                      (1 - dragonAuraMinOpacity) * (s + 1) / 2,
                  child: Transform.scale(
                    scale: 1 + dragonAuraPulseAmount * s,
                    child: child,
                  ),
                );
              },
            );
    } else {
      layer = CustomPaint(
        key: const Key('dragon-aura-code'),
        painter: _AuraPainter(pulse),
        size: Size.infinite,
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: IgnorePointer(child: layer)),
        widget.child,
      ],
    );
  }
}

void _drawStar(Canvas canvas, Paint paint, Offset c, double r) {
  paint.strokeWidth = math.max(1.0, r * 0.35);
  paint.strokeCap = StrokeCap.round;
  canvas.drawLine(c.translate(-r, 0), c.translate(r, 0), paint);
  canvas.drawLine(c.translate(0, -r), c.translate(0, r), paint);
  canvas.drawCircle(c, r * 0.35, paint..style = PaintingStyle.fill);
}

class _AuraPainter extends CustomPainter {
  _AuraPainter(this.pulse) : super(repaint: pulse);

  final Animation<double>? pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final v = pulse?.value ?? 0.0;
    final s = math.sin(v * 2 * math.pi);
    final side = math.min(size.width, size.height);
    final center = Offset(
      size.width * dragonAuraCenter.dx / 512,
      size.height * dragonAuraCenter.dy / 512,
    );
    final radius = side * dragonAuraRadius * (1 + dragonAuraPulseAmount * s);
    final opacity =
        dragonAuraMinOpacity + (1 - dragonAuraMinOpacity) * (s + 1) / 2;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          dragonAuraGold.withValues(alpha: 0.55 * opacity),
          dragonAuraMint.withValues(alpha: 0.38 * opacity),
          dragonAuraMint.withValues(alpha: 0),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
    // Đốm lấp lánh: tĩnh (pha 0,25) khi không có nhịp.
    final star = Paint()..style = PaintingStyle.stroke;
    for (final sp in dragonAuraSparkles) {
      final tw = pulse == null
          ? 0.7
          : (math.sin(2 * math.pi * (v * 2 + sp.$3)) + 1) / 2;
      star.color = dragonAuraGold.withValues(alpha: 0.25 + 0.7 * tw);
      _drawStar(
        canvas,
        star,
        Offset(size.width * sp.$1, size.height * sp.$2),
        side * (0.012 + 0.018 * tw),
      );
    }
  }

  @override
  bool shouldRepaint(_AuraPainter old) => old.pulse != pulse;
}

// --- Hạt phun lửa / nước ---------------------------------------------------

class _Seed {
  const _Seed(this.birth, this.life, this.speed, this.spread, this.size);
  final double birth;
  final double life;
  final double speed;
  final double spread; // -1..1
  final double size;
}

/// Hạt giả ngẫu nhiên cố định (tính một lần, tái dùng mọi lượt).
final List<_Seed> _seeds = () {
  final r = math.Random(7);
  return List<_Seed>.generate(
    dragonFxMaxParticles,
    (_) => _Seed(
      r.nextDouble(),
      0.28 + r.nextDouble() * 0.17,
      r.nextDouble(),
      r.nextDouble() * 2 - 1,
      r.nextDouble(),
    ),
  );
}();

/// Một hiệu ứng phun (lửa hoặc nước) từ miệng rồng, bản đầy đủ hoặc nhỏ.
class DragonBreathPainter extends CustomPainter {
  DragonBreathPainter({
    required this.progress,
    required this.fire,
    required this.small,
    required this.facingLeft,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final bool fire;
  final bool small;
  final bool facingLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1) return;
    final s = size.width / 512;
    final dir = facingLeft ? -1.0 : 1.0;
    final mx = facingLeft ? 512 - dragonMouth.dx : dragonMouth.dx;
    Offset at(double dx, double dy) =>
        Offset((mx + dir * dx) * s, (dragonMouth.dy + dy) * s);
    final reach = small ? dragonBreathReachSmall : dragonBreathReach;
    final count = math.min(
      small
          ? dragonSmallParticles
          : (fire ? dragonFireParticles : dragonWaterParticles),
      dragonFxMaxParticles,
    );
    final k = small ? 0.65 : 1.0;
    final fill = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * s * 2;

    for (var i = 0; i < count; i++) {
      final sd = _seeds[i];
      final age = (t - sd.birth * dragonEmitFraction) / sd.life;
      if (age < 0 || age >= 1) continue;
      final dist = reach * (0.2 + 0.8 * age) * (0.7 + 0.3 * sd.speed);
      if (fire) {
        final p = at(dist, sd.spread * (6 + 28 * age) - 18 * age * age);
        final r = (5 + 11 * age) * (0.7 + 0.6 * sd.size) * k * s;
        fill.color = Color.lerp(
          dragonFireColors[0],
          dragonFireColors[1],
          age,
        )!.withValues(alpha: 0.9 * math.pow(1 - age, 1.2).toDouble());
        canvas.drawCircle(p, r, fill);
      } else if (small || i % 3 == 0) {
        // Bong bóng: trôi nhẹ lên, viền sáng + ruột mờ.
        final p = at(dist * 0.8, sd.spread * 10 - 40 * age);
        final r = (5 + 7 * sd.size) * k * s;
        fill.color = dragonWaterColor.withValues(alpha: 0.25 * (1 - age));
        line.color = dragonWaterLight.withValues(alpha: 0.9 * (1 - age));
        canvas.drawCircle(p, r, fill);
        canvas.drawCircle(p, r, line);
      } else {
        // Giọt nước: bay cong xuống theo trọng lực.
        final p = at(dist, sd.spread * 5 + 150 * age * age - 30 * age);
        final r = (3.5 + 3 * sd.size) * k * s;
        fill.color = Color.lerp(
          dragonWaterColor,
          dragonWaterLight,
          sd.size,
        )!.withValues(alpha: 1 - math.pow(age, 3).toDouble());
        canvas.drawCircle(p, r, fill);
      }
    }

    if (fire && t > 0.45) {
      // Tàn lửa bay lên rồi tắt.
      final n = small ? 3 : 7;
      for (var j = 0; j < n; j++) {
        final sd = _seeds[dragonFxMaxParticles - 1 - j];
        final p = ((t - 0.45) / 0.55 - sd.birth * 0.3);
        if (p <= 0 || p >= 1) continue;
        fill.color = dragonEmberColor.withValues(alpha: 1 - p);
        canvas.drawCircle(
          at(
            reach * (0.35 + 0.55 * sd.speed),
            -6 - p * 55 + math.sin(p * 6 + sd.size * 6) * 6,
          ),
          (1 + 2.2 * (1 - p)) * s * 1.6,
          fill,
        );
      }
    } else if (!fire && !small && t > dragonEmitFraction * 0.55) {
      // Nước tóe xuống đất ở cuối vòi.
      final p =
          ((t - dragonEmitFraction * 0.55) / (1 - dragonEmitFraction * 0.55));
      final c = at(reach * 0.85, 0);
      for (var j = 0; j < 8; j++) {
        final a = math.pi * (j + 0.5) / 8;
        final pos = Offset(
          c.dx + math.cos(a) * 34 * p * s * dir.abs(),
          dragonFeetY * s - math.sin(a) * 46 * 4 * p * (1 - p) * s,
        );
        fill.color = dragonWaterLight.withValues(alpha: 1 - p);
        canvas.drawCircle(pos, 3 * s * 1.6, fill);
      }
    }
  }

  @override
  bool shouldRepaint(DragonBreathPainter old) =>
      old.fire != fire || old.small != small || old.facingLeft != facingLeft;
}

/// Đốm lấp lánh hai bên thân khi vỗ cánh / nhảy-vỗ cánh.
class _FlutterPainter extends CustomPainter {
  _FlutterPainter(this.loop) : super(repaint: loop);

  final Animation<double> loop;

  @override
  void paint(Canvas canvas, Size size) {
    final star = Paint()..style = PaintingStyle.stroke;
    for (var i = 0; i < dragonFlutterSparkles; i++) {
      final tw = (math.sin(2 * math.pi * (loop.value * 2 + i * 0.19)) + 1) / 2;
      final left = i.isEven;
      final x =
          size.width * (left ? 0.16 + 0.05 * (i % 3) : 0.84 - 0.05 * (i % 3));
      final y = size.height * (0.30 + 0.08 * (i % 4)) - tw * size.height * 0.03;
      star.color = (i % 3 == 0 ? dragonAuraMint : dragonAuraGold).withValues(
        alpha: 0.2 + 0.75 * tw,
      );
      _drawStar(canvas, star, Offset(x, y), size.width * (0.012 + 0.016 * tw));
    }
  }

  @override
  bool shouldRepaint(_FlutterPainter old) => false;
}

// --- Rồng trong Phòng -----------------------------------------------------

/// Rồng đã nở: vầng sáng + [PetSprite] + hiệu ứng hành động. Điền kín ô
/// được cấp (cùng khung 512 như ảnh pet).
class DragonPetView extends StatefulWidget {
  const DragonPetView({
    super.key,
    required this.controller,
    required this.stage,
    this.walking = false,
    this.facingLeft = false,
    this.happyTick = 0,
    this.artReady = dragonFxArtReady,
  });

  final DragonFxController controller;
  final PetStage stage;
  final bool walking;
  final bool facingLeft;
  final int happyTick;
  final bool artReady;

  @override
  State<DragonPetView> createState() => _DragonPetViewState();
}

class _DragonPetViewState extends State<DragonPetView>
    with TickerProviderStateMixin {
  late final AnimationController _action = AnimationController(vsync: this);
  late final AnimationController _cruise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: dragonCruiseLiftMs),
  );
  // 8 khung × 110 ms: khung bay đổi mỗi 110 ms, nhịp lắc 880 ms.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: dragonFlyFrameMs * 8),
  );
  DragonAction? _running;

  bool get _art => dragonUsesArt(widget.stage, artReady: widget.artReady);
  bool get _full => dragonFxModeFor(widget.stage) == DragonFxMode.full;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    _action.addListener(_publish);
    _cruise
      ..addListener(_publish)
      ..addStatusListener((_) => _syncLoop());
    _action.addStatusListener((status) {
      if (status == AnimationStatus.completed && _running != null) {
        _running = null;
        _action.value = 0;
        _publish();
        _syncLoop();
        widget.controller.finish();
      }
    });
  }

  @override
  void didUpdateWidget(DragonPetView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _action.dispose();
    _cruise.dispose();
    _loop.dispose();
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    final c = widget.controller;
    final a = c.action;
    if (a != null && _running == null) {
      _running = a;
      _action
        ..duration = Duration(
          milliseconds: dragonActionMs(
            a,
            widget.stage,
            artReady: widget.artReady,
          ),
        )
        ..forward(from: 0);
    } else if (a == null && _running != null) {
      _running = null;
      _action
        ..stop()
        ..value = 0;
    }
    if (AnimationGate.enabled) {
      if (c.cruising) {
        _cruise.forward();
      } else {
        _cruise.reverse();
      }
    }
    _syncLoop();
    _publish();
    setState(() {});
  }

  void _syncLoop() {
    final need =
        _running == DragonAction.fly ||
        widget.controller.cruising ||
        _cruise.value > 0;
    if (need && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!need && _loop.isAnimating) {
      _loop.stop();
    }
  }

  /// Độ nâng (tỉ lệ cạnh hộp) từ hành động bay/nhảy + bay-đi.
  double _liftNow() {
    var l = Curves.easeInOut.transform(_cruise.value) * dragonFlyLift;
    if (_running == DragonAction.fly) {
      final t = _action.value;
      final a = _full
          ? dragonFlyLiftAt(t) * dragonFlyLift
          : math.sin(math.pi * t) * dragonHopLift;
      l = math.max(l, a);
    }
    return l;
  }

  void _publish() => widget.controller.lift.value = _liftNow();

  @override
  Widget build(BuildContext context) {
    return DragonAura(
      artReady: widget.artReady,
      child: AnimatedBuilder(
        animation: Listenable.merge([_action, _cruise, _loop]),
        builder: (context, _) => _content(),
      ),
    );
  }

  Widget _content() {
    final running = _running;
    final airborne = running == DragonAction.fly || _liftNow() > 0.001;
    final bob = airborne
        ? math.sin(_loop.value * 2 * math.pi) *
              dragonFlyBob *
              (running == null ? 1 : (_full ? 1 : 0.3))
        : 0.0;
    final lift = _liftNow() + bob;
    final art = _art;
    final breathing =
        running == DragonAction.fire || running == DragonAction.water;

    Widget flip(Widget w) =>
        widget.facingLeft ? Transform.flip(flipX: true, child: w) : w;
    Widget frame(String path, {double shiftX = 0, double scale = 1}) {
      Widget img = Image.asset(
        path,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
      // Bù lệch/cỡ theo số đo của Muse (khung 512).
      if (shiftX != 0) {
        img = FractionalTranslation(
          translation: Offset(shiftX / 512, 0),
          child: img,
        );
      }
      if (scale != 1) {
        img = Transform.scale(
          scale: scale,
          alignment: Alignment.bottomCenter,
          child: img,
        );
      }
      return flip(img);
    }

    // Thân: hình thật khi có (phun/bay) còn không thì ảnh đứng của pet.
    Widget body;
    if (art && breathing) {
      final ms = (_action.value * _action.duration!.inMilliseconds).round();
      final assets = dragonFxAssets(running!);
      body = frame(
        assets[dragonFxArtFrameAt(ms)],
        shiftX: running == DragonAction.fire ? dragonFireArtShiftX : 0,
      );
    } else if (art && airborne) {
      final assets = dragonFxAssets(DragonAction.fly);
      body = frame(
        assets[(_loop.value * 8).floor() % 4],
        scale: dragonFlyArtScale,
      );
    } else {
      body = PetSprite(
        species: dragonSpecies,
        stage: widget.stage,
        walking: widget.walking && !airborne,
        facingLeft: widget.facingLeft,
        happyTick: widget.happyTick,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: FractionalTranslation(
            key: const Key('dragon-body'),
            translation: Offset(0, -lift),
            child: body,
          ),
        ),
        if (breathing && !art)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: Key('dragon-breath-${running!.name}'),
                painter: DragonBreathPainter(
                  progress: _action,
                  fire: running == DragonAction.fire,
                  small: !_full,
                  facingLeft: widget.facingLeft,
                ),
              ),
            ),
          ),
        if (airborne && !art)
          Positioned.fill(
            child: FractionalTranslation(
              translation: Offset(0, -lift),
              child: IgnorePointer(
                child: CustomPaint(
                  key: const Key('dragon-flutter'),
                  painter: _FlutterPainter(_loop),
                ),
              ),
            ),
          ),
        if (running != null)
          SizedBox.shrink(key: Key('dragon-fx-running-${running.name}')),
        if (_liftNow() > 0.001 && running == null)
          const SizedBox.shrink(key: Key('dragon-fx-cruising')),
      ],
    );
  }
}

// --- Nút hành động ----------------------------------------------------------

/// 3 nút tròn Phun lửa / Phun nước / Bay. [scale] = px mỗi đơn vị khung
/// (Phòng) để nút co theo màn nhưng không nhỏ hơn 44.
class DragonActionMenu extends StatelessWidget {
  const DragonActionMenu({
    super.key,
    required this.onAction,
    this.scale = 1,
    this.enabled = true,
  });

  final ValueChanged<DragonAction> onAction;
  final double scale;
  final bool enabled;

  static const double buttonFrameSize = 96;

  /// Bề rộng cả hàng nút (px màn hình).
  static double widthFor(double scale) {
    final d = math.max(44.0, buttonFrameSize * scale);
    return d * 3 + 12 * 2;
  }

  @override
  Widget build(BuildContext context) {
    final d = math.max(44.0, buttonFrameSize * scale);
    Widget button(DragonAction a, IconData icon, String label, Color color) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: label,
            child: GestureDetector(
              key: Key('dragon-fx-${a.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? () => onAction(a) : null,
              child: Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled ? color : color.withValues(alpha: 0.45),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: d * 0.55),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: [Shadow(color: Color(0xCC000000), blurRadius: 3)],
            ),
          ),
        ],
      );
    }

    return Row(
      key: const Key('dragon-fx-menu'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        button(
          DragonAction.fire,
          Icons.local_fire_department,
          dragonFireLabel,
          const Color(0xFFFF7A1A),
        ),
        const SizedBox(width: 12),
        button(
          DragonAction.water,
          Icons.water_drop,
          dragonWaterLabel,
          const Color(0xFF3FA9F5),
        ),
        const SizedBox(width: 12),
        button(
          DragonAction.fly,
          Icons.flight,
          dragonFlyLabel,
          const Color(0xFF5DC3A8),
        ),
      ],
    );
  }
}
