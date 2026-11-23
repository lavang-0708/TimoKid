/// Nhiệm vụ ngày + chuỗi ngày (tuần 23/11, mục C).
///
/// Tiến độ TÍNH từ dữ liệu có sẵn, không ghi sự kiện riêng:
/// - đúng N câu mảng X / làm lại câu ôn tập: bảng `attempts` (`created_at`
///   trong ngày giờ Việt Nam, `correct_first_try`, `strand`, `is_review`);
/// - xong chặng ngày của tòa X / xong đề ngày: `daily_sets.stage_status`;
/// - leo qua tầng tháp: bộ đếm `tower_clears.<ngày>` do `TowerService` ghi;
/// - đấu trường: `arena_attempts`; cho pet ăn / chơi: `pet_care.<ngày>`.
/// Nhờ tính theo ngày nên đếm chuỗi cho các ngày trước cũng dùng đúng
/// các hàm này.
///
/// Lưu trong `settings` (theo bé), không đổi schema:
/// - `quest_day.<ngày>`: JSON danh sách mã 3 nhiệm vụ của ngày. Chọn
///   bằng seed (bé, ngày) lần đầu xem rồi LƯU, để bé nhận pet giữa ngày
///   cũng không làm nhiệm vụ đổi;
/// - `quest_done.<ngày>`: dấu "xong đủ 3 nhiệm vụ" (chỉ tăng, không mất);
/// - `quest_chest.<ngày>`: rương chuỗi đã đạt ở ngày đó (chờ bé nhận).
///
/// Thưởng ghi `wallet_ledger` với `refId` riêng nên bấm hai lần không
/// cộng đôi: `quest:<bé>:<ngày>:<mã>`, `quest_bonus:<bé>:<ngày>`,
/// `quest_chest:<bé>:<ngày>`.
library;

import 'dart:convert';

import '../../core/database/app_database.dart';
import '../../core/database/models.dart';
import '../../core/database/tables.dart';
import '../../core/time/clock.dart';
import '../arena/league_service.dart' show leagueAddDays;
import '../pet/pet_care_service.dart';
import '../pet/pet_service.dart';
import '../tower/tower_service.dart';
import 'quest_config.dart';

/// Một nhiệm vụ của ngày: loại + mảng (nếu có).
class Quest {
  const Quest(this.type, [this.strand]);

  final QuestType type;
  final String? strand;

  /// Mã ổn định để lưu: `strandCorrect:logic`, `arena`…
  String get id => strand == null ? type.name : '${type.name}:$strand';

  /// Mức cần đạt (số câu hoặc 1 lần).
  int get target => switch (type) {
    QuestType.strandCorrect => QuestConfig.strandCorrectTarget,
    QuestType.reviewRetry => QuestConfig.reviewRetryTarget,
    _ => 1,
  };

  /// Đọc lại từ mã; null nếu mã lạ.
  static Quest? parse(String id) {
    final parts = id.split(':');
    for (final t in QuestType.values) {
      if (t.name != parts.first) continue;
      if (t.needsStrand) {
        if (parts.length != 2 || !Strand.all.contains(parts[1])) return null;
        return Quest(t, parts[1]);
      }
      return Quest(t);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is Quest && other.type == type && other.strand == strand;

  @override
  int get hashCode => Object.hash(type, strand);
}

/// Trạng thái một nhiệm vụ của hôm nay.
class QuestStatus {
  const QuestStatus({
    required this.quest,
    required this.progress,
    required this.claimed,
  });

  final Quest quest;

  /// Tiến độ (đã kẹp tối đa bằng mức cần đạt).
  final int progress;
  final bool claimed;

  int get target => quest.target;
  bool get completed => progress >= target;

  /// Xong mà chưa nhận quà.
  bool get claimable => completed && !claimed;
}

/// Bảng nhiệm vụ của một ngày + chuỗi.
class QuestBoard {
  const QuestBoard({
    required this.date,
    required this.quests,
    required this.bonusClaimed,
    required this.streak,
    required this.pendingChests,
  });

  final String date;
  final List<QuestStatus> quests;

  /// Đã nhận kim cương thưởng "đủ cả 3".
  final bool bonusClaimed;

  /// Số ngày liên tiếp xong đủ 3 nhiệm vụ (kể cả hôm nay nếu đã xong;
  /// hôm nay chưa xong thì tính tới hôm qua).
  final int streak;

  /// Ngày đạt của các rương chuỗi chưa nhận (cũ nhất trước).
  final List<String> pendingChests;

  bool get allCompleted => quests.every((q) => q.completed);
  bool get allClaimed => quests.every((q) => q.claimed);

  /// Số nhiệm vụ đã xong.
  int get completedCount => quests.where((q) => q.completed).length;

  /// Có quà chưa nhận (nhiệm vụ xong hoặc rương chuỗi) → chấm đỏ.
  bool get hasClaimable =>
      quests.any((q) => q.claimable) || pendingChests.isNotEmpty;
}

enum QuestClaimResult { claimed, notDone, alreadyClaimed, unknown }

/// Kết quả một lần bấm nhận nhiệm vụ.
class QuestClaim {
  const QuestClaim(this.result, {this.xu = 0, this.gems = 0});

  final QuestClaimResult result;

  /// Xu nhận được lần này.
  final int xu;

  /// Kim cương nhận được lần này (thưởng "đủ cả 3" nếu đây là lần nhận cuối).
  final int gems;

  bool get ok => result == QuestClaimResult.claimed;
}

String questDayKey(String date) => 'quest_day.$date';
String questDoneKey(String date) => 'quest_done.$date';
String questChestKey(String date) => 'quest_chest.$date';
const String _chestKeyPrefix = 'quest_chest.';

class QuestService {
  QuestService({required this.db});

  final AppDatabase db;

  Clock get _clock => db.clock;
  String get _today => _clock.today();

  static String claimRefId(String childId, String date, String questId) =>
      'quest:$childId:$date:$questId';
  static String bonusRefId(String childId, String date) =>
      'quest_bonus:$childId:$date';
  static String chestRefId(String childId, String date) =>
      'quest_chest:$childId:$date';

  // ------------------------------------------------------------ chọn

  /// Chọn [QuestConfig.questsPerDay] nhiệm vụ cho (bé, ngày): xác định
  /// theo seed, không trùng loại; không có pet thì bỏ nhiệm vụ pet.
  /// Hàm thuần, không đọc database.
  static List<Quest> pickQuests({
    required String childId,
    required String date,
    required bool hasPet,
  }) {
    final rng = _Rng(_fnv1a('$childId|$date'));
    final pool = [
      for (final t in QuestType.values)
        if (hasPet || !t.needsPet) t,
    ];
    // Xáo Fisher–Yates rồi lấy N loại đầu → không trùng loại.
    for (var i = pool.length - 1; i > 0; i--) {
      final j = rng.next(i + 1);
      final tmp = pool[i];
      pool[i] = pool[j];
      pool[j] = tmp;
    }
    return [
      for (final t in pool.take(QuestConfig.questsPerDay))
        Quest(
          t,
          t.needsStrand ? Strand.all[rng.next(Strand.all.length)] : null,
        ),
    ];
  }

  /// 3 nhiệm vụ của [date] (mặc định hôm nay). Lần đầu chọn rồi lưu; với
  /// ngày cũ chưa từng xem thì null (không dựng lại quá khứ).
  Future<List<Quest>?> questsFor(
    String childId, {
    String? date,
    bool create = true,
  }) async {
    final d = date ?? _today;
    final raw = await db.settingsDao.getValue(
      childId: childId,
      key: questDayKey(d),
    );
    if (raw != null) {
      try {
        final quests = <Quest>[
          for (final id in (jsonDecode(raw) as List).cast<String>())
            ?Quest.parse(id),
        ];
        if (quests.isNotEmpty) return quests;
      } catch (_) {}
    }
    if (!create) return null;
    final pet = await PetService(db: db).active(childId);
    final quests = pickQuests(
      childId: childId,
      date: d,
      hasPet: pet != null && pet.hatched,
    );
    await db.settingsDao.setValue(
      childId: childId,
      key: questDayKey(d),
      value: jsonEncode([for (final q in quests) q.id]),
    );
    return quests;
  }

  // --------------------------------------------------------- tiến độ

  DateTime _dayStart(String date) {
    final p = date.split('-').map(int.parse).toList();
    final isUtc = _clock.now().isUtc;
    return isUtc ? DateTime.utc(p[0], p[1], p[2]) : DateTime(p[0], p[1], p[2]);
  }

  /// Tiến độ của [quest] trong ngày [date], tính từ dữ liệu có sẵn.
  Future<int> progressOn(String childId, Quest quest, String date) async {
    final start = _dayStart(date);
    final end = _dayStart(leagueAddDays(date, 1));
    final int raw;
    switch (quest.type) {
      case QuestType.strandCorrect:
        raw = await db.attemptsDao.countFirstTryBetween(
          childId: childId,
          start: start,
          end: end,
          strand: quest.strand,
        );
      case QuestType.reviewRetry:
        raw = await db.attemptsDao.countFirstTryBetween(
          childId: childId,
          start: start,
          end: end,
          reviewOnly: true,
        );
      case QuestType.strandStage:
        final set = await db.dailySetsDao.getDailySet(childId, date);
        final i = Strand.all.indexOf(quest.strand!);
        raw = set != null && _stageDone(set, i) ? 1 : 0;
      case QuestType.dailyComplete:
        final set = await db.dailySetsDao.getDailySet(childId, date);
        final all =
            set != null &&
            [for (var i = 0; i < Strand.all.length; i++) _stageDone(set, i)]
                .every((b) => b);
        raw = all ? 1 : 0;
      case QuestType.towerFloor:
        raw = await TowerService(db: db).clearsOn(childId, date: date);
      case QuestType.arena:
        raw = await db.arenaAttemptsDao.countOnDate(childId, date);
      case QuestType.feedPet:
        raw = await PetCareService(db: db).fedOn(childId, date) ? 1 : 0;
      case QuestType.playPet:
        raw = await PetCareService(db: db).playedOn(childId, date) ? 1 : 0;
    }
    return raw > quest.target ? quest.target : raw;
  }

  bool _stageDone(DailySet set, int index) {
    final st = db.dailySetsDao.readStageStatus(set);
    return index < st.length && st[index] == StageStatus.done;
  }

  Future<bool> _isClaimed(String childId, String date, Quest q) =>
      db.walletDao.hasEntryWithRefId(
        childId: childId,
        refId: claimRefId(childId, date, q.id),
      );

  Future<List<QuestStatus>> _statuses(
    String childId,
    String date,
    List<Quest> quests,
  ) async => [
    for (final q in quests)
      QuestStatus(
        quest: q,
        progress: await progressOn(childId, q, date),
        claimed: await _isClaimed(childId, date, q),
      ),
  ];

  // ----------------------------------------------------------- chuỗi

  /// Ngày [date] đã xong đủ cả 3 nhiệm vụ chưa. Ngày chưa từng có bảng
  /// nhiệm vụ → chưa xong. Đã xong thì ghi dấu để lần sau khỏi tính lại.
  Future<bool> dayComplete(String childId, String date) async {
    final marker = await db.settingsDao.getValue(
      childId: childId,
      key: questDoneKey(date),
    );
    if (marker != null) return true;
    final quests = await questsFor(childId, date: date, create: date == _today);
    if (quests == null) return false;
    for (final q in quests) {
      if (await progressOn(childId, q, date) < q.target) return false;
    }
    await db.settingsDao.setValue(
      childId: childId,
      key: questDoneKey(date),
      value: '1',
    );
    return true;
  }

  /// Các ngày của chuỗi hiện tại, cũ nhất trước (rỗng nếu chuỗi 0).
  Future<List<String>> streakDays(String childId) async {
    final today = _today;
    var cursor = today;
    if (!await dayComplete(childId, today)) {
      cursor = leagueAddDays(today, -1);
    }
    final days = <String>[];
    for (var i = 0; i < QuestConfig.maxStreakLookbackDays; i++) {
      if (!await dayComplete(childId, cursor)) break;
      days.add(cursor);
      cursor = leagueAddDays(cursor, -1);
    }
    return days.reversed.toList();
  }

  /// Chuỗi hiện tại (số ngày liên tiếp xong đủ 3 nhiệm vụ).
  Future<int> streak(String childId) async =>
      (await streakDays(childId)).length;

  /// Ghi nhận rương cho mỗi ngày thứ k × [QuestConfig.streakChestEvery]
  /// của chuỗi, rồi trả ngày đạt của các rương chưa nhận.
  Future<List<String>> _syncChests(String childId, List<String> run) async {
    for (var i = 1; i <= run.length; i++) {
      if (i % QuestConfig.streakChestEvery != 0) continue;
      final key = questChestKey(run[i - 1]);
      if (await db.settingsDao.getValue(childId: childId, key: key) == null) {
        await db.settingsDao.setValue(childId: childId, key: key, value: '1');
      }
    }
    final rows = await db.settingsDao.getAllSettings(childId: childId);
    final dates = [
      for (final r in rows)
        if (r.key.startsWith(_chestKeyPrefix))
          r.key.substring(_chestKeyPrefix.length),
    ]..sort();
    return [
      for (final d in dates)
        if (!await db.walletDao.hasEntryWithRefId(
          childId: childId,
          refId: chestRefId(childId, d),
        ))
          d,
    ];
  }

  // ------------------------------------------------------------ bảng

  /// Bảng nhiệm vụ hôm nay + chuỗi + rương chờ nhận.
  Future<QuestBoard> board(String childId) async {
    final date = _today;
    final quests = (await questsFor(childId))!;
    final statuses = await _statuses(childId, date, quests);
    final run = await streakDays(childId);
    final chests = await _syncChests(childId, run);
    return QuestBoard(
      date: date,
      quests: statuses,
      bonusClaimed: await db.walletDao.hasEntryWithRefId(
        childId: childId,
        refId: bonusRefId(childId, date),
      ),
      streak: run.length,
      pendingChests: chests,
    );
  }

  /// Có quà chưa nhận không (chấm đỏ trên HUD).
  Future<bool> hasClaimable(String childId) async =>
      (await board(childId)).hasClaimable;

  // ------------------------------------------------------------- nhận

  /// Bé bấm nhận nhiệm vụ [questId] của hôm nay: [QuestConfig.claimXu]
  /// xu; nếu đây là nhiệm vụ cuối cùng được nhận thì thêm
  /// [QuestConfig.allClaimedGems] kim cương. Một transaction + `refId`
  /// nên bấm hai lần chỉ nhận một.
  Future<QuestClaim> claim(String childId, String questId) {
    return db.transaction(() async {
      final date = _today;
      final quest = Quest.parse(questId);
      final quests = await questsFor(childId);
      if (quest == null || quests == null || !quests.contains(quest)) {
        return const QuestClaim(QuestClaimResult.unknown);
      }
      if (await progressOn(childId, quest, date) < quest.target) {
        return const QuestClaim(QuestClaimResult.notDone);
      }
      if (await _isClaimed(childId, date, quest)) {
        return const QuestClaim(QuestClaimResult.alreadyClaimed);
      }
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.xu,
        amount: QuestConfig.claimXu,
        reason: 'quest_claim',
        refId: claimRefId(childId, date, quest.id),
      );
      var gems = 0;
      var all = true;
      for (final q in quests) {
        if (!await _isClaimed(childId, date, q)) all = false;
      }
      final bonusRef = bonusRefId(childId, date);
      if (all &&
          !await db.walletDao.hasEntryWithRefId(
            childId: childId,
            refId: bonusRef,
          )) {
        gems = QuestConfig.allClaimedGems;
        await db.walletDao.addEntry(
          childId: childId,
          currency: Currency.gem,
          amount: gems,
          reason: 'quest_bonus',
          refId: bonusRef,
        );
      }
      return QuestClaim(
        QuestClaimResult.claimed,
        xu: QuestConfig.claimXu,
        gems: gems,
      );
    });
  }

  /// Nhận rương chuỗi cũ nhất đang chờ; trả số kim cương (0 nếu không có
  /// rương). `refId` theo ngày đạt nên không nhận hai lần.
  Future<int> claimStreakChest(String childId) {
    return db.transaction(() async {
      final pending = await _syncChests(childId, await streakDays(childId));
      if (pending.isEmpty) return 0;
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.gem,
        amount: QuestConfig.streakChestGems,
        reason: 'quest_streak_chest',
        refId: chestRefId(childId, pending.first),
      );
      return QuestConfig.streakChestGems;
    });
  }
}

/// FNV-1a 32 bit: băm ổn định giữa các lần chạy/nền tảng (khác
/// `String.hashCode`).
int _fnv1a(String s) {
  var h = 0x811C9DC5;
  for (final c in utf8.encode(s)) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// xorshift32: bộ sinh số giả ngẫu nhiên tự viết để kết quả không phụ
/// thuộc phiên bản Dart.
class _Rng {
  _Rng(int seed) : _s = seed == 0 ? 0x9E3779B9 : seed;

  int _s;

  int next(int bound) {
    _s ^= (_s << 13) & 0xFFFFFFFF;
    _s ^= _s >> 17;
    _s ^= (_s << 5) & 0xFFFFFFFF;
    return _s % bound;
  }
}
