/// Cờ + đường dẫn cho hình Muse vẽ cho pet. Cả hai cờ đã bật từ
/// 22/11 (lô 8A trứng nứt, lô 8B khung đi/vui/ngồi); tắt cờ thì app
/// quay về hiệu ứng vẽ bằng code.
///
/// Khi Muse giao hình, chỉ cần thêm PNG vào `assets/images/pets/`
/// (kèm dòng manifest) rồi đổi cờ tương ứng thành `true`; không phải
/// sửa chỗ khác.
///
/// - [eggCrackArtReady]: `{loài}_egg_crack_1..3.png` (trứng nứt 3
///   bước), `{loài}_shell_bottom.png`, `{loài}_shell_top.png`
///   (512x512, cùng khung `{loài}_egg.png`). Màn nở dùng chúng thay
///   cho vết nứt vẽ bằng CustomPaint + hai nửa vỏ cắt từ ảnh trứng.
/// - [petMotionArtReady]: `{loài}_{giai đoạn}_walk_a..d.png` (4 khung
///   đi), `_happy.png` (vui khi bấm), `_sit.png` (ngồi), giai đoạn là
///   newborn/teen/adult, 512x512 cùng khung ảnh đứng `petAsset`. Pet
///   trong Phòng dùng khung thật thay cho nhún bằng code.
library;

import 'pet_growth.dart';

/// Đã có hình trứng nứt + vỏ trứng của Muse chưa.
const bool eggCrackArtReady = true;

/// Đã có hình đi/vui/ngồi của pet (Muse) chưa.
const bool petMotionArtReady = true;

/// Bộ khung chưa dùng được dù cờ đã bật (đang chờ Muse vẽ lại).
/// Trống từ 22/11: chó mới nở đã vẽ lại không vỏ, khớp ảnh đứng.
const Set<String> petMotionArtPending = {};

/// Pet [species] ở [stage] có dùng khung đi/vui/ngồi thật không.
bool petHasMotionArt(String species, PetStage stage) =>
    petMotionArtReady &&
    !petMotionArtPending.contains('${species}_${stage.name}');

/// Trứng nứt bước [step] (1–3).
String eggCrackAsset(String species, int step) =>
    'assets/images/pets/${species}_egg_crack_$step.png';

/// Nửa vỏ trên (bay đi) / nửa vỏ dưới (ở lại rồi mờ).
String shellTopAsset(String species) =>
    'assets/images/pets/${species}_shell_top.png';
String shellBottomAsset(String species) =>
    'assets/images/pets/${species}_shell_bottom.png';

String _petBase(String species, PetStage stage) =>
    'assets/images/pets/${species}_${stage.name}';

/// 4 khung đi a..d của pet.
List<String> petWalkAssets(String species, PetStage stage) => [
  for (final f in const ['a', 'b', 'c', 'd'])
    '${_petBase(species, stage)}_walk_$f.png',
];

String petHappyAsset(String species, PetStage stage) =>
    '${_petBase(species, stage)}_happy.png';

String petSitAsset(String species, PetStage stage) =>
    '${_petBase(species, stage)}_sit.png';
