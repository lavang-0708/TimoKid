/// Bộ đồng bộ (T3-04), theo `docs/SYNC.md`:
///
/// - Chiều lên: gom dòng `synced = false` thành lô ≤ 200 dòng mỗi bảng, gửi
///   theo thứ tự children → daily_sets → attempts → wallet_ledger →
///   skill_progress → review_queue (+ mục đã xóa) → settings (→ thư đã mở)
///   (→ inventory, pets, arena_attempts nếu bật [syncExtraTablesEnabled]).
///   Bảng chỉ thêm dùng `resolution=ignore-duplicates`, bảng có sửa dùng
///   `resolution=merge-duplicates` (`on_conflict=id`). Chỉ đánh dấu
///   `synced` đúng các dòng trong lô gửi thành công; lỗi mạng giữa chừng
///   thì lần sau gửi lại cả lô, upsert theo id nên không trùng dòng.
/// - Chiều xuống: `settings` và `messages` có `updated_at` mới hơn mốc lần
///   trước (mốc lưu trong `settings` của máy, khóa `sync_*`).
///
/// Giờ: app lưu giờ theo quy ước `Clock.now` (UTC + 7 giờ gắn nhãn UTC),
/// nên khi gửi lên trừ 7 giờ để thành thời điểm thật, khi tải về cộng lại.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../time/clock.dart';
import '../../features/custom_questions/custom_question_service.dart';
import 'neon_client.dart';
import 'sync_config.dart';

/// Khóa `settings` chỉ có ý nghĩa trên máy này: không gửi, không nhận.
bool isLocalOnlySettingKey(String key) =>
    key == AppDatabase.activeChildKey ||
    key == 'onboarding_completed' ||
    key == 'sound_enabled' ||
    key == 'music_enabled' ||
    key.startsWith('sync_');

const settingsMarkKey = 'sync_settings_mark';
const messagesMarkKey = 'sync_messages_mark';
const customQuestionsMarkKey = 'sync_custom_questions_mark';

/// Giờ app (UTC+7 gắn nhãn UTC) → ISO-8601 của thời điểm thật.
String toServerTime(DateTime local) => DateTime.fromMillisecondsSinceEpoch(
  local.millisecondsSinceEpoch - vietnamUtcOffset.inMilliseconds,
  isUtc: true,
).toIso8601String();

/// ISO-8601 của server → giờ app.
DateTime fromServerTime(String iso) => DateTime.fromMillisecondsSinceEpoch(
  DateTime.parse(iso).millisecondsSinceEpoch + vietnamUtcOffset.inMilliseconds,
  isUtc: true,
);

String? _t(DateTime? d) => d == null ? null : toServerTime(d);

Object? _jsonOrRaw(String raw) {
  try {
    return jsonDecode(raw);
  } on FormatException {
    return raw;
  }
}

bool _isJson(String raw) {
  try {
    jsonDecode(raw);
    return true;
  } on FormatException {
    return false;
  }
}

String _localValue(Object? server, String? existingRaw) {
  if (server is String && existingRaw != null && !_isJson(existingRaw)) {
    return server;
  }
  return jsonEncode(server);
}

enum SyncOutcome { ok, offline, needsLogin, error, notSignedIn }

class SyncResult {
  const SyncResult(
    this.outcome, {
    this.message,
    this.pushed = const {},
    this.pulledSettings = 0,
    this.pulledMessages = 0,
    this.pulledCustomQuestions = 0,
  });

  final SyncOutcome outcome;
  final String? message;

  /// Số dòng đã gửi thành công theo bảng.
  final Map<String, int> pushed;
  final int pulledSettings;
  final int pulledMessages;
  final int pulledCustomQuestions;

  bool get ok => outcome == SyncOutcome.ok;
  int get totalPushed => pushed.values.fold(0, (a, b) => a + b);
}

class _Pending {
  _Pending(this.id, this.updatedAt, this.json);
  final String id;
  final DateTime updatedAt;
  final Map<String, Object?> json;
}

class _Spec {
  _Spec({
    required this.table,
    required this.sqlTable,
    required this.insertOnly,
    required this.fetch,
    this.stampColumn = 'updated_at',
    this.conflictTarget = 'id',
  });

  /// Tên bảng trên server.
  final String table;

  /// Tên bảng SQLite.
  final String sqlTable;
  final bool insertOnly;
  final Future<List<_Pending>> Function(int limit) fetch;

  /// Cột thời gian dùng để chắc dòng chưa bị sửa giữa lúc gửi.
  final String stampColumn;

  /// Cột `on_conflict` khi upsert. Bảng có khóa duy nhất theo nghĩa (bé +
  /// ngày, bé + dạng bài, bé + món, bé + loài) upsert theo khóa đó: máy thứ
  /// hai hoặc QA xoá dữ liệu sinh id mới thì vẫn ghi đè đúng dòng, không
  /// vướng 409 làm tắc đồng bộ.
  final String conflictTarget;
}

class SyncEngine {
  SyncEngine({
    required this.db,
    required this.client,
    this.batchSize = SyncConfig.batchSize,
    bool? extraTables,
    bool? customQuestions,
    DateTime Function()? nowUtc,
  }) : extraTables = extraTables ?? syncExtraTablesEnabled,
       customQuestions = customQuestions ?? customQuestionsEnabled,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase db;
  final NeonClient client;
  final int batchSize;
  final bool extraTables;

  /// Tải `custom_questions` (T5-03); mặc định theo `customQuestionsEnabled`.
  final bool customQuestions;
  final DateTime Function() _nowUtc;

  bool _running = false;
  bool _familyEnsured = false;

  /// Chạy một lượt đồng bộ. Không bao giờ ném lỗi (trả [SyncResult]).
  Future<SyncResult> syncOnce() async {
    if (_running) return const SyncResult(SyncOutcome.ok);
    _running = true;
    try {
      if (!await client.hasSession()) {
        return const SyncResult(SyncOutcome.notSignedIn);
      }
      if (!_familyEnsured) {
        await client.ensureFamily();
        _familyEnsured = true;
      }
      final pushed = <String, int>{};
      // Cài đặt tải về trước để id dòng khớp server (chỉ mục duy nhất của
      // `settings` là chỉ mục biểu thức nên không upsert theo khóa được)
      // và không gửi đè giá trị mới hơn của bố.
      final ps = await _pullSettings();
      for (final spec in _specs()) {
        final n = await _push(spec);
        if (n > 0) pushed[spec.table] = n;
        if (spec.table == 'settings') {
          final m = await _pushOpenedMessages();
          if (m > 0) pushed['messages'] = m;
        }
      }
      await _touchLastSynced();
      final pm = await _pullMessages();
      final pc = customQuestions ? await _pullCustomQuestions() : 0;
      return SyncResult(
        SyncOutcome.ok,
        pushed: pushed,
        pulledSettings: ps,
        pulledMessages: pm,
        pulledCustomQuestions: pc,
      );
    } on NeonException catch (e) {
      return SyncResult(switch (e.kind) {
        NeonErrorKind.network => SyncOutcome.offline,
        NeonErrorKind.auth => SyncOutcome.needsLogin,
        _ => SyncOutcome.error,
      }, message: e.message);
    } on Object catch (e) {
      return SyncResult(SyncOutcome.error, message: '$e');
    } finally {
      _running = false;
    }
  }

  // ------------------------------------------------------------- gửi

  Future<int> _push(_Spec spec) async {
    var total = 0;
    for (var round = 0; round < 50; round++) {
      final rows = await spec.fetch(batchSize);
      if (rows.isEmpty) break;
      await client.api(
        'POST',
        spec.table,
        query: {'on_conflict': spec.conflictTarget},
        body: [for (final r in rows) r.json],
        prefer: spec.insertOnly
            ? 'resolution=ignore-duplicates,return=minimal'
            : 'resolution=merge-duplicates,return=minimal',
      );
      await _markSynced(spec, rows);
      total += rows.length;
      if (rows.length < batchSize) break;
    }
    return total;
  }

  /// Chỉ đánh dấu đúng các dòng của lô vừa gửi, và chỉ khi dòng chưa bị
  /// sửa từ lúc đọc (cột thời gian còn nguyên).
  Future<void> _markSynced(_Spec spec, List<_Pending> rows) =>
      db.transaction(() async {
        for (final r in rows) {
          await db.customUpdate(
            'UPDATE ${spec.sqlTable} SET synced = 1 '
            'WHERE id = ? AND ${spec.stampColumn} = ?',
            variables: [
              Variable.withString(r.id),
              Variable.withInt(r.updatedAt.millisecondsSinceEpoch ~/ 1000),
            ],
            updates: const {},
          );
        }
      });

  List<_Spec> _specs() => [
    _Spec(
      table: 'children',
      sqlTable: 'children',
      insertOnly: false,
      fetch: (n) async => [
        for (final c in await _unsynced(db.children, n))
          _Pending(c.id, c.updatedAt, {
            'id': c.id,
            'name': _childName(c.name),
            'grade': c.grade.clamp(1, 5),
            'created_at': _t(c.createdAt),
            'updated_at': _t(c.updatedAt),
          }),
      ],
    ),
    _Spec(
      table: 'daily_sets',
      conflictTarget: 'child_id,date',
      sqlTable: 'daily_sets',
      insertOnly: false,
      fetch: (n) async => [
        for (final d in await _unsynced(db.dailySets, n))
          _Pending(d.id, d.updatedAt, {
            'id': d.id,
            'child_id': d.childId,
            'date': d.date,
            'questions': _jsonOrRaw(d.questions),
            'stage_status': _jsonOrRaw(d.stageStatus),
            'completed': d.completed,
            'completed_at': _t(d.completedAt),
            'created_at': _t(d.createdAt),
            'updated_at': _t(d.updatedAt),
          }),
      ],
    ),
    _Spec(
      table: 'attempts',
      sqlTable: 'attempts',
      insertOnly: true,
      fetch: (n) async => [
        for (final a in await _unsynced(db.attempts, n))
          _Pending(a.id, a.updatedAt, {
            'id': a.id,
            'child_id': a.childId,
            'form_id': a.formId,
            'strand': a.strand,
            'level': a.level,
            'rung': a.rung,
            'answer_type': a.answerType,
            'correct_first_try': a.correctFirstTry,
            'attempts_count': a.attemptsCount,
            'duration_ms': a.durationMs,
            'is_review': a.isReview,
            'daily_set_id': a.dailySetId,
            'stage': a.stage,
            'question_seed': a.questionSeed,
            'created_at': _t(a.createdAt),
          }),
      ],
    ),
    _Spec(
      table: 'wallet_ledger',
      sqlTable: 'wallet_ledger',
      insertOnly: true,
      fetch: (n) async => [
        for (final w in await _unsynced(db.walletLedger, n))
          _Pending(w.id, w.updatedAt, {
            'id': w.id,
            'child_id': w.childId,
            'currency': w.currency,
            'amount': w.amount,
            'reason': w.reason.length > 40
                ? w.reason.substring(0, 40)
                : w.reason,
            'ref_id': w.refId,
            'created_at': _t(w.createdAt),
          }),
      ],
    ),
    _Spec(
      table: 'skill_progress',
      conflictTarget: 'child_id,scope,key',
      sqlTable: 'skill_progress',
      insertOnly: false,
      fetch: (n) async => [
        for (final s in await _unsynced(db.skillProgress, n))
          _Pending(s.id, s.updatedAt, {
            'id': s.id,
            'child_id': s.childId,
            'scope': s.scope,
            'key': s.key,
            'rung': s.rung,
            'mastered': s.mastered,
            'mastered_at': _t(s.masteredAt),
            'window_started_at': _t(s.windowStartedAt),
            'created_at': _t(s.createdAt),
            'updated_at': _t(s.updatedAt),
          }),
      ],
    ),
    _Spec(
      table: 'review_queue',
      sqlTable: 'review_queue',
      insertOnly: false,
      fetch: (n) async => [
        for (final r in await _unsynced(db.reviewQueue, n))
          _Pending(r.id, r.updatedAt, {
            'id': r.id,
            'child_id': r.childId,
            'form_id': r.formId,
            'rung': r.rung,
            'due_date': _t(r.dueDate),
            'correct_streak': r.correctStreak.clamp(0, 3),
            'created_at': _t(r.createdAt),
            'updated_at': _t(r.updatedAt),
          }),
      ],
    ),
    // Mục đã xóa khỏi sổ ôn tập: gửi dòng có `deleted_at`.
    _Spec(
      table: 'review_queue',
      sqlTable: 'review_tombstones',
      stampColumn: 'deleted_at',
      insertOnly: false,
      fetch: (n) async => [
        for (final r in await _unsynced(db.reviewTombstones, n))
          _Pending(r.id, r.deletedAt, {
            'id': r.id,
            'child_id': r.childId,
            'form_id': r.formId,
            'rung': r.rung,
            'due_date': _t(r.dueDate),
            'correct_streak': 3,
            'created_at': _t(r.createdAt),
            'updated_at': _t(r.deletedAt),
            'deleted_at': _t(r.deletedAt),
          }),
      ],
    ),
    _Spec(
      table: 'settings',
      sqlTable: 'settings',
      insertOnly: false,
      fetch: (n) async {
        final q = db.select(db.settings)
          ..where(
            (t) =>
                t.synced.equals(false) &
                t.childId.isNotNull() &
                t.key.length.isSmallerOrEqualValue(60),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
        final rows = (await q.get())
            .where((s) => !isLocalOnlySettingKey(s.key))
            .take(n);
        return [
          for (final s in rows)
            _Pending(s.id, s.updatedAt, {
              'id': s.id,
              'child_id': s.childId,
              'key': s.key,
              'value': _jsonOrRaw(s.value),
              'created_at': _t(s.createdAt),
              'updated_at': _t(s.updatedAt),
            }),
        ];
      },
    ),
    if (extraTables) ...[
      _Spec(
        table: 'inventory',
        conflictTarget: 'child_id,item_id',
        sqlTable: 'inventory',
        insertOnly: false,
        fetch: (n) async => [
          for (final i in await _unsynced(db.inventory, n))
            _Pending(i.id, i.updatedAt, {
              'id': i.id,
              'child_id': i.childId,
              'item_id': i.itemId,
              'acquired_at': _t(i.acquiredAt),
              'source': i.source,
              'created_at': _t(i.createdAt),
              'updated_at': _t(i.updatedAt),
            }),
        ],
      ),
      _Spec(
        table: 'pets',
        conflictTarget: 'child_id,species',
        sqlTable: 'pets',
        insertOnly: false,
        fetch: (n) async => [
          for (final p in await _unsynced(db.pets, n))
            _Pending(p.id, p.updatedAt, {
              'id': p.id,
              'child_id': p.childId,
              'species': p.species,
              'xp': p.xp,
              'stage_seen': p.stageSeen,
              'hatched': p.hatched,
              'active': p.active,
              'created_at': _t(p.createdAt),
              'updated_at': _t(p.updatedAt),
            }),
        ],
      ),
      _Spec(
        table: 'arena_attempts',
        sqlTable: 'arena_attempts',
        insertOnly: true,
        fetch: (n) async => [
          for (final a in await _unsynced(db.arenaAttempts, n))
            _Pending(a.id, a.updatedAt, {
              'id': a.id,
              'child_id': a.childId,
              'date': a.date,
              'mode': a.mode,
              'correct_count': a.correctCount,
              'score': a.score,
              'medal': a.medal,
              'duration_sec': a.durationSec,
              'gems_awarded': a.gemsAwarded,
              'created_at': _t(a.createdAt),
            }),
        ],
      ),
    ],
  ];

  /// Đọc tối đa [limit] dòng `synced = false` của bảng [table].
  Future<List<D>> _unsynced<T extends HasResultSet, D>(
    ResultSetImplementation<T, D> table,
    int limit,
  ) {
    final q = db.select(table)
      ..where((_) => const CustomExpression<bool>('synced = 0'))
      ..limit(limit);
    return q.get();
  }

  static String _childName(String name) {
    final n = name.trim();
    if (n.isEmpty) return 'Bé';
    return n.length > 40 ? n.substring(0, 40) : n;
  }

  /// Gửi trạng thái "bé đã mở thư" (thư đã mở trên máy mà server chưa biết).
  Future<int> _pushOpenedMessages() async {
    final rows = await (db.select(
      db.messages,
    )..where((t) => t.synced.equals(false) & t.openedAt.isNotNull())).get();
    var n = 0;
    final now = _nowUtc().toIso8601String();
    for (final m in rows) {
      await client.api(
        'PATCH',
        'messages',
        query: {'id': 'eq.${m.id}'},
        body: {'opened_at': _t(m.openedAt), 'updated_at': now},
        prefer: 'return=minimal',
      );
      await db.customUpdate(
        'UPDATE messages SET synced = 1 WHERE id = ? AND updated_at = ?',
        variables: [
          Variable.withString(m.id),
          Variable.withInt(m.updatedAt.millisecondsSinceEpoch ~/ 1000),
        ],
        updates: const {},
      );
      n++;
    }
    return n;
  }

  Future<void> _touchLastSynced() async {
    final ids = [for (final c in await db.childrenDao.getAllChildren()) c.id];
    if (ids.isEmpty) return;
    await client.api(
      'PATCH',
      'children',
      query: {'id': 'in.(${ids.join(',')})'},
      body: {'last_synced_at': _nowUtc().toIso8601String()},
      prefer: 'return=minimal',
    );
  }

  // ------------------------------------------------------------- tải

  Future<String?> _mark(String key) async {
    final raw = await db.settingsDao.getValue(key: key);
    if (raw == null) return null;
    final v = _jsonOrRaw(raw);
    return v is String ? v : null;
  }

  Future<void> _setMark(String key, String value) =>
      db.settingsDao.setValue(key: key, value: jsonEncode(value));

  Future<List<Map<String, Object?>>> _fetchSince(
    String table,
    String? mark,
    String select,
  ) async {
    final out = <Map<String, Object?>>[];
    var cursor = mark;
    for (var page = 0; page < 20; page++) {
      final res = await client.api(
        'GET',
        table,
        query: {
          'select': select,
          'order': 'updated_at.asc',
          'limit': '500',
          'updated_at': ?(cursor == null ? null : 'gt.$cursor'),
        },
      );
      final body = res.body;
      final rows = body is List
          ? [for (final r in body) (r as Map).cast<String, Object?>()]
          : <Map<String, Object?>>[];
      out.addAll(rows);
      if (rows.length < 500) break;
      cursor = rows.last['updated_at'] as String?;
    }
    return out;
  }

  String? _maxStamp(List<Map<String, Object?>> rows, String? current) {
    var best = current;
    var bestAt = current == null ? null : DateTime.parse(current);
    for (final r in rows) {
      final s = r['updated_at'];
      if (s is! String) continue;
      final at = DateTime.parse(s);
      if (bestAt == null || at.isAfter(bestAt)) {
        best = s;
        bestAt = at;
      }
    }
    return best;
  }

  /// Tải `settings` mới hơn mốc; dòng của bé: `updated_at` mới hơn thắng.
  /// Dòng chung (`child_id` null, vd mức thưởng của bố): server luôn thắng
  /// (app không ghi các khóa này).
  Future<int> _pullSettings() async {
    final mark = await _mark(settingsMarkKey);
    final rows = await _fetchSince(
      'settings',
      mark,
      'id,child_id,key,value,updated_at,created_at',
    );
    var applied = 0;
    final children = {
      for (final c in await db.childrenDao.getAllChildren()) c.id,
    };
    for (final r in rows) {
      final key = r['key'] as String?;
      final id = r['id'] as String?;
      final stamp = r['updated_at'] as String?;
      if (key == null || id == null || stamp == null) continue;
      if (isLocalOnlySettingKey(key)) continue;
      final childId = r['child_id'] as String?;
      if (childId != null && !children.contains(childId)) continue;
      final existing = await db.settingsDao.getRow(childId, key);
      final serverAt = fromServerTime(stamp);
      if (existing == null) {
        await db
            .into(db.settings)
            .insert(
              SettingsCompanion.insert(
                id: id,
                childId: Value(childId),
                key: key,
                value: _localValue(r['value'], null),
                createdAt: fromServerTime(
                  (r['created_at'] as String?) ?? stamp,
                ),
                updatedAt: serverAt,
                synced: const Value(true),
              ),
            );
        applied++;
        continue;
      }
      final serverWins =
          childId == null || serverAt.isAfter(existing.updatedAt);
      if (existing.id != id) {
        await db.customUpdate(
          'UPDATE settings SET id = ? WHERE id = ?',
          variables: [
            Variable.withString(id),
            Variable.withString(existing.id),
          ],
          updates: const {},
        );
      }
      if (serverWins) {
        final value = _localValue(r['value'], existing.value);
        await db.customUpdate(
          'UPDATE settings SET value = ?, updated_at = ? WHERE id = ?',
          variables: [
            Variable.withString(value),
            Variable.withInt(serverAt.millisecondsSinceEpoch ~/ 1000),
            Variable.withString(id),
          ],
          updates: const {},
        );
        // Trigger `settings_unsync` vừa đặt synced = 0; dòng này đang
        // đúng bằng server nên đánh dấu lại.
        await db.customUpdate(
          'UPDATE settings SET synced = 1 WHERE id = ?',
          variables: [Variable.withString(id)],
          updates: const {},
        );
        applied++;
      }
    }
    final next = _maxStamp(rows, mark);
    if (next != null && next != mark) await _setMark(settingsMarkKey, next);
    return applied;
  }

  Future<int> _pullMessages() async {
    final mark = await _mark(messagesMarkKey);
    final rows = await _fetchSince(
      'messages',
      mark,
      'id,child_id,body,gift_xu,gift_gem,gift_item_id,opened_at,claimed_at,created_at,updated_at',
    );
    var n = 0;
    for (final r in rows) {
      final id = r['id'] as String?;
      final childId = r['child_id'] as String?;
      final stamp = r['updated_at'] as String?;
      if (id == null || childId == null || stamp == null) continue;
      final opened = r['opened_at'] as String?;
      final claimed = r['claimed_at'] as String?;
      final local = await (db.select(
        db.messages,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      final openedAt = opened != null
          ? fromServerTime(opened)
          : local?.openedAt;
      final claimedAt = claimed != null
          ? fromServerTime(claimed)
          : local?.claimedAt;
      final needsPush = local?.openedAt != null && opened == null;
      await db
          .into(db.messages)
          .insertOnConflictUpdate(
            MessagesCompanion.insert(
              id: id,
              childId: childId,
              body: '${r['body'] ?? ''}',
              giftXu: Value((r['gift_xu'] as num?)?.toInt() ?? 0),
              giftGem: Value((r['gift_gem'] as num?)?.toInt() ?? 0),
              giftItemId: Value(r['gift_item_id'] as String?),
              openedAt: Value(openedAt),
              claimedAt: Value(claimedAt),
              createdAt: fromServerTime((r['created_at'] as String?) ?? stamp),
              updatedAt: fromServerTime(stamp),
              synced: Value(!needsPush),
            ),
          );
      n++;
    }
    final next = _maxStamp(rows, mark);
    if (next != null && next != mark) await _setMark(messagesMarkKey, next);
    return n;
  }

  /// Tải câu hỏi tự soạn (T5-03) có `updated_at` mới hơn mốc. Mốc lấy từ
  /// chính `updated_at` của server. Câu bị tắt (`active = false`) cũng được
  /// tải để máy ngừng dùng. App không ghi gì lên bảng này.
  Future<int> _pullCustomQuestions() async {
    final mark = await _mark(customQuestionsMarkKey);
    final rows = await _fetchSince(
      'custom_questions',
      mark,
      'id,child_id,strand,rung,grade,text_vi,text_en,answer,choices,explanation_vi,active,created_at,updated_at',
    );
    var n = 0;
    for (final r in rows) {
      final row = customQuestionFromServer(r, fromServerTime);
      if (row == null) continue;
      await db.customQuestionsDao.upsertFromServer(row);
      n++;
    }
    final next = _maxStamp(rows, mark);
    if (next != null && next != mark) {
      await _setMark(customQuestionsMarkKey, next);
    }
    return n;
  }
}
