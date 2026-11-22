/// Database Drift của TimoKid: 7 bảng bản 0.1 + `inventory` (T2-06) +
/// `arena_attempts` (T2-10), schema v3.
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
    Inventory,
    ArenaAttempts,
  ],
  daos: [
    ChildrenDao,
    AttemptsDao,
    SkillProgressDao,
    ReviewQueueDao,
    DailySetsDao,
    WalletDao,
    SettingsDao,
    InventoryDao,
    ArenaAttemptsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor, this.clock = const SystemClock()})
    : super(executor ?? driftDatabase(name: 'timokid.sqlite'));

  /// Nguồn thời gian của app (giờ Việt Nam). Test truyền [FakeClock].
  ///
  /// Không `final`: chỉ menu QA (bản debug, T1-13) mới gán lại bằng
  /// [DebugClock] để nhảy ngày; production không bao giờ đổi đồng hồ
  /// sau khi mở database.
  Clock clock;

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createAppendOnlyTriggers();
      // Mở đầu (T2-03): DB mới tạo thì chưa xong mở đầu → lần đầu
      // mở app hiện màn tạo nhân vật. Máy đã cài bản 0.1 không có
      // khóa này (không chạy onCreate) nên được coi là đã xong, xem
      // `OnboardingService.isCompleted`. Khóa ghi bằng chữ để tránh
      // lớp database phải import feature mở đầu; tên khóa giữ đồng
      // bộ với `OnboardingService.onboardingCompletedKey`.
      await _seedSetting('onboarding_completed', 'false');
    },
    onUpgrade: (migrator, from, to) async {
      // v1 → v2 (T2-06): thêm bảng `inventory`; mọi dữ liệu cũ giữ nguyên.
      if (from < 2) {
        await migrator.createTable(inventory);
      }
      // v2 → v3 (T2-10): thêm bảng `arena_attempts` (Đấu trường).
      if (from < 3) {
        await migrator.createTable(arenaAttempts);
      }
    },
  );

  /// Tạo trigger chặn sửa/xóa trên hai bảng append-only (xem ghi chú
  /// ở đầu file). Gọi trong [migration] lúc tạo DB mới, và gọi lại
  /// trong [resetForQa] sau khi tạo lại bảng — trigger không thuộc
  /// định nghĩa bảng nên `Migrator.createAll()` không tạo lại chúng.
  Future<void> _createAppendOnlyTriggers() async {
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
  }

  /// Đặt lại toàn bộ database về trạng thái mới cài (CHỈ menu QA debug
  /// gọi, xem `QaService.clearAllData`): DROP toàn bộ bảng rồi tạo
  /// lại (kể cả trigger append-only) + gieo dữ liệu mặc định.
  ///
  /// Không dùng DELETE: trigger append-only chặn DELETE trên
  /// `attempts` và `wallet_ledger`, nên cách duy nhất xóa sạch lịch
  /// sử là bỏ bảng rồi tạo lại. Sau khi gọi, mọi màn hình/service
  /// đang giữ dữ liệu cũ phải tải lại (menu QA tự về màn Thị trấn).
  Future<void> resetForQa() async {
    for (final table in allTables) {
      await customStatement('DROP TABLE IF EXISTS ${table.actualTableName}');
    }
    await Migrator(this).createAll();
    await _createAppendOnlyTriggers();
    await ensureSeeded();
    // Về trạng thái mới cài: mở đầu chưa xong nên lần mở sau hiện
    // lại màn tạo nhân vật (để QA kiểm được luồng mở đầu).
    await settingsDao.setValue(key: 'onboarding_completed', value: 'false');
  }

  /// Tạo dữ liệu lần đầu mở app: một hồ sơ bé mặc định lớp 2, bậc 1 cho
  /// cả 5 mảng, và cài đặt chung mặc định. Gọi lại nhiều lần cũng an toàn
  /// (chỉ tạo phần còn thiếu). Trả về id của bé mặc định.
  ///
  /// Bọc trong transaction: hai lần gọi chồng nhau (vd test gọi
  /// `Future.wait`, hoặc `resetForQa` + khởi động app cùng lúc) đều
  /// thấy "chưa có" rồi cùng chèn nếu không có transaction — tạo trùng
  /// hồ sơ bé và trùng khóa cài đặt chung, rồi `getValue` ném
  /// `Bad state: Too many elements` (cột `child_id` nullable nên
  /// unique của SQLite không bắt được trùng khóa chung; xem
  /// `SettingsDao.setValue`). Drift xếp các transaction nối tiếp nhau
  /// nên kiểm-tra-rồi-chèn trong này là nguyên tử.
  Future<String> ensureSeeded() async {
    return transaction(() async {
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
    });
  }

  Future<void> _seedSetting(String key, String value) async {
    final existing = await settingsDao.getValue(key: key);
    if (existing == null) {
      await settingsDao.setValue(key: key, value: value);
    }
  }
}
