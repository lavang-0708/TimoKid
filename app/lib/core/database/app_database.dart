/// Database Drift của TimoKid: 7 bảng bản 0.1 + `inventory` (T2-06) +
/// `arena_attempts` (T2-10) + `pets` (D), schema v4.
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

import '../../features/pet/pet_config.dart';
import '../time/clock.dart';
import 'models.dart';
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
    Pets,
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
    PetsDao,
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
  int get schemaVersion => 4;

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
      await _createPetIndexes();
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
      // v3 → v4 (D): thêm bảng `pets`, chuyển pet cũ từ `settings`.
      if (from < 4) {
        await migrator.createTable(pets);
        await _createPetIndexes();
        await _migrateLegacyPets();
      }
    },
  );

  /// Chỉ mục unique từng phần: mỗi bé chỉ một pet `active` (SQLite
  /// không có cú pháp này trong định nghĩa bảng Drift nên tạo bằng SQL).
  Future<void> _createPetIndexes() => customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS pets_one_active '
    'ON pets (child_id) WHERE active = 1',
  );

  /// Migration v3 → v4: mỗi bé có `selected_egg` hợp lệ trong `settings`
  /// được chuyển thành một dòng `pets` (active). `hatched` theo
  /// `egg_hatched`. Pet đã nở: xp = số ngày xong đề × 20 nhưng không
  /// thấp hơn ngưỡng giai đoạn cũ (nhỡ ≥ 80, lớn ≥ 250) để bé không bị
  /// tụt giai đoạn; `stage_seen` = giai đoạn mới tính được (nên không
  /// chiếu ăn mừng giả). Các khóa cũ trong `settings` được giữ nguyên
  /// (không còn dùng, an toàn nếu cần xem lại). Chạy một lần (chỉ trong
  /// `onUpgrade`), và bỏ qua bé đã có pet.
  Future<void> _migrateLegacyPets() async {
    final eggs =
        await (select(settings)..where(
              (t) => t.key.equals('selected_egg') & t.childId.isNotNull(),
            ))
            .get();
    for (final egg in eggs) {
      final childId = egg.childId!;
      final species = egg.value;
      if (!const ['dog', 'cat', 'rabbit'].contains(species)) continue;
      if (await petsDao.getBySpecies(childId, species) != null) continue;
      final hatched =
          await settingsDao.getValue(childId: childId, key: 'egg_hatched') ==
          'true';
      var xp = 0;
      var seen = 'egg';
      if (hatched) {
        final days = await _legacyDoneDays(childId);
        xp = days * petMigrationXpPerDay;
        if (days >= legacyPetAdultDays && xp < petAdultXp) xp = petAdultXp;
        if (days >= legacyPetTeenDays && days < legacyPetAdultDays) {
          if (xp < petTeenXp) xp = petTeenXp;
        }
        seen = xp >= petAdultXp
            ? 'adult'
            : (xp >= petTeenXp ? 'teen' : 'newborn');
      }
      await petsDao.insertPet(
        childId: childId,
        species: species,
        xp: xp,
        stageSeen: seen,
        hatched: hatched,
        active: true,
      );
    }
  }

  /// Số ngày bé đã xong trọn đề ngày (đủ 5 chặng) — luật cũ của pet.
  Future<int> _legacyDoneDays(String childId) async {
    final sets = await dailySetsDao.getDailySetsForChild(childId);
    var n = 0;
    for (final set in sets) {
      final statuses = dailySetsDao.readStageStatus(set);
      if (statuses.length == 5 &&
          statuses.every((s) => s == StageStatus.done)) {
        n++;
      }
    }
    return n;
  }

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
    await _createPetIndexes();
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
