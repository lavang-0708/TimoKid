/// Migration schema v5 → v6 (lên tiếp v7) (T5-05): thêm bảng `photos` (album ảnh, chỉ
/// trên máy). Mọi dữ liệu cũ phải còn nguyên; bảng ảnh không có cột
/// `synced` và không có trigger đồng bộ.
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
    dir = Directory.systemTemp.createTempSync('timokid_v6_');
    file = File('${dir.path}/timokid.sqlite');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test(
    'v5 → v6 (lên tiếp v7): dữ liệu cũ giữ nguyên, bảng photos dùng được',
    () async {
      var db = AppDatabase(executor: NativeDatabase(file));
      final childId = await db.ensureSeeded();
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.xu,
        amount: 7,
        reason: 'answer_first_try',
      );
      await db.settingsDao.setValue(
        childId: childId,
        key: 'kid_glasses',
        value: 'true',
      );
      // Hạ về dạng v5: bỏ bảng photos.
      await db.customStatement('DROP TABLE photos');
      await db.customStatement('PRAGMA user_version = 5');
      await db.close();

      db = AppDatabase(executor: NativeDatabase(file));
      addTearDown(db.close);
      final version = await db
          .customSelect('PRAGMA user_version')
          .map((r) => r.read<int>('user_version'))
          .getSingle();
      expect(version, 7);
      expect(await db.ensureSeeded(), childId);
      expect(
        await db.walletDao.balance(childId: childId, currency: Currency.xu),
        7,
      );
      expect(
        await db.settingsDao.getValue(childId: childId, key: 'kid_glasses'),
        'true',
      );

      expect(await db.photosDao.listForChild(childId), isEmpty);
      final p = await db.photosDao.insertPhoto(
        childId: childId,
        fileName: 'a.png',
        width: 10,
        height: 5,
      );
      expect((await db.photosDao.listForChild(childId)).single.id, p.id);
      expect(await db.photosDao.countForChild(childId), 1);

      // Chỉ trên máy: không cột synced, không trigger đồng bộ.
      final cols = await db
          .customSelect('PRAGMA table_info(photos)')
          .map((r) => r.read<String>('name'))
          .get();
      expect(cols, isNot(contains('synced')));
      final triggers = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type='trigger'")
          .map((r) => r.read<String>('name'))
          .get();
      expect(triggers.where((t) => t.startsWith('photos')), isEmpty);
    },
  );

  test('DB mới tạo ở v7 có bảng photos', () async {
    final db = AppDatabase(executor: NativeDatabase(file));
    addTearDown(db.close);
    await db.ensureSeeded();
    expect(await db.select(db.photos).get(), isEmpty);
  });
}
