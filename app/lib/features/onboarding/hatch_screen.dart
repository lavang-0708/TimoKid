/// Màn trứng nở (T2-03, DESIGN "Pet": trứng nở sau chặng toán đầu
/// tiên).
///
/// Hiệu ứng đơn giản, chạy một lần rồi dừng (không lặp vô hạn để
/// `pumpAndSettle` trong test dừng được): trứng rung → vết nứt hiện
/// → trứng vỡ (phóng to + mờ dần), pet mới nở hiện ra nảy lên + sao
/// bung ra xung quanh. Xong mới hiện nút "Tiếp tục": bấm thì đánh dấu
/// đã nở ([EggService.consumeHatchCelebration]) rồi về Thị trấn.
///
/// Màn chỉ vào được khi có lần nở đang chờ (`hatch_pending`); nếu
/// mở trực tiếp mà không có trứng hay không có lần chờ thì hiện thông
/// báo và nút về Thị trấn. Pet và trứng là PNG thật (PR #21,
/// `app/assets/images/pets/`); vết nứt vẽ bằng CustomPaint (thay
/// file SVG tạm `egg_crack.svg` đã bỏ).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database_provider.dart';
import '../../core/widgets/press_bounce.dart';
import '../town/town_screen.dart';
import 'egg_service.dart';
import 'onboarding_config.dart';

class HatchScreen extends ConsumerStatefulWidget {
  const HatchScreen({super.key});

  static const String route = '/hatch';

  @override
  ConsumerState<HatchScreen> createState() => _HatchScreenState();
}

class _HatchScreenState extends ConsumerState<HatchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shake;
  late final Animation<double> _crack;
  late final Animation<double> _eggScale;
  late final Animation<double> _eggFade;
  late final Animation<double> _petScale;
  late final Animation<double> _stars;

  String? _species;
  bool _loading = true;
  bool _showContinue = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    // Rung: 0–33% (xoay lắc qua lại). Nứt: 33–66% (vết nứt mờ dần
    // hiện). Vỡ: 66–100% (trứng phóng to + mờ dần, pet nảy lên).
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 10),
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 0.12), weight: 5),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.12, end: -0.12),
        weight: 5,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.12, end: 0.12),
        weight: 5,
      ),
      TweenSequenceItem(tween: Tween<double>(begin: 0.12, end: 0), weight: 8),
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 67),
    ]).animate(_controller);
    _crack = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.33, 0.66, curve: Curves.easeIn),
      ),
    );
    _eggScale = Tween<double>(begin: 1, end: 1.25).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.66, 1.0, curve: Curves.easeOut),
      ),
    );
    _eggFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.66, 1.0, curve: Curves.easeIn),
      ),
    );
    _petScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.66, 1.0, curve: Curves.elasticOut),
      ),
    );
    // Sao bung: 0–66% chưa có sao, lúc trứng vỡ (66–100%) sao bay
    // ra từ giữa rồi mờ dần (opacity 1 → 0 theo cùng nhịp).
    _stars = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.66, 1.0, curve: Curves.easeOut),
      ),
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

  Future<void> _continue() async {
    final db = ref.read(databaseProvider);
    final childId = await db.ensureSeeded();
    await EggService(db: db).consumeHatchCelebration(childId);
    if (!mounted) return;
    context.go(TownScreen.route);
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
            ? _EmptyHatch(onBack: () => context.go(TownScreen.route))
            : _HatchAnimation(
                species: _species!,
                shake: _shake,
                crack: _crack,
                eggScale: _eggScale,
                eggFade: _eggFade,
                petScale: _petScale,
                stars: _stars,
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

/// Hoạt cảnh nở: trứng (rung → nứt → vỡ) rồi pet mới nở nảy lên.
class _HatchAnimation extends StatelessWidget {
  const _HatchAnimation({
    required this.species,
    required this.shake,
    required this.crack,
    required this.eggScale,
    required this.eggFade,
    required this.petScale,
    required this.stars,
    required this.showContinue,
    required this.onContinue,
  });

  final String species;
  final Animation<double> shake;
  final Animation<double> crack;
  final Animation<double> eggScale;
  final Animation<double> eggFade;
  final Animation<double> petScale;
  final Animation<double> stars;
  final bool showContinue;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final petName = newbornSpeciesNames[species] ?? 'pet';
    // Bố cục ngang (màn hình ngang): hoạt cảnh bên trái, chữ + nút
    // bên phải — vừa cả màn 640x320 mà không cần cuộn.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 200,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: shake,
                builder: (context, child) =>
                    Transform.rotate(angle: shake.value, child: child),
                child: AnimatedBuilder(
                  animation: Listenable.merge([eggScale, eggFade]),
                  builder: (context, child) => Transform.scale(
                    scale: eggScale.value,
                    child: Opacity(opacity: eggFade.value, child: child),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        eggSpeciesAssets[species]!,
                        width: 200,
                        height: 220,
                        fit: BoxFit.contain,
                      ),
                      AnimatedBuilder(
                        animation: crack,
                        builder: (context, child) =>
                            Opacity(opacity: crack.value, child: child),
                        child: const SizedBox(
                          width: 200,
                          height: 220,
                          child: CustomPaint(painter: _CrackPainter()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: petScale,
                builder: (context, child) =>
                    Transform.scale(scale: petScale.value, child: child),
                child: Image.asset(
                  newbornSpeciesAssets[species]!,
                  width: 200,
                  height: 220,
                  fit: BoxFit.contain,
                ),
              ),
              // Sao bung lúc trứng vỡ: 5 sao bay ra từ giữa khung
              // rồi mờ dần (theo [stars], 0.66–1.0 của hoạt cảnh).
              // Dùng Icons.star (MaterialIcons) thay vì ký tự `✦`:
              // Nunito không có ký tự dingbat nên chữ sẽ thành ô
              // vuông trên máy thật.
              AnimatedBuilder(
                animation: stars,
                builder: (context, child) {
                  final t = stars.value;
                  if (t <= 0.01) return const SizedBox.shrink();
                  return Opacity(
                    opacity: 1 - t,
                    child: Stack(
                      children: [
                        for (final offset in _starOffsets)
                          Positioned(
                            left: 100 + offset.dx * t - 11,
                            top: 110 + offset.dy * t - 11,
                            child: const Icon(
                              Icons.star,
                              size: 22,
                              color: Color(0xFFFFC93C),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
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
              if (showContinue)
                PressBounce(
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
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Vị trí sao bung lúc trứng vỡ (tương đối so với tâm khung 200x220):
/// 5 sao bay ra theo 5 hướng rồi mờ dần.
const List<Offset> _starOffsets = <Offset>[
  Offset(-70, -80),
  Offset(70, -70),
  Offset(-85, 20),
  Offset(85, 30),
  Offset(0, -95),
];

/// Vết nứt trên trứng lúc nở: đường gãy khúc vẽ bằng CustomPaint
/// (thay file SVG tạm `egg_crack.svg` đã bỏ cùng `assets/temp/`).
class _CrackPainter extends CustomPainter {
  const _CrackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.08)
      ..lineTo(size.width * 0.42, size.height * 0.3)
      ..lineTo(size.width * 0.58, size.height * 0.48)
      ..lineTo(size.width * 0.45, size.height * 0.68)
      ..lineTo(size.width * 0.55, size.height * 0.9);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
