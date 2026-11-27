/// Hộp thư và quà (T3-06): mở quà gọi claim_message, cộng đúng một lần
/// (kể cả gọi lại, đồng bộ lại, lỗi mạng giữa chừng), thư mở được đánh
/// dấu đã đọc và gửi lên server.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/sync/neon_client.dart';
import 'package:timokid/core/sync/session_store.dart';
import 'package:timokid/core/sync/sync_engine.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/mailbox/mailbox_service.dart';

import '../../core/sync/fake_neon.dart';

void main() {
  late FakeNeon neon;
  late AppDatabase db;
  late String childId;
  late NeonClient client;
  late SyncEngine engine;
  late MailboxService mail;

  Map<String, Object?> msg(
    String id, {
    int xu = 0,
    int gem = 0,
    String? item,
  }) => {
    'id': id,
    'child_id': childId,
    'body': 'Bố thưởng con',
    'gift_xu': xu,
    'gift_gem': gem,
    'gift_item_id': item,
    'opened_at': null,
    'claimed_at': null,
    'created_at': '2026-11-28T08:00:00+00:00',
    'updated_at': '2026-11-28T08:00:00+00:00',
  };

  Future<int> xu() =>
      db.walletDao.balance(childId: childId, currency: Currency.xu);
  Future<int> gem() =>
      db.walletDao.balance(childId: childId, currency: Currency.gem);

  setUp(() async {
    neon = FakeNeon();
    db = AppDatabase(
      executor: NativeDatabase.memory(),
      clock: FakeClock(DateTime.utc(2026, 11, 28, 15)),
    );
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    client = neon.signedInClient(MemorySessionStore());
    engine = SyncEngine(db: db, client: client, extraTables: false);
    mail = MailboxService(db: db, client: client);
  });

  test('thư mới về: chưa đọc → đếm; mở thư → đã đọc', () async {
    neon.table('messages')['m1'] = msg('m1');
    await engine.syncOnce();
    expect(await mail.unreadCount(childId), 1);
    await mail.markRead('m1');
    expect(await mail.unreadCount(childId), 0);
    expect((await mail.get('m1'))!.synced, isFalse);
    await engine.syncOnce();
    expect(neon.table('messages')['m1']!['opened_at'], isNotNull);
    expect((await mail.get('m1'))!.synced, isTrue);
  });

  test('nhận quà xu + kim cương + món đồ: cộng đúng một lần', () async {
    neon.table('messages')['m1'] = msg(
      'm1',
      xu: 50,
      gem: 3,
      item: 'girl_top_02',
    );
    await engine.syncOnce();
    final r = await mail.claim('m1');
    expect(r.status, ClaimStatus.claimed);
    expect((r.xu, r.gems, r.itemId), (50, 3, 'girl_top_02'));
    expect(await xu(), 50);
    expect(await gem(), 3);
    expect(await db.inventoryDao.has(childId, 'girl_top_02'), isTrue);
    final entries = await db.walletDao.getEntries(childId);
    expect(
      entries.every((e) => e.refId == 'm1' && e.reason == mailGiftReason),
      isTrue,
    );
    expect((await mail.get('m1'))!.claimedAt, isNotNull);
    expect(await mail.unreadCount(childId), 0);
  });

  test('mở quà hai lần, rồi đồng bộ lại: chỉ cộng một lần', () async {
    neon.table('messages')['m1'] = msg('m1', xu: 50);
    await engine.syncOnce();
    await mail.claim('m1');
    expect((await mail.claim('m1')).status, ClaimStatus.alreadyClaimed);
    expect(await xu(), 50);
    // Đồng bộ lại (gửi ví, tải thư với claimed_at mới) không cộng thêm.
    await engine.syncOnce();
    await engine.syncOnce();
    expect(await xu(), 50);
    expect(
      neon.table('wallet_ledger').values.where((r) => r['ref_id'] == 'm1'),
      hasLength(1),
    );
    expect(neon.log.where((l) => l.table == 'rpc/claim_message'), hasLength(1));
  });

  test('server trả claimed=false (nhận ở máy khác) thì không cộng', () async {
    neon.table('messages')['m1'] = msg('m1', xu: 50);
    await engine.syncOnce();
    neon.table('messages')['m1']!['claimed_at'] = '2026-11-28T09:00:00+00:00';
    final r = await mail.claim('m1');
    expect(r.status, ClaimStatus.alreadyClaimed);
    expect(await xu(), 0);
  });

  test('claimed=true nhưng đã có dòng ví mang id thư (tắt app giữa chừng): không cộng đôi', () async {
    neon.table('messages')['m1'] = msg('m1', xu: 50);
    await engine.syncOnce();
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: 50,
      reason: mailGiftReason,
      refId: 'm1',
    );
    final r = await mail.claim('m1');
    expect(r.status, ClaimStatus.claimed);
    expect(await xu(), 50);
  });

  test('lỗi mạng khi mở quà: chưa cộng, thử lại được', () async {
    neon.table('messages')['m1'] = msg('m1', xu: 50);
    await engine.syncOnce();
    neon.dropRequest = (r) => r.url.path.endsWith('claim_message');
    final fail = await mail.claim('m1');
    expect(fail.status, ClaimStatus.failed);
    expect(await xu(), 0);
    expect((await mail.get('m1'))!.claimedAt, isNull);
    neon.dropRequest = null;
    expect((await mail.claim('m1')).status, ClaimStatus.claimed);
    expect(await xu(), 50);
  });

  test('thư không có quà: không gọi server', () async {
    neon.table('messages')['m1'] = msg('m1');
    await engine.syncOnce();
    expect((await mail.claim('m1')).status, ClaimStatus.noGift);
    expect(neon.log.where((l) => l.table == 'rpc/claim_message'), isEmpty);
  });
}
