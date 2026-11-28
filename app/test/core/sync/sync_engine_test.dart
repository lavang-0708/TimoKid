/// Bộ đồng bộ (T3-04): lô ≤ 200, thứ tự bảng, header upsert, chỉ đánh dấu
/// synced khi gửi thành công, gửi lại sau lỗi mạng không tạo dòng trùng,
/// mốc tải về, settings mới thắng, sổ ôn tập đã xóa. Dùng Neon giả
/// (`FakeNeon`), không có cuộc gọi mạng thật.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/sync/neon_client.dart';
import 'package:timokid/core/sync/session_store.dart';
import 'package:timokid/core/sync/sync_engine.dart';
import 'package:timokid/core/time/clock.dart';

import 'fake_neon.dart';

void main() {
  late FakeNeon neon;
  late AppDatabase db;
  late FakeClock clock;
  late String childId;
  late NeonClient client;

  SyncEngine engine({bool extra = false}) => SyncEngine(
    db: db,
    client: client,
    extraTables: extra,
    nowUtc: () => DateTime.utc(2026, 11, 28, 9),
  );

  Future<int> unsynced(String table) async =>
      (await db
              .customSelect('SELECT COUNT(*) AS n FROM $table WHERE synced = 0')
              .getSingle())
          .read<int>('n');

  Future<void> addAttempt() => db.attemptsDao.recordAttempt(
    childId: childId,
    formId: 'logic.age',
    strand: Strand.logic,
    level: 1,
    rung: 1,
    answerType: AnswerType.choice,
    correctFirstTry: true,
    attemptsCount: 1,
    durationMs: 1000,
  );

  setUp(() async {
    neon = FakeNeon();
    clock = FakeClock(DateTime.utc(2026, 11, 28, 15)); // 22:00 giờ VN
    db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    client = neon.signedInClient(MemorySessionStore());
  });

  test('chưa đăng nhập thì không gọi mạng', () async {
    final e = SyncEngine(
      db: db,
      client: NeonClient(client: neon.client, store: MemorySessionStore()),
    );
    final r = await e.syncOnce();
    expect(r.outcome, SyncOutcome.notSignedIn);
    expect(neon.log, isEmpty);
  });

  test('lô tối đa 200 dòng, upsert chỉ-thêm dùng ignore-duplicates', () async {
    for (var i = 0; i < 450; i++) {
      await addAttempt();
    }
    final r = await engine().syncOnce();
    expect(r.ok, isTrue);
    final posts = neon.posts('attempts');
    expect([for (final p in posts) (p.body as List).length], [200, 200, 50]);
    for (final p in posts) {
      expect(p.prefer, contains('resolution=ignore-duplicates'));
      expect(p.query['on_conflict'], 'id');
    }
    expect(neon.table('attempts'), hasLength(450));
    expect(await unsynced('attempts'), 0);
  });

  test('gửi theo thứ tự children → daily_sets → attempts → ví → bậc → sổ → settings', () async {
    await addAttempt();
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: 5,
      reason: 'answer_first_try',
    );
    await db.reviewQueueDao.upsertEntry(
      childId: childId,
      formId: 'logic.age',
      rung: 1,
      dueDate: DateTime.utc(2026, 11, 29),
    );
    await db.dailySetsDao.createDailySet(
      childId: childId,
      date: '2026-11-28',
      questions: const [],
    );
    await db.settingsDao.setValue(
      childId: childId,
      key: 'kid_glasses',
      value: 'true',
    );
    await engine().syncOnce();
    expect({for (final p in neon.posts()) p.table}.toList(), [
      'children',
      'daily_sets',
      'attempts',
      'wallet_ledger',
      'skill_progress',
      'review_queue',
      'settings',
    ]);
    // Bảng có khóa duy nhất theo nghĩa upsert theo khóa đó (tránh 409 khi
    // máy khác hoặc QA sinh id mới); còn lại upsert theo id.
    final conflict = {
      for (final p in neon.posts()) p.table: p.query['on_conflict'],
    };
    expect(conflict['daily_sets'], 'child_id,date');
    expect(conflict['skill_progress'], 'child_id,scope,key');
    expect(conflict['attempts'], 'id');
    expect(conflict['review_queue'], 'id');
    // Bảng có sửa dùng merge-duplicates.
    for (final t in [
      'children',
      'daily_sets',
      'skill_progress',
      'review_queue',
      'settings',
    ]) {
      expect(
        neon.posts(t).first.prefer,
        contains('resolution=merge-duplicates'),
        reason: t,
      );
    }
    // Cột đúng tên/kiểu server: giờ trừ 7 tiếng (thành thời điểm thật).
    final att = (neon.posts('attempts').single.body as List).single as Map;
    expect(att.keys.toSet(), {
      'id',
      'child_id',
      'form_id',
      'strand',
      'level',
      'rung',
      'answer_type',
      'correct_first_try',
      'attempts_count',
      'duration_ms',
      'is_review',
      'daily_set_id',
      'stage',
      'question_seed',
      'created_at',
    });
    expect(att['created_at'], '2026-11-28T08:00:00.000Z');
    final set = (neon.posts('daily_sets').single.body as List).single as Map;
    expect(set['questions'], isA<List>());
    // Thứ tự lệnh PATCH last_synced_at ở cuối, trước khi tải thư.
    expect(neon.log.where((l) => l.method == 'PATCH').single.table, 'children');
    expect(
      neon.table('children')[childId]!['last_synced_at'],
      '2026-11-28T09:00:00.000Z',
    );
  });

  test('chỉ đánh dấu synced đúng lô gửi thành công', () async {
    for (var i = 0; i < 250; i++) {
      await addAttempt();
    }
    var n = 0;
    neon.dropRequest = (r) =>
        r.url.path.endsWith('/attempts') && ++n == 2; // lô thứ hai hỏng
    final r = await engine().syncOnce();
    expect(r.outcome, SyncOutcome.offline);
    expect(await unsynced('attempts'), 50);
    expect(neon.table('attempts'), hasLength(200));
    // children/daily_sets (gửi trước attempts) đã xong.
    expect(await unsynced('children'), 0);
    // Các bảng sau attempts chưa được đụng.
    expect(neon.posts('wallet_ledger'), isEmpty);
  });

  test(
    'mất mạng sau khi server nhận (mất phản hồi): gửi lại không trùng dòng',
    () async {
      for (var i = 0; i < 30; i++) {
        await addAttempt();
      }
      neon.loseResponse = (r) => r.url.path.endsWith('/attempts');
      final first = await engine().syncOnce();
      expect(first.outcome, SyncOutcome.offline);
      expect(
        await unsynced('attempts'),
        30,
      ); // chưa biết đã nhận → chưa đánh dấu
      expect(neon.table('attempts'), hasLength(30));

      neon.loseResponse = null;
      final second = await engine().syncOnce();
      expect(second.ok, isTrue);
      expect(neon.table('attempts'), hasLength(30)); // không trùng
      expect(neon.posts('attempts'), hasLength(2)); // cả lô gửi lại
      expect(await unsynced('attempts'), 0);
    },
  );

  test(
    'sửa dòng đã đồng bộ thì được gửi lại; dòng chưa đổi thì không',
    () async {
      await engine().syncOnce();
      expect(await unsynced('skill_progress'), 0);
      neon.log.clear();
      await engine().syncOnce();
      expect(neon.posts(), isEmpty);

      clock.advance(const Duration(minutes: 5));
      await db.skillProgressDao.setStrandRung(
        childId: childId,
        strand: Strand.logic,
        rung: 3,
      );
      expect(await unsynced('skill_progress'), 1);
      await engine().syncOnce();
      final rows = neon.posts('skill_progress').single.body as List;
      expect(rows, hasLength(1));
      expect((rows.single as Map)['rung'], 3);
      expect(
        neon
            .table('skill_progress')
            .values
            .where((r) => r['key'] == 'logic')
            .single['rung'],
        3,
      );
    },
  );

  test(
    'dòng cũ gửi lại không ghi đè dòng mới trên server (keep_newest)',
    () async {
      await engine().syncOnce();
      final id = (await db.skillProgressDao.getStrandProgress(
        childId,
        Strand.logic,
      ))!.id;
      neon.table('skill_progress')[id]!['updated_at'] =
          '2030-01-01T00:00:00+00:00';
      neon.table('skill_progress')[id]!['rung'] = 6;
      clock.advance(const Duration(minutes: 1));
      await db.skillProgressDao.setStrandRung(
        childId: childId,
        strand: Strand.logic,
        rung: 2,
      );
      await engine().syncOnce();
      expect(neon.table('skill_progress')[id]!['rung'], 6);
    },
  );

  test('mục sổ ôn tập đã xóa gửi lên với deleted_at', () async {
    final id = await db.reviewQueueDao.upsertEntry(
      childId: childId,
      formId: 'logic.age',
      rung: 2,
      dueDate: DateTime.utc(2026, 11, 29),
    );
    await engine().syncOnce();
    expect(neon.table('review_queue')[id]!['deleted_at'], isNull);
    expect(await unsynced('review_tombstones'), 0);

    await db.customStatement('DELETE FROM review_queue WHERE id = ?', [id]);
    expect(await unsynced('review_tombstones'), 1);
    await engine().syncOnce();
    final row = neon.table('review_queue')[id]!;
    expect(row['deleted_at'], isNotNull);
    expect(row['form_id'], 'logic.age');
    expect(row['rung'], 2);
    expect(await unsynced('review_tombstones'), 0);
  });

  test('settings: khóa chỉ trên máy và cài đặt chung không được gửi', () async {
    await db.settingsDao.setValue(
      childId: childId,
      key: 'kid_glasses',
      value: 'true',
    );
    await engine().syncOnce();
    final keys = [for (final r in neon.table('settings').values) r['key']];
    expect(keys, ['kid_glasses']);
    // value gửi dạng JSON, không phải chuỗi.
    expect(neon.table('settings').values.single['value'], true);
  });

  test('settings: server mới hơn thắng, máy mới hơn thì giữ và gửi lên; id khớp server', () async {
    await db.settingsDao.setValue(
      childId: childId,
      key: 'kid_glasses',
      value: 'false',
    );
    await db.settingsDao.setValue(
      childId: childId,
      key: 'kid_backpack',
      value: 'false',
    );
    final localGlasses = (await db.settingsDao.getRow(childId, 'kid_glasses'))!;
    // Máy: 15:00 giờ app (= 08:00 UTC thật). Server: glasses 10:00 UTC (mới hơn),
    // backpack 07:00 UTC (cũ hơn).
    neon.table('settings')['srv-glasses'] = {
      'id': 'srv-glasses',
      'child_id': childId,
      'key': 'kid_glasses',
      'value': true,
      'updated_at': '2026-11-28T10:00:00+00:00',
      'created_at': '2026-11-28T10:00:00+00:00',
    };
    neon.table('settings')['srv-backpack'] = {
      'id': 'srv-backpack',
      'child_id': childId,
      'key': 'kid_backpack',
      'value': true,
      'updated_at': '2026-11-28T07:00:00+00:00',
      'created_at': '2026-11-28T07:00:00+00:00',
    };
    final r = await engine().syncOnce();
    expect(r.ok, isTrue);
    expect(
      await db.settingsDao.getValue(childId: childId, key: 'kid_glasses'),
      'true',
    );
    expect(
      await db.settingsDao.getValue(childId: childId, key: 'kid_backpack'),
      'false',
    );
    expect(
      (await db.settingsDao.getRow(childId, 'kid_glasses'))!.id,
      'srv-glasses',
    );
    expect(
      (await db.settingsDao.getRow(childId, 'kid_backpack'))!.id,
      'srv-backpack',
    );
    expect(localGlasses.id, isNot('srv-glasses'));
    // Giá trị máy mới hơn đã được gửi lên đúng dòng server (không tạo dòng mới).
    expect(neon.table('settings'), hasLength(2));
    expect(neon.table('settings')['srv-backpack']!['value'], false);
    expect(neon.table('settings')['srv-glasses']!['value'], true);
    final childUnsynced = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM settings WHERE synced = 0 AND child_id IS NOT NULL',
        )
        .getSingle();
    expect(
      childUnsynced.read<int>('n'),
      0,
    ); // dòng chung không gửi nên vẫn synced=0
  });

  test(
    'settings chung của bố (mức thưởng) tải về và thắng giá trị mặc định',
    () async {
      neon.table('settings')['srv-rewards'] = {
        'id': 'srv-rewards',
        'child_id': null,
        'key': 'rewards',
        'value': {'easy': 9, 'medium': 9, 'hard': 9},
        'updated_at': '2020-01-01T00:00:00+00:00',
        'created_at': '2020-01-01T00:00:00+00:00',
      };
      await engine().syncOnce();
      final v =
          jsonDecode((await db.settingsDao.getValue(key: 'rewards'))!) as Map;
      expect(v['easy'], 9);
      expect(
        neon.table('settings').values.where((r) => r['key'] == 'rewards'),
        hasLength(1),
      );
    },
  );

  test('tải thư theo mốc: lần sau chỉ hỏi updated_at > mốc', () async {
    neon.table('messages')['m1'] = {
      'id': 'm1',
      'child_id': childId,
      'body': 'Bố khen con',
      'gift_xu': 50,
      'gift_gem': 0,
      'gift_item_id': null,
      'opened_at': null,
      'claimed_at': null,
      'created_at': '2026-11-28T08:00:00.123456+00:00',
      'updated_at': '2026-11-28T08:00:00.123456+00:00',
    };
    final r1 = await engine().syncOnce();
    expect(r1.pulledMessages, 1);
    final gets1 = neon.log
        .where((l) => l.method == 'GET' && l.table == 'messages')
        .toList();
    expect(gets1.single.query.containsKey('updated_at'), isFalse);
    expect(
      await db.settingsDao.getValue(key: messagesMarkKey),
      '"2026-11-28T08:00:00.123456+00:00"',
    );

    neon.log.clear();
    final r2 = await engine().syncOnce();
    expect(r2.pulledMessages, 0);
    final gets2 = neon.log
        .where((l) => l.method == 'GET' && l.table == 'messages')
        .toList();
    expect(
      gets2.single.query['updated_at'],
      'gt.2026-11-28T08:00:00.123456+00:00',
    );
    // Thư mới hơn mốc được tải.
    neon.table('messages')['m2'] = {
      ...neon.table('messages')['m1']!,
      'id': 'm2',
      'body': 'Thêm',
      'updated_at': '2026-11-28T09:00:00+00:00',
      'created_at': '2026-11-28T09:00:00+00:00',
    };
    expect((await engine().syncOnce()).pulledMessages, 1);
    final m = await db.select(db.messages).get();
    expect(m.map((x) => x.id).toSet(), {'m1', 'm2'});
  });

  test('thư đã mở trên máy được gửi lên (opened_at)', () async {
    neon.table('messages')['m1'] = {
      'id': 'm1',
      'child_id': childId,
      'body': 'Chào',
      'gift_xu': 0,
      'gift_gem': 0,
      'gift_item_id': null,
      'opened_at': null,
      'claimed_at': null,
      'created_at': '2026-11-28T08:00:00+00:00',
      'updated_at': '2026-11-28T08:00:00+00:00',
    };
    await engine().syncOnce();
    await db.customUpdate(
      'UPDATE messages SET opened_at = ?, updated_at = ?, synced = 0 WHERE id = ?',
      variables: [
        Variable.withInt(clock.now().millisecondsSinceEpoch ~/ 1000),
        Variable.withInt(clock.now().millisecondsSinceEpoch ~/ 1000),
        Variable.withString('m1'),
      ],
    );
    await engine().syncOnce();
    expect(
      neon.table('messages')['m1']!['opened_at'],
      '2026-11-28T08:00:00.000Z',
    );
    expect(await unsynced('messages'), 0);
  });

  test('inventory/pets/arena chỉ gửi khi bật cờ', () async {
    await db.inventoryDao.grant(
      childId: childId,
      itemId: 'girl_top_02',
      source: 'shop',
    );
    await db.petsDao.insertPet(
      childId: childId,
      species: 'dog',
      xp: 0,
      stageSeen: 'egg',
      hatched: false,
      active: true,
    );
    await engine().syncOnce();
    expect(neon.posts('inventory'), isEmpty);
    expect(neon.posts('pets'), isEmpty);
    await engine(extra: true).syncOnce();
    expect(neon.posts('inventory'), hasLength(1));
    expect(neon.posts('pets'), hasLength(1));
    expect(
      (neon.posts('inventory').single.body as List).single,
      containsPair('item_id', 'girl_top_02'),
    );
  });
}
