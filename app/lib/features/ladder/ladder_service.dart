/// Thang ải (bậc 1–6 theo mảng) và thành thạo dạng bài (T1-07).
///
/// Dart thuần, không phụ thuộc widget. Đọc/ghi qua DAO của T1-04
/// (`AttemptsDao`, `SkillProgressDao`); thời gian qua `Clock` của DB
/// (DAO tự lấy `db.clock.now()` khi ghi, service này không gọi giờ).
///
/// API này là API mà T1-08 (đề ngày) sẽ dùng tiếp:
/// - [rungFor]/[rungsFor]: bậc hiện tại (chưa có dòng thì bậc 1).
/// - [evaluateStrand]: sau mỗi lần bé trả lời xong, đánh giá cửa sổ
///   10 câu của mảng và lên/xuống bậc nếu đủ điều kiện; đổi bậc thì
///   cửa sổ reset (DAO đặt lại `windowStartedAt`).
/// - [evaluateFormMastery]/[isFormMastered]: thành thạo theo dạng bài.
///
/// "Đúng" ở mọi chỗ dưới đây luôn là đúng ngay lần đầu
/// (`correctFirstTry`); câu đúng sau gợi ý không tính (PLAN mục (f)).
library;

import '../../core/database/daos.dart';
import '../../core/database/tables.dart';
import '../questions/question_registry.dart';
import 'ladder_config.dart';

/// Kết quả một lần đánh giá lên/xuống bậc của một mảng.
class RungEvaluation {
  const RungEvaluation({
    required this.previousRung,
    required this.newRung,
    required this.correctCount,
    required this.attemptedCount,
  });

  /// Bậc trước khi đánh giá.
  final int previousRung;

  /// Bậc sau khi đánh giá (bằng bậc cũ nếu không đổi).
  final int newRung;

  /// Số câu đúng ngay lần đầu trong cửa sổ.
  final int correctCount;

  /// Số câu trong cửa sổ (nhỏ hơn [LadderConfig.windowSize] nghĩa là
  /// cửa sổ chưa đủ 10 câu nên chưa đánh giá).
  final int attemptedCount;

  /// Cửa sổ đã đủ 10 câu hay chưa.
  bool get windowFull => attemptedCount >= LadderConfig.windowSize;

  /// Có đổi bậc hay không.
  bool get changed => newRung != previousRung;

  /// Lên bậc.
  bool get promoted => newRung > previousRung;

  /// Xuống bậc.
  bool get demoted => newRung < previousRung;
}

/// Tính bậc theo mảng và trạng thái thành thạo theo dạng bài.
class LadderService {
  LadderService({required this._attemptsDao, required this._skillProgressDao});
  final AttemptsDao _attemptsDao;
  final SkillProgressDao _skillProgressDao;

  /// Bậc hiện tại của một mảng. Chưa có dòng tiến độ thì bậc 1.
  Future<int> rungFor({required String childId, required String strand}) async {
    final progress = await _skillProgressDao.getStrandProgress(childId, strand);
    return progress?.rung ?? LadderConfig.initialRung;
  }

  /// Bậc hiện tại của cả 5 mảng (thiếu mảng nào thì bậc 1).
  Future<Map<String, int>> rungsFor({required String childId}) async {
    final rows = await _skillProgressDao.getAllStrandProgress(childId);
    final rungs = {for (final s in Strand.all) s: LadderConfig.initialRung};
    for (final row in rows) {
      if (row.rung != null) {
        rungs[row.key] = row.rung!;
      }
    }
    return rungs;
  }

  /// Đánh giá cửa sổ 10 câu gần nhất của một mảng (tính từ mốc đổi bậc
  /// gần nhất trở đi) và lên/xuống bậc nếu đủ điều kiện:
  /// - Đúng ngay ≥ 8/10 và chưa ở bậc 6 → lên 1 bậc.
  /// - Đúng ngay < 5/10 và chưa ở bậc 1 → xuống 1 bậc.
  /// - Còn lại giữ nguyên bậc.
  ///
  /// Cửa sổ chưa đủ 10 câu thì không làm gì. Đổi bậc thì DAO đặt lại
  /// mốc cửa sổ (`windowStartedAt`) nên lần sau tính lại từ 10 câu mới.
  /// Câu ôn tập (`isReview`) vẫn tính như câu thường: luật chỉ nói
  /// "10 câu gần nhất của mảng", không loại trừ câu ôn tập.
  Future<RungEvaluation> evaluateStrand({
    required String childId,
    required String strand,
  }) async {
    final progress = await _skillProgressDao.getStrandProgress(childId, strand);
    final currentRung = progress?.rung ?? LadderConfig.initialRung;
    final attempts = await _attemptsDao.getRecentStrandAttempts(
      childId: childId,
      strand: strand,
      since: progress?.windowStartedAt,
      limit: LadderConfig.windowSize,
    );
    final correctCount = attempts.where((a) => a.correctFirstTry).length;
    var newRung = currentRung;
    if (attempts.length >= LadderConfig.windowSize) {
      if (correctCount >= LadderConfig.promoteThreshold &&
          currentRung < LadderConfig.maxRung) {
        newRung = currentRung + 1;
      } else if (correctCount < LadderConfig.demoteThreshold &&
          currentRung > LadderConfig.minRung) {
        newRung = currentRung - 1;
      }
    }
    if (newRung != currentRung) {
      await _skillProgressDao.setStrandRung(
        childId: childId,
        strand: strand,
        rung: newRung,
      );
    }
    return RungEvaluation(
      previousRung: currentRung,
      newRung: newRung,
      correctCount: correctCount,
      attemptedCount: attempts.length,
    );
  }

  /// Đánh giá thành thạo một dạng bài (mục (b)): đúng ngay lần đầu
  /// 4/5 câu gần nhất ở mức thành thạo của dạng (mức cao nhất dạng hỗ
  /// trợ, không thấp hơn Vừa nếu dạng có Vừa). Kết quả được ghi vào
  /// `skill_progress` (dòng `form`) và trả về.
  ///
  /// Chỉ tính các lượt trả lời ĐÚNG ở mức thành thạo: câu làm ở mức thấp
  /// hơn không tính vào cửa sổ 5 câu. Chưa đủ 5 câu ở mức đó thì chưa
  /// thành thạo.
  Future<bool> evaluateFormMastery({
    required String childId,
    required String formId,
  }) async {
    final generator = questionGeneratorFor(formId);
    if (generator == null) {
      throw ArgumentError('Không có dạng bài nào mang mã $formId');
    }
    final masteryLevel = LadderConfig.masteryLevelForForm(
      generator.supportedLevels,
    );
    final attempts = await _attemptsDao.getRecentFormAttempts(
      childId: childId,
      formId: formId,
      level: masteryLevel,
      limit: LadderConfig.masteryWindow,
    );
    final correctCount = attempts.where((a) => a.correctFirstTry).length;
    final mastered =
        attempts.length >= LadderConfig.masteryWindow &&
        correctCount >= LadderConfig.masteryCorrectNeeded;
    await _skillProgressDao.setFormMastered(
      childId: childId,
      formId: formId,
      mastered: mastered,
    );
    return mastered;
  }

  /// Dạng bài đã thành thạo hay chưa (đọc cờ đã lưu, không tính lại).
  Future<bool> isFormMastered({
    required String childId,
    required String formId,
  }) async {
    final progress = await _skillProgressDao.getFormProgress(childId, formId);
    return progress?.mastered ?? false;
  }

  /// Các dạng bài đã thành thạo của bé.
  Future<List<String>> masteredForms({required String childId}) async {
    final rows = await _skillProgressDao.getMasteredForms(childId);
    return rows.map((r) => r.key).toList();
  }
}
