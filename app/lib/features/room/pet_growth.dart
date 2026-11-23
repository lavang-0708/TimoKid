/// Pet lớn dần: trứng → mới nở → nhỡ → trưởng thành.
///
/// Trứng nở ở chặng toán đầu tiên ([EggService]). Từ 23/11 (spec D)
/// pet lớn theo số CÂU ĐÚNG NGAY LẦN ĐẦU tích lũy khi pet đi theo
/// (cột `pets.xp`, xem `PetService.addXp`), không còn theo số ngày xong
/// đề: mới nở 0, tuổi nhỡ từ [petTeenXp], trưởng thành từ [petAdultXp]
/// (ngưỡng ở `pet_config.dart`).
///
/// Cỡ pet (chiều cao thân so với nhân vật cao 360 px trong khung
/// Phòng): trứng 30%, mới nở 40%, nhỡ 58% (chủ dự án chốt "tạm thời để
/// vậy xem sao"), trưởng thành 72%. Ảnh pet 512x512 có thân cao 400 px
/// (y 40–440) ở mọi giai đoạn nên hộp = chiều cao thân × 512/400.
library;

import '../pet/pet_config.dart';

enum PetStage { egg, newborn, teen, adult }

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

/// Giai đoạn của pet ĐÃ NỞ theo số câu đúng tích lũy [xp].
PetStage petStageForXp(int xp) {
  if (xp >= petAdultXp) return PetStage.adult;
  if (xp >= petTeenXp) return PetStage.teen;
  return PetStage.newborn;
}

/// Giai đoạn theo [xp] và đã nở chưa (chưa nở = trứng).
PetStage petStageFor({required int xp, required bool hatched}) =>
    hatched ? petStageForXp(xp) : PetStage.egg;

/// Còn bao nhiêu câu đúng nữa thì lên giai đoạn sau (null nếu đã
/// trưởng thành).
int? petXpToNextStage(int xp) {
  if (xp >= petAdultXp) return null;
  if (xp >= petTeenXp) return petAdultXp - xp;
  return petTeenXp - xp;
}

/// Đọc tên giai đoạn lưu trong `pets.stage_seen`; không hiểu thì null.
PetStage? petStageFromName(String? name) {
  for (final s in PetStage.values) {
    if (s.name == name) return s;
  }
  return null;
}
