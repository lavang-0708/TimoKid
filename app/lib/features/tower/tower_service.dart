/// Dịch vụ Tháp nhiều tầng (tuần 23/11, mục A): đọc/lưu tầng cao nhất
/// đã qua của từng mảng, chấm một lượt leo tầng và cộng thưởng lần
/// qua đầu tiên.
///
/// Dart thuần. Tầng cao nhất lưu ở `settings` theo bé, khóa
/// `tower_floor.<strand>` ([TowerConfig.settingsKey]). Thưởng ghi vào
/// `wallet_ledger` với `refId` riêng mỗi (bé, mảng, tầng) nên gọi lại
/// không cộng trùng dù tầng đó được qua nhiều lần.
///
/// Điểm cho tính năng khác gắn vào (nhiệm vụ ngày, pet):
/// - [highestCleared] / [nextFloor]: đọc tiến độ.
/// - [floorCleared]: luồng sự kiện phát mỗi khi một tầng được qua
///   (kể cả qua lại tầng cũ, xem [TowerFloorCleared.firstClear]).
library;

import 'dart:async';

import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import 'tower_config.dart';

/// Kết quả một lượt leo tầng.
class TowerOutcome {
  const TowerOutcome({
    required this.strand,
    required this.floor,
    required this.firstTryCorrect,
    required this.passNeeded,
    required this.passed,
    required this.firstClear,
    required this.rewardXu,
    required this.rewardGems,
  });

  final String strand;
  final int floor;

  /// Số câu đúng ngay lần đầu trong lượt này.
  final int firstTryCorrect;

  /// Số câu đúng ngay lần đầu cần để qua tầng.
  final int passNeeded;

  /// Có qua tầng không.
  final bool passed;

  /// Có phải lần qua đầu tiên của tầng này không (chỉ khi đó có thưởng).
  final bool firstClear;

  /// Thưởng lần qua đầu tiên đã cộng (0 nếu không phải lần đầu/trượt).
  final int rewardXu;
  final int rewardGems;

  bool get isBoss => TowerConfig.isBoss(floor);

  /// Tầng kế tiếp bé có thể leo, null nếu đã ở đỉnh hoặc chưa qua.
  int? get nextFloor =>
      passed && floor < TowerConfig.floorsPerTower ? floor + 1 : null;
}

/// Sự kiện "đã qua một tầng" cho tính năng khác lắng nghe.
class TowerFloorCleared {
  const TowerFloorCleared({
    required this.childId,
    required this.strand,
    required this.floor,
    required this.firstClear,
  });

  final String childId;
  final String strand;
  final int floor;

  /// Lần qua đầu tiên của tầng này (có thưởng).
  final bool firstClear;
}

class TowerService {
  TowerService({required this._db});

  final AppDatabase _db;

  static final StreamController<TowerFloorCleared> _events =
      StreamController<TowerFloorCleared>.broadcast();

  /// Luồng sự kiện mỗi khi một tầng được qua (phát sau khi đã lưu và
  /// cộng thưởng). Dùng cho nhiệm vụ ngày ("leo qua 1 tầng tháp").
  static Stream<TowerFloorCleared> get floorCleared => _events.stream;

  /// Tầng cao nhất đã qua của [strand] (0 nếu chưa qua tầng nào).
  Future<int> highestCleared({
    required String childId,
    required String strand,
  }) async {
    final raw = await _db.settingsDao.getValue(
      childId: childId,
      key: TowerConfig.settingsKey(strand),
    );
    final value = int.tryParse(raw ?? '') ?? 0;
    return value.clamp(0, TowerConfig.floorsPerTower);
  }

  /// Tầng kế tiếp cần leo (1–30); null nếu đã lên đỉnh.
  Future<int?> nextFloor({
    required String childId,
    required String strand,
  }) async {
    final highest = await highestCleared(childId: childId, strand: strand);
    return highest >= TowerConfig.floorsPerTower ? null : highest + 1;
  }

  /// Số lượt qua tầng (mọi mảng) trong ngày [date] (`YYYY-MM-DD`, giờ
  /// Việt Nam); mặc định hôm nay. Nhiệm vụ ngày đọc số này.
  Future<int> clearsOn(String childId, {String? date}) async {
    final raw = await _db.settingsDao.getValue(
      childId: childId,
      key: TowerConfig.clearsKey(date ?? _db.clock.today()),
    );
    return int.tryParse(raw ?? '') ?? 0;
  }

  Future<void> _bumpClearsToday(String childId) async {
    final n = await clearsOn(childId);
    await _db.settingsDao.setValue(
      childId: childId,
      key: TowerConfig.clearsKey(_db.clock.today()),
      value: '${n + 1}',
    );
  }

  /// Chấm lượt leo [floor] của [strand] với [firstTryCorrect] câu đúng
  /// ngay lần đầu. Qua tầng thì cập nhật tầng cao nhất; nếu là lần qua
  /// đầu tiên (floor > tầng cao nhất cũ) thì cộng thưởng một lần.
  Future<TowerOutcome> recordResult({
    required String childId,
    required String strand,
    required int floor,
    required int firstTryCorrect,
  }) async {
    if (!Strand.all.contains(strand)) {
      throw ArgumentError('Không có mảng nào mang mã $strand');
    }
    if (floor < 1 || floor > TowerConfig.floorsPerTower) {
      throw ArgumentError('Tầng ngoài 1–${TowerConfig.floorsPerTower}: $floor');
    }
    final needed = TowerConfig.passNeeded(floor);
    final passed = firstTryCorrect >= needed;
    var firstClear = false;
    var xu = 0;
    var gems = 0;
    if (passed) {
      final highest = await highestCleared(childId: childId, strand: strand);
      final refId = TowerConfig.rewardRefId(
        childId: childId,
        strand: strand,
        floor: floor,
      );
      final alreadyPaid = await _db.walletDao.hasEntryWithRefId(
        childId: childId,
        refId: refId,
      );
      firstClear = floor > highest && !alreadyPaid;
      if (firstClear) {
        xu = TowerConfig.firstClearXu(floor);
        gems = TowerConfig.firstClearGems(floor);
        await _db.walletDao.addEntry(
          childId: childId,
          currency: Currency.xu,
          amount: xu,
          reason: 'tower_clear',
          refId: refId,
        );
        if (gems > 0) {
          await _db.walletDao.addEntry(
            childId: childId,
            currency: Currency.gem,
            amount: gems,
            reason: 'tower_clear',
            refId: refId,
          );
        }
      }
      if (floor > highest) {
        await _db.settingsDao.setValue(
          childId: childId,
          key: TowerConfig.settingsKey(strand),
          value: '$floor',
        );
      }
      await _bumpClearsToday(childId);
      _events.add(
        TowerFloorCleared(
          childId: childId,
          strand: strand,
          floor: floor,
          firstClear: firstClear,
        ),
      );
    }
    return TowerOutcome(
      strand: strand,
      floor: floor,
      firstTryCorrect: firstTryCorrect,
      passNeeded: needed,
      passed: passed,
      firstClear: firstClear,
      rewardXu: xu,
      rewardGems: gems,
    );
  }
}
