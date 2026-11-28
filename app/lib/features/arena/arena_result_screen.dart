/// Màn Kết quả Đấu trường (T2-10) — route `/arena/result`.
///
/// CHỈ hiện số liệu tổng: "Đúng X/25" (Chung kết X/30), "Y/100 điểm", số câu đúng từng
/// phần, huy chương và kim cương thưởng. KHÔNG lộ câu nào đúng/sai và
/// không có đáp án (yêu cầu của chủ dự án) — [ArenaResult] cũng không
/// mang thông tin đó nên màn này không thể hiện ra được.
///
/// Thưởng chỉ có ở bài đầu tiên trong ngày; các bài sau hiện "Hôm nay
/// đã nhận thưởng, thi tiếp để luyện tập".
library;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/fx_particles.dart';
import '../../core/widgets/game_ui.dart';
import '../../core/widgets/round_back_button.dart';
import 'arena_config.dart';
import 'arena_exam_screen.dart';
import 'arena_lobby_screen.dart';
import 'arena_service.dart';
import 'arena_widgets.dart';

class ArenaResultScreen extends StatelessWidget {
  const ArenaResultScreen({super.key, this.result});

  static const String route = '/arena/result';

  /// Kết quả vừa nộp (qua GoRouter `extra`).
  final ArenaResult? result;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    if (result == null) {
      return Scaffold(
        key: const Key('arena-result-screen'),
        body: Stack(
          children: [
            const Positioned.fill(child: ArenaBackground()),
            SafeArea(
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: RoundBackButton(key: Key('arena-back-button')),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Chưa có kết quả thi',
                        style: gameOutlinedText(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final score = result.score;
    final medal = score.medal;
    return Scaffold(
      key: const Key('arena-result-screen'),
      backgroundColor: const Color(0xFF7E63C9),
      body: Stack(
        children: [
          const Positioned.fill(child: ArenaBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      const RoundBackButton(
                        key: Key('arena-back-button'),
                        size: 44,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            result.format.code == ArenaFormat.finalRound.code
                                ? 'Kết quả Chung kết'
                                : 'Kết quả Đấu trường',
                            style: gameOutlinedText(24),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xEEFFFFFF),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: LayoutBuilder(
                                    builder: (context, c) => ArenaMedalBadge(
                                      medal: medal,
                                      size: c.maxHeight.clamp(40.0, 96.0),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    medal == ArenaMedal.participant
                                        ? 'Tham gia'
                                        : 'Huy chương ${medal.label}',
                                    key: const Key('arena-result-medal'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: gameInk,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            // Màn thấp/font rộng thì thu cả khối lại vừa cột
                            // thay vì tràn (khối rộng tối đa 280 dp).
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 280,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'Đúng ${score.correct}/${score.total}',
                                          key: const Key(
                                            'arena-result-correct',
                                          ),
                                          style: const TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.w900,
                                            color: gameInk,
                                          ),
                                        ),
                                      ),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '${score.points}/${score.maxPoints} điểm',
                                          key: const Key('arena-result-score'),
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF7E63C9),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          for (
                                            var i = 0;
                                            i < arenaSections.length;
                                            i++
                                          )
                                            Container(
                                              key: Key(
                                                'arena-result-section-$i',
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEDE7FA),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '${arenaSections[i].shortName} '
                                                '${score.sectionCorrect[i]}/'
                                                '${score.sectionTotal}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: gameInk,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            // Thu cả khối lại vừa cột khi màn thấp (như cột giữa).
                            child: LayoutBuilder(
                              builder: (context, c) => Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SizedBox(
                                    width: c.maxWidth,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (result.gemsAwarded > 0) ...[
                                          if (arenaArtReady)
                                            Image.asset(
                                              arenaGemChestAsset,
                                              height: 40,
                                            ),
                                          Center(
                                            child: Container(
                                              key: const Key(
                                                'arena-result-reward',
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF7E63C9),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: ArenaGemAmount(
                                                amount: result.gemsAwarded,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ] else
                                          Text(
                                            'Hôm nay đã nhận thưởng, thi tiếp để luyện tập',
                                            key: const Key(
                                              'arena-result-reward',
                                            ),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: gameInk,
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        ArenaCandyButton(
                                          key: const Key(
                                            'arena-result-retry-button',
                                          ),
                                          text: 'Thi lại',
                                          height: 36,
                                          fontSize: 16,
                                          onPressed: () => context.go(
                                            ArenaExamScreen.route,
                                            extra: result.format,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        ArenaCandyButton(
                                          key: const Key(
                                            'arena-result-lobby-button',
                                          ),
                                          text: 'Về sảnh',
                                          color: const Color(0xFF5BA8F5),
                                          height: 36,
                                          fontSize: 16,
                                          onPressed: () => context.go(
                                            ArenaLobbyScreen.route,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Được huy chương (Vàng/Bạc/Đồng) thì bắn pháo giấy (T2-08).
          if (medal != ArenaMedal.participant)
            const Positioned.fill(
              child: ConfettiBurst(key: Key('arena-medal-confetti')),
            ),
        ],
      ),
    );
  }
}
