/// Migration schema v4 → v5 (T3-04/T3-06): thêm `messages` +
/// `review_tombstones`, trigger đồng bộ, và nới trigger append-only chỉ
/// cho phép đánh dấu `synced`. Mọi dữ liệu cũ phải còn nguyên.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/time/clock.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('timokid_v5_');
    file = File('${dir.path}/timokid.sqlite');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('v4 → v5: dữ liệu giữ nguyên, bé đầu tiên giữ mọi dữ liệu cũ', () async {
    var db = AppDatabase(executor: NativeDatabase(file));
    final childId = await db.ensureSeeded();
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: 42,
      reason: 'answer_first_try',
    );
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
    await db.settingsDao.setValue(
      childId: childId,
      key: 'kid_glasses',
      value: 'true',
    );
    await db.inventoryDao.grant(
      childId: childId,
      itemId: 'girl_top_02',
      source: 'shop',
    );
    // Hạ về dạng v4: bỏ bảng + trigger mới, trigger append-only kiểu cũ.
    await db.customStatement('DROP TABLE messages');
    await db.customStatement('DROP TABLE review_tombstones');
    for (final t in [
      'children',
      'skill_progress',
      'review_queue',
      'daily_sets',
      'settings',
      'inventory',
      'pets',
      'arena_attempts',
    ]) {
      await db.customStatement('DROP TRIGGER IF EXISTS ${t}_unsync');
    }
    await db.customStatement('DROP TRIGGER IF EXISTS review_queue_tombstone');
    await db.customStatement('DROP TRIGGER attempts_no_update');
    await db.customStatement(
      "CREATE TRIGGER attempts_no_update BEFORE UPDATE ON attempts BEGIN SELECT RAISE(ABORT, 'attempts is append-only'); END;",
    );
    await db.customStatement('PRAGMA user_version = 4');
    await db.close();

    db = AppDatabase(executor: NativeDatabase(file));
    addTearDown(db.close);

    final version = await db
        .customSelect('PRAGMA user_version')
        .map((r) => r.read<int>('user_version'))
        .getSingle();
    expect(version, 6);
    expect(await db.ensureSeeded(), childId);
    expect((await db.childrenDao.getFirstChild())!.id, childId);
    expect(
      await db.walletDao.balance(childId: childId, currency: Currency.xu),
      42,
    );
    expect(await db.attemptsDao.getAttemptsForChild(childId), hasLength(1));
    expect(
      await db.settingsDao.getValue(childId: childId, key: 'kid_glasses'),
      'true',
    );
    expect(await db.inventoryDao.has(childId, 'girl_top_02'), isTrue);
    // Dòng cũ chưa gửi → synced = false.
    final a = (await db.attemptsDao.getAttemptsForChild(childId)).single;
    expect(a.synced, isFalse);

    // Bảng mới dùng được.
    expect(await db.select(db.messages).get(), isEmpty);
    expect(await db.select(db.reviewTombstones).get(), isEmpty);

    // Trigger append-only mới: đánh dấu synced được, đổi cột khác thì không.
    await db.customStatement('UPDATE attempts SET synced = 1');
    await expectLater(
      db.customStatement('UPDATE attempts SET duration_ms = 1'),
      throwsA(anything),
    );
    await expectLater(
      db.customStatement('DELETE FROM attempts'),
      throwsA(anything),
    );
    await expectLater(
      db.customStatement('UPDATE wallet_ledger SET amount = 1'),
      throwsA(anything),
    );
    await db.customStatement('UPDATE wallet_ledger SET synced = 1');

    // Trigger đồng bộ mới: sửa dòng đã synced thì synced về false.
    await db.customStatement('UPDATE settings SET synced = 1');
    await db.settingsDao.setValue(
      childId: childId,
      key: 'kid_glasses',
      value: 'false',
    );
    expect(
      (await db.settingsDao.getRow(childId, 'kid_glasses'))!.synced,
      isFalse,
    );
  });

  test(
    'ensureSeeded: nhiều bé → trả bé đang chọn; bé đầu tiên là bé tạo sớm nhất',
    () async {
      final db = AppDatabase(
        executor: NativeDatabase(file),
        clock: FakeClock(DateTime.utc(2026, 11, 28)),
      );
      addTearDown(db.close);
      final first = await db.ensureSeeded();
      (db.clock as FakeClock).advance(const Duration(minutes: 1));
      final second = (await db.childrenDao.createChild(name: 'Bé hai')).id;
      expect(await db.ensureSeeded(), first);
      await db.setActiveChild(second);
      expect(await db.ensureSeeded(), second);
      // Trỏ tới bé không còn thì quay về bé đầu tiên.
      await db.setActiveChild('khong-co');
      expect(await db.ensureSeeded(), first);
    },
  );
}
