/// Widget của mùa (T5-02): biển ở Thị trấn, ruy băng trên thẻ món, thẻ
/// "chưa có món" của tab Bộ sưu tập mùa.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/widgets/game_ui.dart';
import 'season_config.dart';

/// Biển mùa ở Thị trấn: "Mùa Tết!" + ưu đãi. Không bấm được.
class SeasonBanner extends StatelessWidget {
  const SeasonBanner({super.key, required this.season});

  final SeasonDef season;

  @override
  Widget build(BuildContext context) {
    final color = Color(season.colorValue);
    return IgnorePointer(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color, Color.lerp(color, Colors.black, 0.25)!],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  offset: Offset(0, 3),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  season.bannerTitle,
                  key: const Key('season-banner-title'),
                  style: gameOutlinedText(20),
                ),
                Text(
                  season.bannerSubtitle,
                  key: const Key('season-banner-subtitle'),
                  style: gameOutlinedText(11.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ruy băng nhỏ chéo ở góc thẻ món thuộc mùa ("Mùa Tết").
class SeasonRibbon extends StatelessWidget {
  const SeasonRibbon({super.key, required this.seasonId});

  final String seasonId;

  @override
  Widget build(BuildContext context) {
    final season = SeasonConfig.byId(seasonId);
    if (season == null) return const SizedBox.shrink();
    return Transform.rotate(
      angle: 0.24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(
          color: Color(season.colorValue),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              offset: Offset(0, 1.5),
              blurRadius: 2,
            ),
          ],
        ),
        child: Text(
          season.ribbon,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Thẻ báo mùa này chưa có món riêng (Trung thu, Giáng sinh khi chưa có hình).
class SeasonEmptyCard extends StatelessWidget {
  const SeasonEmptyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: const Key('shop-season-empty'),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD0BFF0), width: 3),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration_rounded, size: 44, color: Color(0xFF8E6FD8)),
            SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đồ của mùa này đang được vẽ!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: gameInk,
                    ),
                  ),
                  Text(
                    'Bé vẫn được +50% xu khi làm đề ngày nhé.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: gameInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
