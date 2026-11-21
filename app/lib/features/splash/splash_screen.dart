/// Màn khởi động (góp ý 21/11): mở app thì hiện logo + thanh tải nhanh
/// (~1,8 giây) rồi mới vào màn đầu (mở đầu / nở trứng / Phòng), như game.
///
/// Hiệu ứng là một lượt rồi dừng (không lặp) nên `pumpAndSettle` vẫn
/// dừng được; khi cổng [AnimationGate] tắt (test) thì chuyển ngay.
/// Logo tạm vẽ bằng chữ + ảnh 2 bé; khi Muse vẽ xong `ui_logo.png` thì
/// thay vào [_Logo].
library;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/animation/animation_gate.dart';
import '../../core/widgets/game_ui.dart';
import '../character/kid_assets.dart';

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
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBFE3FF), Color(0xFFFFE3F0), Color(0xFFFFF3D9)],
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

/// Logo tạm: 2 bé hai bên + chữ "TimoKid" tròn mập viền trắng.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    Widget kid(String g) => SizedBox(
      height: 150,
      child: Image.asset(kidFullAsset(g, 1, wave: true), fit: BoxFit.contain),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        kid('girl'),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Text(
                  'TimoKid',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 8
                      ..color = Colors.white,
                  ),
                ),
                const Text(
                  'TimoKid',
                  key: Key('splash-title'),
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8E6FD8),
                    shadows: [
                      Shadow(color: Color(0x553B2E5A), offset: Offset(0, 4)),
                    ],
                  ),
                ),
              ],
            ),
            Text('Học toán TIMO mà chơi', style: gameOutlinedText(16)),
            const SizedBox(height: 18),
          ],
        ),
        const SizedBox(width: 8),
        kid('boy'),
      ],
    );
  }
}
