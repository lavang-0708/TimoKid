/// Trứng và nở trứng (T2-03, theo DESIGN "Pet"), từ D chạy trên bảng
/// `pets`.
///
/// Bé chọn 1 trong 3 trứng ở bước cuối mở đầu ([selectEgg] thêm một
/// pet-trứng đang đi theo). Trứng nở khi bé xong chặng toán đầu tiên
/// (bất kỳ chặng nào, kể cả chặng tự chọn / tầng / đấu trường), có hiệu
/// ứng nở ở màn riêng ([HatchScreen]). Mỗi trứng nở một lần. "Pet" ở
/// đây luôn là pet ĐANG ĐI THEO ([PetService.active]); trứng nhận sau
/// (khi pet lớn, mua ở Cửa hàng) cũng nở theo luồng này khi nó đang đi
/// theo.
///
/// Cờ chờ nở vẫn lưu trong `settings` theo từng bé:
/// - `hatch_pending`: `'true'` khi có một lần nở đang chờ bé xem.
/// (Các khóa cũ `selected_egg`/`egg_hatched` đã được chuyển sang bảng
/// `pets` ở migration v4 và không còn đọc.)
///
/// Luồng: xong chặng → [noteStageCompleted] đặt `hatch_pending` nếu
/// pet đang đi theo là trứng chưa nở → màn Kết quả chặng rẽ sang màn nở
/// → bé xem xong bấm Tiếp → [consumeHatchCelebration] đánh dấu đã nở và
/// xóa `hatch_pending`. Tắt app giữa chừng thì lần mở sau vẫn thấy màn
/// nở (route khởi đầu kiểm tra `hatch_pending`).
library;

import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart';
import '../../core/database/daos.dart';
import '../pet/pet_config.dart';
import '../pet/pet_service.dart';

class EggService {
  EggService({required AppDatabase db}) : _db = db, _pets = PetService(db: db);

  final AppDatabase _db;
  final PetService _pets;

  SettingsDao get _settings => _db.settingsDao;

  /// Khóa lần nở đang chờ bé xem (theo từng bé).
  static const String hatchPendingKey = 'hatch_pending';

  /// Loài của pet đang đi theo (trứng hoặc đã nở), null nếu chưa có
  /// (máy 0.1 cũ, chưa qua mở đầu).
  Future<String?> selectedEgg(String childId) async =>
      (await _pets.active(childId))?.species;

  /// Pet đang đi theo đã nở chưa.
  Future<bool> isHatched(String childId) async =>
      (await _pets.active(childId))?.hatched ?? false;

  /// Có lần nở đang chờ bé xem màn nở không.
  Future<bool> isHatchPending(String childId) async {
    final value = await _settings.getValue(
      childId: childId,
      key: hatchPendingKey,
    );
    return value == 'true';
  }

  /// Ghi trứng bé chọn ở bước cuối mở đầu: thêm pet-trứng đang đi theo.
  /// Chọn lại (quay lại bước trứng) thì đổi loài của trứng chưa nở.
  Future<void> selectEgg({
    required String childId,
    required String species,
  }) async {
    if (!starterSpecies.contains(species)) {
      throw ArgumentError('Không có loài trứng nào mang mã $species');
    }
    await _db.transaction(() async {
      final current = await _pets.active(childId);
      if (current != null && !current.hatched) {
        if (current.species == species) return;
        await _db.petsDao.updatePet(
          current.id,
          PetsCompanion(species: Value(species)),
        );
        return;
      }
      await _pets.createEgg(
        childId: childId,
        species: species,
        makeActive: true,
      );
    });
  }

  /// Ghi nhận bé vừa xong một chặng. Nếu pet đang đi theo là trứng
  /// chưa nở và chưa có lần nở nào đang chờ thì đặt cờ chờ nở.
  /// Trả true khi vừa đặt cờ (mỗi trứng một lần).
  Future<bool> noteStageCompleted(String childId) async {
    final active = await _pets.active(childId);
    if (active == null || active.hatched) return false;
    if (await isHatchPending(childId)) return false;
    await _settings.setValue(
      childId: childId,
      key: hatchPendingKey,
      value: 'true',
    );
    return true;
  }

  /// Bé đã xem xong màn nở: đánh dấu pet đang đi theo đã nở, xóa cờ
  /// chờ. Gọi lại cũng an toàn (đã nở rồi thì không đổi gì).
  Future<void> consumeHatchCelebration(String childId) async {
    await _db.transaction(() async {
      final active = await _pets.active(childId);
      if (active != null && !active.hatched) {
        await _pets.markHatched(active.id);
      }
      await _settings.setValue(
        childId: childId,
        key: hatchPendingKey,
        value: 'false',
      );
    });
  }
}
