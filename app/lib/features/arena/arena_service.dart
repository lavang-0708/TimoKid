/// Lưu bài thi Đấu trường và cộng kim cương (T2-10).
///
/// Thưởng kim cương chỉ cho bài ĐẦU TIÊN nộp xong mỗi ngày theo giờ
/// Việt Nam (ngày lấy từ `Clock` của database) CỦA TỪNG VÒNG: vòng loại
/// Vàng 5, Bạc 3, Đồng 2, Tham gia 1; Chung kết 8 / 5 / 3 / 2
/// ([ArenaFormat.gemsFor]). Kim cương ghi vào `wallet_ledger`
/// (loại `gem`, lý do `arena_reward`) với `refId` theo ngày và vòng nên
/// không bao giờ cộng hai lần một vòng trong một ngày dù nộp lại; bé
/// vẫn nhận được thưởng của cả hai vòng nếu thi cả hai trong ngày. Bài thi bỏ dở không
/// qua đây nên không được tính, không được thưởng.
library;

import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import '../pet/pet_care_service.dart';
import '../pet/pet_service.dart';
import 'arena_config.dart';
import 'arena_session.dart';

/// Kết quả một bài đã nộp, đưa sang màn Kết quả.
class ArenaResult {
  const ArenaResult({
    required this.score,
    required this.durationSec,
    required this.gemsAwarded,
    required this.alreadyRewardedToday,
    this.format = ArenaFormat.heat,
  });

  /// Vòng đã thi.
  final ArenaFormat format;

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
    this.finalUnlocked = false,
    this.finalBestScore,
    this.finalBestCorrect,
    this.finalBestMedal,
    this.finalRewardedToday = false,
  });

  /// Vòng Chung kết đã mở (có huy chương Bạc trở lên ở vòng loại).
  final bool finalUnlocked;

  /// Bài điểm cao nhất của Chung kết (null nếu chưa thi).
  final int? finalBestScore;
  final int? finalBestCorrect;
  final ArenaMedal? finalBestMedal;

  /// Hôm nay đã nhận thưởng Chung kết chưa.
  final bool finalRewardedToday;

  /// Điểm cao nhất của vòng loại (null nếu chưa thi).
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

  /// `refId` của thưởng Đấu trường: một lần mỗi ngày, mỗi bé, mỗi vòng.
  /// Vòng loại giữ dạng cũ `arena_daily:...` (tương thích dữ liệu đã
  /// có); Chung kết là `arena_final_daily:...`.
  static String dailyRewardRefId({
    required String childId,
    required String date,
    ArenaFormat format = ArenaFormat.heat,
  }) => format.code == ArenaFormat.finalRound.code
      ? 'arena_final_daily:$childId:$date'
      : 'arena_daily:$childId:$date';

  /// Vòng Chung kết đã mở chưa: bé có ít nhất một bài vòng loại được
  /// huy chương [arenaFinalUnlockMedal] (Bạc) trở lên.
  Future<bool> isFinalUnlocked(String childId) async {
    final rows = await _db.arenaAttemptsDao.getAll(childId);
    return rows.any(
      (a) =>
          a.mode != ArenaFormat.finalRound.code &&
          arenaMedalAtLeast(
            ArenaMedal.fromCode(a.medal),
            arenaFinalUnlockMedal,
          ),
    );
  }

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
      final refId = dailyRewardRefId(
        childId: childId,
        date: date,
        format: format,
      );
      final already = await _db.walletDao.hasEntryWithRefId(
        childId: childId,
        refId: refId,
      );
      final gems = already ? 0 : format.gemsFor(score.medal);
      if (!already) {
        await _db.walletDao.addEntry(
          childId: childId,
          currency: Currency.gem,
          amount: gems,
          reason: 'arena_reward',
          refId: refId,
        );
      }
      // Pet (D): câu đúng của đấu trường (không gợi ý, không thử lại)
      // đều là đúng ngay lần đầu → cộng xp; xong đấu trường lần đầu
      // trong ngày nhận một suất ăn.
      await PetService(db: _db).addXp(childId, amount: score.correct);
      await PetCareService(db: _db)
          .awardMeal(childId, refId: 'arena:$childId:$date');
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
        format: format,
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
    final rows = await _db.arenaAttemptsDao.getAll(childId);
    ArenaAttempt? bestOf(bool isFinal) {
      ArenaAttempt? best;
      for (final a in rows) {
        if ((a.mode == ArenaFormat.finalRound.code) != isFinal) continue;
        if (best == null || a.score > best.score) best = a;
      }
      return best;
    }

    final heat = bestOf(false);
    final fin = bestOf(true);
    final today = rows.where((a) => a.date == date).length;
    Future<bool> rewarded(ArenaFormat f) => _db.walletDao.hasEntryWithRefId(
      childId: childId,
      refId: dailyRewardRefId(childId: childId, date: date, format: f),
    );
    final balances = await _db.walletDao.balances(childId);
    return ArenaSummary(
      bestScore: heat?.score,
      bestCorrect: heat?.correctCount,
      bestMedal: heat == null ? null : ArenaMedal.fromCode(heat.medal),
      attemptsToday: today,
      rewardedToday: await rewarded(ArenaFormat.heat),
      xu: balances[Currency.xu] ?? 0,
      gems: balances[Currency.gem] ?? 0,
      finalUnlocked: await isFinalUnlocked(childId),
      finalBestScore: fin?.score,
      finalBestCorrect: fin?.correctCount,
      finalBestMedal: fin == null ? null : ArenaMedal.fromCode(fin.medal),
      finalRewardedToday: await rewarded(ArenaFormat.finalRound),
    );
  }
}
