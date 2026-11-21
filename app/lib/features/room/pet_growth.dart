/// Pet lớn dần (F): trứng → mới nở → nhỡ → trưởng thành.
///
/// Trứng nở ở chặng toán đầu tiên ([EggService]). Sau đó pet lớn theo
/// số NGÀY bé xong trọn đề ngày (đủ 5 chặng) — đếm thẳng từ bảng đề
/// ngày nên không cần lưu thêm gì và không lệch khi tắt app:
/// - mới nở: 0–2 ngày xong đề;
/// - nhỡ: 3–7 ngày;
/// - trưởng thành: từ 8 ngày.
///
/// Cỡ pet (chiều cao thân so với nhân vật cao 360 px trong khung
/// Phòng): trứng 30%, mới nở 40%, nhỡ 58% (chủ dự án chốt "tạm thời để
/// vậy xem sao"), trưởng thành 72%. Ảnh pet 512x512 có thân cao 400 px
/// (y 40–440) ở mọi giai đoạn nên hộp = chiều cao thân × 512/400.
library;

import '../../core/database/app_database.dart';
import '../../core/database/models.dart';
import '../daily_set/daily_set_config.dart';

enum PetStage { egg, newborn, teen, adult }

/// Số ngày xong đề cần để lên mỗi giai đoạn.
const int petTeenDays = 3;
const int petAdultDays = 8;

/// Tỉ lệ chiều cao thân pet so với nhân vật (360 px).
const Map<PetStage, double> petHeightRatio = <PetStage, double>{
  PetStage.egg: 0.30,
  PetStage.newborn: 0.40,
  PetStage.teen: 0.58,
  PetStage.adult: 0.72,
};

/// Tên giai đoạn để hiện cho bé.
const Map<PetStage, String> petStageNames = <PetStage, String>{
  PetStage.egg: 'trứng',
  PetStage.newborn: 'mới nở',
  PetStage.teen: 'tuổi nhỡ',
  PetStage.adult: 'trưởng thành',
};

/// Cạnh hộp pet (px khung Phòng) theo giai đoạn: thân cao
/// 360 × tỉ lệ, ảnh 512 có thân 400 px.
double petBoxSize(PetStage stage) => 360 * petHeightRatio[stage]! * 512 / 400;

/// Đường dẫn ảnh pet theo loài + giai đoạn.
String petAsset(String species, PetStage stage) =>
    'assets/images/pets/${species}_${stage.name}.png';

/// Giai đoạn theo số ngày xong đề (đã nở).
PetStage petStageForDays(int doneDays) {
  if (doneDays >= petAdultDays) return PetStage.adult;
  if (doneDays >= petTeenDays) return PetStage.teen;
  return PetStage.newborn;
}

/// Còn bao nhiêu ngày xong đề nữa thì lên giai đoạn sau (null nếu đã
/// trưởng thành).
int? petDaysToNextStage(int doneDays) {
  if (doneDays >= petAdultDays) return null;
  if (doneDays >= petTeenDays) return petAdultDays - doneDays;
  return petTeenDays - doneDays;
}

class PetGrowthService {
  PetGrowthService({required this.db});

  final AppDatabase db;

  /// Khóa giai đoạn bé đã thấy lần trước (để chúc mừng khi pet lớn).
  static const String seenStageKey = 'pet_stage_seen';

  /// Số ngày bé đã xong trọn đề ngày (đủ 5 chặng).
  Future<int> doneDays(String childId) async {
    final sets = await db.dailySetsDao.getDailySetsForChild(childId);
    var n = 0;
    for (final set in sets) {
      final statuses = db.dailySetsDao.readStageStatus(set);
      if (statuses.length == DailySetConfig.stagesPerDay &&
          statuses.every((s) => s == StageStatus.done)) {
        n++;
      }
    }
    return n;
  }

  /// Giai đoạn bé thấy lần trước (null nếu chưa ghi).
  Future<PetStage?> seenStage(String childId) async {
    final raw = await db.settingsDao.getValue(
      childId: childId,
      key: seenStageKey,
    );
    for (final s in PetStage.values) {
      if (s.name == raw) return s;
    }
    return null;
  }

  Future<void> markSeen(String childId, PetStage stage) => db.settingsDao
      .setValue(childId: childId, key: seenStageKey, value: stage.name);
}
