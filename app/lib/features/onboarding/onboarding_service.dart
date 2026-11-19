/// Lưu hồ sơ nhân vật + cờ hoàn thành mở đầu (T2-03).
///
/// Không thêm bảng mới: hồ sơ (JSON), trứng đã chọn và trạng thái nở
/// đều là vài giá trị của một bé, lưu trong bảng `settings` theo đúng
/// quyết định (e) của PLAN (`pets` thuộc T2-07, `inventory` thuộc
/// T2-05). Tên nhân vật đồng thời ghi vào bảng `children` (hồ sơ bé)
/// để các màn sau dùng chung một tên.
///
/// Cờ `onboarding_completed` (khóa chung, không theo bé):
/// - DB mới tạo: `AppDatabase.onCreate` gieo `'false'` → hiện mở đầu.
/// - Máy đã cài bản 0.1: khóa CHƯA TỒN TẠI (bản 0.1 không gieo) → coi
///   như đã hoàn thành, KHÔNG bắt bé làm lại mở đầu; bé giữ tên "Bé"
///   và tiến độ cũ. Chỉ khóa tồn tại và bằng `'false'` mới hiện mở đầu.
/// - Xong mở đầu: đặt `'true'`. Menu QA "xóa dữ liệu" đặt lại
///   `'false'` (trạng thái mới cài) trong `resetForQa`.
///
/// Tên khóa `'onboarding_completed'` được gieo ở `AppDatabase`
/// (lớp database không import feature này để tránh vòng nhập) nên
/// giữ đồng bộ bằng hằng [onboardingCompletedKey] ở đây + test khóa
/// lại trong `onboarding_service_test.dart`.
library;

import 'dart:convert';

import '../../core/database/app_database.dart';
import '../../core/database/daos.dart';
import 'egg_service.dart';
import 'onboarding_model.dart';

class OnboardingService {
  OnboardingService({required AppDatabase db})
    : _db = db,
      _settings = db.settingsDao,
      _children = db.childrenDao,
      _eggs = EggService(db: db);

  final AppDatabase _db;
  final SettingsDao _settings;
  final ChildrenDao _children;
  final EggService _eggs;

  /// Khóa cờ hoàn thành mở đầu (chung, không theo bé).
  static const String onboardingCompletedKey = 'onboarding_completed';

  /// Khóa hồ sơ nhân vật (JSON, theo từng bé).
  static const String profileKey = 'character_profile';

  /// Đã xong mở đầu chưa. Khóa chưa tồn tại (máy 0.1 cũ) thì coi như
  /// đã xong — xem ghi chú ở đầu file.
  Future<bool> isCompleted() async {
    final value = await _settings.getValue(key: onboardingCompletedKey);
    return value != 'false';
  }

  /// Hồ sơ nhân vật đã lưu của bé (null nếu chưa tạo).
  Future<CharacterProfile?> loadProfile(String childId) async {
    final raw = await _settings.getValue(childId: childId, key: profileKey);
    if (raw == null) return null;
    try {
      return CharacterProfile.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on FormatException {
      return null;
    }
  }

  /// Lưu toàn bộ kết quả mở đầu trong một transaction: hồ sơ nhân
  /// vật (JSON), tên vào bảng `children`, trứng đã chọn, cờ hoàn
  /// thành `'true'`. Ghi một lần ở cuối luồng nên bé tắt app giữa
  /// chừng thì lần sau mở lại vẫn thấy mở đầu từ đầu.
  Future<void> completeOnboarding({
    required String childId,
    required CharacterProfile profile,
    required String eggSpecies,
  }) async {
    final trimmed = profile.copyWith(name: profile.name.trim());
    await _db.transaction(() async {
      await _settings.setValue(
        childId: childId,
        key: profileKey,
        value: jsonEncode(trimmed.toJson()),
      );
      await _children.updateChild(childId, name: trimmed.name);
      await _eggs.selectEgg(childId: childId, species: eggSpecies);
      await _settings.setValue(key: onboardingCompletedKey, value: 'true');
    });
  }
}
