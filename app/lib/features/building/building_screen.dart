/// Màn Tòa nhà (PR (B)): bấm một công trình trên bản đồ Thị trấn thì
/// vào màn này của mảng đó, CHƯA vào làm bài ngay.
///
/// Màn dùng màu của khu đã có trong app (nền theo mảng như màn toán,
/// xem [MathColors.strandBackground]) — KHÔNG vẽ ảnh nội thất mới.
/// Thống kê đọc qua [loadBuildingStats]: trạng thái chặng hôm nay
/// (chưa làm / đang làm / xong), số câu đúng + xu nhận trong chặng,
/// bậc hiện tại của mảng, các chặng tự chọn đã làm hôm nay.
///
/// Nút lớn "Thử thách" để xác nhận vào làm: chặng ngày nếu chưa xong;
/// xong rồi thì nút thành "Leo tầng N" — leo tầng tiếp theo của Tháp
/// 30 tầng của mảng (xem `tower_config.dart`, [TowerService]). Bên
/// phải thẻ là cột tầng: tầng đã qua / tầng hiện tại / tầng khóa,
/// tầng boss có huy hiệu (icon Material tạm khi [towerArtReady] tắt). Nhà hồng (Nhà của bé) không vào màn này mà về Phòng
/// như trước (xem [TownScreen]).
///
/// Nút Trở về tròn ở góc trên trái về Thị trấn (xem
/// [RoundBackButton]); cùng nút dùng ở Phòng và màn toán.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/app_database.dart';
import '../../core/test_build.dart';
import '../../core/database/database_provider.dart';
import '../../core/database/models.dart';
import '../../core/database/tables.dart';
import '../../core/widgets/press_bounce.dart';
import '../../core/widgets/round_back_button.dart';
import '../daily_set/daily_set_service.dart';
import '../ladder/ladder_service.dart';
import '../math/math_decor.dart';
import '../math/math_screen.dart';
import '../residents/resident_content.dart';
import '../residents/resident_service.dart';
import '../residents/resident_widgets.dart';
import '../tower/tower_config.dart';
import '../tower/tower_service.dart';
import '../town/town_assets.dart';
import 'building_stats.dart';

/// Tham số vào màn Tòa nhà qua GoRouter `extra`.
class BuildingScreenArgs {
  const BuildingScreenArgs({required this.stageIndex});

  /// Chỉ số chặng/mảng (0–4), theo thứ tự [Strand.all].
  final int stageIndex;
}

/// Màn Tòa nhà — route `/building`.
class BuildingScreen extends ConsumerStatefulWidget {
  const BuildingScreen({super.key, this.args});

  static const String route = '/building';

  final BuildingScreenArgs? args;

  @override
  ConsumerState<BuildingScreen> createState() => _BuildingScreenState();
}

class _BuildingScreenState extends ConsumerState<BuildingScreen> {
  BuildingStats? _stats;
  String? _error;
  bool _loading = true;

  /// Tầng tháp cao nhất bé đã qua ở mảng này (0 = chưa qua tầng nào).
  int _highestFloor = 0;

  ScrollController _floorScroll = ScrollController();

  /// Lời thoại cư dân của khu (T4-02); null nếu không đọc được nội dung.
  ResidentContext? _resident;

  /// Số lần bé chạm cư dân (mỗi lần nghe một câu chào khác).
  int _residentTaps = 0;

  static const double _floorTileHeight = 34;

  int get _stageIndex => widget.args?.stageIndex ?? 0;

  DailySetService _dailySetService(AppDatabase db) => DailySetService(
    dailySetsDao: db.dailySetsDao,
    reviewQueueDao: db.reviewQueueDao,
    customQuestionsDao: db.customQuestionsDao,
    settingsDao: db.settingsDao,
    ladderService: LadderService(
      attemptsDao: db.attemptsDao,
      skillProgressDao: db.skillProgressDao,
    ),
    clock: db.clock,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _floorScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final db = ref.read(databaseProvider);
      final childId = await db.ensureSeeded();
      // Tạo đề ngày hôm nay nếu chưa có (như màn Thị trấn) rồi mới
      // đọc thống kê — [loadBuildingStats] cần đề ngày có sẵn.
      await _dailySetService(db).getOrCreateTodaySet(childId: childId);
      final stats = await loadBuildingStats(
        db: db,
        childId: childId,
        stageIndex: _stageIndex,
      );
      final resident = await loadResidentContext(db, childId);
      final highest = await TowerService(db: db)
          .highestCleared(childId: childId, strand: Strand.all[_stageIndex]);
      if (!mounted) return;
      // Cuộn sẵn để tầng hiện tại nằm gần đáy khung nhìn (đảo chiều:
      // offset 0 là tầng 1).
      _floorScroll.dispose();
      _floorScroll = ScrollController(
        initialScrollOffset: (highest - 1).clamp(0, 30) * _floorTileHeight,
      );
      setState(() {
        _stats = stats;
        _highestFloor = highest;
        _resident = resident;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// Nút Thử thách: chặng ngày chưa xong thì vào chặng ngày; xong
  /// rồi thì thành "Leo tầng N" và vào làm tầng đó của tháp.
  Future<void> _onChallenge() async {
    final stats = _stats;
    if (stats == null) return;
    if (!_towerOpen(stats)) {
      if (!mounted) return;
      context.go(
        MathScreen.route,
        extra: MathScreenArgs(stageIndex: _stageIndex),
      );
      return;
    }
    // Xong chặng ngày: leo tầng kế tiếp của tháp (câu sinh trong
    // MathScreen để thử lại tầng cũng ra câu mới).
    final floor = _highestFloor + 1;
    if (floor > TowerConfig.floorsPerTower) return;
    context.go(
      MathScreen.route,
      extra: MathScreenArgs(
        towerStrand: Strand.all[_stageIndex],
        towerFloor: floor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        key: Key('building-screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final stats = _stats;
    if (_error != null || stats == null) {
      return Scaffold(
        key: const Key('building-screen'),
        body: Center(child: Text('Không tải được Tòa nhà: $_error')),
      );
    }
    final area = townAreas[_stageIndex];
    final background = MathColors.strandBackground(area.strand);
    final statusText = stats.status == StageStatus.done
        ? 'Xong ✓'
        : stats.status == StageStatus.inProgress
        ? 'Đang làm'
        : 'Chưa làm';
    final extraText = stats.extraStagesDone == 0 && !stats.extraStageInProgress
        ? 'Chưa có chặng tự chọn hôm nay'
        : stats.extraStageInProgress
        ? 'Tự chọn: ${stats.extraStagesDone} xong · 1 đang dở'
        : 'Tự chọn hôm nay: ${stats.extraStagesDone} đã xong';
    return Scaffold(
      key: const Key('building-screen'),
      backgroundColor: background,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const RoundBackButton(key: Key('building-back-button')),
                const SizedBox(width: 12),
                Expanded(
                  // FittedBox co chữ lại thay vì cắt `...` khi tên khu
                  // dài (phông test Ahem rộng hơn Nunito thật).
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      area.name,
                      key: const Key('building-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: MathColors.questionText,
                      ),
                    ),
                  ),
                ),
                Container(
                  key: const Key('building-rung'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Bậc ${stats.rung}/6',
                    style: const TextStyle(
                      fontSize: 18,
                      color: MathColors.questionText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _statsCard(stats, extraText, statusText)),
                  const SizedBox(width: 8),
                  SizedBox(width: 150, child: _towerColumn(stats)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            PressBounce(
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  key: const Key('building-challenge-button'),
                  onPressed: _towerFinished ? null : _onChallenge,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _challengeTitle(stats),
                        style: const TextStyle(fontSize: 22),
                      ),
                      Text(
                        _challengeSubtitle(stats),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tháp mở khi chặng ngày đã xong; bản thử (cờ TEST_UNLOCKS) mở luôn.
  bool _towerOpen(BuildingStats stats) =>
      TestUnlocks.enabled || stats.status == StageStatus.done;

  bool get _towerFinished => _highestFloor >= TowerConfig.floorsPerTower;

  String _challengeTitle(BuildingStats stats) {
    if (!_towerOpen(stats)) return 'Thử thách';
    return _towerFinished
        ? 'Đã lên đỉnh tháp'
        : 'Leo tầng ${_highestFloor + 1}';
  }

  String _challengeSubtitle(BuildingStats stats) {
    if (!_towerOpen(stats)) return 'Làm chặng hôm nay';
    if (_towerFinished) {
      return 'Bé đã qua cả ${TowerConfig.floorsPerTower} tầng';
    }
    final floor = _highestFloor + 1;
    final needed = TowerConfig.passNeeded(floor);
    return TowerConfig.isBoss(floor)
        ? 'Tầng boss: đúng $needed/${TowerConfig.questionsPerFloor} câu'
        : 'Cần đúng $needed/${TowerConfig.questionsPerFloor} câu';
  }

  /// Cột tầng của tháp (tầng cao nhất ở trên, danh sách đảo chiều
  /// nên tầng 1 ở đáy): đã qua / hiện tại / khóa. Mở màn là cuộn sẵn
  /// tới gần tầng hiện tại ([_floorScroll]).
  Widget _towerColumn(BuildingStats stats) {
    final current = _highestFloor + 1;
    return Container(
      key: const Key('building-tower'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.builder(
        key: const Key('building-tower-list'),
        reverse: true,
        controller: _floorScroll,
        itemExtent: _floorTileHeight,
        itemCount: TowerConfig.floorsPerTower,
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) {
          final floor = index + 1;
          return _FloorTile(
            floor: floor,
            state: floor <= _highestFloor
                ? _FloorState.cleared
                : floor == current
                ? _FloorState.current
                : _FloorState.locked,
          );
        },
      ),
    );
  }

  /// Lời cư dân đang hiện: chưa xong chặng ngày thì "nhờ giúp"; xong rồi
  /// thì câu chào (hoặc lời đặc biệt khi đã mở khóa). Bé chạm cư dân thì
  /// nghe câu chào khác.
  String? _residentText(BuildingStats stats, Resident resident) {
    final ctx = _resident;
    if (ctx == null) return null;
    final kind = _residentTaps > 0
        ? LineKind.greeting
        : stats.status != StageStatus.done
        ? LineKind.ask
        : ctx.specialUnlocked
        ? LineKind.special
        : LineKind.greeting;
    final text = pickResidentLine(
      resident,
      kind,
      date: ctx.date,
      childName: ctx.childName,
      variant: _residentTaps,
    );
    return text.isEmpty ? null : text;
  }

  Widget _statsCard(BuildingStats stats, String extraText, String statusText) {
    final resident = _resident?.residentFor(Strand.all[_stageIndex]);
    final residentText = resident == null
        ? null
        : _residentText(stats, resident);
    return Container(
      key: const Key('building-stats-card'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          // Màn thấp (608x248): thống kê gọn một hàng chữ, bỏ dòng "tự chọn".
          final compact = c.maxHeight < 150;
          final withResident = resident != null && residentText != null;
          Widget statsRow() => Row(
            children: [
              Expanded(
                child: _StatBlock(
                  label: 'Chặng',
                  value: statusText,
                  valueKey: const Key('building-status'),
                  compact: compact,
                ),
              ),
              Expanded(
                child: _StatBlock(
                  label: 'Câu đúng',
                  value: '${stats.correctCount}/5',
                  valueKey: const Key('building-correct'),
                  compact: compact,
                ),
              ),
              Expanded(
                child: _StatBlock(
                  label: 'Xu nhận',
                  value: '${stats.xuEarned} xu',
                  valueKey: const Key('building-xu'),
                  compact: compact,
                ),
              ),
            ],
          );
          final extra = Text(
            extraText,
            key: const Key('building-extra'),
            textAlign: TextAlign.center,
            // Một dòng: phông test Ahem rộng, dòng dài gãy
            // làm đôi sẽ tràn thẻ ở 608x248.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              color: MathColors.questionText,
            ),
          );
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (withResident) ...[
                Expanded(
                  child: ResidentSpeech(
                    resident: resident,
                    text: residentText,
                    bubbleKey: const Key('building-resident-bubble'),
                    onTap: () => setState(() => _residentTaps++),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              statsRow(),
              if (!compact || !withResident) ...[
                const SizedBox(height: 8),
                extra,
              ] else
                // Giữ khóa để test/đọc màn hình: dòng tự chọn ẩn khi thấp.
                const SizedBox.shrink(key: Key('building-extra')),
            ],
          );
        },
      ),
    );
  }
}

/// Một ô thống kê trong thẻ trắng: nhãn nhỏ trên, giá trị to dưới
/// (hoặc nhãn + giá trị trên một dòng khi [compact]).
class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    required this.valueKey,
    this.compact = false,
  });

  final String label;
  final String value;
  final Key valueKey;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label ',
              maxLines: 1,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A7FA6)),
            ),
            Text(
              value,
              key: valueKey,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: MathColors.questionText,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, color: Color(0xFF8A7FA6)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          key: valueKey,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: MathColors.questionText,
          ),
        ),
      ],
    );
  }
}

enum _FloorState { cleared, current, locked }

/// Một tầng trong cột tháp: tầng đã qua (dấu tích), tầng hiện tại
/// (nổi màu), tầng khóa (ổ khóa); tầng boss có huy hiệu. Khi
/// [towerArtReady] tắt dùng icon Material tạm thay ảnh
/// `ui_tower_lock` / `ui_tower_boss`.
class _FloorTile extends StatelessWidget {
  const _FloorTile({required this.floor, required this.state});

  final int floor;
  final _FloorState state;

  @override
  Widget build(BuildContext context) {
    final boss = TowerConfig.isBoss(floor);
    final color = switch (state) {
      _FloorState.cleared => const Color(0xFF2E8B57),
      _FloorState.current => MathColors.questionText,
      _FloorState.locked => const Color(0xFF8A7FA6),
    };
    final stateIcon = switch (state) {
      _FloorState.cleared => Icons.check_circle,
      _FloorState.current => Icons.play_circle_fill,
      _FloorState.locked => Icons.lock,
    };
    return Container(
      key: Key('tower-floor-$floor'),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: state == _FloorState.current
            ? const Color(0xFFFFE9A8)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (towerArtReady && state == _FloorState.locked)
            Image.asset(TowerConfig.lockAsset, width: 18, height: 18)
          else
            Icon(stateIcon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Tầng $floor',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: state == _FloorState.current
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: color,
              ),
            ),
          ),
          if (boss && towerArtReady)
            Image.asset(
              TowerConfig.bossAsset,
              key: Key('tower-boss-$floor'),
              width: 18,
              height: 18,
            )
          else if (boss)
            Icon(
              Icons.shield,
              key: Key('tower-boss-$floor'),
              size: 18,
              color: const Color(0xFFD9534F),
            ),
        ],
      ),
    );
  }
}
