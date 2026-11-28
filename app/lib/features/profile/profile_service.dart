/// Nhiều bé trên một máy (T3-03). Bé đang chơi lưu ở khóa `settings`
/// chung `active_child_id` (chỉ trên máy); `AppDatabase.ensureSeeded` trả
/// về bé này nên mọi màn hiện có dùng đúng bé được chọn.
///
/// Dữ liệu máy cũ (một bé) giữ nguyên và thuộc bé đầu tiên (tạo sớm nhất).
library;

import '../../core/database/app_database.dart';
import '../onboarding/onboarding_service.dart';

class ChildSummary {
  const ChildSummary({required this.id, required this.name});

  final String id;
  final String name;
}

class ProfileService {
  ProfileService({required this.db});

  final AppDatabase db;

  /// Mọi bé, bé đầu tiên trước; tên lấy từ hồ sơ nhân vật nếu có.
  Future<List<ChildSummary>> children() async {
    final rows = await db.childrenDao.getChildrenInOrder();
    final onboarding = OnboardingService(db: db);
    return [
      for (final c in rows)
        ChildSummary(
          id: c.id,
          name: (await onboarding.loadProfile(c.id))?.name ?? c.name,
        ),
    ];
  }

  Future<int> count() async => (await db.childrenDao.getAllChildren()).length;

  /// Chọn bé đang chơi.
  Future<void> select(String childId) => db.setActiveChild(childId);

  /// Thêm bé mới: tạo hồ sơ + bậc 1 cho 5 mảng, chọn làm bé đang chơi và
  /// đặt lại cờ mở đầu để bé đi qua mở đầu (giới tính/đồ/tên/trứng).
  /// Trả id bé mới.
  Future<String> addChild() async {
    return db.transaction(() async {
      final child = await db.childrenDao.createChild(name: 'Bé', grade: 2);
      await db.seedChildProgress(child.id);
      await db.setActiveChild(child.id);
      await db.settingsDao.setValue(
        key: OnboardingService.onboardingCompletedKey,
        value: 'false',
      );
      return child.id;
    });
  }
}
