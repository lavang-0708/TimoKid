// Kiểm thử thật với Neon (không chạy trong CI). Tạo tài khoản rls-app-*@example.com.
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/sync/neon_client.dart';
import 'package:timokid/core/sync/session_store.dart';
import 'package:timokid/core/sync/sync_engine.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/mailbox/mailbox_service.dart';

void main() {
  test('đồng bộ thật với Neon', () async {
    final ctx = SecurityContext(withTrustedRoots: true)
      ..setTrustedCertificates(
        '${Platform.environment['HOME']}/.ccr/ca-bundle.crt',
      );
    final hc = HttpClient(context: ctx)
      ..findProxy = HttpClient.findProxyFromEnvironment;
    final client = NeonClient(
      client: IOClient(hc),
      store: MemorySessionStore(),
    );
    final email =
        'rls-app-${Random().nextInt(1 << 30).toRadixString(16)}@example.com';
    await client.signUp(
      email,
      'Smoke-${Random().nextInt(1 << 30)}x!',
      name: 'Smoke',
    );
    expect(await client.hasSession(), isTrue);
    await client.ensureFamily();

    final db = AppDatabase(
      executor: NativeDatabase.memory(),
      clock: SystemClock(),
    );
    final childId = await db.ensureSeeded();
    for (var i = 0; i < 3; i++) {
      await db.attemptsDao.recordAttempt(
        childId: childId,
        formId: 'logic.age',
        strand: Strand.logic,
        level: 1,
        rung: 1,
        answerType: AnswerType.choice,
        correctFirstTry: true,
        attemptsCount: 1,
        durationMs: 900,
      );
    }
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: 5,
      reason: 'answer_first_try',
    );
    await db.inventoryDao.grant(
      childId: childId,
      itemId: 'girl_top_08',
      source: 'shop',
    );
    await db.petsDao.insertPet(
      childId: childId,
      species: 'cat',
      xp: 30,
      active: true,
      hatched: true,
      stageSeen: 'newborn',
    );
    await db.arenaAttemptsDao.record(
      childId: childId,
      date: '2026-11-28',
      mode: 'heat',
      correctCount: 20,
      score: 80,
      medal: 'silver',
      durationSec: 1200,
      gemsAwarded: 3,
    );
    await db.settingsDao.setValue(
      childId: childId,
      key: 'kid_glasses',
      value: 'true',
    );

    final engine = SyncEngine(db: db, client: client);
    final r1 = await engine.syncOnce();
    // ignore: avoid_print
    print('sync1 ${r1.outcome} ${r1.pushed} ${r1.message}');
    expect(r1.ok, isTrue);
    for (final t in [
      'attempts',
      'wallet_ledger',
      'inventory',
      'pets',
      'arena_attempts',
      'settings',
    ]) {
      final res = await client.api(
        'GET',
        t,
        query: {'child_id': 'eq.$childId', 'select': 'id'},
      );
      // ignore: avoid_print
      print('$t ${(res.body as List).length}');
      expect((res.body as List), isNotEmpty);
    }
    // Gửi lại: không trùng.
    final r2 = await engine.syncOnce();
    expect(r2.ok, isTrue);
    final att = await client.api(
      'GET',
      'attempts',
      query: {'child_id': 'eq.$childId', 'select': 'id'},
    );
    expect((att.body as List).length, 3);

    // Bố gửi thư có quà.
    await client.api(
      'POST',
      'messages',
      body: {
        'child_id': childId,
        'body': 'Bố thương con!',
        'gift_xu': 50,
        'gift_gem': 2,
      },
      prefer: 'return=minimal',
    );
    final r3 = await engine.syncOnce();
    expect(r3.ok, isTrue);
    expect(r3.pulledMessages, 1);
    final mail = MailboxService(db: db, client: client);
    final msgs = await mail.list(childId);
    expect(msgs, hasLength(1));
    final before = await db.walletDao.balances(childId);
    final c1 = await mail.claim(msgs.first.id);
    final c2 = await mail.claim(msgs.first.id);
    await engine.syncOnce();
    final after = await db.walletDao.balances(childId);
    // ignore: avoid_print
    print('claim ${c1.status} ${c2.status} before=$before after=$after');
    expect(after['xu']! - before['xu']!, 50);
    expect(after['gem']! - (before['gem'] ?? 0), 2);
    final srv = await client.api(
      'GET',
      'messages',
      query: {'select': 'claimed_at,opened_at'},
    );
    // ignore: avoid_print
    print('server msg $srv ${srv.body}');
    await client.signOut();
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
