/// Màn trứng nở (T2-03, DESIGN "Pet": trứng nở sau chặng toán đầu
/// tiên).
///
/// Hiệu ứng đơn giản, chạy một lần rồi dừng (không lặp vô hạn để
/// `pumpAndSettle` trong test dừng được): trứng rung → vết nứt hiện
/// → trứng vỡ (phóng to + mờ dần) và pet mới nở hiện ra nảy lên.
/// Xong mới hiện nút "Tiếp tục": bấm thì đánh dấu đã nở
/// ([EggService.consumeHatchCelebration]) rồi về Thị trấn.
///
/// Màn chỉ vào được khi có lần nở đang chờ (`hatch_pending`); nếu
/// mở trực tiếp mà không có trứng hay không có lần chờ thì hiện thông
/// báo và nút về Thị trấn. Pet và trứng là hình tạm (SVG vẽ đơn giản,
/// xem `app/assets/temp/eggs/` và `app/assets/temp/pets/`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database_provider.dart';
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
        ElevatedButton.icon(
          key: const Key('hatch-back-button'),
          icon: const Text('←', style: TextStyle(fontSize: 24)),
          label: const Text('Về Thị trấn', style: TextStyle(fontSize: 20)),
          style: ElevatedButton.styleFrom(minimumSize: const Size(56, 56)),
          onPressed: onBack,
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
    required this.showContinue,
    required this.onContinue,
  });

  final String species;
  final Animation<double> shake;
  final Animation<double> crack;
  final Animation<double> eggScale;
  final Animation<double> eggFade;
  final Animation<double> petScale;
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
                      SvgPicture.asset(eggSpeciesAssets[species]!),
                      AnimatedBuilder(
                        animation: crack,
                        builder: (context, child) =>
                            Opacity(opacity: crack.value, child: child),
                        child: SvgPicture.asset(
                          'assets/temp/eggs/egg_crack.svg',
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
                child: SvgPicture.asset(newbornSpeciesAssets[species]!),
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
                ElevatedButton.icon(
                  key: const Key('hatch-continue-button'),
                  label: const Text('Tiếp tục', style: TextStyle(fontSize: 22)),
                  icon: const Text('→', style: TextStyle(fontSize: 24)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(56, 56),
                  ),
                  onPressed: onContinue,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
