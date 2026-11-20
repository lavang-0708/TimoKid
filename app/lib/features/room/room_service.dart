/// Cổng mỗi ngày của màn Phòng (T2-04).
///
/// Phần chơi (Tủ đồ, Cửa hàng, chơi với pet) chỉ mở khi bé đã xong
/// đề ngày hôm nay; chưa xong thì khóa, kể cả sang ngày mới (đề mới
/// chưa xong thì khóa lại).
///
/// Nguồn sự thật duy nhất là trạng thái 5 chặng của đề ngày đã lưu
/// trong DB (`DailySetsDao.readStageStatus`), cùng cách tính như
/// `RewardService.awardDailyCompleteIfDone` (cả 5 chặng `done`).
/// Không tạo đề ở đây: chưa có đề hôm nay thì coi như chưa xong
/// (khóa); đề được tạo khi bé vào Thị trấn (như trước). Không thêm
/// bảng, không tăng schema.
library;

import '../../core/database/app_database.dart';
import '../../core/database/daos.dart';
import '../../core/database/models.dart';
import '../../core/time/clock.dart';
import '../daily_set/daily_set_config.dart';

class RoomService {
  RoomService({required AppDatabase db})
    : _sets = db.dailySetsDao,
      _clock = db.clock;

  final DailySetsDao _sets;
  final Clock _clock;

  /// Bé đã xong đề ngày hôm nay chưa (cả 5 chặng `done`).
  /// Chưa có đề hôm nay thì chưa xong (khóa).
  Future<bool> isPlayUnlocked(String childId) async {
    final set = await _sets.getDailySet(childId, _clock.today());
    if (set == null) return false;
    final statuses = _sets.readStageStatus(set);
    return statuses.length == DailySetConfig.stagesPerDay &&
        statuses.every((s) => s == StageStatus.done);
  }

  /// Số chặng đã xong hôm nay (0–5). Chưa có đề hôm nay thì 0.
  Future<int> doneStageCount(String childId) async {
    final set = await _sets.getDailySet(childId, _clock.today());
    if (set == null) return 0;
    return _sets
        .readStageStatus(set)
        .where((s) => s == StageStatus.done)
        .length;
  }
}
