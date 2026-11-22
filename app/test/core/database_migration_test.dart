/// Migration schema v1 → v2 (T2-06) và v2 → v3 (T2-10): thêm bảng
/// `inventory` rồi `arena_attempts`, giữ nguyên mọi dữ liệu cũ (bé, ví
/// xu, cài đặt) và trigger append-only.
///
/// Dựng file DB cũ bằng cách tạo DB hiện tại rồi bỏ các bảng mới hơn và
/// đặt `user_version` — đúng schema cũ (mỗi phiên bản chỉ thêm bảng).
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('timokid_migration_');
    file = File('${dir.path}/timokid.sqlite');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('mở DB v1 thì lên v3: có bảng inventory + arena_attempts, dữ liệu cũ còn nguyên', () async {
    // 1) Tạo DB, ghi dữ liệu, rồi hạ về dạng v1.
    var db = AppDatabase(executor: NativeDatabase(file));
    final childId = await db.ensureSeeded();
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: 37,
      reason: 'question_correct',
    );
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.gem,
      amount: 2,
      reason: 'daily_complete',
    );
    await db.settingsDao.setValue(
      childId: childId,
      key: 'kid_glasses',
      value: 'true',
    );
    await db.customStatement('DROP TABLE inventory');
    await db.customStatement('DROP TABLE arena_attempts');
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();

    // 2) Mở lại bằng app bản mới: migration chạy.
    db = AppDatabase(executor: NativeDatabase(file));
    addTearDown(db.close);

    final version = await db
        .customSelect('PRAGMA user_version')
        .map((r) => r.read<int>('user_version'))
        .getSingle();
    expect(version, 3);

    // Dữ liệu cũ còn nguyên.
    final child = await db.childrenDao.getFirstChild();
    expect(child!.id, childId);
    expect(await db.walletDao.balances(childId), {
      Currency.xu: 37,
      Currency.gem: 2,
    });
    expect(
      await db.settingsDao.getValue(childId: childId, key: 'kid_glasses'),
      'true',
    );
    expect(await db.walletDao.getEntries(childId), hasLength(2));

    // Bảng mới dùng được, rỗng lúc đầu, có unique (child_id, item_id).
    expect(await db.inventoryDao.getAll(childId), isEmpty);
    expect(
      await db.inventoryDao.grant(
        childId: childId,
        itemId: 'girl_top_02',
        source: 'grandfather',
      ),
      isTrue,
    );
    expect(
      await db.inventoryDao.grant(
        childId: childId,
        itemId: 'girl_top_02',
        source: 'shop',
      ),
      isFalse,
    );
    expect(await db.inventoryDao.getAll(childId), hasLength(1));

    // Bảng của v3 cũng được tạo khi nhảy từ v1.
    expect(await db.arenaAttemptsDao.getAll(childId), isEmpty);

    // Trigger append-only của ví vẫn còn sau migration.
    await expectLater(
      db.customStatement('DELETE FROM wallet_ledger'),
      throwsA(anything),
    );
  });

  test(
    'mở DB v2 thì lên v3: có bảng arena_attempts, dữ liệu cũ còn nguyên',
    () async {
      // 1) DB có đủ dữ liệu v2 (ví, kho đồ, cài đặt), rồi hạ về dạng v2.
      var db = AppDatabase(executor: NativeDatabase(file));
      final childId = await db.ensureSeeded();
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.xu,
        amount: 50,
        reason: 'question_correct',
      );
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.gem,
        amount: 4,
        reason: 'daily_complete',
      );
      await db.inventoryDao.grant(
        childId: childId,
        itemId: 'girl_top_02',
        source: 'shop',
      );
      await db.settingsDao.setValue(
        childId: childId,
        key: 'kid_glasses',
        value: 'true',
      );
      await db.customStatement('DROP TABLE arena_attempts');
      await db.customStatement('PRAGMA user_version = 2');
      await db.close();

      // 2) Mở lại bằng app bản mới: migration chạy.
      db = AppDatabase(executor: NativeDatabase(file));
      addTearDown(db.close);

      final version = await db
          .customSelect('PRAGMA user_version')
          .map((r) => r.read<int>('user_version'))
          .getSingle();
      expect(version, 3);

      // Dữ liệu cũ còn nguyên.
      expect((await db.childrenDao.getFirstChild())!.id, childId);
      expect(await db.walletDao.balances(childId), {
        Currency.xu: 50,
        Currency.gem: 4,
      });
      expect(await db.walletDao.getEntries(childId), hasLength(2));
      expect(await db.inventoryDao.has(childId, 'girl_top_02'), isTrue);
      expect(
        await db.settingsDao.getValue(childId: childId, key: 'kid_glasses'),
        'true',
      );

      // Bảng mới dùng được, rỗng lúc đầu.
      expect(await db.arenaAttemptsDao.getAll(childId), isEmpty);
      await db.arenaAttemptsDao.record(
        childId: childId,
        date: '2026-11-22',
        mode: 'heat',
        correctCount: 18,
        score: 72,
        medal: 'silver',
        durationSec: 3000,
        gemsAwarded: 3,
      );
      final best = await db.arenaAttemptsDao.best(childId);
      expect(best!.score, 72);
      expect(best.medal, 'silver');
      expect(await db.arenaAttemptsDao.countOnDate(childId, '2026-11-22'), 1);

      // Trigger append-only của ví vẫn còn sau migration.
      await expectLater(
        db.customStatement('DELETE FROM wallet_ledger'),
        throwsA(anything),
      );
    },
  );

  test('DB mới tạo thẳng ở v3 có bảng inventory + arena_attempts', () async {
    final db = AppDatabase(executor: NativeDatabase(file));
    addTearDown(db.close);
    final childId = await db.ensureSeeded();
    expect(await db.inventoryDao.getAll(childId), isEmpty);
    expect(await db.arenaAttemptsDao.getAll(childId), isEmpty);
    final version = await db
        .customSelect('PRAGMA user_version')
        .map((r) => r.read<int>('user_version'))
        .getSingle();
    expect(version, 3);
  });
}
