/// Lưu lựa chọn trang phục của bé (Tủ đồ): bộ đồ nằm trong hồ sơ
/// nhân vật (`CharacterProfile.dress`), phụ kiện đầu lưu riêng trong
/// `settings` (khóa [headAccessoryKey], theo từng bé).
library;

import 'dart:convert';

import '../../core/database/app_database.dart';
import '../onboarding/onboarding_model.dart';
import '../onboarding/onboarding_service.dart';
import 'kid_assets.dart';

class KidLookService {
  KidLookService({required this.db});

  final AppDatabase db;

  static const String headAccessoryKey = 'kid_head_accessory';
  static const String glassesKey = 'kid_glasses';
  static const String whiteShoesKey = 'kid_white_shoes';
  static const String backpackKey = 'kid_backpack';

  Future<bool> _flag(String childId, String key) async =>
      await db.settingsDao.getValue(childId: childId, key: key) == 'true';

  Future<void> _setFlag(String childId, String key, bool on) =>
      db.settingsDao.setValue(childId: childId, key: key, value: '$on');

  /// Đeo kính tròn không.
  Future<bool> glasses(String childId) => _flag(childId, glassesKey);
  Future<void> setGlasses(String childId, bool on) =>
      _setFlag(childId, glassesKey, on);

  /// Đeo balo không.
  Future<bool> backpack(String childId) => _flag(childId, backpackKey);
  Future<void> setBackpack(String childId, bool on) =>
      _setFlag(childId, backpackKey, on);

  /// Đi giày trắng (thay giày màu của bộ đồ) không.
  Future<bool> whiteShoes(String childId) => _flag(childId, whiteShoesKey);
  Future<void> setWhiteShoes(String childId, bool on) =>
      _setFlag(childId, whiteShoesKey, on);

  /// Phụ kiện đầu đang đeo (`hat`/`bow`), null nếu không đeo.
  Future<String?> headAccessory(String childId) async {
    final value = await db.settingsDao.getValue(
      childId: childId,
      key: headAccessoryKey,
    );
    return (value == 'hat' || value == 'bow') ? value : null;
  }

  Future<void> setHeadAccessory(String childId, String? accessory) =>
      db.settingsDao.setValue(
        childId: childId,
        key: headAccessoryKey,
        value: accessory ?? 'none',
      );

  /// Đổi bộ đồ (1–3, hoặc 1–7 khi đã có hình bộ cao cấp) trong hồ sơ đã lưu; trả hồ sơ mới.
  Future<CharacterProfile> setOutfit(
    String childId,
    CharacterProfile profile,
    int outfit,
  ) async {
    final ids = kidAllOutfitIds[kidGender(profile.gender)]!;
    final updated = profile.copyWith(
      dress: ids[outfit.clamp(1, kidOutfitLimit()) - 1],
    );
    await db.settingsDao.setValue(
      childId: childId,
      key: OnboardingService.profileKey,
      value: jsonEncode(updated.toJson()),
    );
    return updated;
  }
}
