/// Dịch vụ cộng xu/kim cương và đọc số dư (T1-11 "Ví xu").
///
/// Mọi lần cộng xu/kim cương đều ghi một dòng vào `wallet_ledger`
/// qua [WalletDao] (chỉ thêm dòng, không sửa/xóa); số dư = tổng cột
/// `amount` theo từng loại tiền. Thưởng một-lần-mỗi-ngày chống cộng
/// trùng bằng `refId` (xem [dailyCompleteRefId]).
library;

import '../../core/database/app_database.dart';
import '../../core/database/daos.dart';
import '../../core/database/models.dart';
import '../../core/database/tables.dart';
import '../daily_set/daily_set_config.dart';
import 'reward_config.dart';

class RewardService {
  RewardService({required AppDatabase db, required this.config})
    : _db = db,
      _walletDao = db.walletDao;

  final AppDatabase _db;
  final WalletDao _walletDao;

  /// Bảng thưởng đang dùng.
  final RewardConfig config;

  /// `refId` cho thưởng xong đề ngày: một lần mỗi ngày, mỗi bé.
  /// Dạng `daily_complete:<childId>:<YYYY-MM-DD>`.
  static String dailyCompleteRefId({
    required String childId,
    required String date,
  }) => 'daily_complete:$childId:$date';

  /// Cộng xu cho một câu trả lời đúng. Trả về số xu đã cộng.
  Future<int> awardQuestion({
    required String childId,
    required int rung,
    required bool correctFirstTry,
    required bool isReview,
    String? refId,
  }) async {
    final xu = config.xuForQuestion(
      rung: rung,
      correctFirstTry: correctFirstTry,
      isReview: isReview,
    );
    await _walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: xu,
      reason: isReview
          ? (correctFirstTry ? 'review_correct' : 'review_correct_after_hint')
          : (correctFirstTry
                ? 'question_correct'
                : 'question_correct_after_hint'),
      refId: refId,
    );
    return xu;
  }

  /// Cộng xu xong chặng. Chặng trong đề ngày đã xong rồi (trạng thái
  /// `done` trong đề đã lưu) thì không cộng lại (trả 0); chặng tự
  /// chọn (`dailySetId` null) luôn cộng vì làm thêm không giới hạn
  /// (DESIGN). Đề ngày không tìm thấy thì vẫn cộng (không chặn bé
  /// vì lỗi dữ liệu lạ).
  Future<int> awardStageComplete({
    required String childId,
    required String? dailySetId,
    required int stageIndex,
  }) async {
    if (dailySetId != null) {
      final set = await _db.dailySetsDao.getDailySetById(dailySetId);
      if (set != null) {
        final statuses = _db.dailySetsDao.readStageStatus(set);
        if (stageIndex < statuses.length &&
            statuses[stageIndex] == StageStatus.done) {
          return 0;
        }
      }
    }
    await _walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: config.stageCompleteBonusXu,
      reason: 'stage_complete',
      refId: dailySetId,
    );
    return config.stageCompleteBonusXu;
  }

  /// Cộng thưởng xong đề ngày nếu cả 5 chặng đã xong. Idempotent:
  /// gọi lại trong cùng ngày thì không cộng thêm (trả false).
  /// Trả true nếu vừa cộng (xu + kim cương) và đánh dấu đề đã xong;
  /// false nếu chưa đủ chặng hoặc đã cộng rồi.
  Future<bool> awardDailyCompleteIfDone({
    required String childId,
    required String dailySetId,
  }) async {
    final set = await _db.dailySetsDao.getDailySetById(dailySetId);
    if (set == null) return false;
    final statuses = _db.dailySetsDao.readStageStatus(set);
    if (statuses.length != DailySetConfig.stagesPerDay ||
        statuses.any((s) => s != StageStatus.done)) {
      return false;
    }
    final refId = dailyCompleteRefId(childId: childId, date: set.date);
    if (await _walletDao.hasEntryWithRefId(childId: childId, refId: refId)) {
      // Đã cộng rồi (vd: app tắt giữa chừng sau khi cộng nhưng
      // trước khi đánh dấu xong): đảm bảo đề được đánh dấu xong.
      await _db.dailySetsDao.markCompleted(dailySetId);
      return false;
    }
    await _walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: config.dailySetCompleteBonusXu,
      reason: 'daily_complete',
      refId: refId,
    );
    await _walletDao.addEntry(
      childId: childId,
      currency: Currency.gem,
      amount: config.dailySetCompleteBonusGems,
      reason: 'daily_complete',
      refId: refId,
    );
    await _db.dailySetsDao.markCompleted(dailySetId);
    return true;
  }

  /// Số dư xu và kim cương = tổng `wallet_ledger` của bé.
  Future<Map<String, int>> balances(String childId) =>
      _walletDao.balances(childId);

  /// Số dư xu của bé.
  Future<int> xuBalance(String childId) =>
      _walletDao.balance(childId: childId, currency: Currency.xu);

  /// Số dư kim cương của bé.
  Future<int> gemBalance(String childId) =>
      _walletDao.balance(childId: childId, currency: Currency.gem);
}
