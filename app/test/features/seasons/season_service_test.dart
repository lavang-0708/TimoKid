/// Test mùa (T5-02): ngày bắt đầu/kết thúc theo giờ Việt Nam, ngoài mùa
/// không đổi gì, món thuộc mùa + giảm giá, mua đúng giá giảm, xu đề ngày
/// +50% trong mùa. Đồng hồ giả với ngày cố định.
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart' hide AnswerType;
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/room/room_themes.dart';
import 'package:timokid/features/seasons/season_config.dart';
import 'package:timokid/features/seasons/season_service.dart';
import 'package:timokid/features/shop/shop_catalog.dart';
import 'package:timokid/features/shop/shop_service.dart';

import '../building/play_stage_helper.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUp(() => SeasonService.debugDisabled = false);
  tearDown(() {
    SeasonService.debugDisabled = true;
    SeasonService.forcedSeasonId = null;
  });

  String? at(String date) => SeasonService.activeOn(date)?.id;

  group('ngày của mùa (giờ Việt Nam)', () {
    test('Tết 2027: 30/1 đến 12/2, cả hai đầu đều tính', () {
      expect(at('2027-01-29'), isNull);
      expect(at('2027-01-30'), 'tet');
      expect(at('2027-02-06'), 'tet'); // mùng 1
      expect(at('2027-02-12'), 'tet');
      expect(at('2027-02-13'), isNull);
    });

    test('Tết 2028–2030 ôm quanh mùng 1 đúng 14 ngày', () {
      // Mùng 1: 26/1/2028, 13/2/2029, 2/2/2030.
      for (final (tet, start, end) in [
        ('2028-01-26', '2028-01-19', '2028-02-01'),
        ('2029-02-13', '2029-02-06', '2029-02-19'),
        ('2030-02-02', '2030-01-26', '2030-02-08'),
      ]) {
        expect(at(tet), 'tet', reason: tet);
        expect(at(start), 'tet', reason: start);
        expect(at(end), 'tet', reason: end);
        final before = DateTime.parse(start).subtract(const Duration(days: 1));
        final after = DateTime.parse(end).add(const Duration(days: 1));
        String d(DateTime t) => t.toIso8601String().substring(0, 10);
        expect(at(d(before)), isNull, reason: d(before));
        expect(at(d(after)), isNull, reason: d(after));
      }
    });

    test('mỗi mùa Tết dài đúng 14 ngày', () {
      for (final w in SeasonConfig.tet.windows) {
        final days =
            DateTime.parse(w.end).difference(DateTime.parse(w.start)).inDays +
            1;
        expect(days, 14, reason: w.start);
      }
    });

    test(
      'Trung thu 2027–2030: rằm 15/9/2027, 3/10/2028, 22/9/2029, 12/9/2030',
      () {
        for (final ram in [
          '2027-09-15',
          '2028-10-03',
          '2029-09-22',
          '2030-09-12',
        ]) {
          expect(at(ram), 'trung_thu', reason: ram);
        }
        expect(at('2027-09-07'), isNull);
        expect(at('2027-09-08'), 'trung_thu');
        expect(at('2027-09-16'), 'trung_thu');
        expect(at('2027-09-17'), isNull);
      },
    );

    test('Giáng sinh 15/12 đến 31/12 mỗi năm', () {
      for (final y in [2026, 2027, 2028, 2029, 2030, 2031]) {
        expect(at('$y-12-14'), isNull);
        expect(at('$y-12-15'), 'giang_sinh');
        expect(at('$y-12-25'), 'giang_sinh');
        expect(at('$y-12-31'), 'giang_sinh');
        expect(at('${y + 1}-01-01'), isNull);
      }
    });

    test('ngoài mùa không có mùa nào', () {
      for (final d in [
        '2026-11-28',
        '2027-05-01',
        '2027-08-10',
        '2028-06-15',
      ]) {
        expect(at(d), isNull, reason: d);
      }
    });

    test('Clock: dùng ngày giờ Việt Nam, cuối ngày 12/2 vẫn trong mùa', () {
      final late = FakeClock(DateTime(2027, 2, 12, 23, 59));
      final next = FakeClock(DateTime(2027, 2, 13, 0, 1));
      expect(SeasonService.active(late)?.id, 'tet');
      expect(SeasonService.active(next), isNull);
    });

    test('QA ép mùa thắng ngày thật; bỏ ép thì về theo ngày', () {
      final clock = FakeClock(DateTime(2027, 5, 1));
      expect(SeasonService.active(clock), isNull);
      SeasonService.forcedSeasonId = 'trung_thu';
      expect(SeasonService.active(clock)?.id, 'trung_thu');
      SeasonService.forcedSeasonId = null;
      expect(SeasonService.active(clock), isNull);
    });

    test('cờ debugDisabled tắt mùa (cho golden)', () {
      SeasonService.debugDisabled = true;
      expect(SeasonService.active(FakeClock(DateTime(2027, 2, 6))), isNull);
    });
  });

  group('món thuộc mùa + giá', () {
    test('Tết gồm bộ đồ 09 của cả hai dáng và phòng Tết, không gì khác', () {
      for (final g in ['girl', 'boy']) {
        final items = shopItemsFor(g);
        final tet = SeasonService.itemsOf(items, SeasonConfig.tet);
        expect(tet, isNotEmpty);
        for (final i in tet) {
          expect(i.seasonId, 'tet');
          final isOutfit9 = i.kind == ShopItemKind.outfit && i.outfit == 9;
          expect(isOutfit9 || i.roomThemeId == 'tet', isTrue, reason: i.id);
        }
        expect(tet.where((i) => i.outfit == 9), hasLength(1));
        expect(
          tet.where((i) => i.kind == ShopItemKind.roomTheme),
          hasLength(1),
        );
        // Đồ khác không bị gắn nhãn.
        final other = SeasonService.decorateAll(
          items,
          SeasonConfig.tet,
        ).where((i) => !tet.any((t) => t.id == i.id));
        expect(
          other.every((i) => i.seasonId == null && i.listPrice == null),
          isTrue,
        );
      }
    });

    test('giảm 20%: bộ phòng Tết 2000 xu → 1600, món lẻ làm tròn gần nhất', () {
      final room = shopItemById('girl', roomThemeItemId('tet'))!;
      final d = SeasonService.decorate(room, SeasonConfig.tet);
      expect(d.priceXu, 1600);
      expect(d.listPrice, 2000);
      final piece = shopItemsFor('girl').firstWhere(
        (i) => i.kind == ShopItemKind.roomThemeItem && i.roomThemeId == 'tet',
      );
      final dp = SeasonService.decorate(piece, SeasonConfig.tet);
      expect(dp.priceXu, (piece.priceXu * 0.8).round());
      expect(SeasonService.discounted(450, 20), 360);
      expect(SeasonService.discounted(0, 20), 0);
    });

    test('Trung thu / Giáng sinh chưa có món riêng nhưng không lỗi', () {
      final items = shopItemsFor('girl');
      expect(SeasonService.itemsOf(items, SeasonConfig.trungThu), isEmpty);
      expect(SeasonService.itemsOf(items, SeasonConfig.giangSinh), isEmpty);
      expect(SeasonService.decorateAll(items, null), same(items));
    });
  });

  group('mua trong mùa', () {
    late FakeClock clock;
    late AppDatabase db;
    late String childId;

    setUp(() async {
      clock = FakeClock(DateTime(2027, 5, 1, 9));
      db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
      addTearDown(db.close);
      childId = await db.ensureSeeded();
      await OnboardingService(db: db).completeOnboarding(
        childId: childId,
        profile: CharacterProfile.defaults().copyWith(
          gender: 'girl',
          dress: 'girl_top_01',
          name: 'An',
        ),
        eggSpecies: 'dog',
      );
    });

    Future<void> giveXu(int xu) => db.walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: xu,
      reason: 'test',
    );

    test('ngoài mùa: bộ đồ 09 (450 xu) mua giá thường', () async {
      await giveXu(500);
      final r = await ShopService(db: db)
          .buy(childId: childId, gender: 'girl', itemId: 'girl_top_09');
      expect(r, BuyResult.bought);
      expect(await ShopService(db: db).xuBalance(childId), 50);
    });

    test(
      'trong mùa Tết: cùng bộ đồ giá 360 xu, vẫn mua được ngoài mùa',
      () async {
        clock.set(DateTime(2027, 2, 6, 10));
        await giveXu(400);
        final svc = ShopService(db: db);
        expect(
          await svc.buy(
            childId: childId,
            gender: 'girl',
            itemId: 'girl_top_09',
          ),
          BuyResult.bought,
        );
        expect(await svc.xuBalance(childId), 40);
      },
    );

    test('trong mùa: đủ giá giảm nhưng thiếu giá gốc vẫn mua; thiếu giá giảm thì không', () async {
      clock.set(DateTime(2027, 2, 6, 10));
      await giveXu(359);
      final svc = ShopService(db: db);
      expect(
        await svc.buy(childId: childId, gender: 'girl', itemId: 'girl_top_09'),
        BuyResult.insufficient,
      );
      await giveXu(1);
      expect(
        await svc.buy(childId: childId, gender: 'girl', itemId: 'girl_top_09'),
        BuyResult.bought,
      );
    });

    test('đồ không thuộc mùa không giảm trong mùa Tết', () async {
      clock.set(DateTime(2027, 2, 6, 10));
      await giveXu(80);
      final svc = ShopService(db: db);
      expect(
        await svc.buy(childId: childId, gender: 'girl', itemId: 'girl_top_02'),
        BuyResult.bought,
      );
      expect(await svc.xuBalance(childId), 0);
    });
  });

  group('xu đề ngày +50% trong mùa', () {
    Future<(AppDatabase, String, FakeClock)> open(DateTime now) async {
      final clock = FakeClock(now);
      final db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
      addTearDown(db.close);
      final childId = await db.ensureSeeded();
      return (db, childId, clock);
    }

    Future<int> xuAfterStage(
      AppDatabase db,
      String childId,
      FakeClock clock, {
      required bool daily,
    }) async {
      final set = await DailySetService(
        dailySetsDao: db.dailySetsDao,
        reviewQueueDao: db.reviewQueueDao,
        ladderService: LadderService(
          attemptsDao: db.attemptsDao,
          skillProgressDao: db.skillProgressDao,
        ),
        clock: clock,
      ).getOrCreateTodaySet(childId: childId);
      final qs = db.dailySetsDao.readQuestions(set).take(5).toList();
      await playStageCorrectly(
        db: db,
        childId: childId,
        questions: qs,
        dailySetId: daily ? set.id : null,
        stageIndex: daily ? 0 : -1,
      );
      return db.walletDao.balance(childId: childId, currency: Currency.xu);
    }

    test('ngoài mùa: không có dòng season_bonus', () async {
      final (db, childId, clock) = await open(DateTime(2027, 5, 1, 9));
      await xuAfterStage(db, childId, clock, daily: true);
      final rows = await db.walletDao.getEntries(childId);
      expect(rows.where((r) => r.reason == seasonBonusReason), isEmpty);
    });

    test(
      'trong mùa: chặng đề ngày được +50% mỗi khoản, ghi sổ season_bonus',
      () async {
        final (db, childId, clock) = await open(DateTime(2027, 2, 6, 9));
        final (db0, child0, clock0) = await open(DateTime(2027, 5, 1, 9));
        final inSeason = await xuAfterStage(db, childId, clock, daily: true);
        final outSeason = await xuAfterStage(db0, child0, clock0, daily: true);
        final rows = await db.walletDao.getEntries(childId);
        final bonus = rows
            .where((r) => r.reason == seasonBonusReason)
            .fold<int>(0, (a, r) => a + r.amount);
        final base = rows
            .where((r) => r.reason != seasonBonusReason)
            .fold<int>(0, (a, r) => a + r.amount);
        expect(bonus, greaterThan(0));
        // Mỗi khoản được làm tròn riêng nên tổng thưởng nằm sát 50%.
        expect(
          bonus,
          inInclusiveRange((base * 0.5).floor() - 3, (base * 0.5).ceil() + 3),
        );
        expect(inSeason, base + bonus);
        expect(inSeason, greaterThan(outSeason));
      },
    );

    test('chặng tự chọn (không thuộc đề ngày) không được thưởng mùa', () async {
      final (db, childId, clock) = await open(DateTime(2027, 2, 6, 9));
      await xuAfterStage(db, childId, clock, daily: false);
      final rows = await db.walletDao.getEntries(childId);
      expect(rows.where((r) => r.reason == seasonBonusReason), isEmpty);
    });

    test('bonusFor làm tròn gần nhất', () {
      expect(SeasonService.bonusFor(2), 1);
      expect(SeasonService.bonusFor(3), 2);
      expect(SeasonService.bonusFor(5), 3);
      expect(SeasonService.bonusFor(20), 10);
      expect(SeasonService.bonusFor(0), 0);
    });
  });
}
