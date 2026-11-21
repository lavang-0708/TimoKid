/// Migration schema v1 → v2 (T2-06): thêm bảng `inventory`, giữ nguyên
/// mọi dữ liệu cũ (bé, ví xu, cài đặt) và trigger append-only.
///
/// Dựng file DB "v1" bằng cách tạo DB hiện tại rồi bỏ bảng `inventory`
/// và đặt `user_version = 1` — đúng schema v1 (v2 chỉ thêm bảng đó).
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

  test(
    'mở DB v1 thì lên v2: có bảng inventory, dữ liệu cũ còn nguyên',
    () async {
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
      await db.customStatement('PRAGMA user_version = 1');
      await db.close();

      // 2) Mở lại bằng app bản mới: migration chạy.
      db = AppDatabase(executor: NativeDatabase(file));
      addTearDown(db.close);

      final version = await db
          .customSelect('PRAGMA user_version')
          .map((r) => r.read<int>('user_version'))
          .getSingle();
      expect(version, 2);

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

      // Trigger append-only của ví vẫn còn sau migration.
      await expectLater(
        db.customStatement('DELETE FROM wallet_ledger'),
        throwsA(anything),
      );
    },
  );

  test('DB mới tạo thẳng ở v2 có bảng inventory', () async {
    final db = AppDatabase(executor: NativeDatabase(file));
    addTearDown(db.close);
    final childId = await db.ensureSeeded();
    expect(await db.inventoryDao.getAll(childId), isEmpty);
    final version = await db
        .customSelect('PRAGMA user_version')
        .map((r) => r.read<int>('user_version'))
        .getSingle();
    expect(version, 2);
  });
}
