/// Thành phần giao diện dùng chung của Đấu trường (T2-10): nền, nút
/// kẹo, huy chương, hàng kim cương.
///
/// Khi [arenaArtReady] là false (ảnh họa sĩ chưa về) mọi thứ vẽ bằng
/// code: nền chuyển màu, icon `emoji_events` cho huy chương, ảnh
/// `ui_gem.webp` có sẵn cho kim cương. Khi true thì dùng ảnh thật.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/widgets/game_ui.dart';
import '../../core/widgets/press_bounce.dart';
import 'arena_config.dart';

/// Nền màn Đấu trường: ảnh `arena_bg.webp` khi [arenaArtReady], không
/// thì nền chuyển màu tím-xanh vẽ bằng code.
class ArenaBackground extends StatelessWidget {
  const ArenaBackground({super.key});

  @override
  Widget build(BuildContext context) {
    if (arenaArtReady) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(arenaBackgroundAsset),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7E63C9), Color(0xFF5B8BD9), Color(0xFFA9D6F5)],
        ),
      ),
    );
  }
}

/// Nút kẹo to (mẫu cửa hàng): viền dưới đậm, bóng, nhấn thì nảy.
class ArenaCandyButton extends StatelessWidget {
  const ArenaCandyButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = const Color(0xFF4CC38A),
    this.height = 44,
    this.fontSize = 18,
  });

  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final base = enabled ? color : const Color(0xFFC9C3D6);
    final top = Color.lerp(base, Colors.white, 0.3)!;
    final edge = Color.lerp(base, Colors.black, 0.28)!;
    return PressBounce(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: text,
          child: Container(
            height: height + 4,
            padding: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: edge,
              borderRadius: BorderRadius.circular(height / 2 + 2),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [top, base],
                ),
                borderRadius: BorderRadius.circular(height / 2),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  maxLines: 1,
                  style: gameOutlinedText(fontSize),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Màu icon huy chương khi chưa có ảnh thật.
Color arenaMedalColor(ArenaMedal medal) => switch (medal) {
  ArenaMedal.gold => const Color(0xFFFFC21A),
  ArenaMedal.silver => const Color(0xFFB8C0CC),
  ArenaMedal.bronze => const Color(0xFFCD7F32),
  ArenaMedal.participant => const Color(0xFF8FB8DE),
};

/// Huy chương: ảnh `medal_<mã>.webp` khi [arenaArtReady], không thì
/// icon cúp `emoji_events` tô màu vàng/bạc/đồng.
class ArenaMedalBadge extends StatelessWidget {
  const ArenaMedalBadge({super.key, required this.medal, this.size = 72});

  final ArenaMedal medal;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (arenaArtReady) {
      return Image.asset(
        'assets/images/ui/medal_${medal.code}.webp',
        width: size,
        height: size,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: arenaMedalColor(medal), width: size * 0.06),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        Icons.emoji_events,
        size: size * 0.62,
        color: arenaMedalColor(medal),
      ),
    );
  }
}

/// Hàng "+N" kèm viên kim cương (ảnh `ui_gem.webp` có sẵn).
class ArenaGemAmount extends StatelessWidget {
  const ArenaGemAmount({super.key, required this.amount, this.size = 28});

  final int amount;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('$uiArt/ui_gem.webp', width: size, height: size),
        const SizedBox(width: 4),
        Text('+$amount', style: gameOutlinedText(size * 0.8)),
      ],
    );
  }
}

/// Dòng xu + kim cương của bé ở góc màn (HUD kiểu game).
class ArenaWalletHud extends StatelessWidget {
  const ArenaWalletHud({super.key, required this.xu, required this.gems});

  final int xu;
  final int gems;

  @override
  Widget build(BuildContext context) {
    return GameHudBar(
      children: [
        GameStat(
          icon: Icons.monetization_on_rounded,
          image: '$uiArt/ui_coin.webp',
          color: const Color(0xFFF5B83D),
          text: '$xu',
          textKey: const Key('arena-xu-balance'),
        ),
        GameStat(
          icon: Icons.diamond_rounded,
          image: '$uiArt/ui_gem.webp',
          color: const Color(0xFFA07BE0),
          text: '$gems',
          textKey: const Key('arena-gem-balance'),
        ),
      ],
    );
  }
}
