/// Trứng và nở trứng (T2-03, theo DESIGN "Pet").
///
/// Bé chọn 1 trong 3 trứng ở bước cuối mở đầu. Trứng nở khi bé xong
/// chặng toán đầu tiên (bất kỳ chặng nào, kể cả chặng tự chọn), có
/// hiệu ứng nở ở màn riêng ([HatchScreen]). Chỉ nở một lần duy nhất.
///
/// Trạng thái lưu trong `settings` theo từng bé (không thêm bảng:
/// bảng `pets` thuộc T2-07, xem quyết định (e) của PLAN):
/// - `selected_egg`: mã loài (`dog`/`cat`/`rabbit`), null nếu chưa chọn.
/// - `egg_hatched`: `'true'` khi đã nở xong (đã xem màn nở).
/// - `hatch_pending`: `'true'` khi có một lần nở đang chờ bé xem.
///
/// Luồng: xong chặng → [noteStageCompleted] đặt `hatch_pending` nếu
/// có trứng mà chưa nở → màn Kết quả chặng rẽ sang màn nở → bé xem
/// xong bấm Tiếp → [consumeHatchCelebration] đặt `egg_hatched` và xóa
/// `hatch_pending`. Tắt app giữa chừng thì lần mở sau vẫn thấy màn nở
/// (route khởi đầu kiểm tra `hatch_pending`).
library;

import '../../core/database/app_database.dart';
import '../../core/database/daos.dart';
import 'onboarding_config.dart';

class EggService {
  EggService({required AppDatabase db}) : _settings = db.settingsDao;

  final SettingsDao _settings;

  /// Khóa trứng đã chọn (theo từng bé).
  static const String selectedEggKey = 'selected_egg';

  /// Khóa đã nở xong (theo từng bé).
  static const String eggHatchedKey = 'egg_hatched';

  /// Khóa lần nở đang chờ bé xem (theo từng bé).
  static const String hatchPendingKey = 'hatch_pending';

  /// Trứng bé đã chọn, null nếu chưa chọn (máy 0.1 cũ, chưa qua mở đầu).
  Future<String?> selectedEgg(String childId) async {
    final value = await _settings.getValue(
      childId: childId,
      key: selectedEggKey,
    );
    if (value == null) return null;
    return eggSpeciesNames.containsKey(value) ? value : null;
  }

  /// Bé đã có pet nở chưa.
  Future<bool> isHatched(String childId) async {
    final value = await _settings.getValue(
      childId: childId,
      key: eggHatchedKey,
    );
    return value == 'true';
  }

  /// Có lần nở đang chờ bé xem màn nở không.
  Future<bool> isHatchPending(String childId) async {
    final value = await _settings.getValue(
      childId: childId,
      key: hatchPendingKey,
    );
    return value == 'true';
  }

  /// Ghi trứng bé chọn ở bước cuối mở đầu.
  Future<void> selectEgg({
    required String childId,
    required String species,
  }) async {
    if (!eggSpeciesNames.containsKey(species)) {
      throw ArgumentError('Không có loài trứng nào mang mã $species');
    }
    await _settings.setValue(
      childId: childId,
      key: selectedEggKey,
      value: species,
    );
  }

  /// Ghi nhận bé vừa xong một chặng. Nếu bé đã chọn trứng mà trứng
  /// chưa nở và chưa có lần nở nào đang chờ thì đặt cờ chờ nở.
  /// Trả true khi vừa đặt cờ (chỉ xảy ra một lần duy nhất).
  Future<bool> noteStageCompleted(String childId) async {
    final egg = await selectedEgg(childId);
    if (egg == null) return false;
    if (await isHatched(childId)) return false;
    if (await isHatchPending(childId)) return false;
    await _settings.setValue(
      childId: childId,
      key: hatchPendingKey,
      value: 'true',
    );
    return true;
  }

  /// Bé đã xem xong màn nở: đánh dấu đã nở, xóa cờ chờ. Gọi lại
  /// cũng an toàn (đã nở rồi thì không đổi gì).
  Future<void> consumeHatchCelebration(String childId) async {
    await _settings.setValue(
      childId: childId,
      key: eggHatchedKey,
      value: 'true',
    );
    await _settings.setValue(
      childId: childId,
      key: hatchPendingKey,
      value: 'false',
    );
  }
}
