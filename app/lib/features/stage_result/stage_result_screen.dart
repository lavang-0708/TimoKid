/// Màn Kết quả chặng (T1-09): hiện sau khi bé làm xong 5 câu của một
/// chặng — số câu đúng, số câu đúng ngay lần đầu, xu nhận được trong
/// chặng, lời cảm ơn của cư dân. Bé về Thị trấn hoặc làm chặng tiếp
/// theo (nếu còn chặng sau trong đề ngày).
///
/// Hai nút là nút có biểu tượng, tối thiểu 56x56 dp, chữ to
/// (sửa sau review PR #11). Biểu tượng là ký tự chữ (←, →) thay vì
/// `Icon` vì font MaterialIcons không có trong môi trường test nên
/// golden test sẽ bị ô vuông; các ký tự này có trong font DejaVu
/// dùng ở test và trong Roboto trên máy thật.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database_provider.dart';
import '../math/math_decor.dart';
import '../math/math_screen.dart';
import '../math/math_session.dart' show strandNames;
import '../onboarding/egg_service.dart';
import '../building/building_screen.dart';
import '../onboarding/hatch_screen.dart';
import '../tower/tower_service.dart';
import '../../core/database/tables.dart' show Strand;

/// Kết quả một chặng, màn làm toán truyền qua GoRouter `extra`.
class StageResultArgs {
  const StageResultArgs({
    required this.stageIndex,
    required this.strand,
    required this.correctCount,
    required this.firstTryCorrectCount,
    required this.totalQuestions,
    required this.xuEarned,
    this.nextStageIndex,
    this.tower,
  });

  /// Chỉ số chặng vừa xong (0–4); -1 với chặng tự chọn.
  final int stageIndex;

  final String strand;
  final int correctCount;
  final int firstTryCorrectCount;
  final int totalQuestions;
  final int xuEarned;

  /// Chặng tiếp theo (null nếu đây là chặng cuối của đề ngày).
  final int? nextStageIndex;

  /// Kết quả leo tầng tháp; null nếu không phải tầng tháp.
  final TowerOutcome? tower;
}

/// Màn Kết quả chặng — route `/stage-result`.
class StageResultScreen extends StatelessWidget {
  const StageResultScreen({super.key, this.result});

  static const String route = '/stage-result';

  /// Kết quả chặng vừa xong. Bỏ trống: màn hiện thông báo chung
  /// (đi thẳng vào route mà không qua màn làm toán).
  final StageResultArgs? result;

  /// Rời màn kết quả: nếu có lần nở trứng đang chờ (bé vừa xong
  /// chặng đầu tiên sau khi chọn trứng) thì rẽ sang màn nở trứng
  /// trước, không cho bé bỏ qua màn ăn mừng bằng cách bấm sang
  /// chặng tiếp theo; còn lại thì đi theo `next` (về Thị trấn hoặc
  /// sang chặng tiếp theo).
  Future<void> _continue(
    BuildContext context, {
    required VoidCallback next,
  }) async {
    final db = ProviderScope.containerOf(context).read(databaseProvider);
    final childId = await db.ensureSeeded();
    final pending = await EggService(db: db).isHatchPending(childId);
    if (!context.mounted) return;
    if (pending) {
      context.go(HatchScreen.route);
      return;
    }
    next();
  }

  /// Màn kết quả của một lượt leo tầng tháp: qua/chưa qua tầng, số
  /// câu đúng ngay lần đầu so với ngưỡng, thưởng lần qua đầu tiên.
  Widget _buildTower(
    BuildContext context,
    StageResultArgs args,
    TowerOutcome tower,
    String strandName,
  ) {
    final background = MathColors.strandBackground(args.strand);
    final what = tower.isBoss ? 'boss tầng' : 'tầng';
    final title = tower.passed
        ? 'Qua $what ${tower.floor}!'
        : 'Chưa qua $what ${tower.floor}';
    final reward = <String>[
      if (tower.rewardXu > 0) '${tower.rewardXu} xu',
      if (tower.rewardGems > 0) '${tower.rewardGems} kim cương',
    ];
    final stageIndex = Strand.all.indexOf(args.strand);
    void toBuilding() => context.go(
      BuildingScreen.route,
      extra: BuildingScreenArgs(stageIndex: stageIndex < 0 ? 0 : stageIndex),
    );
    void climb(int floor) => context.go(
      MathScreen.route,
      extra: MathScreenArgs(towerStrand: args.strand, towerFloor: floor),
    );
    return Scaffold(
      key: const Key('stage-result-screen'),
      backgroundColor: background,
      appBar: AppBar(
        title: Text('Tháp $strandName'),
        backgroundColor: background,
        foregroundColor: MathColors.questionText,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                key: const Key('tower-result-title'),
                style: const TextStyle(fontSize: 30),
              ),
              const SizedBox(height: 12),
              Text(
                'Đúng ngay lần đầu ${tower.firstTryCorrect}/'
                '${args.totalQuestions} câu (cần ${tower.passNeeded})',
                key: const Key('stage-result-correct-count'),
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 8),
              if (reward.isNotEmpty)
                Text(
                  'Thưởng lần đầu qua tầng: ${reward.join(' + ')}',
                  key: const Key('tower-result-reward'),
                  style: const TextStyle(fontSize: 24),
                )
              else if (tower.passed)
                const Text(
                  'Tầng này bé đã qua rồi, không có thưởng thêm.',
                  key: Key('tower-result-reward'),
                  style: TextStyle(fontSize: 20),
                )
              else
                const Text(
                  'Thử lại với câu mới nhé, bé làm được!',
                  key: Key('tower-result-reward'),
                  style: TextStyle(fontSize: 22),
                ),
              const SizedBox(height: 4),
              Text(
                'Xu từng câu: ${args.xuEarned - tower.rewardXu} xu',
                key: const Key('stage-result-xu'),
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  ElevatedButton.icon(
                    key: const Key('stage-result-back-button'),
                    icon: const Text('←', style: TextStyle(fontSize: 24)),
                    label: const Text(
                      'Về Tòa nhà',
                      style: TextStyle(fontSize: 22),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(56, 56),
                    ),
                    onPressed: () => _continue(context, next: toBuilding),
                  ),
                  if (tower.passed && tower.nextFloor != null)
                    ElevatedButton.icon(
                      key: const Key('tower-next-floor-button'),
                      icon: const Text('→', style: TextStyle(fontSize: 24)),
                      label: Text(
                        'Leo tầng ${tower.nextFloor}',
                        style: const TextStyle(fontSize: 22),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(56, 56),
                      ),
                      onPressed: () => _continue(
                        context,
                        next: () => climb(tower.nextFloor!),
                      ),
                    ),
                  if (!tower.passed)
                    ElevatedButton.icon(
                      key: const Key('tower-retry-button'),
                      icon: const Text('↻', style: TextStyle(fontSize: 24)),
                      label: const Text(
                        'Thử lại',
                        style: TextStyle(fontSize: 22),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(56, 56),
                      ),
                      onPressed: () =>
                          _continue(context, next: () => climb(tower.floor)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = result;
    if (args == null) {
      return Scaffold(
        key: const Key('stage-result-screen'),
        appBar: AppBar(title: const Text('Kết quả chặng')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Chưa có kết quả chặng nào.'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('stage-result-back-button'),
                icon: const Text('←', style: TextStyle(fontSize: 24)),
                label: const Text(
                  'Về Thị trấn',
                  style: TextStyle(fontSize: 22),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(56, 56),
                ),
                onPressed: () =>
                    _continue(context, next: () => context.go('/')),
              ),
            ],
          ),
        ),
      );
    }
    final strandName = strandNames[args.strand] ?? args.strand;
    final tower = args.tower;
    if (tower != null) {
      return _buildTower(context, args, tower, strandName);
    }
    final title = args.stageIndex >= 0
        ? 'Xong chặng ${args.stageIndex + 1} — $strandName!'
        : 'Xong chặng tự chọn — $strandName!';
    // Cùng nền và phông với màn làm toán (sửa sau review PR #14,
    // không chặn): nền pastel theo mảng, phông Nunito đã có sẵn
    // toàn app qua AppTheme.
    final background = MathColors.strandBackground(args.strand);
    return Scaffold(
      key: const Key('stage-result-screen'),
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Kết quả chặng'),
        backgroundColor: background,
        foregroundColor: MathColors.questionText,
      ),
      // Cuộn được để không tràn trên màn thấp (640x320 dp).
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 16),
              Text(
                'Đúng ${args.correctCount}/${args.totalQuestions} câu',
                key: const Key('stage-result-correct-count'),
                style: const TextStyle(fontSize: 26),
              ),
              Text(
                'Đúng ngay lần đầu: ${args.firstTryCorrectCount} câu',
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text(
                'Nhận được ${args.xuEarned} xu',
                key: const Key('stage-result-xu'),
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cảm ơn bé nhé, làm tốt lắm!',
                style: TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 24),
              // Hai nút xuống dòng khi không vừa một hàng (màn hẹp /
              // font test DejaVu rộng hơn Nunito nên ở 608 dp hai nút
              // cộng lại vượt chiều rộng 127 px): màn cuộn dọc sẵn
              // nên xuống dòng vẫn thấy đủ nút; khi chạy app (Nunito)
              // vẫn một hàng như trước.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  ElevatedButton.icon(
                    key: const Key('stage-result-back-button'),
                    icon: const Text('←', style: TextStyle(fontSize: 24)),
                    label: const Text(
                      'Về Thị trấn',
                      style: TextStyle(fontSize: 22),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(56, 56),
                    ),
                    onPressed: () =>
                        _continue(context, next: () => context.go('/')),
                  ),
                  if (args.nextStageIndex != null)
                    ElevatedButton.icon(
                      key: const Key('stage-result-next-button'),
                      icon: const Text('→', style: TextStyle(fontSize: 24)),
                      label: const Text(
                        'Chặng tiếp theo',
                        style: TextStyle(fontSize: 22),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(56, 56),
                      ),
                      onPressed: () => _continue(
                        context,
                        next: () => context.go(
                          MathScreen.route,
                          extra: MathScreenArgs(
                            stageIndex: args.nextStageIndex,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
