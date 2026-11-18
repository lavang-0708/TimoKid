/// Hằng số cấu hình của đề ngày (T1-08).
///
/// Mọi con số của cấu trúc đề nằm ở đúng một chỗ này — không viết cứng
/// rải rác trong service hay test. Đổi cấu trúc chỉ cần sửa file này.
///
/// Luật (PLAN mục T1-08 + mục "Làm rõ" (f), (g)):
/// - Mỗi ngày theo giờ Việt Nam một đề 25 câu, 5 chặng theo 5 mảng.
/// - Trong mỗi chặng: câu 1 và 2 thấp hơn bậc hiện tại một bậc (không
///   dưới bậc 1), câu 3 đúng bậc, câu 4 lấy từ sổ ôn tập nếu đến hạn
///   (nếu không thì đúng bậc), câu 5 cao hơn một bậc (không quá bậc 6).
/// - Không lặp dạng bài trong cùng chặng nếu mảng còn dạng khác; thiếu
///   dạng thì được lặp, ưu tiên lặp dạng ít gặp nhất trong 7 ngày qua.
/// - Câu ôn tập dùng bậc đã lưu trong `review_queue` (mục (g)) và thắng
///   khi xung đột dạng: giữ câu ôn tập, đổi dạng của câu kia.
/// - "Đúng" luôn nghĩa là đúng ngay lần đầu (mục (f)) — luật này thuộc
///   thang ải (T1-07), đề ngày không tính đúng/sai.
library;

/// Toàn bộ hằng số cấu trúc của đề ngày, ở một chỗ duy nhất.
class DailySetConfig {
  const DailySetConfig._();

  /// Số chặng trong một đề ngày (5 mảng).
  static const int stagesPerDay = 5;

  /// Số câu trong mỗi chặng.
  static const int questionsPerStage = 5;

  /// Tổng số câu của một đề ngày.
  static const int totalQuestions = stagesPerDay * questionsPerStage;

  /// Vị trí (chỉ số 0-based) của câu ôn tập trong mỗi chặng: câu 4.
  static const int reviewSlotIndex = 3;

  /// Số ngày gần đây dùng để ưu tiên dạng ít gặp khi phải lặp dạng
  /// (mục (g)): đếm số lần mỗi dạng đã xuất hiện trong các đề ngày
  /// của bé trong khoảng này.
  static const int recentDaysForLeastSeen = 7;

  /// Các dạng luôn trắc nghiệm ở mọi bậc (choiceOnly — mục (d)):
  /// generator của chúng chỉ sinh câu trắc nghiệm, thang ải không ép
  /// được thành điền số. Danh sách này phải khớp với `gen.py`;
  /// test phủ dạng trong `daily_set_service_test.dart` sẽ báo nếu
  /// nội dung đổi mà danh sách này không đổi theo.
  static const Set<String> choiceOnlyFormIds = {
    'logic.compare',
    'logic.weekday',
    'number.parityrule',
  };

  /// Dạng bài có phải luôn trắc nghiệm ở mọi bậc không.
  static bool isChoiceOnly(String formId) => choiceOnlyFormIds.contains(formId);
}
