/// Màn trứng nở (T2-03, DESIGN "Pet": trứng nở sau chặng toán đầu
/// tiên).
///
/// Hoạt cảnh nở nhiều bước cho giống thật (góp ý 22/11: "vỡ trứng
/// chưa thật, nứt từ từ rồi nở ra"), chạy một lần ~3,6 giây rồi
/// dừng (không lặp vô hạn để `pumpAndSettle` trong test dừng được):
///
/// 1. trứng lắc nhẹ, nghỉ, lắc mạnh hơn, nghỉ, lắc mạnh nhất — mỗi
///    đợt lắc xong thì hiện thêm một vết nứt (3 bước, vẽ từ từ);
/// 2. lúc nứt có mảnh vỏ nhỏ văng ra;
/// 3. trứng nén lại rồi nửa vỏ trên bật bay đi, pet nhảy vọt lên
///    (nén – giãn – nén lúc tiếp đất) cùng sao + ánh sáng, nửa vỏ
///    dưới ở lại một lúc rồi mờ dần.
///
/// Bé bấm vào trứng để làm nhanh: mỗi lần bấm nhảy tới bước kế tiếp
/// (nứt 1 → nứt 2 → nứt 3 → vỡ). Xong mới hiện nút "Tiếp tục": bấm
/// thì đánh dấu đã nở ([EggService.consumeHatchCelebration]) rồi về
/// Thị trấn.
///
/// Hình: mặc định vết nứt vẽ bằng CustomPaint đè lên PNG trứng, hai
/// nửa vỏ là PNG trứng cắt theo đường ziczac; khi Muse giao hình
/// ([eggCrackArtReady] = true) thì dùng `{loài}_egg_crack_1..3.png`,
/// `{loài}_shell_top.png`, `{loài}_shell_bottom.png`.
///
/// Màn chỉ vào được khi có lần nở đang chờ (`hatch_pending`); nếu
/// mở trực tiếp mà không có trứng hay không có lần chờ thì hiện thông
/// báo và nút về Thị trấn. Pet và trứng là PNG thật (PR #21,
/// `app/assets/images/pets/`).
library;

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database_provider.dart';
import '../../core/widgets/press_bounce.dart';
import '../room/pet_art.dart';
import '../room/room_screen.dart';
import 'egg_service.dart';
import 'onboarding_config.dart';

/// Tổng thời gian hoạt cảnh (ms) và các mốc (ms) trên trục đó.
const int hatchTotalMs = 3600;
const int _crack1End = 900;
const int _crack2End = 1800;
const int _crack3End = 2600;
const int _burstMs = 2700;

/// Mốc bé bấm sẽ nhảy tới (nứt 1, nứt 2, nứt 3, vỡ).
const List<int> hatchTapMilestones = <int>[
  _crack1End,
  _crack2End,
  _crack3End,
  _burstMs,
];

class HatchScreen extends ConsumerStatefulWidget {
  const HatchScreen({super.key});

  static const String route = '/hatch';

  @override
  ConsumerState<HatchScreen> createState() => _HatchScreenState();
}

class _HatchScreenState extends ConsumerState<HatchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  String? _species;
  bool _loading = true;
  bool _showContinue = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: hatchTotalMs),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showContinue = true);
      }
    });
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final childId = await db.ensureSeeded();
    final eggs = EggService(db: db);
    final species = await eggs.selectedEgg(childId);
    final pending = await eggs.isHatchPending(childId);
    if (!mounted) return;
    setState(() {
      _species = pending ? species : null;
      _loading = false;
    });
    if (_species != null) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Bé bấm trứng: nhảy nhanh (~0,3 giây) tới bước nứt kế tiếp rồi
  /// chạy tiếp bình thường. Vỡ rồi thì không làm gì.
  void _onEggTap() {
    if (!_controller.isAnimating) return;
    final ms = _controller.value * hatchTotalMs;
    if (ms >= _burstMs) return;
    final target = hatchTapMilestones.firstWhere(
      (m) => m > ms + 20,
      orElse: () => _burstMs,
    );
    _controller
        .animateTo(
          target / hatchTotalMs,
          duration: const Duration(milliseconds: 300),
          curve: Curves.linear,
        )
        .then((_) {
          if (mounted && _controller.value < 1) _controller.forward();
        });
  }

  Future<void> _continue() async {
    final db = ref.read(databaseProvider);
    final childId = await db.ensureSeeded();
    await EggService(db: db).consumeHatchCelebration(childId);
    if (!mounted) return;
    context.go(RoomScreen.route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('hatch-screen'),
      appBar: AppBar(
        title: const Text('Trứng nở rồi!'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _species == null
            ? _EmptyHatch(onBack: () => context.go(RoomScreen.route))
            : _HatchAnimation(
                species: _species!,
                progress: _controller,
                onEggTap: _onEggTap,
                showContinue: _showContinue,
                onContinue: _continue,
              ),
      ),
    );
  }
}

/// Màn nở khi không có trứng hay không có lần chờ (mở trực tiếp).
class _EmptyHatch extends StatelessWidget {
  const _EmptyHatch({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Chưa có trứng nào nở.', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 16),
        PressBounce(
          child: ElevatedButton.icon(
            key: const Key('hatch-back-button'),
            icon: const Text('←', style: TextStyle(fontSize: 24)),
            label: const Text('Về Thị trấn', style: TextStyle(fontSize: 20)),
            style: ElevatedButton.styleFrom(minimumSize: const Size(56, 56)),
            onPressed: onBack,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Dòng thời gian (ms) — hàm thuần để dễ test.
// ---------------------------------------------------------------------

/// Tiến độ 0→1 của [ms] trong khoảng [from, to].
double _ramp(double ms, double from, double to) =>
    ((ms - from) / (to - from)).clamp(0.0, 1.0);

/// Các đợt lắc: (bắt đầu, kết thúc, biên độ rad, số lần qua lại).
const List<(double, double, double, double)> _wobbles = [
  (350, 850, 0.06, 3),
  (1250, 1750, 0.10, 4),
  (2000, 2600, 0.16, 6),
];

/// Góc xoay của trứng (rad) tại [ms]: lắc mạnh dần, có nghỉ giữa
/// các đợt; không còn lắc sau khi vỡ.
double hatchWobbleAngle(double ms) {
  for (final (from, to, amp, cycles) in _wobbles) {
    if (ms >= from && ms <= to) {
      final t = (ms - from) / (to - from);
      return amp * math.sin(math.pi * t) * math.sin(t * cycles * 2 * math.pi);
    }
  }
  return 0;
}

/// Mức vẽ xong (0–1) của 3 vết nứt tại [ms].
({double c1, double c2, double c3}) hatchCrackProgress(double ms) => (
  c1: _ramp(ms, 700, _crack1End.toDouble()),
  c2: _ramp(ms, 1600, _crack2End.toDouble()),
  c3: _ramp(ms, 2400, _crack3End.toDouble()),
);

/// Khung then chốt của pet nhảy ra: (t, ngang, dọc, dịch lên px).
const List<(double, double, double, double)> _petKeys = [
  (0.00, 0.30, 0.15, 12),
  (0.30, 0.88, 1.22, -28),
  (0.55, 0.95, 1.10, -34),
  (0.78, 1.12, 0.88, 0),
  (0.90, 0.97, 1.05, -4),
  (1.00, 1.00, 1.00, 0),
];

/// (co giãn ngang, co giãn dọc, dịch dọc px) của pet tại [ms]: trước
/// lúc vỡ pet chưa hiện (0), sau đó nén – giãn – nén lúc tiếp đất –
/// ổn định.
(double, double, double) hatchPetPose(double ms) {
  if (ms < _burstMs + 20) return (0, 0, 0);
  final t = _ramp(ms, _burstMs + 20, _burstMs + 800);
  for (var i = 1; i < _petKeys.length; i++) {
    final a = _petKeys[i - 1];
    final b = _petKeys[i];
    if (t <= b.$1) {
      final u = Curves.easeInOut.transform((t - a.$1) / (b.$1 - a.$1));
      return (
        a.$2 + (b.$2 - a.$2) * u,
        a.$3 + (b.$3 - a.$3) * u,
        a.$4 + (b.$4 - a.$4) * u,
      );
    }
  }
  return (1, 1, 0);
}

// ---------------------------------------------------------------------
// Hình
// ---------------------------------------------------------------------

/// Khung hoạt cảnh (px).
const double _boxW = 200;
const double _boxH = 220;

/// Chân trứng/pet (đất y = 440/512 của ảnh 200x200 đặt giữa khung
/// cao 220) → trục co giãn/xoay: Alignment y = 0.645.
const Alignment _pivot = Alignment(0, 0.645);

/// Màu vỏ theo loài (trung bình ảnh trứng) cho mảnh vỏ văng ra.
const Map<String, Color> _shellColors = <String, Color>{
  'dog': Color(0xFFEABB98),
  'cat': Color(0xFFE1B488),
  'rabbit': Color(0xFFC2C8D0),
};

/// Hoạt cảnh nở: trứng (lắc → nứt → vỡ) rồi pet mới nở nhảy ra.
class _HatchAnimation extends StatelessWidget {
  const _HatchAnimation({
    required this.species,
    required this.progress,
    required this.onEggTap,
    required this.showContinue,
    required this.onContinue,
  });

  final String species;
  final Animation<double> progress;
  final VoidCallback onEggTap;
  final bool showContinue;
  final VoidCallback onContinue;

  Widget _egg(String asset) => Image.asset(
    asset,
    width: _boxW,
    height: _boxH,
    fit: BoxFit.contain,
    gaplessPlayback: true,
  );

  @override
  Widget build(BuildContext context) {
    final petName = newbornSpeciesNames[species] ?? 'pet';
    final shell = _shellColors[species] ?? const Color(0xFFE8C8A8);
    // Bố cục ngang (màn hình ngang): hoạt cảnh bên trái, chữ + nút
    // bên phải — vừa cả màn 640x320 mà không cần cuộn.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          key: const Key('hatch-egg'),
          behavior: HitTestBehavior.opaque,
          onTap: onEggTap,
          child: SizedBox(
            width: _boxW,
            height: _boxH,
            child: AnimatedBuilder(
              animation: progress,
              builder: (context, _) =>
                  _buildStage(progress.value * hatchTotalMs, shell),
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Expanded để cột chữ không tràn Row khi phông chữ rộng
        // (trong widget test, phông dự phòng rộng hơn Nunito thật;
        // trên máy thật chữ vừa một dòng, không xuống dòng).
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chào bé $petName!',
                key: const Key('hatch-pet-name'),
                style: const TextStyle(fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: showContinue
                    ? PressBounce(
                        child: ElevatedButton.icon(
                          key: const Key('hatch-continue-button'),
                          label: const Text(
                            'Tiếp tục',
                            style: TextStyle(fontSize: 22),
                          ),
                          icon: const Text('→', style: TextStyle(fontSize: 24)),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(56, 56),
                          ),
                          onPressed: onContinue,
                        ),
                      )
                    : const Center(
                        child: Text(
                          'Chạm vào trứng nhé!',
                          key: Key('hatch-hint'),
                          style: TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Vẽ một khung của hoạt cảnh tại thời điểm [ms].
  Widget _buildStage(double ms, Color shell) {
    final burst = ms >= _burstMs;
    final crack = hatchCrackProgress(ms);
    final (psx, psy, pdy) = hatchPetPose(ms);
    final children = <Widget>[];

    // Pet nằm sau nửa vỏ dưới: nhảy ra khỏi vỏ.
    children.add(
      Transform.translate(
        offset: Offset(0, pdy),
        child: Transform(
          alignment: _pivot,
          transform: Matrix4.diagonal3Values(psx, psy, 1),
          child: _egg(newbornSpeciesAssets[species]!),
        ),
      ),
    );

    if (!burst) {
      // Trứng nguyên: lắc, lúc sắp vỡ nén nhẹ lại (dồn sức).
      final squash = 1 - 0.07 * _ramp(ms, 2600, _burstMs.toDouble());
      Widget egg;
      if (eggCrackArtReady) {
        final step = crack.c3 >= 1
            ? 3
            : crack.c2 >= 1
            ? 2
            : crack.c1 >= 1
            ? 1
            : 0;
        egg = _egg(
          step == 0 ? eggSpeciesAssets[species]! : eggCrackAsset(species, step),
        );
      } else {
        egg = Stack(
          alignment: Alignment.center,
          children: [
            _egg(eggSpeciesAssets[species]!),
            SizedBox(
              width: _boxW,
              height: _boxH,
              child: CustomPaint(
                painter: HatchCrackPainter(
                  c1: crack.c1,
                  c2: crack.c2,
                  c3: crack.c3,
                ),
              ),
            ),
          ],
        );
      }
      children.add(
        Transform.rotate(
          alignment: _pivot,
          angle: hatchWobbleAngle(ms),
          child: Transform(
            alignment: _pivot,
            transform: Matrix4.diagonal3Values(2 - squash, squash, 1),
            child: egg,
          ),
        ),
      );
    } else {
      // Sau khi vỡ: nửa dưới ở lại rồi mờ (2950–3500), nửa trên bay.
      final bottomOpacity = 1 - _ramp(ms, 2950, 3500);
      final tp = _ramp(ms, _burstMs.toDouble(), _burstMs + 800.0);
      final fly = Curves.easeOut.transform(tp);
      final topOpacity = 1 - _ramp(tp, 0.6, 1.0);
      Widget bottom = eggCrackArtReady
          ? _egg(shellBottomAsset(species))
          : ClipPath(
              clipper: const _ShellClipper(top: false),
              child: _egg(eggSpeciesAssets[species]!),
            );
      Widget top = eggCrackArtReady
          ? _egg(shellTopAsset(species))
          : ClipPath(
              clipper: const _ShellClipper(top: true),
              child: _egg(eggSpeciesAssets[species]!),
            );
      children.add(
        Opacity(
          key: const Key('hatch-shell-bottom'),
          opacity: bottomOpacity,
          child: bottom,
        ),
      );
      children.add(
        Opacity(
          key: const Key('hatch-shell-top'),
          opacity: topOpacity,
          child: Transform.translate(
            offset: Offset(80 * tp, -170 * fly),
            child: Transform.rotate(
              alignment: const Alignment(0, -0.3),
              angle: 1.4 * tp,
              child: top,
            ),
          ),
        ),
      );
    }

    // Mảnh vỏ văng ra (lúc nứt và lúc vỡ).
    children.add(
      SizedBox(
        width: _boxW,
        height: _boxH,
        child: CustomPaint(
          painter: _ChipPainter(ms: ms, color: shell),
        ),
      ),
    );

    // Ánh sáng + sao bung lúc vỡ (Icons.star thay ký tự `✦`: Nunito
    // không có ký tự dingbat nên chữ sẽ thành ô vuông trên máy thật).
    if (ms > _burstMs) {
      final t = _ramp(ms, _burstMs.toDouble(), _burstMs + 800.0);
      final flash = 1 - _ramp(ms, _burstMs.toDouble(), _burstMs + 300.0);
      children.add(
        IgnorePointer(
          child: SizedBox(
            width: _boxW,
            height: _boxH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (flash > 0.01)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Color.fromRGBO(255, 244, 200, 0.85 * flash),
                            const Color(0x00FFF4C8),
                          ],
                          stops: const [0.0, 0.6],
                        ),
                      ),
                    ),
                  ),
                if (t > 0.01 && t < 1)
                  for (var i = 0; i < _sparkleAngles.length; i++)
                    Positioned(
                      left:
                          100 +
                          math.cos(_sparkleAngles[i]) *
                              (30 + 70 * Curves.easeOut.transform(t)) -
                          11,
                      top:
                          105 +
                          math.sin(_sparkleAngles[i]) *
                              (30 + 70 * Curves.easeOut.transform(t)) -
                          11,
                      child: Opacity(
                        opacity: 1 - t,
                        child: Icon(
                          Icons.star,
                          size: i.isEven ? 22 : 15,
                          color: i.isEven
                              ? const Color(0xFFFFC93C)
                              : const Color(0xFFFFE08A),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      key: const Key('hatch-stage'),
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: children,
    );
  }
}

/// 8 hướng sao bung (rad), lệch đều quanh tâm.
final List<double> _sparkleAngles = <double>[
  for (var i = 0; i < 8; i++) -math.pi / 2 + i * math.pi / 4 + 0.2,
];

/// Cắt ảnh trứng thành hai nửa theo đường ziczac (khung 200x220):
/// nửa trên / nửa dưới ghép lại đúng bằng ảnh trứng nguyên.
class _ShellClipper extends CustomClipper<Path> {
  const _ShellClipper({required this.top});

  final bool top;

  static const List<Offset> _zigzag = <Offset>[
    Offset(0, 100),
    Offset(30, 92),
    Offset(55, 108),
    Offset(80, 94),
    Offset(100, 106),
    Offset(125, 92),
    Offset(150, 108),
    Offset(175, 94),
    Offset(200, 100),
  ];

  @override
  Path getClip(Size size) {
    final sx = size.width / _boxW;
    final sy = size.height / _boxH;
    final path = Path();
    if (top) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
    }
    for (final p in _zigzag.reversed) {
      path.lineTo(p.dx * sx, p.dy * sy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _ShellClipper old) => old.top != top;
}

/// Vết nứt trên trứng, 3 bước (khung 200x220, thân trứng x 45–155,
/// y 26–184): mỗi bước là vài đoạn gãy khúc, [c1]/[c2]/[c3] là mức
/// đã vẽ (0–1) nên vết nứt chạy dài ra từ từ (cắt theo
/// `PathMetric`). Bước sau nối tiếp và tách nhánh từ bước trước.
class HatchCrackPainter extends CustomPainter {
  const HatchCrackPainter({this.c1 = 0, this.c2 = 0, this.c3 = 0});

  final double c1;
  final double c2;
  final double c3;

  static Path _line(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  // Bước 1: một vết ngắn từ đỉnh.
  static final List<Path> _step1 = [
    _line(const [
      Offset(100, 30),
      Offset(92, 48),
      Offset(104, 62),
      Offset(95, 78),
    ]),
  ];
  // Bước 2: vết dài thêm + một nhánh.
  static final List<Path> _step2 = [
    _line(const [Offset(95, 78), Offset(106, 94), Offset(97, 108)]),
    _line(const [Offset(104, 62), Offset(122, 70), Offset(128, 84)]),
  ];
  // Bước 3: vết xuống tới đáy + nhiều nhánh (sắp vỡ).
  static final List<Path> _step3 = [
    _line(const [
      Offset(97, 108),
      Offset(108, 122),
      Offset(98, 138),
      Offset(104, 154),
    ]),
    _line(const [Offset(97, 108), Offset(78, 114), Offset(70, 130)]),
    _line(const [Offset(106, 94), Offset(124, 100), Offset(132, 114)]),
  ];

  void _draw(
    Canvas canvas,
    List<Path> paths,
    double progress,
    Paint dark,
    Paint light,
  ) {
    if (progress <= 0) return;
    for (final path in paths) {
      for (final metric in path.computeMetrics()) {
        final part = metric.extractPath(0, metric.length * progress);
        canvas.drawPath(part.shift(const Offset(1, 1)), light);
        canvas.drawPath(part, dark);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _boxW, size.height / _boxH);
    final dark = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final light = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _draw(canvas, _step1, c1, dark, light);
    _draw(canvas, _step2, c2, dark, light);
    _draw(canvas, _step3, c3, dark, light);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HatchCrackPainter old) =>
      old.c1 != c1 || old.c2 != c2 || old.c3 != c3;
}

/// Mảnh vỏ nhỏ văng ra: (thời điểm bắt đầu ms, gốc, vận tốc px/giây,
/// quay rad/giây, cỡ px). Rơi theo trọng lực rồi mờ trong 0,6 giây.
class _Chip {
  const _Chip(
    this.startMs,
    this.origin,
    this.vx,
    this.vy,
    this.spin,
    this.size,
  );

  final double startMs;
  final Offset origin;
  final double vx;
  final double vy;
  final double spin;
  final double size;
}

const List<_Chip> _chips = <_Chip>[
  // Lúc nứt bước 2.
  _Chip(1650, Offset(106, 94), 60, -90, 6, 7),
  _Chip(1670, Offset(92, 62), -70, -80, -7, 6),
  _Chip(1700, Offset(125, 76), 90, -60, 5, 5),
  // Lúc nứt bước 3.
  _Chip(2450, Offset(108, 122), 80, -110, 8, 8),
  _Chip(2470, Offset(78, 114), -90, -100, -6, 7),
  _Chip(2500, Offset(124, 100), 100, -90, 7, 6),
  _Chip(2520, Offset(100, 140), -50, -70, -5, 6),
  // Lúc vỡ: mảnh to hơn bay tung.
  _Chip(2700, Offset(60, 98), -150, -170, -9, 11),
  _Chip(2700, Offset(140, 98), 160, -180, 9, 12),
  _Chip(2710, Offset(100, 100), 20, -220, 7, 10),
  _Chip(2710, Offset(80, 104), -110, -120, -6, 9),
  _Chip(2720, Offset(125, 104), 120, -140, 8, 9),
];

class _ChipPainter extends CustomPainter {
  const _ChipPainter({required this.ms, required this.color});

  final double ms;
  final Color color;

  static const double _gravity = 520; // px/giây²
  static const double _lifeMs = 650;

  @override
  void paint(Canvas canvas, Size size) {
    for (final chip in _chips) {
      final age = ms - chip.startMs;
      if (age < 0 || age > _lifeMs) continue;
      final t = age / 1000;
      final pos = Offset(
        chip.origin.dx + chip.vx * t,
        chip.origin.dy + chip.vy * t + 0.5 * _gravity * t * t,
      );
      final opacity = 1 - ((age - _lifeMs * 0.5) / (_lifeMs * 0.5)).clamp(0, 1);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(chip.spin * t);
      final s = chip.size;
      final path = Path()
        ..moveTo(-s * 0.5, s * 0.4)
        ..lineTo(0, -s * 0.6)
        ..lineTo(s * 0.55, s * 0.35)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: opacity.toDouble()),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF8D6E63)
              .withValues(alpha: opacity.toDouble())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ChipPainter old) =>
      old.ms != ms || old.color != color;
}
