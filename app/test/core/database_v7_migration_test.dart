/// Migration schema v6 → v7 (T5-03): thêm bảng `custom_questions` (câu tự
/// soạn tải về từ server, chỉ tải về). Mọi dữ liệu cũ phải còn nguyên.
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('timokid_v7_');
    file = File('${dir.path}/timokid.sqlite');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('v6 → v7: dữ liệu cũ (kể cả ảnh) giữ nguyên, bảng custom_questions dùng được', () async {
    var db = AppDatabase(executor: NativeDatabase(file));
    final childId = await db.ensureSeeded();
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: 11,
      reason: 'answer_first_try',
    );
    await db.photosDao.insertPhoto(
      childId: childId,
      fileName: 'p.png',
      width: 2,
      height: 1,
    );
    // Hạ về dạng v6: bỏ bảng custom_questions.
    await db.customStatement('DROP TABLE custom_questions');
    await db.customStatement('PRAGMA user_version = 6');
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
      11,
    );
    expect(await db.photosDao.countForChild(childId), 1);

    expect(await db.customQuestionsDao.getAll(), isEmpty);
    await db.customQuestionsDao.upsertFromServer(
      CustomQuestionsCompanion.insert(
        id: 'q1',
        strand: 'arith',
        rung: 2,
        textVi: 'Hai cộng ba?',
        answer: '5',
        createdAt: DateTime(2027),
        updatedAt: DateTime(2027),
      ),
    );
    final row = (await db.customQuestionsDao.getAll()).single;
    expect(row.childId, isNull);
    expect(row.grade, 2);
    expect(row.active, isTrue);
    expect(row.explanationVi, '');

    // Dòng cũ hơn không ghi đè dòng mới hơn.
    await db.customQuestionsDao.upsertFromServer(
      CustomQuestionsCompanion.insert(
        id: 'q1',
        strand: 'arith',
        rung: 2,
        textVi: 'Cũ',
        answer: '5',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        active: const Value(false),
      ),
    );
    expect((await db.customQuestionsDao.getById('q1'))!.textVi, 'Hai cộng ba?');

    // Chỉ tải về: không cột synced, không trigger đồng bộ.
    final cols = await db
        .customSelect('PRAGMA table_info(custom_questions)')
        .map((r) => r.read<String>('name'))
        .get();
    expect(cols, isNot(contains('synced')));
  });

  test('DB mới tạo ở v7 có bảng custom_questions', () async {
    final db = AppDatabase(executor: NativeDatabase(file));
    addTearDown(db.close);
    await db.ensureSeeded();
    expect(await db.select(db.customQuestions).get(), isEmpty);
  });
}
