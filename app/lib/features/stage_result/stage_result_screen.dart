/// Màn Kết quả chặng (T1-09): hiện sau khi bé làm xong 5 câu của một
/// chặng — số câu đúng, số câu đúng ngay lần đầu, xu nhận được trong
/// chặng, lời cảm ơn của cư dân. Bé về Thị trấn hoặc làm chặng tiếp
/// theo (nếu còn chặng sau trong đề ngày).
library;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../math/math_screen.dart';
import '../math/math_session.dart' show strandNames;

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
}

/// Màn Kết quả chặng — route `/stage-result`.
class StageResultScreen extends StatelessWidget {
  const StageResultScreen({super.key, this.result});

  static const String route = '/stage-result';

  /// Kết quả chặng vừa xong. Bỏ trống: màn hiện thông báo chung
  /// (đi thẳng vào route mà không qua màn làm toán).
  final StageResultArgs? result;

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
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  key: const Key('stage-result-back-button'),
                  onPressed: () => context.go('/'),
                  child: const Text('Về Thị trấn'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final strandName = strandNames[args.strand] ?? args.strand;
    final title = args.stageIndex >= 0
        ? 'Xong chặng ${args.stageIndex + 1} — $strandName!'
        : 'Xong chặng tự chọn — $strandName!';
    return Scaffold(
      key: const Key('stage-result-screen'),
      appBar: AppBar(title: const Text('Kết quả chặng')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    key: const Key('stage-result-back-button'),
                    onPressed: () => context.go('/'),
                    child: const Text('Về Thị trấn'),
                  ),
                ),
                if (args.nextStageIndex != null) ...[
                  const SizedBox(width: 16),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      key: const Key('stage-result-next-button'),
                      onPressed: () => context.go(
                        MathScreen.route,
                        extra: MathScreenArgs(stageIndex: args.nextStageIndex),
                      ),
                      child: const Text('Chặng tiếp theo'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
