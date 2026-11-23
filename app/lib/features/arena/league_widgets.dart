/// Widget Hạng tuần: huy hiệu hạng, thẻ tiến độ cho sảnh Đấu trường và
/// hộp thoại rương cuối tuần (spec tuần 23/11, mục B).
///
/// Khi [leagueArtReady] false thì dùng icon Material; true thì dùng ảnh
/// `ui_league_<mã>.png` và `ui_chest_<mã>.png`.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/widgets/game_ui.dart';
import 'arena_widgets.dart';
import 'league_config.dart';
import 'league_service.dart';

/// Màu theo hạng.
Color leagueTierColor(LeagueTier tier) => switch (tier) {
  LeagueTier.bronze => const Color(0xFFCD7F32),
  LeagueTier.silver => const Color(0xFFA9B4C2),
  LeagueTier.gold => const Color(0xFFFFC21A),
  LeagueTier.diamond => const Color(0xFF4FC3F7),
};

/// Huy hiệu hạng tuần.
class LeagueBadge extends StatelessWidget {
  const LeagueBadge({super.key, required this.tier, this.size = 44});

  final LeagueTier tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (leagueArtReady) {
      return Image.asset(
        'assets/images/ui/ui_league_${tier.code}.png',
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
        border: Border.all(color: leagueTierColor(tier), width: size * 0.07),
      ),
      child: Icon(
        tier == LeagueTier.diamond ? Icons.diamond_rounded : Icons.shield,
        size: size * 0.58,
        color: leagueTierColor(tier),
      ),
    );
  }
}

/// Rương cuối tuần (icon tạm khi chưa có ảnh).
class LeagueChestIcon extends StatelessWidget {
  const LeagueChestIcon({super.key, required this.tier, this.size = 96});

  final LeagueTier tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (leagueArtReady) {
      return Image.asset(
        'assets/images/ui/ui_chest_${tier.code}.png',
        width: size,
        height: size,
      );
    }
    return Icon(
      Icons.inventory_2_rounded,
      size: size,
      color: leagueTierColor(tier),
    );
  }
}

/// Thẻ hạng tuần: huy hiệu, thanh tiến độ, số ngày còn lại.
class LeagueCard extends StatelessWidget {
  const LeagueCard({super.key, required this.week});

  final LeagueWeek week;

  @override
  Widget build(BuildContext context) {
    final tier = week.tier;
    final next = week.nextTier;
    final String title = tier == null
        ? 'Tuần này chưa có hạng'
        : 'Hạng tuần: ${tier.label}';
    final String hint = next == null
        ? 'Đã đạt hạng cao nhất!'
        : tier == null
        ? 'Thi một bài để lên hạng ${next.label}'
        : 'Còn ${week.pointsToNext} câu đúng để lên ${next.label}';
    final days = week.daysLeft <= 1
        ? 'Hôm nay là ngày cuối của tuần'
        : 'Còn ${week.daysLeft} ngày trong tuần';
    return Container(
      key: const Key('league-card'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x99FFFFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (tier != null)
            LeagueBadge(key: const Key('league-badge'), tier: tier, size: 44)
          else
            const Icon(Icons.shield_outlined, size: 44, color: gameInk),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  key: const Key('league-title'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: gameInk,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    key: const Key('league-progress'),
                    value: week.progress,
                    minHeight: 10,
                    backgroundColor: const Color(0x33000000),
                    color: tier == null
                        ? const Color(0xFF8FB8DE)
                        : leagueTierColor(next ?? tier),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tier == null ? hint : '$hint (${week.points} câu đúng)',
                  key: const Key('league-hint'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: gameInk,
                  ),
                ),
                Text(
                  days,
                  key: const Key('league-days-left'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: gameInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hộp thoại rương cuối tuần: bấm rương để mở, hiện số kim cương.
/// [onClaim] trả số kim cương vừa cộng.
Future<void> showLeagueChestDialog(
  BuildContext context, {
  required LeagueChest chest,
  required Future<int> Function() onClaim,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LeagueChestDialog(chest: chest, onClaim: onClaim),
  );
}

class _LeagueChestDialog extends StatefulWidget {
  const _LeagueChestDialog({required this.chest, required this.onClaim});

  final LeagueChest chest;
  final Future<int> Function() onClaim;

  @override
  State<_LeagueChestDialog> createState() => _LeagueChestDialogState();
}

class _LeagueChestDialogState extends State<_LeagueChestDialog> {
  int? _gems;
  bool _busy = false;

  Future<void> _open() async {
    if (_busy || _gems != null) return;
    setState(() => _busy = true);
    final gems = await widget.onClaim();
    if (!mounted) return;
    setState(() {
      _gems = gems;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.chest.tier;
    final opened = _gems != null;
    return Dialog(
      key: const Key('league-chest-dialog'),
      backgroundColor: const Color(0xFFFFF8E7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rương tuần trước: hạng ${tier.label}',
                key: const Key('league-chest-title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: gameInk,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                key: const Key('league-chest-open'),
                behavior: HitTestBehavior.opaque,
                onTap: _open,
                child: opened
                    ? Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color: leagueTierColor(tier),
                      )
                    : LeagueChestIcon(tier: tier, size: 80),
              ),
              const SizedBox(height: 8),
              if (!opened)
                const Text(
                  'Bấm vào rương để mở nhé!',
                  key: Key('league-chest-hint'),
                  style: TextStyle(fontSize: 15, color: gameInk),
                )
              else ...[
                ArenaGemAmount(amount: _gems!, size: 28),
                const SizedBox(height: 8),
                ArenaCandyButton(
                  key: const Key('league-chest-close'),
                  text: 'Tuyệt vời',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
