/// Sổ ôn tập (T1-10).
///
/// Dart thuần, không phụ thuộc widget. Đọc/ghi qua `ReviewQueueDao` của
/// T1-04; thời gian qua `Clock` (phải là cùng một `Clock` database dùng,
/// để test dùng `FakeClock` điều khiển được cả hai).
///
/// Luật (PLAN T1-10 + mục (g)):
/// - Câu sai hoặc đúng sau gợi ý (không đúng ngay lần đầu) đưa dạng bài
///   và bậc của câu vừa làm vào sổ: chuỗi đúng về 0, hỏi lại sau 1 ngày.
/// - Hỏi lại (câu ôn tập, `isReview`): đúng ngay lần đầu thì chuỗi +1,
///   hỏi lại sau 3 ngày (chuỗi 1) rồi 7 ngày (chuỗi 2); đủ 3 lần đúng
///   ngay thì ra khỏi sổ. Sai hoặc đúng sau gợi ý thì chuỗi về 0, hỏi
///   lại sau 1 ngày.
/// - Một dạng chỉ có một mục: gặp lại thì cập nhật bậc của câu vừa làm
///   và đặt lại mốc (DAO `upsertEntry` đã làm việc này).
///
/// "Đúng" ở mọi chỗ dưới đây luôn là đúng ngay lần đầu
/// (`correctFirstTry`); câu đúng sau gợi ý không tính là đúng (PLAN
/// mục (f)) — phía ghi `attempts` (T1-09) chịu trách nhiệm đặt
/// `correctFirstTry` false cho câu đúng sau gợi ý.
///
/// API cho T1-09 (màn làm toán) dùng sau mỗi lượt trả lời:
/// - [recordAnswer]: ghi kết quả một câu thường.
/// - [recordReviewAnswer]: ghi kết quả một câu ôn tập.
/// - [dueEntries]/[allEntries]: mục đến hạn / toàn bộ sổ.
library;

import '../../core/database/app_database.dart';
import '../../core/database/daos.dart';
import '../../core/time/clock.dart';
import 'review_book_config.dart';

/// Kết quả ghi nhận một lần trả lời câu ôn tập.
enum ReviewAnswerOutcome {
  /// Đúng ngay lần đầu, chuỗi tăng nhưng chưa đủ 3: mục còn trong sổ.
  streakAdvanced,

  /// Đúng ngay lần đầu lần thứ 3: đủ chuỗi, dạng ra khỏi sổ.
  graduated,

  /// Sai hoặc đúng sau gợi ý: chuỗi về 0, hỏi lại sau 1 ngày.
  reset,

  /// Không có mục nào cho dạng này trong sổ (câu ôn tập gọi nhầm dạng
  /// chưa vào sổ): không làm gì.
  noEntry,
}

/// Sổ ôn tập của một bé: ghi nhận kết quả trả lời và tra mục đến hạn.
class ReviewBookService {
  ReviewBookService({required this._reviewQueueDao, required this._clock});

  final ReviewQueueDao _reviewQueueDao;

  /// Đồng hồ của app (giờ Việt Nam). Phải là cùng một `Clock` mà
  /// database dùng để ghi `createdAt`, để test dùng `FakeClock`
  /// điều khiển được cả hai.
  final Clock _clock;

  /// Ngày hỏi lại: 0h giờ Việt Nam của ngày (hôm nay + [delay] ngày).
  ///
  /// Mốc theo ngày, không giữ giờ trong ngày: đề ngày tạo ở lần mở app
  /// đầu tiên trong ngày, nên sai lúc 20h thì 7h sáng hôm sau câu đó đã
  /// đến hạn — giữ giờ sẽ thành 20h hôm sau, lỡ đề và trễ thêm 1 ngày
  /// (1-3-7 thành 2-4-8). Dùng chung cho cả [recordAnswer] và
  /// [recordReviewAnswer].
  ///
  /// `Clock.now()` trả về DateTime vùng UTC nhưng các trường giờ là giờ
  /// Việt Nam, nên dựng 0h bằng `DateTime.utc` để không phụ thuộc múi
  /// giờ của máy.
  DateTime _dueDate(Duration delay) {
    final now = _clock.now();
    return DateTime.utc(now.year, now.month, now.day).add(delay);
  }

  /// Ghi kết quả một câu THƯỜNG (không phải câu ôn tập):
  /// - Sai hoặc đúng sau gợi ý (`correctFirstTry` false) → đưa dạng
  ///   vào sổ (hoặc cập nhật mục đã có: bậc của câu vừa làm, chuỗi
  ///   về 0, hỏi lại sau 1 ngày).
  /// - Đúng ngay lần đầu → không động vào sổ: chuỗi chỉ tăng qua câu
  ///   ôn tập, không tăng qua câu thường.
  Future<void> recordAnswer({
    required String childId,
    required String formId,
    required int rung,
    required bool correctFirstTry,
  }) async {
    if (correctFirstTry) return;
    await _reviewQueueDao.upsertEntry(
      childId: childId,
      formId: formId,
      rung: rung,
      dueDate: _dueDate(const Duration(days: ReviewBookConfig.retryDays)),
    );
  }

  /// Ghi kết quả một câu ÔN TẬP (câu hỏi lại từ sổ):
  /// - Đúng ngay lần đầu → chuỗi +1; đủ 3 thì xóa mục (ra khỏi sổ),
  ///   chưa đủ thì đặt ngày hỏi lại theo mốc của chuỗi mới. Bậc đã lưu
  ///   không đổi vì câu ôn tập được sinh từ chính bậc đó (xem T1-08).
  /// - Sai hoặc đúng sau gợi ý → chuỗi về 0, hỏi lại sau 1 ngày, bậc
  ///   cập nhật theo bậc của câu vừa làm.
  ///
  /// `rung` là bậc của câu vừa làm. Với câu ôn tập, bậc này bằng bậc đã
  /// lưu trong sổ trong thực tế (câu được sinh từ bậc đó); tham số vẫn
  /// nhận vào để đường sai dùng chung một chỗ ghi với [recordAnswer].
  Future<ReviewAnswerOutcome> recordReviewAnswer({
    required String childId,
    required String formId,
    required int rung,
    required bool correctFirstTry,
  }) async {
    final entry = await _reviewQueueDao.getEntry(childId, formId);
    if (entry == null) return ReviewAnswerOutcome.noEntry;
    if (!correctFirstTry) {
      await _reviewQueueDao.upsertEntry(
        childId: childId,
        formId: formId,
        rung: rung,
        dueDate: _dueDate(const Duration(days: ReviewBookConfig.retryDays)),
      );
      return ReviewAnswerOutcome.reset;
    }
    final streak = entry.correctStreak + 1;
    if (streak >= ReviewBookConfig.requiredStreak) {
      await _reviewQueueDao.removeEntry(entry.id);
      return ReviewAnswerOutcome.graduated;
    }
    await _reviewQueueDao.updateStreakAndDue(
      id: entry.id,
      correctStreak: streak,
      dueDate: _dueDate(ReviewBookConfig.dueDelayForStreak(streak)),
    );
    return ReviewAnswerOutcome.streakAdvanced;
  }

  /// Các mục đến hạn hỏi lại (ngày hỏi lại <= giờ hiện tại), mục đến
  /// hạn sớm nhất trước.
  Future<List<ReviewQueueData>> dueEntries({required String childId}) =>
      _reviewQueueDao.getDueEntries(childId: childId, now: _clock.now());

  /// Toàn bộ sổ của bé, mục đến hạn sớm nhất trước.
  Future<List<ReviewQueueData>> allEntries({required String childId}) =>
      _reviewQueueDao.getAllEntries(childId);
}
