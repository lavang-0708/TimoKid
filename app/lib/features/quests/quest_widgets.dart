/// Giao diện Nhiệm vụ ngày: nút trên HUD (chấm đỏ khi có quà) và bảng
/// nhiệm vụ (tuần 23/11, mục C).
///
/// Khi [questArtReady] false thì dùng icon Material tạm; true thì dùng
/// ảnh `ui_quest_*` / `ui_streak_*` (xem `quest_config.dart`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database_provider.dart';
import '../../core/widgets/game_ui.dart';
import '../arena/arena_widgets.dart';
import '../math/math_session.dart' show strandNames;
import 'quest_config.dart';
import 'quest_service.dart';

/// Tên hiển thị của một nhiệm vụ.
String questTitle(Quest q) {
  final strand = strandNames[q.strand] ?? q.strand ?? '';
  return switch (q.type) {
    QuestType.strandCorrect => 'Đúng ngay ${q.target} câu mảng $strand',
    QuestType.strandStage => 'Xong chặng ngày của tòa $strand',
    QuestType.towerFloor => 'Leo qua 1 tầng tháp',
    QuestType.arena => 'Làm bài Đấu trường hôm nay',
    QuestType.dailyComplete => 'Xong đề ngày',
    QuestType.reviewRetry => 'Làm lại đúng ${q.target} câu trong sổ ôn tập',
    QuestType.feedPet => 'Cho pet ăn',
    QuestType.playPet => 'Chơi với pet',
  };
}

IconData _questIcon(QuestType t) => switch (t) {
  QuestType.strandCorrect => Icons.check_circle_outline_rounded,
  QuestType.strandStage => Icons.apartment_rounded,
  QuestType.towerFloor => Icons.stairs_rounded,
  QuestType.arena => Icons.emoji_events,
  QuestType.dailyComplete => Icons.star_rounded,
  QuestType.reviewRetry => Icons.menu_book_rounded,
  QuestType.feedPet => Icons.restaurant_rounded,
  QuestType.playPet => Icons.sports_esports_rounded,
};

/// Nút nhiệm vụ trên HUD Thị trấn / Phòng; [showDot] vẽ chấm đỏ.
class QuestHudButton extends StatelessWidget {
  const QuestHudButton({
    super.key,
    required this.onPressed,
    required this.showDot,
  });

  final VoidCallback onPressed;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GameRoundButton(
          icon: Icons.assignment_turned_in_rounded,
          image: questArtReady ? QuestConfig.boardAsset : null,
          color: const Color(0xFFEF7B6B),
          label: 'Nhiệm vụ',
          tooltip: 'Nhiệm vụ hôm nay',
          onPressed: onPressed,
        ),
        if (showDot)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              key: const Key('quest-red-dot'),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Mở bảng nhiệm vụ; xong (đóng) thì chạy tiếp để HUD tải lại số dư/chấm đỏ.
Future<void> showQuestBoardDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const QuestBoardDialog(),
);

class QuestBoardDialog extends ConsumerStatefulWidget {
  const QuestBoardDialog({super.key});

  @override
  ConsumerState<QuestBoardDialog> createState() => _QuestBoardDialogState();
}

class _QuestBoardDialogState extends ConsumerState<QuestBoardDialog> {
  QuestBoard? _board;
  String? _childId;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final childId = await db.ensureSeeded();
    final board = await QuestService(db: db).board(childId);
    if (!mounted) return;
    setState(() {
      _childId = childId;
      _board = board;
    });
  }

  Future<void> _claim(Quest q) async {
    if (_busy) return;
    setState(() => _busy = true);
    final service = QuestService(db: ref.read(databaseProvider));
    final r = await service.claim(_childId!, q.id);
    if (!mounted) return;
    _message = r.ok
        ? (r.gems > 0
              ? 'Nhận ${r.xu} xu và ${r.gems} kim cương thưởng!'
              : 'Nhận ${r.xu} xu!')
        : null;
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _claimChest() async {
    if (_busy) return;
    setState(() => _busy = true);
    final gems = await QuestService(db: ref.read(databaseProvider))
        .claimStreakChest(_childId!);
    if (!mounted) return;
    _message = gems > 0 ? 'Rương chuỗi: $gems kim cương!' : null;
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    return Dialog(
      key: const Key('quest-board-dialog'),
      backgroundColor: const Color(0xFFFFF8E7),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: board == null
              ? const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final s in board.quests) _row(s),
                            _bonusRow(board),
                          ],
                        ),
                      ),
                    ),
                    // Chuỗi + rương luôn hiện (không cuộn mất ở màn thấp).
                    const Divider(height: 14),
                    _streakRow(board),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      Icon(
        Icons.assignment_turned_in_rounded,
        color: const Color(0xFFEF7B6B),
        size: 26,
      ),
      const SizedBox(width: 8),
      const Expanded(
        child: Text(
          'Nhiệm vụ hôm nay',
          key: Key('quest-title'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: gameInk,
          ),
        ),
      ),
      IconButton(
        key: const Key('quest-close'),
        tooltip: 'Đóng',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.close_rounded, color: gameInk),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );

  Widget _row(QuestStatus s) {
    final id = s.quest.id;
    return Container(
      key: Key('quest-row-$id'),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: s.claimed ? const Color(0xFFE6F6EC) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: s.completed
              ? const Color(0xFF4CC38A)
              : const Color(0xFFE2D9C8),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(_questIcon(s.quest.type), color: gameInk, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  questTitle(s.quest),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: gameInk,
                  ),
                ),
                Text(
                  '${s.progress}/${s.target}',
                  key: Key('quest-progress-$id'),
                  style: const TextStyle(fontSize: 12, color: gameInk),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (s.claimed)
            questArtReady
                ? Image.asset(QuestConfig.checkAsset, width: 32, height: 32)
                : const Icon(
                    Icons.check_circle_rounded,
                    key: Key('quest-claimed'),
                    color: Color(0xFF2E9E6B),
                    size: 32,
                  )
          else
            ArenaCandyButton(
              key: Key('quest-claim-$id'),
              text: 'Nhận ${QuestConfig.claimXu} xu',
              height: 34,
              fontSize: 14,
              onPressed: s.claimable ? () => _claim(s.quest) : null,
            ),
        ],
      ),
    );
  }

  Widget _bonusRow(QuestBoard b) {
    final text = b.bonusClaimed
        ? 'Đã nhận ${QuestConfig.allClaimedGems} kim cương thưởng'
        : 'Nhận đủ ${QuestConfig.questsPerDay} nhiệm vụ: '
              '+${QuestConfig.allClaimedGems} kim cương';
    return Row(
      key: const Key('quest-bonus-row'),
      children: [
        const Icon(Icons.diamond_rounded, color: Color(0xFFA07BE0), size: 20),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: gameInk,
            ),
          ),
        ),
      ],
    );
  }

  Widget _streakRow(QuestBoard b) {
    final every = QuestConfig.streakChestEvery;
    final toChest = every - (b.streak % every);
    final hasChest = b.pendingChests.isNotEmpty;
    return Row(
      children: [
        questArtReady
            ? Image.asset(QuestConfig.flameAsset, width: 32, height: 32)
            : const Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFFF8A3D),
                size: 32,
              ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chuỗi ${b.streak} ngày',
                key: const Key('quest-streak-count'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: gameInk,
                ),
              ),
              // Lời báo vừa nhận quà thay cho dòng gợi ý (đỡ tốn chỗ ở màn thấp).
              if (_message != null)
                Text(
                  _message!,
                  key: const Key('quest-message'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E9E6B),
                  ),
                )
              else
                Text(
                  'Còn $toChest ngày nữa được rương '
                  '${QuestConfig.streakChestGems} kim cương',
                  key: const Key('quest-streak-hint'),
                  style: const TextStyle(fontSize: 12, color: gameInk),
                ),
            ],
          ),
        ),
        if (hasChest)
          GestureDetector(
            key: const Key('quest-chest-claim'),
            behavior: HitTestBehavior.opaque,
            onTap: _claimChest,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                questArtReady
                    ? Image.asset(QuestConfig.chestAsset, width: 40, height: 40)
                    : const Icon(
                        Icons.inventory_2_rounded,
                        color: Color(0xFFE0A526),
                        size: 40,
                      ),
                Text(
                  'Mở rương',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: gameInk,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
