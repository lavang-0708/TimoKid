/// Hạng đấu trường theo tuần và rương cuối tuần (spec tuần 23/11, mục B).
///
/// Điểm tuần = tổng số câu đúng của các ngày thi trong tuần (thứ Hai đến
/// Chủ nhật, giờ Việt Nam, lấy từ `Clock` của database nên QA nhảy ngày
/// thử được). Mỗi ngày chỉ tính bài đúng nhiều nhất, tối đa 25 câu, để
/// thi lại luyện tập không làm phình điểm. Bài Chung kết (30 câu) tính
/// như vòng loại: lấy số câu đúng cao nhất trong ngày qua mọi vòng, nên
/// một ngày tối đa 30 điểm (kẹp theo số câu của vòng đó). Rương tuần trước nhận một lần:
/// khóa `settings` + `refId` trong `wallet_ledger` chống cộng hai lần.
library;

import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import 'arena_config.dart';
import 'league_config.dart';

/// Thứ Hai đầu tuần của ngày [date] (`YYYY-MM-DD`), cùng dạng chuỗi.
String leagueWeekStart(String date) {
  final d = _parse(date);
  return _fmt(d.subtract(Duration(days: d.weekday - DateTime.monday)));
}

/// Ngày [date] cộng thêm [days] ngày (có thể âm).
String leagueAddDays(String date, int days) =>
    _fmt(_parse(date).add(Duration(days: days)));

DateTime _parse(String date) {
  final p = date.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Tình trạng hạng của một tuần.
class LeagueWeek {
  const LeagueWeek({
    required this.weekStart,
    required this.points,
    required this.attempts,
    required this.daysLeft,
  });

  /// Thứ Hai của tuần (`YYYY-MM-DD`).
  final String weekStart;

  /// Điểm tuần (số câu đúng cộng dồn theo ngày).
  final int points;

  /// Số ngày có thi trong tuần.
  final int attempts;

  /// Số ngày còn lại tính cả hôm nay (Chủ nhật = 1); 0 cho tuần đã qua.
  final int daysLeft;

  /// Hạng hiện có; null nếu tuần chưa thi.
  LeagueTier? get tier => leagueTierFor(points: points, attempts: attempts);

  /// Hạng kế tiếp cần đạt; null nếu chưa thi (Đồng là bước đầu) hoặc đã
  /// ở hạng cao nhất.
  LeagueTier? get nextTier => tier == null ? LeagueTier.bronze : tier!.next;

  /// Tiến độ 0..1 tới hạng kế (1 nếu đã cao nhất).
  double get progress {
    final cur = tier;
    final nxt = nextTier;
    if (nxt == null) return 1;
    if (cur == null) return 0;
    final span = nxt.minPoints - cur.minPoints;
    return ((points - cur.minPoints) / span).clamp(0.0, 1.0);
  }

  /// Số câu đúng còn thiếu để lên hạng kế (0 nếu đã cao nhất).
  int get pointsToNext {
    final nxt = nextTier;
    if (nxt == null || tier == null) return 0;
    return (nxt.minPoints - points).clamp(0, nxt.minPoints);
  }
}

/// Rương cuối tuần đang chờ bé mở.
class LeagueChest {
  const LeagueChest({
    required this.weekStart,
    required this.tier,
    required this.points,
  });

  /// Thứ Hai của tuần đã kết thúc.
  final String weekStart;
  final LeagueTier tier;
  final int points;

  /// Số kim cương trong rương.
  int get gems => tier.chestGems;
}

class LeagueService {
  LeagueService({required this._db});

  final AppDatabase _db;

  /// `settings` khóa đã nhận rương của tuần bắt đầu [weekStart].
  static String claimedKey(String weekStart) =>
      '$leagueClaimedKeyPrefix$weekStart';

  /// `refId` ví của rương tuần: một lần mỗi tuần, mỗi bé.
  static String chestRefId({
    required String childId,
    required String weekStart,
  }) => 'arena_week:$childId:$weekStart';

  /// Thứ Hai của tuần hiện tại (theo đồng hồ của database).
  String currentWeekStart() => leagueWeekStart(_db.clock.today());

  /// Tình trạng tuần bắt đầu từ [weekStart] (mặc định tuần này).
  Future<LeagueWeek> week(String childId, {String? weekStart}) async {
    final today = _db.clock.today();
    final start = weekStart ?? leagueWeekStart(today);
    final end = leagueAddDays(start, leagueWeekDays - 1);
    final rows = await _db.arenaAttemptsDao.getAll(childId);
    final bestByDay = <String, int>{};
    for (final a in rows) {
      if (a.date.compareTo(start) < 0 || a.date.compareTo(end) > 0) continue;
      final c = a.correctCount.clamp(
        0,
        ArenaFormat.fromCode(a.mode).totalQuestions,
      );
      if (c > (bestByDay[a.date] ?? -1)) bestByDay[a.date] = c;
    }
    final points = bestByDay.values.fold<int>(0, (s, c) => s + c);
    final left = today.compareTo(end) > 0
        ? 0
        : (leagueWeekDays - (_dayIndex(start, today))).clamp(0, 7);
    return LeagueWeek(
      weekStart: start,
      points: points,
      attempts: bestByDay.length,
      daysLeft: left,
    );
  }

  int _dayIndex(String start, String today) =>
      _parse(today).difference(_parse(start)).inDays.clamp(0, 6);

  /// Rương của tuần trước nếu có thi và chưa nhận; ngược lại null.
  Future<LeagueChest?> pendingChest(String childId) async {
    final lastStart = leagueAddDays(currentWeekStart(), -leagueWeekDays);
    final claimed = await _db.settingsDao.getValue(
      childId: childId,
      key: claimedKey(lastStart),
    );
    if (claimed != null) return null;
    final w = await week(childId, weekStart: lastStart);
    final tier = w.tier;
    if (tier == null) return null;
    return LeagueChest(weekStart: lastStart, tier: tier, points: w.points);
  }

  /// Nhận rương: cộng kim cương một lần. Trả số kim cương vừa cộng
  /// (0 nếu đã nhận hoặc không có rương).
  Future<int> claimChest(String childId, {required String weekStart}) {
    return _db.transaction(() async {
      final key = claimedKey(weekStart);
      final refId = chestRefId(childId: childId, weekStart: weekStart);
      final done =
          await _db.settingsDao.getValue(childId: childId, key: key) != null ||
          await _db.walletDao.hasEntryWithRefId(childId: childId, refId: refId);
      final w = await week(childId, weekStart: weekStart);
      final tier = w.tier;
      if (done || tier == null) return 0;
      await _db.walletDao.addEntry(
        childId: childId,
        currency: Currency.gem,
        amount: tier.chestGems,
        reason: 'arena_week_chest',
        refId: refId,
      );
      await _db.settingsDao.setValue(childId: childId, key: key, value: '1');
      return tier.chestGems;
    });
  }
}
