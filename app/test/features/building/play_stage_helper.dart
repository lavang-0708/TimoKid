/// Helper chơi chặng cho test màn Tòa nhà (PR (B)): trả lời đúng
/// ngay lần đầu mọi câu của [questions] qua [StageSession] rồi bấm
/// Tiếp tới hết chặng.
///
/// Chặng trong đề ngày: truyền `dailySetId` + `stageIndex` (0–4).
/// Chặng tự chọn: để trống cả hai (mặc định -1/null). [advance]
/// cho đồng hồ giả trôi thêm sau mỗi câu (để cửa sổ thời gian của
/// các chặng không chồng lên nhau — xem `building_stats.dart`).
library;

import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/math/math_session.dart';
import 'package:timokid/features/questions/question.dart';

Future<void> playStageCorrectly({
  required AppDatabase db,
  required String childId,
  required List<DailySetQuestion> questions,
  String? dailySetId,
  int stageIndex = -1,
  FakeClock? clock,
  Duration advance = Duration.zero,
}) async {
  final session = StageSession(
    db: db,
    childId: childId,
    dailySetId: dailySetId,
    stageIndex: stageIndex,
    questions: questions,
  );
  await session.markStageInProgress();
  for (var i = 0; i < session.resolved.length; i++) {
    final resolved = session.resolved[i];
    if (resolved.displayType == AnswerType.choice) {
      await session.submitChoice(resolved.correctDisplayIndex);
    } else {
      final answer = '${resolved.question.answer}';
      for (final ch in answer.split('')) {
        session.appendDigit(ch);
      }
      await session.submitNumber();
    }
    if (clock != null && advance != Duration.zero) {
      clock.advance(advance);
    }
    await session.next();
  }
}

/// Chơi [count] câu đầu của [questions] (đúng ngay lần đầu), không
/// kết thúc chặng — dùng để tạo trạng thái đang làm dở.
Future<void> playStagePartially({
  required AppDatabase db,
  required String childId,
  required List<DailySetQuestion> questions,
  required int count,
  String? dailySetId,
  int stageIndex = -1,
}) async {
  final session = StageSession(
    db: db,
    childId: childId,
    dailySetId: dailySetId,
    stageIndex: stageIndex,
    questions: questions,
  );
  await session.markStageInProgress();
  for (var i = 0; i < count; i++) {
    final resolved = session.resolved[i];
    if (resolved.displayType == AnswerType.choice) {
      await session.submitChoice(resolved.correctDisplayIndex);
    } else {
      final answer = '${resolved.question.answer}';
      for (final ch in answer.split('')) {
        session.appendDigit(ch);
      }
      await session.submitNumber();
    }
    await session.next();
  }
}
