/// Unit test cho T1-04: Drift với 7 bảng trên cơ sở dữ liệu trong bộ nhớ,
/// cộng một test tắt/mở lại app với DB file thật trong thư mục tạm.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/time/clock.dart';

AppDatabase openMemoryDb({Clock? clock}) => AppDatabase(
  executor: NativeDatabase.memory(),
  clock: clock ?? const SystemClock(),
);

/// 25 câu mẫu cho một đề ngày: 5 chặng x 5 câu, đủ 5 mảng.
List<DailySetQuestion> sampleQuestions() {
  final questions = <DailySetQuestion>[];
  for (var stage = 0; stage < 5; stage++) {
    final strand = Strand.all[stage];
    for (var i = 0; i < 5; i++) {
      questions.add(
        DailySetQuestion(
          formId: '$strand.sample',
          strand: strand,
          level: 1 + (i % 3),
          rung: 1 + (i % 6),
          answerType: i.isEven ? AnswerType.choice : AnswerType.number,
          seed: stage * 10 + i,
        ),
      );
    }
  }
  return questions;
}

void main() {
  group('Clock', () {
    test('FakeClock trả ngày YYYY-MM-DD theo giờ đã đặt', () {
      final clock = FakeClock(DateTime(2026, 11, 17, 23, 30));
      expect(clock.today(), '2026-11-17');
      clock.advance(const Duration(hours: 1));
      expect(clock.today(), '2026-11-18');
    });

    test('SystemClock trả ngày hôm nay theo giờ Việt Nam (UTC+7)', () {
      final expected = DateTime.now().toUtc().add(vietnamUtcOffset);
      final y = expected.year.toString().padLeft(4, '0');
      final m = expected.month.toString().padLeft(2, '0');
      final d = expected.day.toString().padLeft(2, '0');
      expect(const SystemClock().today(), '$y-$m-$d');
    });
  });

  group('ensureSeeded', () {
    test('lần đầu mở app tạo bé mặc định lớp 2, bậc 1 cả 5 mảng', () async {
      final db = openMemoryDb();
      addTearDown(db.close);

      final childId = await db.ensureSeeded();

      final child = await db.childrenDao.getChild(childId);
      expect(child, isNotNull);
      expect(child!.name, 'Bé');
      expect(child.grade, 2);
      expect(child.familyId, isNull);

      final strands = await db.skillProgressDao.getAllStrandProgress(childId);
      expect(strands.map((s) => s.key).toSet(), Strand.all.toSet());
      expect(strands.map((s) => s.rung).toSet(), {1});

      final rewards = await db.settingsDao.getValue(key: 'rewards');
      expect(jsonDecode(rewards!)['easy'], 2);
    });

    test('gọi lại nhiều lần không tạo trùng', () async {
      final db = openMemoryDb();
      addTearDown(db.close);

      final first = await db.ensureSeeded();
      final second = await db.ensureSeeded();
      expect(second, first);

      expect((await db.childrenDao.getAllChildren()).length, 1);
      expect((await db.skillProgressDao.getAllStrandProgress(first)).length, 5);
      expect((await db.settingsDao.getAllSettings()).length, 3);
    });

    test('hai lần gọi chồng nhau không tạo trùng settings', () async {
      // Hồi quy T1-13: hai lần gọi chồng nhau (Future.wait) đều thấy
      // settings chưa có rồi cùng chèn, tạo trùng khóa chung và
      // `getValue` ném `Bad state: Too many elements` (cột `child_id`
      // nullable nên unique của SQLite không bắt được trùng).
      final db = openMemoryDb();
      addTearDown(db.close);

      final results = await Future.wait([db.ensureSeeded(), db.ensureSeeded()]);
      expect(results[0], results[1]);

      expect((await db.childrenDao.getAllChildren()).length, 1);
      expect(
        (await db.skillProgressDao.getAllStrandProgress(results[0])).length,
        5,
      );
      expect((await db.settingsDao.getAllSettings()).length, 3);
      // Đọc lại được, không ném lỗi.
      expect(await db.settingsDao.getValue(key: 'rewards'), isNotNull);
    });
  });

  group('children', () {
    test('tạo, đọc, đổi tên/lớp, xóa', () async {
      final db = openMemoryDb();
      addTearDown(db.close);

      final child = await db.childrenDao.createChild(name: 'An', grade: 2);
      expect(child.name, 'An');

      await db.childrenDao.updateChild(child.id, name: 'Bình', grade: 3);
      final updated = await db.childrenDao.getChild(child.id);
      expect(updated!.name, 'Bình');
      expect(updated.grade, 3);

      await db.childrenDao.deleteChild(child.id);
      expect(await db.childrenDao.getChild(child.id), isNull);
    });
  });

  group('attempts', () {
    test('ghi và đọc lượt trả lời, mới nhất trước', () async {
      final db = openMemoryDb(clock: FakeClock(DateTime(2026, 11, 17, 8, 0)));
      addTearDown(db.close);
      final childId = await db.ensureSeeded();

      await db.attemptsDao.recordAttempt(
        childId: childId,
        formId: 'logic.balance',
        strand: Strand.logic,
        level: 1,
        rung: 1,
        answerType: AnswerType.choice,
        correctFirstTry: true,
        attemptsCount: 1,
        durationMs: 12000,
      );
      // Cho đồng hồ trôi 1 phút để lượt sau mới hơn lượt trước
      // (cả hai lượt cùng một mốc thời gian thì thứ tự sắp xếp không chắc).
      (db.clock as FakeClock).advance(const Duration(minutes: 1));
      await db.attemptsDao.recordAttempt(
        childId: childId,
        formId: 'arith.plus',
        strand: Strand.arith,
        level: 2,
        rung: 3,
        answerType: AnswerType.number,
        correctFirstTry: false,
        attemptsCount: 2,
        durationMs: 45000,
        isReview: true,
      );

      final all = await db.attemptsDao.getAttemptsForChild(childId);
      expect(all.length, 2);
      expect(all.first.formId, 'arith.plus');
      expect(all.first.correctFirstTry, isFalse);
      expect(all.first.attemptsCount, 2);
      expect(all.first.isReview, isTrue);

      final logicOnly = await db.attemptsDao.getRecentStrandAttempts(
        childId: childId,
        strand: Strand.logic,
      );
      expect(logicOnly.length, 1);
      expect(logicOnly.first.formId, 'logic.balance');
    });

    test('trigger chặn sửa và xóa (append-only)', () async {
      final db = openMemoryDb();
      addTearDown(db.close);
      final childId = await db.ensureSeeded();

      final id = await db.attemptsDao.recordAttempt(
        childId: childId,
        formId: 'logic.balance',
        strand: Strand.logic,
        level: 1,
        rung: 1,
        answerType: AnswerType.choice,
        correctFirstTry: true,
        attemptsCount: 1,
        durationMs: 1000,
      );

      await expectLater(
        db.customUpdate(
          'UPDATE attempts SET duration_ms = 999 WHERE id = ?',
          variables: [Variable.withString(id)],
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        db.customUpdate(
          'DELETE FROM attempts WHERE id = ?',
          variables: [Variable.withString(id)],
        ),
        throwsA(isA<Exception>()),
      );

      // Dòng vẫn còn nguyên, không bị sửa.
      final kept = (await db.attemptsDao.getAttemptsForChild(childId)).single;
      expect(kept.id, id);
      expect(kept.durationMs, 1000);
    });
  });

  group('skill_progress', () {
    test('đặt bậc theo mảng: upsert, không trùng dòng', () async {
      final db = openMemoryDb();
      addTearDown(db.close);
      final childId = await db.ensureSeeded();

      await db.skillProgressDao.setStrandRung(
        childId: childId,
        strand: Strand.geo,
        rung: 3,
      );
      await db.skillProgressDao.setStrandRung(
        childId: childId,
        strand: Strand.geo,
        rung: 4,
      );

      final rows = await db.skillProgressDao.getAllStrandProgress(childId);
      expect(rows.where((r) => r.key == Strand.geo).length, 1);
      expect(
        (await db.skillProgressDao.getStrandProgress(
          childId,
          Strand.geo,
        ))!.rung,
        4,
      );
    });

    test('đánh dấu thành thạo theo dạng bài', () async {
      final db = openMemoryDb();
      addTearDown(db.close);
      final childId = await db.ensureSeeded();

      await db.skillProgressDao.setFormMastered(
        childId: childId,
        formId: 'logic.balance',
        mastered: true,
      );
      await db.skillProgressDao.setFormMastered(
        childId: childId,
        formId: 'geo.square',
        mastered: false,
      );

      final mastered = await db.skillProgressDao.getMasteredForms(childId);
      expect(mastered.map((r) => r.key), ['logic.balance']);
      expect(mastered.single.masteredAt, isNotNull);
    });
  });

  group('review_queue', () {
    test(
      'thêm, trùng dạng thì cập nhật không trùng mục, hỏi lại theo hạn',
      () async {
        final db = openMemoryDb();
        addTearDown(db.close);
        final childId = await db.ensureSeeded();
        final now = DateTime(2026, 11, 17, 8, 0);

        final id = await db.reviewQueueDao.upsertEntry(
          childId: childId,
          formId: 'logic.balance',
          rung: 2,
          dueDate: now.add(const Duration(days: 1)),
        );
        final again = await db.reviewQueueDao.upsertEntry(
          childId: childId,
          formId: 'logic.balance',
          rung: 3,
          dueDate: now.add(const Duration(days: 1)),
        );
        expect(again, id);
        expect((await db.reviewQueueDao.getAllEntries(childId)).length, 1);

        final entry = await db.reviewQueueDao.getEntry(
          childId,
          'logic.balance',
        );
        expect(entry!.rung, 3);
        expect(entry.correctStreak, 0);

        // Chưa đến hạn: không có mục nào.
        expect(
          (await db.reviewQueueDao.getDueEntries(
            childId: childId,
            now: now,
          )).length,
          0,
        );
        // Qua 1 ngày: đến hạn.
        expect(
          (await db.reviewQueueDao.getDueEntries(
            childId: childId,
            now: now.add(const Duration(days: 1, minutes: 1)),
          )).length,
          1,
        );

        await db.reviewQueueDao.updateStreakAndDue(
          id: id,
          correctStreak: 1,
          dueDate: now.add(const Duration(days: 3)),
        );
        expect(
          (await db.reviewQueueDao.getEntry(
            childId,
            'logic.balance',
          ))!.correctStreak,
          1,
        );

        await db.reviewQueueDao.removeEntry(id);
        expect(
          await db.reviewQueueDao.getEntry(childId, 'logic.balance'),
          isNull,
        );
      },
    );
  });

  group('daily_sets', () {
    test('tạo đề ngày, đọc lại đúng 25 câu và trạng thái chặng', () async {
      final db = openMemoryDb();
      addTearDown(db.close);
      final childId = await db.ensureSeeded();

      final questions = sampleQuestions();
      final id = await db.dailySetsDao.createDailySet(
        childId: childId,
        date: '2026-11-17',
        questions: questions,
      );

      final set = await db.dailySetsDao.getDailySet(childId, '2026-11-17');
      expect(set, isNotNull);
      expect(set!.id, id);
      expect(db.dailySetsDao.readQuestions(set).length, 25);
      expect(db.dailySetsDao.readQuestions(set).first.formId, 'logic.sample');
      expect(db.dailySetsDao.readQuestions(set).last.strand, Strand.comb);
      expect(
        db.dailySetsDao.readStageStatus(set),
        List.filled(5, StageStatus.notStarted),
      );
      expect(set.completed, isFalse);

      await db.dailySetsDao.updateStageStatus(
        id: id,
        stageIndex: 0,
        status: StageStatus.done,
      );
      final after = await db.dailySetsDao.getDailySet(childId, '2026-11-17');
      expect(db.dailySetsDao.readStageStatus(after!).first, StageStatus.done);

      await db.dailySetsDao.markCompleted(id);
      final done = await db.dailySetsDao.getDailySet(childId, '2026-11-17');
      expect(done!.completed, isTrue);
      expect(done.completedAt, isNotNull);
    });
  });

  group('wallet_ledger', () {
    test('số dư = tổng ledger theo từng loại tiền', () async {
      final db = openMemoryDb();
      addTearDown(db.close);
      final childId = await db.ensureSeeded();

      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.xu,
        amount: 3,
        reason: 'answer_first_try',
      );
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.xu,
        amount: 5,
        reason: 'stage_complete',
      );
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.xu,
        amount: -2,
        reason: 'purchase',
      );
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.gem,
        amount: 1,
        reason: 'daily_complete',
      );

      expect(
        await db.walletDao.balance(childId: childId, currency: Currency.xu),
        6,
      );
      expect(
        await db.walletDao.balance(childId: childId, currency: Currency.gem),
        1,
      );
      expect(await db.walletDao.balances(childId), {
        Currency.xu: 6,
        Currency.gem: 1,
      });
      expect((await db.walletDao.getEntries(childId)).length, 4);
    });

    test('trigger chặn sửa và xóa (append-only)', () async {
      final db = openMemoryDb();
      addTearDown(db.close);
      final childId = await db.ensureSeeded();

      final id = await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.xu,
        amount: 10,
        reason: 'answer_first_try',
      );

      await expectLater(
        db.customUpdate(
          'UPDATE wallet_ledger SET amount = 999 WHERE id = ?',
          variables: [Variable.withString(id)],
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        db.customUpdate(
          'DELETE FROM wallet_ledger WHERE id = ?',
          variables: [Variable.withString(id)],
        ),
        throwsA(isA<Exception>()),
      );

      expect(
        await db.walletDao.balance(childId: childId, currency: Currency.xu),
        10,
      );
    });
  });

  group('settings', () {
    test('cài đặt chung, cài đặt riêng bé, và giá trị hiệu lực', () async {
      final db = openMemoryDb();
      addTearDown(db.close);
      final childId = await db.ensureSeeded();

      await db.settingsDao.setValue(key: 'sound_enabled', value: 'true');
      await db.settingsDao.setValue(
        childId: childId,
        key: 'sound_enabled',
        value: 'false',
      );
      // Đặt lại cùng khóa chung: cập nhật, không tạo trùng.
      await db.settingsDao.setValue(key: 'sound_enabled', value: 'true');

      expect(await db.settingsDao.getValue(key: 'sound_enabled'), 'true');
      expect(
        await db.settingsDao.getValue(childId: childId, key: 'sound_enabled'),
        'false',
      );
      // Bé có cài đặt riêng thì lấy riêng, không thì lấy chung.
      expect(
        await db.settingsDao.getEffectiveValue(
          childId: childId,
          key: 'sound_enabled',
        ),
        'false',
      );
      expect(
        await db.settingsDao.getEffectiveValue(
          childId: childId,
          key: 'rewards',
        ),
        contains('"easy":2'),
      );
      expect((await db.settingsDao.getAllSettings()).length, 3);

      await db.settingsDao.deleteSetting(key: 'sound_enabled');
      expect(await db.settingsDao.getValue(key: 'sound_enabled'), isNull);
    });
  });

  group('tắt/mở lại app', () {
    test('dữ liệu còn nguyên sau khi đóng và mở lại DB file', () async {
      final dir = await Directory.systemTemp.createTemp('timokid_db_test');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/timokid.sqlite';

      final first = AppDatabase(executor: NativeDatabase(File(path)));
      final childId = await first.ensureSeeded();
      await first.attemptsDao.recordAttempt(
        childId: childId,
        formId: 'logic.balance',
        strand: Strand.logic,
        level: 1,
        rung: 1,
        answerType: AnswerType.choice,
        correctFirstTry: true,
        attemptsCount: 1,
        durationMs: 5000,
      );
      await first.walletDao.addEntry(
        childId: childId,
        currency: Currency.xu,
        amount: 3,
        reason: 'answer_first_try',
      );
      await first.close();

      // Mở lại cùng file: dữ liệu phải còn nguyên.
      final second = AppDatabase(executor: NativeDatabase(File(path)));
      addTearDown(second.close);

      final child = await second.childrenDao.getChild(childId);
      expect(child, isNotNull);
      expect(child!.grade, 2);
      expect((await second.attemptsDao.getAttemptsForChild(childId)).length, 1);
      expect(
        await second.walletDao.balance(childId: childId, currency: Currency.xu),
        3,
      );
      // Hạt giống không chạy lại gây trùng khi mở lại.
      await second.ensureSeeded();
      expect((await second.childrenDao.getAllChildren()).length, 1);
    });
  });
}
