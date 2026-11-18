/// Database Drift của TimoKid: 7 bảng bản 0.1, schema v1.
///
/// Mở file `timokid.sqlite` trong thư mục tài liệu của app trên máy thật
/// (qua `drift_flutter`). Test truyền executor riêng
/// (`NativeDatabase.memory()` hoặc file tạm) nên không cần Android SDK.
///
/// `attempts` và `wallet_ledger` chỉ thêm dòng: ngoài việc DAO không có
/// hàm sửa/xóa, database còn tạo trigger SQLite chặn UPDATE/DELETE ở
/// tầng dữ liệu — kể cả code nào đó chạy SQL thô cũng không sửa được
/// lịch sử trả lời và lịch sử xu.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../time/clock.dart';
import 'daos.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Bảng thưởng mặc định (T1-11), lưu vào `settings` chung lúc hạt giống:
/// bậc 1–2: 2 xu, bậc 3–4: 3 xu, bậc 5–6: 5 xu cho mỗi câu đúng ngay;
/// xong chặng +5 xu; xong đề ngày +20 xu và 1 kim cương;
/// thành thạo một dạng mới +2 kim cương.
const defaultRewardsJson =
    '{"easy":2,"medium":3,"hard":5,'
    '"stage_complete":5,'
    '"daily_complete_xu":20,"daily_complete_gem":1,'
    '"mastery_gem":2}';

@DriftDatabase(
  tables: [
    Children,
    Attempts,
    SkillProgress,
    ReviewQueue,
    DailySets,
    WalletLedger,
    Settings,
  ],
  daos: [
    ChildrenDao,
    AttemptsDao,
    SkillProgressDao,
    ReviewQueueDao,
    DailySetsDao,
    WalletDao,
    SettingsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor, this.clock = const SystemClock()})
    : super(executor ?? driftDatabase(name: 'timokid.sqlite'));

  /// Nguồn thời gian của app (giờ Việt Nam). Test truyền [FakeClock].
  final Clock clock;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      // Chặn sửa/xóa lịch sử ở tầng SQLite (bổ sung cho việc DAO
      // không có hàm sửa/xóa). Trigger sống cùng file DB nên còn
      // hiệu lực cả sau khi tắt/mở lại app.
      for (final name in [
        attempts.actualTableName,
        walletLedger.actualTableName,
      ]) {
        await customStatement(
          'CREATE TRIGGER ${name}_no_update BEFORE UPDATE ON $name '
          'BEGIN SELECT RAISE(ABORT, \'$name is append-only\'); END;',
        );
        await customStatement(
          'CREATE TRIGGER ${name}_no_delete BEFORE DELETE ON $name '
          'BEGIN SELECT RAISE(ABORT, \'$name is append-only\'); END;',
        );
      }
    },
  );

  /// Tạo dữ liệu lần đầu mở app: một hồ sơ bé mặc định lớp 2, bậc 1 cho
  /// cả 5 mảng, và cài đặt chung mặc định. Gọi lại nhiều lần cũng an toàn
  /// (chỉ tạo phần còn thiếu). Trả về id của bé mặc định.
  Future<String> ensureSeeded() async {
    var child = await childrenDao.getFirstChild();
    child ??= await childrenDao.createChild(name: 'Bé', grade: 2);
    final childId = child.id;

    for (final strand in Strand.all) {
      final existing = await skillProgressDao.getStrandProgress(
        childId,
        strand,
      );
      if (existing == null) {
        await skillProgressDao.setStrandRung(
          childId: childId,
          strand: strand,
          rung: 1,
        );
      }
    }

    await _seedSetting('rewards', defaultRewardsJson);
    await _seedSetting('sound_enabled', jsonEncode(true));
    await _seedSetting('music_enabled', jsonEncode(true));

    return childId;
  }

  Future<void> _seedSetting(String key, String value) async {
    final existing = await settingsDao.getValue(key: key);
    if (existing == null) {
      await settingsDao.setValue(key: key, value: value);
    }
  }
}
