/// Bảng thưởng xu (DESIGN.md "Luật xu và kim cương", mục (c) trong
/// PLAN.md "Làm rõ ngày 17/11"). Mọi mức thưởng nằm ở một chỗ duy nhất
/// này để T1-11 (Ví xu) hoàn thiện bảng thưởng và hiển thị số dư.
///
/// - Đúng lần đầu: bậc 1–2 → 2 xu, bậc 3–4 → 3 xu, bậc 5–6 → 5 xu.
/// - Đúng sau gợi ý: nửa số xu, làm tròn lên.
/// - Câu ôn tập (từ sổ): gấp đôi (áp dụng sau khi chia đôi nếu có).
/// - Xong một chặng: 5 xu.
///
/// Ví dụ kiểm chứng T1-11: bậc 3–4, sổ ôn tập rỗng, 25 câu đúng ngay
/// lần đầu = 25 × 3 + 5 chặng × 5 + 20 (xong đề ngày) = 120 xu.
/// Thưởng xong đề ngày (20 xu + 1 kim cương) chưa cộng ở T1-09 mà do
/// T1-11 hoàn thiện, vì màn Thị trấn mới là nơi xác nhận xong đề ngày.
library;

class RewardConfig {
  RewardConfig._();

  /// Xu cơ số khi đúng ngay lần đầu, theo bậc của câu.
  static int baseXuForRung(int rung) {
    if (rung <= 2) return 2;
    if (rung <= 4) return 3;
    return 5;
  }

  /// Số xu một câu trả lời đúng được nhận.
  ///
  /// [correctFirstTry] false nghĩa là đúng sau gợi ý: nửa số xu,
  /// làm tròn lên. [isReview] true nghĩa là câu ôn tập: gấp đôi.
  static int xuForQuestion({
    required int rung,
    required bool correctFirstTry,
    required bool isReview,
  }) {
    var xu = baseXuForRung(rung);
    if (!correctFirstTry) {
      xu = (xu + 1) ~/ 2;
    }
    if (isReview) {
      xu *= 2;
    }
    return xu;
  }

  /// Xu thưởng khi xong một chặng (5 câu).
  static const int stageCompleteBonusXu = 5;

  /// Xu thưởng khi xong cả đề ngày (T1-11 cộng).
  static const int dailySetCompleteBonusXu = 20;

  /// Kim cương thưởng khi xong cả đề ngày (T1-11 cộng).
  static const int dailySetCompleteBonusGems = 1;
}
