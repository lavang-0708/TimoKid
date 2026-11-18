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

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../math/math_decor.dart';
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
                onPressed: () => context.go('/'),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                    onPressed: () => context.go('/'),
                  ),
                  if (args.nextStageIndex != null) ...[
                    const SizedBox(width: 16),
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
                      onPressed: () => context.go(
                        MathScreen.route,
                        extra: MathScreenArgs(stageIndex: args.nextStageIndex),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
