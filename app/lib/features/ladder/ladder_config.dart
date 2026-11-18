/// Hằng số cấu hình của thang ải và thành thạo (T1-07).
///
/// MỌI ngưỡng của thang ải nằm ở đúng một chỗ này — không viết cứng
/// rải rác trong service hay test. Đổi ngưỡng chỉ cần sửa file này.
///
/// Luật (PLAN mục T1-07 + mục "Làm rõ" (b), (f)):
/// - Mỗi mảng có bậc 1–6. Bậc lẻ trắc nghiệm, bậc chẵn điền số.
///   Bậc 1–2 nội dung Dễ, 3–4 Vừa, 5–6 Khó. Bé mới bắt đầu ở bậc 1.
/// - Lên một bậc khi đúng ngay lần đầu từ 8/10 câu gần nhất của mảng;
///   xuống một bậc khi dưới 5/10; sau mỗi lần đổi bậc thì tính lại
///   từ 10 câu mới (cửa sổ reset).
/// - Thành thạo dạng bài: đúng ngay lần đầu 4/5 câu gần nhất ở mức cao
///   nhất mà dạng hỗ trợ, nhưng không thấp hơn Vừa nếu dạng có Vừa.
/// - "Đúng" luôn nghĩa là đúng ngay lần đầu (PLAN mục (f)): câu đúng
///   sau gợi ý KHÔNG tính là đúng.
library;

import '../questions/question.dart';

/// Toàn bộ ngưỡng và ánh xạ của thang ải, ở một chỗ duy nhất.
class LadderConfig {
  const LadderConfig._();

  /// Bậc thấp nhất và cao nhất của thang ải.
  static const int minRung = 1;
  static const int maxRung = 6;

  /// Bậc khởi đầu của bé mới cho mỗi mảng.
  static const int initialRung = 1;

  /// Số câu trong cửa sổ đánh giá lên/xuống bậc của một mảng.
  static const int windowSize = 10;

  /// Lên bậc khi đúng ngay lần đầu từ số câu này trở lên trong cửa sổ.
  static const int promoteThreshold = 8;

  /// Xuống bậc khi đúng ngay lần đầu DƯỚI số câu này trong cửa sổ.
  /// Đúng đúng bằng số này (5/10) thì giữ nguyên bậc.
  static const int demoteThreshold = 5;

  /// Số câu trong cửa sổ đánh giá thành thạo của một dạng bài.
  static const int masteryWindow = 5;

  /// Thành thạo khi đúng ngay lần đầu từ số câu này trở lên trong
  /// cửa sổ thành thạo.
  static const int masteryCorrectNeeded = 4;

  /// Mức nội dung (1 Dễ, 2 Vừa, 3 Khó) của một bậc.
  /// Bậc 1–2 Dễ, 3–4 Vừa, 5–6 Khó.
  static int levelForRung(int rung) {
    assert(rung >= minRung && rung <= maxRung, 'Bậc ngoài 1–6: $rung');
    return (rung + 1) ~/ 2;
  }

  /// Kiểu trả lời của một bậc: bậc lẻ trắc nghiệm, bậc chẵn điền số.
  /// Ngoại lệ: các dạng `choiceOnly` (compare, weekday, parityrule)
  /// luôn là trắc nghiệm ở mọi bậc — việc đó do generator quyết,
  /// không phải thang ải.
  static AnswerType answerTypeForRung(int rung) {
    assert(rung >= minRung && rung <= maxRung, 'Bậc ngoài 1–6: $rung');
    return rung.isOdd ? AnswerType.choice : AnswerType.number;
  }

  /// Mức dùng để xét thành thạo một dạng bài (mục (b)):
  /// mức cao nhất dạng hỗ trợ, nhưng không thấp hơn Vừa nếu dạng có Vừa.
  /// - Dạng có 3 mức → Khó (3); dạng chỉ Dễ–Vừa → Vừa (2);
  ///   dạng chỉ có 1 mức → mức duy nhất đó.
  ///
  /// Chỉ cần mức cao nhất: dạng nào có Vừa (2) thì mức cao nhất của nó
  /// đã ≥ 2, nên điều kiện "không thấp hơn Vừa" không cần kiểm tra riêng
  /// (nhánh cũ `contains(2) && highest < 2` không bao giờ đúng).
  static int masteryLevelForForm(Set<int> supportedLevels) {
    assert(supportedLevels.isNotEmpty, 'Dạng bài phải hỗ trợ ít nhất 1 mức');
    return supportedLevels.reduce((a, b) => a > b ? a : b);
  }
}
