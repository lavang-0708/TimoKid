/// Sảnh Đấu trường (T2-10) — route `/arena`: luật thi bằng lời dễ hiểu,
/// điểm cao nhất, trạng thái thưởng hôm nay và nút "Bắt đầu thi".
///
/// Từ Thị trấn (khu Đấu trường hoặc nút tròn trên HUD) vào đây; nút
/// Trở về tròn về Thị trấn. Nền xem [ArenaBackground].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database_provider.dart';
import '../../core/widgets/game_ui.dart';
import '../../core/widgets/round_back_button.dart';
import 'arena_config.dart';
import 'arena_exam_screen.dart';
import 'arena_service.dart';
import 'arena_widgets.dart';
import 'league_service.dart';
import 'league_widgets.dart';

class ArenaLobbyScreen extends ConsumerStatefulWidget {
  const ArenaLobbyScreen({super.key});

  static const String route = '/arena';

  @override
  ConsumerState<ArenaLobbyScreen> createState() => _ArenaLobbyScreenState();
}

class _ArenaLobbyScreenState extends ConsumerState<ArenaLobbyScreen> {
  ArenaSummary? _summary;
  LeagueWeek? _week;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = ref.read(databaseProvider);
      final childId = await db.ensureSeeded();
      final summary = await ArenaService(db: db).summary(childId);
      final league = LeagueService(db: db);
      final week = await league.week(childId);
      final chest = await league.pendingChest(childId);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _week = week;
      });
      if (chest != null) {
        // Rương tuần trước: bé bấm mở, nhận một lần rồi tải lại số dư.
        await showLeagueChestDialog(
          context,
          chest: chest,
          onClaim: () => league.claimChest(childId, weekStart: chest.weekStart),
        );
        if (!mounted) return;
        final fresh = await ArenaService(db: db).summary(childId);
        if (!mounted) return;
        setState(() => _summary = fresh);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      key: const Key('arena-lobby-screen'),
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
                            'Đấu trường TIMO',
                            key: const Key('arena-title'),
                            style: gameOutlinedText(26),
                          ),
                        ),
                      ),
                      if (summary != null)
                        ArenaWalletHud(xu: summary.xu, gems: summary.gems),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: _error != null
                        ? Center(
                            child: Text(
                              'Không tải được Đấu trường: $_error',
                              style: gameOutlinedText(16),
                            ),
                          )
                        : summary == null
                        ? const Center(child: CircularProgressIndicator())
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 6, child: _RulesCard()),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 4,
                                child: _StatusPanel(
                                  summary: summary,
                                  week: _week,
                                  onStart: () =>
                                      context.go(ArenaExamScreen.route),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ luật thi (cuộn được khi màn thấp).
class _RulesCard extends StatelessWidget {
  static const _inkText = TextStyle(
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: gameInk,
  );

  Widget _rule(IconData icon, Color color, String text, {Key? key}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, key: key, style: _inkText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const format = ArenaFormat.heat;
    final names = arenaSections.map((s) => s.name).join(', ');
    return Container(
      key: const Key('arena-rules'),
      decoration: BoxDecoration(
        color: const Color(0xEEFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rule(
              Icons.quiz_rounded,
              const Color(0xFF7E63C9),
              '${format.totalQuestions} câu, chia ${format.sections} phần: '
              '$names.',
            ),
            _rule(
              Icons.timer_rounded,
              const Color(0xFFF08A3C),
              '${format.minutes} phút, đồng hồ đếm ngược. Hết giờ là tự nộp bài.',
            ),
            _rule(
              Icons.visibility_off_rounded,
              const Color(0xFF3E8FD6),
              'Không báo đúng sai khi làm. Nộp bài xong mới biết điểm.',
            ),
            _rule(
              Icons.diamond_rounded,
              const Color(0xFFA07BE0),
              'Thưởng kim cương cho bài đầu tiên mỗi ngày: '
              'Vàng ${ArenaMedal.gold.gems}, Bạc ${ArenaMedal.silver.gems}, '
              'Đồng ${ArenaMedal.bronze.gems}, '
              'Tham gia ${ArenaMedal.participant.gems}.',
              key: const Key('arena-rule-rewards'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cột phải: điểm cao nhất, trạng thái hôm nay, nút bắt đầu.
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.summary,
    required this.week,
    required this.onStart,
  });

  final ArenaSummary summary;
  final LeagueWeek? week;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final best = summary.bestScore;
    final bestMedal = summary.bestMedal;
    // Nút Bắt đầu ghim ở đáy để luôn thấy; thẻ phía trên cuộn được.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (week != null) ...[
                  LeagueCard(week: week!),
                  const SizedBox(height: 6),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x99FFFFFF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      if (bestMedal != null) ...[
                        ArenaMedalBadge(medal: bestMedal, size: 44),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          best == null
                              ? 'Bé chưa thi lần nào'
                              : 'Điểm cao nhất: $best/${ArenaFormat.heat.maxScore}',
                          key: const Key('arena-best-score'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: gameInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  summary.rewardedToday
                      ? 'Hôm nay đã nhận thưởng, thi tiếp để luyện tập'
                      : 'Hôm nay chưa nhận kim cương. Thi ngay nhé!',
                  key: const Key('arena-today-status'),
                  textAlign: TextAlign.center,
                  style: gameOutlinedText(13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        ArenaCandyButton(
          key: const Key('arena-start-button'),
          text: 'Bắt đầu thi',
          height: 52,
          fontSize: 22,
          onPressed: onStart,
        ),
      ],
    );
  }
}
