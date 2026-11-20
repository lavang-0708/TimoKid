/// Màn Tòa nhà (PR (B)): bấm một công trình trên bản đồ Thị trấn thì
/// vào màn này của mảng đó, CHƯA vào làm bài ngay.
///
/// Màn dùng màu của khu đã có trong app (nền theo mảng như màn toán,
/// xem [MathColors.strandBackground]) — KHÔNG vẽ ảnh nội thất mới.
/// Thống kê đọc qua [loadBuildingStats]: trạng thái chặng hôm nay
/// (chưa làm / đang làm / xong), số câu đúng + xu nhận trong chặng,
/// bậc hiện tại của mảng, các chặng tự chọn đã làm hôm nay.
///
/// Nút lớn "Thử thách" để xác nhận vào làm: chặng ngày nếu chưa xong,
/// xong rồi thì sinh chặng tự chọn mới ([DailySetService.buildExtraStage])
/// rồi vào làm. Nhà hồng (Nhà của bé) không vào màn này mà về Phòng
/// như trước (xem [TownScreen]).
///
/// Nút Trở về tròn ở góc trên trái về Thị trấn (xem
/// [RoundBackButton]); cùng nút dùng ở Phòng và màn toán.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/database/models.dart';
import '../../core/database/tables.dart';
import '../../core/widgets/press_bounce.dart';
import '../../core/widgets/round_back_button.dart';
import '../daily_set/daily_set_service.dart';
import '../ladder/ladder_service.dart';
import '../math/math_decor.dart';
import '../math/math_screen.dart';
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

  /// Đang sinh chặng tự chọn (khóa nút Thử thách lúc chờ).
  bool _starting = false;

  int get _stageIndex => widget.args?.stageIndex ?? 0;

  DailySetService _dailySetService(AppDatabase db) => DailySetService(
    dailySetsDao: db.dailySetsDao,
    reviewQueueDao: db.reviewQueueDao,
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
      if (!mounted) return;
      setState(() {
        _stats = stats;
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
  /// rồi thì sinh chặng tự chọn mới rồi vào làm.
  Future<void> _onChallenge() async {
    final stats = _stats;
    if (stats == null || _starting) return;
    if (stats.status != StageStatus.done) {
      if (!mounted) return;
      context.go(
        MathScreen.route,
        extra: MathScreenArgs(stageIndex: _stageIndex),
      );
      return;
    }
    setState(() => _starting = true);
    try {
      final db = ref.read(databaseProvider);
      final childId = await db.ensureSeeded();
      final questions = await _dailySetService(db)
          .buildExtraStage(childId: childId, strand: Strand.all[_stageIndex]);
      if (!mounted) return;
      context.go(
        MathScreen.route,
        extra: MathScreenArgs(extraQuestions: questions),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chưa sinh được chặng tự chọn: $e')),
      );
    }
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
              child: Container(
                key: const Key('building-stats-card'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatBlock(
                            label: 'Chặng',
                            value: statusText,
                            valueKey: const Key('building-status'),
                          ),
                        ),
                        Expanded(
                          child: _StatBlock(
                            label: 'Câu đúng',
                            value: '${stats.correctCount}/5',
                            valueKey: const Key('building-correct'),
                          ),
                        ),
                        Expanded(
                          child: _StatBlock(
                            label: 'Xu nhận',
                            value: '${stats.xuEarned} xu',
                            valueKey: const Key('building-xu'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
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
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            PressBounce(
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  key: const Key('building-challenge-button'),
                  onPressed: _starting ? null : _onChallenge,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _starting ? 'Đang chuẩn bị…' : 'Thử thách',
                        style: const TextStyle(fontSize: 22),
                      ),
                      if (!_starting)
                        Text(
                          stats.status == StageStatus.done
                              ? 'Chặng ngày xong, làm chặng tự chọn'
                              : 'Làm chặng hôm nay',
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
}

/// Một ô thống kê trong thẻ trắng: nhãn nhỏ trên, giá trị to dưới.
class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
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
