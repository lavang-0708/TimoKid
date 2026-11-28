/// DAO cho 7 bảng của T1-04.
///
/// Các DAO chỉ làm CRUD và truy vấn; luật học (lên/xuống bậc, sổ ôn tập,
/// tính xu) nằm ở các nhiệm vụ sau (T1-07, T1-08, T1-10, T1-11) và sẽ
/// gọi các hàm này.
///
/// Hai bảng append-only (`attempts`, `wallet_ledger`) cố tình KHÔNG có
/// hàm sửa/xóa ở tầng DAO, và database chặn thêm bằng trigger SQLite
/// (xem `app_database.dart`). Mọi kiểm tra "chỉ thêm" trong test đều
/// dựa trên cả hai lớp chặn này.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'models.dart';
import 'tables.dart';

part 'daos.g.dart';

const _uuid = Uuid();

/// Sinh id UUID v4 cho dòng mới.
String newId() => _uuid.v4();

@DriftAccessor(tables: [Children])
class ChildrenDao extends DatabaseAccessor<AppDatabase>
    with _$ChildrenDaoMixin {
  ChildrenDao(super.db);

  /// Tạo hồ sơ bé mới. Mặc định lớp 2.
  Future<ChildrenData> createChild({
    required String name,
    int grade = 2,
    String? familyId,
  }) async {
    final now = db.clock.now();
    final companion = ChildrenCompanion.insert(
      id: newId(),
      name: name,
      grade: Value(grade),
      familyId: Value(familyId),
      createdAt: now,
      updatedAt: now,
    );
    await into(db.children).insert(companion);
    return ChildrenData(
      id: companion.id.value,
      name: name,
      grade: grade,
      familyId: familyId,
      createdAt: now,
      updatedAt: now,
      synced: false,
    );
  }

  Future<ChildrenData?> getChild(String id) =>
      (select(db.children)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<ChildrenData>> getAllChildren() => select(db.children).get();

  /// Hồ sơ bé đầu tiên (tạo sớm nhất). Dữ liệu từ bản 0.1/0.2 (một bé
  /// mặc định) luôn thuộc bé này khi có thêm bé khác (T3-03).
  Future<ChildrenData?> getFirstChild() =>
      (select(db.children)
            ..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
            ])
            ..limit(1))
          .getSingleOrNull();

  /// Mọi bé, thứ tự tạo (bé đầu tiên trước).
  Future<List<ChildrenData>> getChildrenInOrder() =>
      (select(db.children)..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
          ]))
          .get();

  /// Đổi tên / lớp của bé. `updatedAt` tự cập nhật.
  Future<void> updateChild(String id, {String? name, int? grade}) async {
    await (update(db.children)..where((t) => t.id.equals(id))).write(
      ChildrenCompanion(
        name: name == null ? const Value.absent() : Value(name),
        grade: grade == null ? const Value.absent() : Value(grade),
        updatedAt: Value(db.clock.now()),
      ),
    );
  }

  Future<int> deleteChild(String id) =>
      (delete(db.children)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [Attempts])
class AttemptsDao extends DatabaseAccessor<AppDatabase>
    with _$AttemptsDaoMixin {
  AttemptsDao(super.db);

  /// Ghi một lượt trả lời. Chỉ thêm dòng, không có hàm sửa/xóa.
  Future<String> recordAttempt({
    required String childId,
    required String formId,
    required String strand,
    required int level,
    required int rung,
    required String answerType,
    required bool correctFirstTry,
    required int attemptsCount,
    required int durationMs,
    bool isReview = false,
    String? dailySetId,
    int? stage,
    int? questionSeed,
  }) async {
    final now = db.clock.now();
    final id = newId();
    await into(db.attempts).insert(
      AttemptsCompanion.insert(
        id: id,
        childId: childId,
        formId: formId,
        strand: strand,
        level: level,
        rung: rung,
        answerType: answerType,
        correctFirstTry: correctFirstTry,
        attemptsCount: attemptsCount,
        durationMs: durationMs,
        isReview: Value(isReview),
        dailySetId: Value(dailySetId),
        stage: Value(stage),
        questionSeed: Value(questionSeed),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// Các lượt trả lời của bé, mới nhất trước.
  Future<List<Attempt>> getAttemptsForChild(String childId, {int? limit}) {
    final query = select(db.attempts)
      ..where((t) => t.childId.equals(childId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  /// Số câu đúng ngay lần đầu trong khoảng [start, end) (dùng cho nhiệm
  /// vụ ngày). [strand] lọc theo mảng; [reviewOnly] chỉ tính câu ôn tập.
  Future<int> countFirstTryBetween({
    required String childId,
    required DateTime start,
    required DateTime end,
    String? strand,
    bool reviewOnly = false,
  }) async {
    final query = select(db.attempts)
      ..where(
        (t) =>
            t.childId.equals(childId) &
            t.correctFirstTry.equals(true) &
            t.createdAt.isBiggerOrEqualValue(start) &
            t.createdAt.isSmallerThanValue(end),
      );
    if (strand != null) query.where((t) => t.strand.equals(strand));
    if (reviewOnly) query.where((t) => t.isReview.equals(true));
    return (await query.get()).length;
  }

  /// Các lượt trả lời gần nhất của một mảng (phục vụ cửa sổ 10 câu
  /// của T1-07). `since` giới hạn từ mốc đổi bậc gần nhất trở đi.
  Future<List<Attempt>> getRecentStrandAttempts({
    required String childId,
    required String strand,
    DateTime? since,
    int limit = 10,
  }) {
    final query = select(db.attempts)
      ..where((t) => t.childId.equals(childId) & t.strand.equals(strand))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit);
    if (since != null) {
      query.where((t) => t.createdAt.isBiggerThanValue(since));
    }
    return query.get();
  }

  /// Các lượt trả lời gần nhất của một dạng bài (phục vụ tính thành thạo
  /// 4/5 câu của T1-07). `level` giới hạn chỉ các câu ở một mức
  /// (vd: mức thành thạo của dạng); bỏ trống thì lấy mọi mức.
  Future<List<Attempt>> getRecentFormAttempts({
    required String childId,
    required String formId,
    int? level,
    int limit = 5,
  }) {
    final query = select(db.attempts)
      ..where((t) => t.childId.equals(childId) & t.formId.equals(formId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit);
    if (level != null) {
      query.where((t) => t.level.equals(level));
    }
    return query.get();
  }
}

@DriftAccessor(tables: [SkillProgress])
class SkillProgressDao extends DatabaseAccessor<AppDatabase>
    with _$SkillProgressDaoMixin {
  SkillProgressDao(super.db);

  /// Đặt bậc hiện tại của một mảng. Tạo dòng nếu chưa có, cập nhật nếu
  /// đã có; đồng thời đặt lại mốc cửa sổ 10 câu (`windowStartedAt`).
  /// Ghi chú: `insertOnConflictUpdate` của Drift chỉ nhắm vào khóa chính
  /// (`id` UUID mới mỗi lần gọi) nên không bắt được trùng
  /// (child_id, scope, key); vì vậy hàm này tự kiểm tra rồi cập nhật.
  Future<void> setStrandRung({
    required String childId,
    required String strand,
    required int rung,
  }) async {
    final now = db.clock.now();
    final existing = await getStrandProgress(childId, strand);
    if (existing != null) {
      await (update(
        db.skillProgress,
      )..where((t) => t.id.equals(existing.id))).write(
        SkillProgressCompanion(
          rung: Value(rung),
          windowStartedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return;
    }
    await into(db.skillProgress).insert(
      SkillProgressCompanion.insert(
        id: newId(),
        childId: childId,
        scope: SkillScope.strand,
        key: strand,
        rung: Value(rung),
        windowStartedAt: Value(now),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<SkillProgressData?> getStrandProgress(String childId, String strand) =>
      (select(db.skillProgress)..where(
            (t) =>
                t.childId.equals(childId) &
                t.scope.equals(SkillScope.strand) &
                t.key.equals(strand),
          ))
          .getSingleOrNull();

  /// Bậc hiện tại của cả 5 mảng (thiếu mảng nào thì coi như bậc 1).
  Future<List<SkillProgressData>> getAllStrandProgress(String childId) =>
      (select(db.skillProgress)..where(
            (t) =>
                t.childId.equals(childId) & t.scope.equals(SkillScope.strand),
          ))
          .get();

  /// Đánh dấu một dạng bài đã / chưa thành thạo.
  /// (Tự kiểm tra rồi cập nhật như [setStrandRung], vì
  /// `insertOnConflictUpdate` chỉ nhắm vào khóa chính.)
  Future<void> setFormMastered({
    required String childId,
    required String formId,
    required bool mastered,
  }) async {
    final now = db.clock.now();
    final existing = await getFormProgress(childId, formId);
    if (existing != null) {
      await (update(
        db.skillProgress,
      )..where((t) => t.id.equals(existing.id))).write(
        SkillProgressCompanion(
          mastered: Value(mastered),
          // Giữ mastered_at lần đầu đạt: ghi true lần nữa không đẩy
          // ngày thành thạo lên hiện tại.
          masteredAt: Value(mastered ? (existing.masteredAt ?? now) : null),
          updatedAt: Value(now),
        ),
      );
      return;
    }
    await into(db.skillProgress).insert(
      SkillProgressCompanion.insert(
        id: newId(),
        childId: childId,
        scope: SkillScope.form,
        key: formId,
        mastered: Value(mastered),
        masteredAt: Value(mastered ? now : null),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<SkillProgressData?> getFormProgress(String childId, String formId) =>
      (select(db.skillProgress)..where(
            (t) =>
                t.childId.equals(childId) &
                t.scope.equals(SkillScope.form) &
                t.key.equals(formId),
          ))
          .getSingleOrNull();

  /// Các dạng bài đã thành thạo của bé.
  Future<List<SkillProgressData>> getMasteredForms(String childId) =>
      (select(db.skillProgress)..where(
            (t) =>
                t.childId.equals(childId) &
                t.scope.equals(SkillScope.form) &
                t.mastered.equals(true),
          ))
          .get();
}

@DriftAccessor(tables: [ReviewQueue])
class ReviewQueueDao extends DatabaseAccessor<AppDatabase>
    with _$ReviewQueueDaoMixin {
  ReviewQueueDao(super.db);

  /// Thêm dạng bài vào sổ ôn tập (hoặc cập nhật mục đã có: đặt lại bậc,
  /// ngày hỏi lại và chuỗi đúng về 0).
  Future<String> upsertEntry({
    required String childId,
    required String formId,
    required int rung,
    required DateTime dueDate,
  }) async {
    final now = db.clock.now();
    final existing = await getEntry(childId, formId);
    if (existing != null) {
      await (update(
        db.reviewQueue,
      )..where((t) => t.id.equals(existing.id))).write(
        ReviewQueueCompanion(
          rung: Value(rung),
          dueDate: Value(dueDate),
          correctStreak: const Value(0),
          updatedAt: Value(now),
        ),
      );
      return existing.id;
    }
    final id = newId();
    await into(db.reviewQueue).insert(
      ReviewQueueCompanion.insert(
        id: id,
        childId: childId,
        formId: formId,
        rung: rung,
        dueDate: dueDate,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<ReviewQueueData?> getEntry(String childId, String formId) =>
      (select(db.reviewQueue)
            ..where((t) => t.childId.equals(childId) & t.formId.equals(formId)))
          .getSingleOrNull();

  /// Các mục đến hạn hỏi lại (ngày hỏi lại <= `now`).
  Future<List<ReviewQueueData>> getDueEntries({
    required String childId,
    required DateTime now,
  }) =>
      (select(db.reviewQueue)
            ..where(
              (t) =>
                  t.childId.equals(childId) &
                  t.dueDate.isSmallerOrEqualValue(now),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
          .get();

  Future<List<ReviewQueueData>> getAllEntries(String childId) =>
      (select(db.reviewQueue)
            ..where((t) => t.childId.equals(childId))
            ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
          .get();

  /// Cập nhật chuỗi đúng liên tiếp và ngày hỏi lại sau một lần hỏi lại.
  Future<void> updateStreakAndDue({
    required String id,
    required int correctStreak,
    required DateTime dueDate,
  }) async {
    await (update(db.reviewQueue)..where((t) => t.id.equals(id))).write(
      ReviewQueueCompanion(
        correctStreak: Value(correctStreak),
        dueDate: Value(dueDate),
        updatedAt: Value(db.clock.now()),
      ),
    );
  }

  /// Xóa mục khỏi sổ (đủ 3 lần đúng ngay, T1-10).
  Future<int> removeEntry(String id) =>
      (delete(db.reviewQueue)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [DailySets])
class DailySetsDao extends DatabaseAccessor<AppDatabase>
    with _$DailySetsDaoMixin {
  DailySetsDao(super.db);

  /// Tạo đề ngày mới. Trạng thái 5 chặng ban đầu đều là `not_started`.
  Future<String> createDailySet({
    required String childId,
    required String date,
    required List<DailySetQuestion> questions,
  }) async {
    final now = db.clock.now();
    final id = newId();
    await into(db.dailySets).insert(
      DailySetsCompanion.insert(
        id: id,
        childId: childId,
        date: date,
        questions: jsonEncode(questions.map((q) => q.toJson()).toList()),
        stageStatus: jsonEncode(List.filled(5, StageStatus.notStarted)),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<DailySet?> getDailySet(String childId, String date) =>
      (select(db.dailySets)
            ..where((t) => t.childId.equals(childId) & t.date.equals(date)))
          .getSingleOrNull();

  /// Tìm đề ngày theo id (null nếu không có).
  Future<DailySet?> getDailySetById(String id) =>
      (select(db.dailySets)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<DailySet>> getDailySetsForChild(String childId) =>
      (select(db.dailySets)
            ..where((t) => t.childId.equals(childId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  /// Đọc 25 câu của đề đã lưu.
  List<DailySetQuestion> readQuestions(DailySet set) {
    final raw = jsonDecode(set.questions) as List<dynamic>;
    return raw
        .map((e) => DailySetQuestion.fromJson(e as Map<String, Object?>))
        .toList();
  }

  /// Đọc trạng thái 5 chặng của đề đã lưu.
  List<String> readStageStatus(DailySet set) {
    final raw = jsonDecode(set.stageStatus) as List<dynamic>;
    return raw.map((e) => e as String).toList();
  }

  /// Đổi trạng thái một chặng (chỉ số 0–4).
  Future<void> updateStageStatus({
    required String id,
    required int stageIndex,
    required String status,
  }) async {
    final set = (await (select(
      db.dailySets,
    )..where((t) => t.id.equals(id))).getSingle());
    final stages = readStageStatus(set);
    stages[stageIndex] = status;
    await (update(db.dailySets)..where((t) => t.id.equals(id))).write(
      DailySetsCompanion(
        stageStatus: Value(jsonEncode(stages)),
        updatedAt: Value(db.clock.now()),
      ),
    );
  }

  /// Đánh dấu đã xong cả đề ngày.
  Future<void> markCompleted(String id) async {
    final now = db.clock.now();
    await (update(db.dailySets)..where((t) => t.id.equals(id))).write(
      DailySetsCompanion(
        completed: const Value(true),
        completedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }
}

@DriftAccessor(tables: [WalletLedger])
class WalletDao extends DatabaseAccessor<AppDatabase> with _$WalletDaoMixin {
  WalletDao(super.db);

  /// Ghi một giao dịch xu/kim cương. Chỉ thêm dòng, không có hàm sửa/xóa.
  /// `amount` dương là cộng, âm là trừ.
  Future<String> addEntry({
    required String childId,
    required String currency,
    required int amount,
    required String reason,
    String? refId,
  }) async {
    final now = db.clock.now();
    final id = newId();
    await into(db.walletLedger).insert(
      WalletLedgerCompanion.insert(
        id: id,
        childId: childId,
        currency: currency,
        amount: amount,
        reason: reason,
        refId: Value(refId),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// Số dư một loại tiền = tổng cột `amount` của bé đó.
  Future<int> balance({
    required String childId,
    required String currency,
  }) async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM ${db.walletLedger.actualTableName} '
      'WHERE child_id = ? AND currency = ?',
      variables: [Variable.withString(childId), Variable.withString(currency)],
      readsFrom: {db.walletLedger},
    ).getSingle();
    return row.read<int>('total');
  }

  /// Đã có giao dịch nào với `refId` này của bé chưa (dùng để
  /// chống cộng trùng thưởng một-lần-mỗi-ngày, xem `RewardService`).
  Future<bool> hasEntryWithRefId({
    required String childId,
    required String refId,
  }) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS n FROM ${db.walletLedger.actualTableName} '
      'WHERE child_id = ? AND ref_id = ?',
      variables: [Variable.withString(childId), Variable.withString(refId)],
      readsFrom: {db.walletLedger},
    ).getSingle();
    return row.read<int>('n') > 0;
  }

  /// Số dư cả hai loại tiền.
  Future<Map<String, int>> balances(String childId) async {
    return {
      Currency.xu: await balance(childId: childId, currency: Currency.xu),
      Currency.gem: await balance(childId: childId, currency: Currency.gem),
    };
  }

  /// Lịch sử giao dịch của bé, mới nhất trước.
  Future<List<WalletLedgerData>> getEntries(String childId, {int? limit}) {
    final query = select(db.walletLedger)
      ..where((t) => t.childId.equals(childId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }
}

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  /// Đặt giá trị một khóa. `childId` null = cài đặt chung.
  /// Ghi chú: cột `child_id` nullable nên ràng buộc unique của SQLite
  /// không bắt được trùng khóa chung (NULL coi như khác nhau); vì vậy
  /// hàm này tự kiểm tra rồi cập nhật thay vì dựa vào `ON CONFLICT`.
  Future<void> setValue({
    String? childId,
    required String key,
    required String value,
  }) async {
    final now = db.clock.now();
    final existing = await _find(childId, key);
    if (existing != null) {
      await (update(db.settings)..where((t) => t.id.equals(existing.id))).write(
        SettingsCompanion(value: Value(value), updatedAt: Value(now)),
      );
      return;
    }
    await into(db.settings).insert(
      SettingsCompanion.insert(
        id: newId(),
        childId: Value(childId),
        key: key,
        value: value,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Đọc giá trị một khóa. Trả null nếu chưa có.
  Future<String?> getValue({String? childId, required String key}) async {
    final row = await _find(childId, key);
    return row?.value;
  }

  /// Đọc giá trị hiệu lực: cài đặt riêng của bé trước, nếu không có thì
  /// lấy cài đặt chung.
  Future<String?> getEffectiveValue({
    String? childId,
    required String key,
  }) async {
    if (childId != null) {
      final own = await getValue(childId: childId, key: key);
      if (own != null) return own;
    }
    return getValue(key: key);
  }

  Future<int> deleteSetting({String? childId, required String key}) async {
    final row = await _find(childId, key);
    if (row == null) return 0;
    return (delete(db.settings)..where((t) => t.id.equals(row.id))).go();
  }

  Future<List<Setting>> getAllSettings({String? childId}) {
    final query = select(db.settings);
    if (childId != null) {
      query.where((t) => t.childId.equals(childId));
    } else {
      query.where((t) => t.childId.isNull());
    }
    return query.get();
  }

  /// Dòng cài đặt (cho bộ đồng bộ cần id và `updatedAt`).
  Future<Setting?> getRow(String? childId, String key) => _find(childId, key);

  Future<Setting?> _find(String? childId, String key) {
    final query = select(db.settings)..where((t) => t.key.equals(key));
    if (childId == null) {
      query.where((t) => t.childId.isNull());
    } else {
      query.where((t) => t.childId.equals(childId));
    }
    return query.getSingleOrNull();
  }
}

/// Kho đồ của bé (T2-06): món đã sở hữu. Không mua trùng nhờ unique
/// (child_id, item_id); [grant] bỏ qua nếu đã có.
@DriftAccessor(tables: [Inventory])
class InventoryDao extends DatabaseAccessor<AppDatabase>
    with _$InventoryDaoMixin {
  InventoryDao(super.db);

  /// Thêm món cho bé; trả true nếu vừa thêm, false nếu bé đã có món này.
  Future<bool> grant({
    required String childId,
    required String itemId,
    required String source,
  }) async {
    return transaction(() async {
      if (await has(childId, itemId)) return false;
      final now = db.clock.now();
      await into(db.inventory).insert(
        InventoryCompanion.insert(
          id: newId(),
          childId: childId,
          itemId: itemId,
          acquiredAt: now,
          source: source,
          createdAt: now,
          updatedAt: now,
        ),
        // Phòng hờ: unique (child_id, item_id) cũng chặn ở tầng SQLite.
        mode: InsertMode.insertOrIgnore,
      );
      return true;
    });
  }

  /// Bé đã có món này chưa.
  Future<bool> has(String childId, String itemId) async {
    final row =
        await (select(db.inventory)..where(
              (t) => t.childId.equals(childId) & t.itemId.equals(itemId),
            ))
            .getSingleOrNull();
    return row != null;
  }

  /// Mọi món bé đang có, theo thứ tự có món.
  Future<List<InventoryData>> getAll(String childId) =>
      (select(db.inventory)
            ..where((t) => t.childId.equals(childId))
            ..orderBy([(t) => OrderingTerm.asc(t.acquiredAt)]))
          .get();
}

/// Bài thi Đấu trường đã nộp (T2-10). Chỉ thêm dòng; đọc để hiện điểm
/// cao nhất và trạng thái hôm nay.
@DriftAccessor(tables: [ArenaAttempts])
class ArenaAttemptsDao extends DatabaseAccessor<AppDatabase>
    with _$ArenaAttemptsDaoMixin {
  ArenaAttemptsDao(super.db);

  /// Ghi một bài thi đã nộp. Trả id dòng mới.
  Future<String> record({
    required String childId,
    required String date,
    required String mode,
    required int correctCount,
    required int score,
    required String medal,
    required int durationSec,
    required int gemsAwarded,
  }) async {
    final now = db.clock.now();
    final id = newId();
    await into(db.arenaAttempts).insert(
      ArenaAttemptsCompanion.insert(
        id: id,
        childId: childId,
        date: date,
        mode: Value(mode),
        correctCount: correctCount,
        score: score,
        medal: medal,
        durationSec: durationSec,
        gemsAwarded: Value(gemsAwarded),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// Mọi bài đã nộp của bé, mới nhất trước.
  Future<List<ArenaAttempt>> getAll(String childId) =>
      (select(db.arenaAttempts)
            ..where((t) => t.childId.equals(childId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// Số bài bé đã nộp trong ngày [date] (`YYYY-MM-DD`).
  Future<int> countOnDate(String childId, String date) async {
    final rows = await (select(
      db.arenaAttempts,
    )..where((t) => t.childId.equals(childId) & t.date.equals(date))).get();
    return rows.length;
  }

  /// Bài điểm cao nhất của bé (hòa thì bài mới hơn); null nếu chưa thi.
  Future<ArenaAttempt?> best(String childId) =>
      (select(db.arenaAttempts)
            ..where((t) => t.childId.equals(childId))
            ..orderBy([
              (t) => OrderingTerm.desc(t.score),
              (t) => OrderingTerm.desc(t.createdAt),
            ])
            ..limit(1))
          .getSingleOrNull();
}

/// Pet của bé (D, schema v4). Chỉ CRUD thô; luật (một pet active, cộng
/// xp, nở, đổi pet) nằm ở `PetService`.
@DriftAccessor(tables: [Pets])
class PetsDao extends DatabaseAccessor<AppDatabase> with _$PetsDaoMixin {
  PetsDao(super.db);

  Future<List<Pet>> getAll(String childId) =>
      (select(db.pets)
            ..where((t) => t.childId.equals(childId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<Pet?> getById(String petId) =>
      (select(db.pets)..where((t) => t.id.equals(petId))).getSingleOrNull();

  Future<Pet?> getActive(String childId) =>
      (select(db.pets)
            ..where((t) => t.childId.equals(childId) & t.active.equals(true)))
          .getSingleOrNull();

  Future<Pet?> getBySpecies(String childId, String species) =>
      (select(db.pets)..where(
            (t) => t.childId.equals(childId) & t.species.equals(species),
          ))
          .getSingleOrNull();

  /// Thêm một pet; trả dòng vừa thêm. Gọi trong transaction của service.
  Future<Pet> insertPet({
    required String childId,
    required String species,
    int xp = 0,
    String stageSeen = 'egg',
    bool hatched = false,
    bool active = false,
  }) async {
    final now = db.clock.now();
    final id = newId();
    await into(db.pets).insert(
      PetsCompanion.insert(
        id: id,
        childId: childId,
        species: species,
        xp: Value(xp),
        stageSeen: Value(stageSeen),
        hatched: Value(hatched),
        active: Value(active),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (await getById(id))!;
  }

  Future<void> updatePet(String petId, PetsCompanion changes) =>
      (update(db.pets)..where((t) => t.id.equals(petId))).write(
        changes.copyWith(updatedAt: Value(db.clock.now())),
      );

  /// Bỏ active mọi pet của bé (bước đầu của đổi pet).
  Future<void> clearActive(String childId) =>
      (update(db.pets)
            ..where((t) => t.childId.equals(childId) & t.active.equals(true)))
          .write(PetsCompanion(active: const Value(false)));
}

/// Ảnh album của bé (T5-05). Chỉ trên máy, xem [Photos].
@DriftAccessor(tables: [Photos])
class PhotosDao extends DatabaseAccessor<AppDatabase> with _$PhotosDaoMixin {
  PhotosDao(super.db);

  /// Thêm một ảnh. Trả dòng vừa tạo.
  Future<Photo> insertPhoto({
    required String childId,
    required String fileName,
    required int width,
    required int height,
    String? id,
  }) async {
    final row = PhotosCompanion.insert(
      id: id ?? newId(),
      childId: childId,
      fileName: fileName,
      width: width,
      height: height,
      createdAt: db.clock.now(),
    );
    await into(db.photos).insert(row);
    return (select(
      db.photos,
    )..where((t) => t.id.equals(row.id.value))).getSingle();
  }

  /// Ảnh của bé, mới nhất trước.
  Future<List<Photo>> listForChild(String childId) =>
      (select(db.photos)
            ..where((t) => t.childId.equals(childId))
            ..orderBy([
              (t) => OrderingTerm.desc(t.createdAt),
              (t) => OrderingTerm.desc(t.id),
            ]))
          .get();

  Future<int> countForChild(String childId) async {
    final n = db.photos.id.count();
    final q = selectOnly(db.photos)
      ..addColumns([n])
      ..where(db.photos.childId.equals(childId));
    return (await q.getSingle()).read(n) ?? 0;
  }

  Future<Photo?> getById(String id) =>
      (select(db.photos)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> deleteById(String id) =>
      (delete(db.photos)..where((t) => t.id.equals(id))).go();
}

/// Câu hỏi tự soạn đã tải về (T5-03). Chỉ tải về, xem [CustomQuestions].
@DriftAccessor(tables: [CustomQuestions])
class CustomQuestionsDao extends DatabaseAccessor<AppDatabase>
    with _$CustomQuestionsDaoMixin {
  CustomQuestionsDao(super.db);

  /// Thêm hoặc cập nhật theo id (bộ đồng bộ tải về); dòng cũ hơn dòng đã
  /// có thì bỏ qua.
  Future<void> upsertFromServer(CustomQuestionsCompanion row) async {
    final existing = await (select(
      db.customQuestions,
    )..where((t) => t.id.equals(row.id.value))).getSingleOrNull();
    if (existing != null && existing.updatedAt.isAfter(row.updatedAt.value)) {
      return;
    }
    await into(db.customQuestions).insertOnConflictUpdate(row);
  }

  /// Câu đang bật của [strand] đúng bậc [rung] dành cho bé [childId]
  /// (câu của riêng bé hoặc của mọi bé), cũ nhất trước.
  Future<List<CustomQuestion>> activeFor({
    required String childId,
    required String strand,
    required int rung,
  }) =>
      (select(db.customQuestions)
            ..where(
              (t) =>
                  t.active.equals(true) &
                  t.strand.equals(strand) &
                  t.rung.equals(rung) &
                  (t.childId.isNull() | t.childId.equals(childId)),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();

  Future<List<CustomQuestion>> getAll() => select(db.customQuestions).get();

  Future<CustomQuestion?> getById(String id) => (select(
    db.customQuestions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
}
