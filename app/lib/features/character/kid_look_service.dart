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

  /// Đổi bộ đồ (1–3) trong hồ sơ đã lưu; trả hồ sơ mới.
  Future<CharacterProfile> setOutfit(
    String childId,
    CharacterProfile profile,
    int outfit,
  ) async {
    final ids = kidOutfitIds[kidGender(profile.gender)]!;
    final updated = profile.copyWith(dress: ids[outfit.clamp(1, 3) - 1]);
    await db.settingsDao.setValue(
      childId: childId,
      key: OnboardingService.profileKey,
      value: jsonEncode(updated.toJson()),
    );
    return updated;
  }
}
