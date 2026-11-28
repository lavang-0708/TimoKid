/// Bản chính thức (không TEST_UNLOCKS) trên máy từng chạy bản thử:
/// xu/kim cương tặng thử không lên server và bị dọn khỏi máy đúng một lần;
/// mức thưởng và khóa kiểu trả lời bố đặt trên web admin được app áp dụng
/// sau khi đồng bộ; tên/lớp bố sửa trên web admin về lại app.
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart' hide AnswerType;
import 'package:timokid/features/questions/question.dart' show AnswerType;
import 'package:timokid/core/sync/session_store.dart';
import 'package:timokid/core/sync/sync_engine.dart';
import 'package:timokid/core/test_build.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/qa/test_grant_service.dart';
import 'package:timokid/features/rewards/reward_config.dart';

import '../../core/sync/fake_neon.dart';

void main() {
  late AppDatabase db;
  late FakeNeon neon;
  late String childId;
  late FakeClock clock;

  SyncEngine engine() => SyncEngine(
    db: db,
    client: neon.signedInClient(MemorySessionStore()),
    nowUtc: () => DateTime.utc(2026, 11, 28, 9),
  );

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 11, 28, 15));
    db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
    addTearDown(db.close);
    neon = FakeNeon();
    childId = await db.ensureSeeded();
  });

  Future<void> spend(int xu) => db.walletDao.addEntry(
    childId: childId,
    currency: Currency.xu,
    amount: -xu,
    reason: 'shop',
  );

  group('xu/kim cương của bản thử', () {
    test('không bao giờ được gửi lên server, kể cả bản thử', () async {
      await TestGrantService(db: db).grantIfNeeded(childId);
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.xu,
        amount: 7,
        reason: 'answer',
      );
      final r = await engine().syncOnce();
      expect(r.outcome, SyncOutcome.ok);
      final rows = neon.table('wallet_ledger').values.toList();
      expect(rows, hasLength(1));
      expect(rows.single['reason'], 'answer');
      // Dòng thử còn trên máy, chưa đánh dấu đã gửi (không bị gửi ở lượt sau).
      await engine().syncOnce();
      expect(neon.table('wallet_ledger'), hasLength(1));
    });

    test('dọn lần đầu: xóa dòng tặng, số dư về đúng phần thật', () async {
      await TestGrantService(db: db).grantIfNeeded(childId);
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.xu,
        amount: 40,
        reason: 'answer',
      );
      await spend(5000);
      expect(
        await db.walletDao.balance(childId: childId, currency: Currency.xu),
        5040,
      );
      final removed = await TestGrantCleanup(db: db).runIfNeeded();
      expect(removed, 2);
      // Đã tiêu quá phần thật: bù về 0 bằng dòng chỉ nằm trên máy.
      expect(
        await db.walletDao.balance(childId: childId, currency: Currency.xu),
        0,
      );
      expect(
        await db.walletDao.balance(childId: childId, currency: Currency.gem),
        0,
      );
      final compensating = (await db.walletDao.getEntries(childId))
          .where((e) => e.reason == 'test_cleanup')
          .toList();
      expect(compensating, hasLength(1));
      expect(compensating.single.synced, isTrue);
      // Dòng bù không lên server.
      await engine().syncOnce();
      expect(
        neon
            .table('wallet_ledger')
            .values
            .where((r) => r['reason'] == 'test_cleanup'),
        isEmpty,
      );
    });

    test('dọn đúng một lần và giữ nguyên số dư thật', () async {
      await TestGrantService(db: db).grantIfNeeded(childId);
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.xu,
        amount: 123,
        reason: 'answer',
      );
      await TestGrantCleanup(db: db).runIfNeeded();
      expect(
        await db.walletDao.balance(childId: childId, currency: Currency.xu),
        123,
      );
      expect(await TestGrantCleanup(db: db).runIfNeeded(), 0);
      // Sổ ví vẫn chặn xóa/sửa sau khi dọn (trigger đã tạo lại).
      await expectLater(
        db.customStatement('DELETE FROM wallet_ledger'),
        throwsA(isA<Object>()),
      );
      expect(
        await db.walletDao.balance(childId: childId, currency: Currency.xu),
        123,
      );
    });

    test('máy chưa từng chạy bản thử: không đụng gì, chỉ đặt cờ', () async {
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.xu,
        amount: 10,
        reason: 'answer',
      );
      expect(await TestGrantCleanup(db: db).runIfNeeded(), 0);
      expect(
        await db.walletDao.balance(childId: childId, currency: Currency.xu),
        10,
      );
      expect(
        await db.settingsDao.getValue(key: TestGrantCleanup.doneKey),
        'true',
      );
    });

    test('mọi lý do của bản thử nằm trong testWalletReasons', () {
      expect(
        testWalletReasons,
        containsAll(['test_grant', 'test_topup', 'test_cleanup']),
      );
    });
  });

  group('cài đặt của bố được áp dụng', () {
    Future<void> putServerSetting(String key, Object value) async {
      neon.table('settings')['srv-$key'] = {
        'id': 'srv-$key',
        'child_id': childId,
        'key': key,
        'value': value,
        'created_at': '2026-11-28T09:30:00+00:00',
        'updated_at': '2026-11-28T09:30:00+00:00',
      };
    }

    test('mức thưởng riêng của bé thay mức mặc định sau khi tải về', () async {
      expect((await RewardConfig.load(db)).easy, 2);
      await putServerSetting('rewards', {'easy': 4, 'stage_complete': 9});
      await engine().syncOnce();
      final c = await RewardConfig.load(db);
      expect(c.easy, 4);
      expect(c.stageCompleteXu, 9);
      // Khóa thiếu giữ mặc định.
      expect(c.medium, 3);
      expect(
        c.xuForQuestion(rung: 1, correctFirstTry: true, isReview: false),
        4,
      );
    });

    test('mức thưởng của bé khác không ảnh hưởng bé đang chơi', () async {
      final other = await db.childrenDao.createChild(name: 'Na');
      neon.table('settings')['x'] = {
        'id': 'x',
        'child_id': other.id,
        'key': 'rewards',
        'value': {'easy': 9},
        'created_at': '2026-11-28T09:30:00+00:00',
        'updated_at': '2026-11-28T09:30:00+00:00',
      };
      await engine().syncOnce();
      expect((await RewardConfig.load(db)).easy, 2);
      expect((await RewardConfig.load(db, childId: other.id)).easy, 9);
    });

    test('khóa kiểu trả lời: parse bỏ giá trị lạ', () {
      final m = DailySetService.parseAnswerTypeLock(
        jsonEncode({
          'logic': 'number',
          'arith': 'choice',
          'geo': null,
          'comb': 'xyz',
          'zzz': 'choice',
        }),
      );
      expect(m, {'logic': AnswerType.number, 'arith': AnswerType.choice});
      expect(DailySetService.parseAnswerTypeLock('hỏng{'), isEmpty);
      expect(DailySetService.parseAnswerTypeLock(null), isEmpty);
    });

    test('khóa kiểu trả lời áp vào chặng tự chọn và đề ngày', () async {
      await putServerSetting('answer_type_lock', {
        'arith': 'number',
        'geo': 'choice',
        'logic': null,
      });
      await engine().syncOnce();
      final svc = DailySetService(
        dailySetsDao: db.dailySetsDao,
        reviewQueueDao: db.reviewQueueDao,
        ladderService: LadderService(
          attemptsDao: db.attemptsDao,
          skillProgressDao: db.skillProgressDao,
        ),
        clock: clock,
        random: Random(7),
        settingsDao: db.settingsDao,
      );
      final arith = await svc.buildExtraStage(
        childId: childId,
        strand: Strand.arith,
      );
      // Dạng chỉ-trắc-nghiệm vẫn là trắc nghiệm; còn lại phải điền số.
      expect(arith.where((q) => q.answerType == 'number'), isNotEmpty);
      final geo = await svc.buildExtraStage(
        childId: childId,
        strand: Strand.geo,
      );
      expect(geo.every((q) => q.answerType == 'choice'), isTrue);
      final set = await svc.getOrCreateTodaySet(childId: childId);
      final qs = db.dailySetsDao.readQuestions(set);
      expect(
        qs
            .where((q) => q.strand == Strand.geo)
            .every((q) => q.answerType == 'choice'),
        isTrue,
      );
      expect(
        qs
            .where((q) => q.strand == Strand.arith)
            .any((q) => q.answerType == 'number'),
        isTrue,
      );
    });

    test('không có khóa: kiểu trả lời theo bậc như cũ', () async {
      final svc = DailySetService(
        dailySetsDao: db.dailySetsDao,
        reviewQueueDao: db.reviewQueueDao,
        ladderService: LadderService(
          attemptsDao: db.attemptsDao,
          skillProgressDao: db.skillProgressDao,
        ),
        clock: clock,
        random: Random(7),
        settingsDao: db.settingsDao,
      );
      final qs = await svc.buildExtraStage(
        childId: childId,
        strand: Strand.arith,
      );
      // Bậc 1 = trắc nghiệm; vài ô bậc 2 điền số.
      expect(qs.first.answerType, 'choice');
    });
  });

  group('tên và lớp sửa trên web admin', () {
    test('server mới hơn thì máy cập nhật và không gửi ngược lại', () async {
      final eng = engine();
      await eng.syncOnce(); // đẩy bé lên
      final row = neon.table('children')[childId]!;
      row['name'] = 'Bé Na';
      row['grade'] = 3;
      row['updated_at'] = '2026-11-29T01:00:00+00:00';
      await eng.syncOnce();
      final c = (await db.childrenDao.getChild(childId))!;
      expect(c.name, 'Bé Na');
      expect(c.grade, 3);
      expect(c.synced, isTrue);
    });

    test('dòng server cũ hơn thì giữ tên trên máy', () async {
      final eng = engine();
      await eng.syncOnce();
      final before = (await db.childrenDao.getChild(childId))!.name;
      neon.table('children')[childId]!['name'] = 'Tên cũ';
      await eng.syncOnce();
      expect((await db.childrenDao.getChild(childId))!.name, before);
    });
  });
}
