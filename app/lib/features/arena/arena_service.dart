/// Lưu bài thi Đấu trường và cộng kim cương (T2-10).
///
/// Thưởng kim cương chỉ cho bài ĐẦU TIÊN nộp xong mỗi ngày theo giờ
/// Việt Nam (ngày lấy từ `Clock` của database): Vàng 5, Bạc 3, Đồng 2,
/// Tham gia 1 ([ArenaMedal.gems]). Kim cương ghi vào `wallet_ledger`
/// (loại `gem`, lý do `arena_reward`) với `refId` theo ngày nên không
/// bao giờ cộng hai lần trong một ngày dù nộp lại. Bài thi bỏ dở không
/// qua đây nên không được tính, không được thưởng.
library;

import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import 'arena_config.dart';
import 'arena_session.dart';

/// Kết quả một bài đã nộp, đưa sang màn Kết quả.
class ArenaResult {
  const ArenaResult({
    required this.score,
    required this.durationSec,
    required this.gemsAwarded,
    required this.alreadyRewardedToday,
  });

  /// Điểm và số câu đúng (không có thông tin từng câu).
  final ArenaScore score;

  /// Thời gian làm bài, giây.
  final int durationSec;

  /// Kim cương vừa được cộng (0 nếu hôm nay đã nhận thưởng).
  final int gemsAwarded;

  /// Hôm nay đã nhận thưởng từ bài trước.
  final bool alreadyRewardedToday;
}

/// Tóm tắt cho màn sảnh: điểm cao nhất, trạng thái hôm nay.
class ArenaSummary {
  const ArenaSummary({
    required this.bestScore,
    required this.bestCorrect,
    required this.bestMedal,
    required this.attemptsToday,
    required this.rewardedToday,
    required this.xu,
    required this.gems,
  });

  /// Điểm cao nhất (null nếu chưa thi).
  final int? bestScore;

  /// Số câu đúng của bài điểm cao nhất.
  final int? bestCorrect;

  /// Huy chương của bài điểm cao nhất.
  final ArenaMedal? bestMedal;

  /// Số bài đã nộp hôm nay.
  final int attemptsToday;

  /// Hôm nay đã nhận thưởng kim cương chưa.
  final bool rewardedToday;

  /// Số dư xu.
  final int xu;

  /// Số dư kim cương.
  final int gems;
}

class ArenaService {
  ArenaService({required this._db});

  final AppDatabase _db;

  /// `refId` của thưởng Đấu trường: một lần mỗi ngày, mỗi bé.
  static String dailyRewardRefId({
    required String childId,
    required String date,
  }) => 'arena_daily:$childId:$date';

  /// Nộp bài: lưu `arena_attempts`, cộng kim cương nếu là bài đầu
  /// tiên trong ngày. Làm trong một transaction để hai lần nộp chồng
  /// nhau cũng không thưởng đôi.
  Future<ArenaResult> submit({
    required String childId,
    required ArenaScore score,
    required Duration duration,
    ArenaFormat format = ArenaFormat.heat,
  }) {
    return _db.transaction(() async {
      final date = _db.clock.today();
      final refId = dailyRewardRefId(childId: childId, date: date);
      final already = await _db.walletDao.hasEntryWithRefId(
        childId: childId,
        refId: refId,
      );
      final gems = already ? 0 : score.medal.gems;
      if (!already) {
        await _db.walletDao.addEntry(
          childId: childId,
          currency: Currency.gem,
          amount: gems,
          reason: 'arena_reward',
          refId: refId,
        );
      }
      await _db.arenaAttemptsDao.record(
        childId: childId,
        date: date,
        mode: format.code,
        correctCount: score.correct,
        score: score.points,
        medal: score.medal.code,
        durationSec: duration.inSeconds,
        gemsAwarded: gems,
      );
      return ArenaResult(
        score: score,
        durationSec: duration.inSeconds,
        gemsAwarded: gems,
        alreadyRewardedToday: already,
      );
    });
  }

  /// Hôm nay (giờ Việt Nam) bé đã nộp bài Đấu trường chưa. Dùng cho
  /// nhiệm vụ ngày "làm đấu trường hôm nay".
  Future<bool> didArenaToday(String childId) async =>
      await _db.arenaAttemptsDao.countOnDate(childId, _db.clock.today()) > 0;

  /// Tóm tắt cho màn sảnh.
  Future<ArenaSummary> summary(String childId) async {
    final date = _db.clock.today();
    final best = await _db.arenaAttemptsDao.best(childId);
    final today = await _db.arenaAttemptsDao.countOnDate(childId, date);
    final rewarded = await _db.walletDao.hasEntryWithRefId(
      childId: childId,
      refId: dailyRewardRefId(childId: childId, date: date),
    );
    final balances = await _db.walletDao.balances(childId);
    return ArenaSummary(
      bestScore: best?.score,
      bestCorrect: best?.correctCount,
      bestMedal: best == null ? null : ArenaMedal.fromCode(best.medal),
      attemptsToday: today,
      rewardedToday: rewarded,
      xu: balances[Currency.xu] ?? 0,
      gems: balances[Currency.gem] ?? 0,
    );
  }
}
