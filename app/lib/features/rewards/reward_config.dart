/// Bảng thưởng xu và kim cương (DESIGN.md "Luật xu và kim cương",
/// mục (c) trong PLAN.md "Làm rõ ngày 17/11"). T1-11: bảng thưởng
/// đọc từ `settings` (khóa `rewards`, đã seed từ T1-04 bằng
/// [defaultRewardsJson]) thay vì giá trị cứng như bản T1-09.
///
/// - Đúng lần đầu: bậc 1–2 → 2 xu, bậc 3–4 → 3 xu, bậc 5–6 → 5 xu.
/// - Đúng sau gợi ý: nửa số xu, làm tròn lên.
/// - Câu ôn tập (từ sổ): gấp đôi (áp dụng sau khi chia đôi nếu có).
/// - Xong một chặng: 5 xu.
/// - Xong đề ngày: 20 xu và 1 kim cương (một lần mỗi ngày).
/// - Thành thạo một dạng mới: 2 kim cương (khóa `mastery_gem` có
///   trong bảng nhưng chưa cộng ở T1-11, xem DECISIONS mục T1-11).
///
/// Ví dụ kiểm chứng T1-11: bậc 3–4, sổ ôn tập rỗng, 25 câu đúng ngay
/// lần đầu = 25 × 3 + 5 chặng × 5 + 20 (xong đề ngày) = 120 xu,
/// và 1 kim cương.
library;

import 'dart:convert';

import '../../core/database/app_database.dart';

class RewardConfig {
  const RewardConfig({
    required this.easy,
    required this.medium,
    required this.hard,
    required this.stageCompleteXu,
    required this.dailyCompleteXu,
    required this.dailyCompleteGem,
    required this.masteryGem,
  });

  /// Bảng mặc định — bằng đúng [defaultRewardsJson] đã seed vào
  /// `settings` (T1-04). Dùng khi settings chưa có hoặc JSON lỗi.
  factory RewardConfig.defaults() => RewardConfig.fromJson(
    jsonDecode(defaultRewardsJson) as Map<String, dynamic>,
  );

  /// Dựng từ JSON đã giải mã. Thiếu khóa nào hoặc khóa nào không
  /// phải số nguyên thì lấy giá trị mặc định của khóa đó.
  factory RewardConfig.fromJson(Map<String, Object?> json) {
    int pick(String key, int fallback) {
      final value = json[key];
      return value is int ? value : fallback;
    }

    return RewardConfig(
      easy: pick('easy', 2),
      medium: pick('medium', 3),
      hard: pick('hard', 5),
      stageCompleteXu: pick('stage_complete', 5),
      dailyCompleteXu: pick('daily_complete_xu', 20),
      dailyCompleteGem: pick('daily_complete_gem', 1),
      masteryGem: pick('mastery_gem', 2),
    );
  }

  /// Đọc bảng thưởng hiệu lực từ `settings` (khóa `rewards`): mức riêng
  /// của bé (web admin ghi theo bé, app tải về sau mỗi lần đồng bộ) trước,
  /// không có thì mức chung đã seed. [childId] mặc định là bé đang chơi.
  /// Settings thiếu, JSON lỗi hoặc không phải object thì dùng mặc định.
  static Future<RewardConfig> load(AppDatabase db, {String? childId}) async {
    final raw = await db.settingsDao.getEffectiveValue(
      childId: childId ?? await db.activeChildId(),
      key: 'rewards',
    );
    if (raw == null) return RewardConfig.defaults();
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) {
        return RewardConfig.fromJson(parsed);
      }
    } catch (_) {
      // JSON hỏng: rơi về mặc định.
    }
    return RewardConfig.defaults();
  }

  /// Xu cơ số khi đúng ngay lần đầu, mức Dễ (bậc 1–2).
  final int easy;

  /// Xu cơ số khi đúng ngay lần đầu, mức Vừa (bậc 3–4).
  final int medium;

  /// Xu cơ số khi đúng ngay lần đầu, mức Khó (bậc 5–6).
  final int hard;

  /// Xu thưởng khi xong một chặng (5 câu).
  final int stageCompleteXu;

  /// Xu thưởng khi xong cả đề ngày.
  final int dailyCompleteXu;

  /// Kim cương thưởng khi xong cả đề ngày.
  final int dailyCompleteGem;

  /// Kim cương thưởng khi thành thạo một dạng bài mới.
  final int masteryGem;

  /// Xu thưởng khi xong một chặng (bí danh cho [stageCompleteXu]).
  int get stageCompleteBonusXu => stageCompleteXu;

  /// Xu thưởng khi xong cả đề ngày (bí danh cho [dailyCompleteXu]).
  int get dailySetCompleteBonusXu => dailyCompleteXu;

  /// Kim cương thưởng khi xong cả đề ngày (bí danh cho
  /// [dailyCompleteGem]).
  int get dailySetCompleteBonusGems => dailyCompleteGem;

  /// Xu cơ số khi đúng ngay lần đầu, theo bậc của câu.
  int baseXuForRung(int rung) {
    if (rung <= 2) return easy;
    if (rung <= 4) return medium;
    return hard;
  }

  /// Số xu một câu trả lời đúng được nhận.
  ///
  /// [correctFirstTry] false nghĩa là đúng sau gợi ý: nửa số xu,
  /// làm tròn lên. [isReview] true nghĩa là câu ôn tập: gấp đôi
  /// (áp dụng sau khi chia đôi nếu có).
  int xuForQuestion({
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

  @override
  bool operator ==(Object other) =>
      other is RewardConfig &&
      other.easy == easy &&
      other.medium == medium &&
      other.hard == hard &&
      other.stageCompleteXu == stageCompleteXu &&
      other.dailyCompleteXu == dailyCompleteXu &&
      other.dailyCompleteGem == dailyCompleteGem &&
      other.masteryGem == masteryGem;

  @override
  int get hashCode => Object.hash(
    easy,
    medium,
    hard,
    stageCompleteXu,
    dailyCompleteXu,
    dailyCompleteGem,
    masteryGem,
  );
}
