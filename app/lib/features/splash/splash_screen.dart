/// Màn khởi động (góp ý 21/11): mở app thì hiện logo + thanh tải nhanh
/// (~1,8 giây) rồi mới vào màn đầu (mở đầu / nở trứng / Phòng), như game.
///
/// Hiệu ứng là một lượt rồi dừng (không lặp) nên `pumpAndSettle` vẫn
/// dừng được; khi cổng [AnimationGate] tắt (test) thì chuyển ngay.
/// Logo và nền là ảnh lô 6 (`ui_logo.png`, `ui_splash_bg.png`).
library;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/animation/animation_gate.dart';
import '../../core/widgets/game_ui.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});

  static const String route = '/splash';

  /// Route đi tiếp sau màn khởi động.
  final String next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (!AnimationGate.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _go());
      return;
    }
    _c.forward().whenComplete(_go);
    // Nạp trước ảnh nền Phòng/Thị trấn trong lúc chờ để vào màn sau mượt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final p in [
        'assets/images/backgrounds/room_v3.png',
        'assets/images/town/town_v3.png',
      ]) {
        precacheImage(AssetImage(p), context, onError: (_, _) {});
      }
    });
  }

  void _go() {
    if (!mounted) return;
    context.go(widget.next);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('splash-screen'),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFE3F0),
          image: DecorationImage(
            image: AssetImage('$uiArt/ui_splash_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              final pop = Curves.elasticOut.transform((t / 0.45).clamp(0, 1));
              return Column(
                children: [
                  const Spacer(),
                  Transform.scale(scale: 0.6 + 0.4 * pop, child: const _Logo()),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 220,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        key: const Key('splash-progress'),
                        value: AnimationGate.enabled ? t : null,
                        minHeight: 12,
                        backgroundColor: const Color(0x66FFFFFF),
                        color: const Color(0xFFFF9EB5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Đang vào thị trấn…', style: gameOutlinedText(14)),
                  const Spacer(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Logo TimoKid (ảnh lô 6: chữ + bé gái, bé trai, 3 pet) + khẩu hiệu.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          '$uiArt/ui_logo.png',
          key: const Key('splash-title'),
          height: 190,
          semanticLabel: 'TimoKid',
        ),
        Text('Học toán TIMO mà chơi', style: gameOutlinedText(16)),
      ],
    );
  }
}
