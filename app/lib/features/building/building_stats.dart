/// Thống kê cho màn Tòa nhà (PR (B)): trạng thái chặng hôm nay của
/// một mảng, số câu đúng + xu nhận trong chặng đó, bậc hiện tại của
/// mảng, và số chặng tự chọn đã làm hôm nay.
///
/// Số câu đúng + xu lấy từ `wallet_ledger` (không đếm từ `attempts`):
/// bảng `attempts` không phân biệt được "đúng sau gợi ý" với "sai cả
/// hai lần" (cùng `attemptsCount` 2), còn ví ghi đúng một dòng cho
/// mỗi câu đúng (`question_correct` / `question_correct_after_hint`,
/// câu ôn tập là `review_correct` / `review_correct_after_hint`,
/// `refId` là id đề ngày) và một dòng `stage_complete` khi xong chặng.
/// Thưởng xong đề ngày (`daily_complete`, `refId` dạng
/// `daily_complete:<childId>:<ngày>`) không thuộc chặng nào nên
/// không đếm ở đây.
///
/// Chỉ đếm ví trong cửa sổ làm chặng [lượt làm gần nhất]: từ lần trả
/// lời đầu tới lần cuối của lượt đó + 1 giây (dòng `stage_complete`
/// ghi ngay sau câu cuối). Lấy tối đa 5 lần trả lời gần nhất của
/// chặng — bé vào lại chặng đang làm dở thì làm lại từ đầu chặng nên
/// lượt cũ không tính. Vì vậy test phải cho đồng hồ trôi giữa các
/// chặng (đồng hồ đứng yên thì mọi thời điểm bằng nhau, cửa sổ sẽ
/// chồng lên nhau).
library;

import '../../core/database/app_database.dart';
import '../../core/database/models.dart';
import '../../core/database/tables.dart';
import '../daily_set/daily_set_config.dart';
import '../ladder/ladder_service.dart';

/// Thống kê một mảng cho màn Tòa nhà.
class BuildingStats {
  const BuildingStats({
    required this.status,
    required this.correctCount,
    required this.xuEarned,
    required this.rung,
    required this.extraStagesDone,
    required this.extraStageInProgress,
  });

  /// Trạng thái chặng hôm nay: [StageStatus.notStarted] /
  /// [StageStatus.inProgress] / [StageStatus.done].
  final String status;

  /// Số câu đúng trong lượt làm chặng hôm nay gần nhất (0–5).
  final int correctCount;

  /// Xu nhận trong lượt làm chặng hôm nay gần nhất (câu đúng +
  /// thưởng xong chặng).
  final int xuEarned;

  /// Bậc hiện tại của mảng (1–6).
  final int rung;

  /// Số chặng tự chọn đã làm xong hôm nay (mỗi chặng 5 câu).
  final int extraStagesDone;

  /// Có đang làm dở một chặng tự chọn hôm nay không (1–4 câu).
  final bool extraStageInProgress;
}

/// Tải thống kê của mảng ở chặng [stageIndex] (0–4).
///
/// Đề ngày hôm nay phải có sẵn (màn Tòa nhà tạo qua
/// `DailySetService.getOrCreateTodaySet` trước khi gọi hàm này);
/// chưa có đề thì trả lỗi.
Future<BuildingStats> loadBuildingStats({
  required AppDatabase db,
  required String childId,
  required int stageIndex,
}) async {
  final set = await db.dailySetsDao.getDailySet(childId, db.clock.today());
  if (set == null) {
    throw StateError('Chưa có đề ngày hôm nay');
  }
  final strand = Strand.all[stageIndex];
  final status = db.dailySetsDao.readStageStatus(set)[stageIndex];
  final rung = await LadderService(
    attemptsDao: db.attemptsDao,
    skillProgressDao: db.skillProgressDao,
  ).rungFor(childId: childId, strand: strand);

  final attempts = await db.attemptsDao.getAttemptsForChild(childId);
  // Lượt làm chặng hôm nay gần nhất: tối đa 5 lần trả lời, cũ nhất
  // trước (DAO trả mới nhất trước).
  final stageAttempts =
      attempts
          .where((a) => a.dailySetId == set.id && a.stage == stageIndex)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final lastPlay = stageAttempts.length > DailySetConfig.questionsPerStage
      ? stageAttempts.sublist(
          stageAttempts.length - DailySetConfig.questionsPerStage,
        )
      : stageAttempts;

  var correctCount = 0;
  var xuEarned = 0;
  if (lastPlay.isNotEmpty) {
    final windowStart = lastPlay.first.createdAt;
    // Dòng `stage_complete` ghi ngay sau câu cuối nên + 1 giây.
    final windowEnd = lastPlay.last.createdAt.add(const Duration(seconds: 1));
    final entries = await db.walletDao.getEntries(childId);
    for (final entry in entries) {
      if (entry.refId != set.id || entry.currency != Currency.xu) continue;
      if (entry.createdAt.isBefore(windowStart) ||
          entry.createdAt.isAfter(windowEnd)) {
        continue;
      }
      switch (entry.reason) {
        case 'question_correct':
        case 'question_correct_after_hint':
        case 'review_correct':
        case 'review_correct_after_hint':
          correctCount++;
          xuEarned += entry.amount;
        case 'stage_complete':
          xuEarned += entry.amount;
      }
    }
  }

  // Chặng tự chọn hôm nay: lượt trả lời không gắn đề ngày/chặng,
  // cùng mảng, trong ngày hôm nay. 5 câu = 1 chặng xong; lẻ ra là
  // đang làm dở. So ngày bằng trường giờ Việt Nam của `createdAt`
  // (đồng hồ trả `DateTime` vùng UTC mà trường là giờ Việt Nam;
  // Drift giữ nguyên thời điểm khi đọc lại nên `.toUtc()` trả đúng
  // trường giờ Việt Nam đã ghi).
  final today = db.clock.today();
  final todayParts = today.split('-').map(int.parse).toList();
  final extraAttempts =
      attempts
          .where(
            (a) =>
                a.dailySetId == null &&
                a.stage == null &&
                a.strand == strand &&
                _isToday(a.createdAt, todayParts),
          )
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final extraStagesDone =
      extraAttempts.length ~/ DailySetConfig.questionsPerStage;
  final extraStageInProgress =
      extraAttempts.length % DailySetConfig.questionsPerStage > 0;

  return BuildingStats(
    status: status,
    correctCount: correctCount,
    xuEarned: xuEarned,
    rung: rung,
    extraStagesDone: extraStagesDone,
    extraStageInProgress: extraStageInProgress,
  );
}

/// `createdAt` có phải ngày hôm nay không; [todayParts] là
/// [năm, tháng, ngày] từ `Clock.today()` ('YYYY-MM-DD').
bool _isToday(DateTime createdAt, List<int> todayParts) {
  final vn = createdAt.toUtc();
  return vn.year == todayParts[0] &&
      vn.month == todayParts[1] &&
      vn.day == todayParts[2];
}
