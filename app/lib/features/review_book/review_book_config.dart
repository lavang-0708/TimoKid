/// Hằng số sổ ôn tập (T1-10): mọi ngưỡng ở một chỗ duy nhất.
///
/// Diễn giải mốc ngày từ PLAN ("hỏi lại sau 1, 3 và 7 ngày") + cột
/// `correct_streak` của T1-04: chuỗi đúng là số lần đúng ngay lần đầu
/// liên tiếp ở câu ôn tập; mốc hỏi lại sau mỗi lần đúng lấy theo chuỗi
/// đúng MỚI đạt được (xem [dueDelayForStreak]).
library;

/// Cấu hình sổ ôn tập.
class ReviewBookConfig {
  /// Số lần đúng ngay lần đầu liên tiếp ở câu ôn tập thì ra khỏi sổ.
  static const int requiredStreak = 3;

  /// Số ngày chờ trước lần hỏi lại tiếp theo, theo chuỗi đúng vừa đạt:
  /// chuỗi 0 (mới vào sổ vì sai) → 1 ngày, chuỗi 1 → 3 ngày,
  /// chuỗi 2 → 7 ngày. Chuỗi 3 thì ra khỏi sổ, không còn mốc nào.
  static const List<int> intervalDays = [1, 3, 7];

  /// Số ngày chờ sau khi sai (hoặc đúng sau gợi ý): quay về mốc 1 ngày.
  static const int retryDays = 1;

  /// Thời gian chờ trước lần hỏi lại tiếp theo khi chuỗi đúng hiện tại
  /// là [streak] (0..2). Mốc tính từ thời điểm trả lời vừa xong.
  static Duration dueDelayForStreak(int streak) {
    assert(
      streak >= 0 && streak < requiredStreak,
      'Chuỗi đúng ngoài 0–2: $streak',
    );
    return Duration(days: intervalDays[streak]);
  }
}
