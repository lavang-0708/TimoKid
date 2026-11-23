/// Test Nhiệm vụ ngày + chuỗi ngày (tuần 23/11, mục C): chọn theo seed,
/// không trùng loại, nhiệm vụ pet, tiến độ từng loại, ranh giới ngày
/// Việt Nam, nhận một lần, thưởng đủ cả 3, chuỗi + rương ngày 7.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/arena/league_service.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/pet/pet_care_service.dart';
import 'package:timokid/features/pet/pet_service.dart';
import 'package:timokid/features/quests/quest_config.dart';
import 'package:timokid/features/quests/quest_service.dart';
import 'package:timokid/features/tower/tower_service.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late QuestService quests;

  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 24, 8));
    db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    quests = QuestService(db: db);
  });

  Future<void> attempt({
    String strand = Strand.logic,
    bool first = true,
    bool review = false,
  }) => db.attemptsDao.recordAttempt(
    childId: childId,
    formId: '$strand.x',
    strand: strand,
    level: 1,
    rung: 1,
    answerType: AnswerType.number,
    correctFirstTry: first,
    attemptsCount: first ? 1 : 2,
    durationMs: 1000,
    isReview: review,
  );

  Future<DailySet> todaySet() => DailySetService(
    dailySetsDao: db.dailySetsDao,
    reviewQueueDao: db.reviewQueueDao,
    ladderService: LadderService(
      attemptsDao: db.attemptsDao,
      skillProgressDao: db.skillProgressDao,
    ),
    clock: clock,
  ).getOrCreateTodaySet(childId: childId);

  Future<void> doneStage(int i) async {
    final set = await todaySet();
    await db.dailySetsDao.updateStageStatus(
      id: set.id,
      stageIndex: i,
      status: StageStatus.done,
    );
  }

  Future<void> hatchPet() async {
    final p = await PetService(db: db)
        .createEgg(childId: childId, species: 'cat', makeActive: true);
    await PetService(db: db).markHatched(p!.id);
  }

  Future<void> fulfill(Quest q) async {
    switch (q.type) {
      case QuestType.strandCorrect:
        for (var i = 0; i < q.target; i++) {
          await attempt(strand: q.strand!);
        }
      case QuestType.strandStage:
        await doneStage(Strand.all.indexOf(q.strand!));
      case QuestType.dailyComplete:
        for (var i = 0; i < 5; i++) {
          await doneStage(i);
        }
      case QuestType.towerFloor:
        await TowerService(db: db).recordResult(
          childId: childId,
          strand: Strand.logic,
          floor: 1,
          firstTryCorrect: 5,
        );
      case QuestType.arena:
        await db.arenaAttemptsDao.record(
          childId: childId,
          date: clock.today(),
          mode: 'heat',
          correctCount: 10,
          score: 40,
          medal: 'participant',
          durationSec: 600,
          gemsAwarded: 0,
        );
      case QuestType.reviewRetry:
        for (var i = 0; i < q.target; i++) {
          await attempt(review: true);
        }
      case QuestType.feedPet:
        final care = PetCareService(db: db);
        await care.awardMeal(childId);
        await care.feed(childId, foodId: 'meal');
      case QuestType.playPet:
        final care = PetCareService(db: db);
        await care.awardMeal(childId);
        await care.play(childId);
    }
  }

  Future<void> completeDay() async {
    for (final q in (await quests.questsFor(childId))!) {
      await fulfill(q);
    }
  }

  Future<int> balance(String currency) =>
      db.walletDao.balance(childId: childId, currency: currency);

  group('chọn nhiệm vụ', () {
    test('cố định theo (bé, ngày), 3 nhiệm vụ, không trùng loại', () {
      final a = QuestService.pickQuests(
        childId: 'c1',
        date: '2026-11-24',
        hasPet: true,
      );
      final b = QuestService.pickQuests(
        childId: 'c1',
        date: '2026-11-24',
        hasPet: true,
      );
      expect([for (final q in a) q.id], [for (final q in b) q.id]);
      expect(a.length, QuestConfig.questsPerDay);
      var different = 0;
      for (var d = 1; d <= 120; d++) {
        final date = leagueAddDays('2026-11-01', d);
        final picked = QuestService.pickQuests(
          childId: 'c1',
          date: date,
          hasPet: true,
        );
        expect(picked.map((q) => q.type).toSet().length, picked.length);
        for (final q in picked) {
          expect(Quest.parse(q.id), q);
          if (q.type.needsStrand) expect(Strand.all, contains(q.strand));
        }
        if (picked.map((q) => q.id).join() != a.map((q) => q.id).join()) {
          different++;
        }
      }
      expect(different, greaterThan(100));
      final other = QuestService.pickQuests(
        childId: 'c2',
        date: '2026-11-24',
        hasPet: true,
      );
      final other2 = QuestService.pickQuests(
        childId: 'c3',
        date: '2026-11-24',
        hasPet: true,
      );
      expect(
        {
          a.map((q) => q.id).join(),
          other.map((q) => q.id).join(),
          other2.map((q) => q.id).join(),
        }.length,
        greaterThan(1),
      );
    });

    test('kết quả ổn định theo thời gian (khóa thuật toán)', () {
      List<String> ids(bool pet) => [
        for (final q in QuestService.pickQuests(
          childId: 'abc',
          date: '2026-11-24',
          hasPet: pet,
        ))
          q.id,
      ];
      expect(ids(true), ['feedPet', 'strandCorrect:comb', 'strandStage:geo']);
      expect(ids(false), ['towerFloor', 'arena', 'strandCorrect:geo']);
    });

    test('không có pet thì không có nhiệm vụ pet; có pet thì có lúc có', () {
      var petSeen = false;
      for (var d = 0; d < 200; d++) {
        final date = leagueAddDays('2026-11-01', d);
        final none = QuestService.pickQuests(
          childId: 'c',
          date: date,
          hasPet: false,
        );
        expect(none.length, 3);
        expect(none.any((q) => q.type.needsPet), isFalse);
        final withPet = QuestService.pickQuests(
          childId: 'c',
          date: date,
          hasPet: true,
        );
        if (withPet.any((q) => q.type.needsPet)) petSeen = true;
      }
      expect(petSeen, isTrue);
    });

    test('pet chưa nở không được tính; ba nhiệm vụ lưu cả ngày', () async {
      await PetService(db: db)
          .createEgg(childId: childId, species: 'dog', makeActive: true);
      final first = await quests.questsFor(childId);
      expect(first!.any((q) => q.type.needsPet), isFalse);
      await hatchPet();
      final again = await quests.questsFor(childId);
      expect([for (final q in again!) q.id], [for (final q in first) q.id]);
    });
  });

  group('tiến độ tính từ dữ liệu có sẵn', () {
    Future<int> prog(Quest q) => quests.progressOn(childId, q, clock.today());

    test('đúng N câu mảng X: chỉ đúng ngay lần đầu, đúng mảng', () async {
      const q = Quest(QuestType.strandCorrect, Strand.geo);
      expect(await prog(q), 0);
      await attempt(strand: Strand.geo);
      await attempt(strand: Strand.geo, first: false);
      await attempt(strand: Strand.logic);
      expect(await prog(q), 1);
      for (var i = 0; i < 8; i++) {
        await attempt(strand: Strand.geo);
      }
      expect(await prog(q), q.target, reason: 'kẹp ở mức cần đạt');
    });

    test('xong chặng ngày của tòa X', () async {
      const q = Quest(QuestType.strandStage, Strand.number);
      await todaySet();
      expect(await prog(q), 0);
      await doneStage(Strand.all.indexOf(Strand.logic));
      expect(await prog(q), 0);
      await doneStage(Strand.all.indexOf(Strand.number));
      expect(await prog(q), 1);
    });

    test('xong đề ngày cần cả 5 chặng', () async {
      const q = Quest(QuestType.dailyComplete);
      for (var i = 0; i < 4; i++) {
        await doneStage(i);
      }
      expect(await prog(q), 0);
      await doneStage(4);
      expect(await prog(q), 1);
    });

    test('leo qua 1 tầng tháp: chỉ khi qua tầng', () async {
      const q = Quest(QuestType.towerFloor);
      final tower = TowerService(db: db);
      await tower.recordResult(
        childId: childId,
        strand: Strand.arith,
        floor: 1,
        firstTryCorrect: 2,
      );
      expect(await prog(q), 0);
      await tower.recordResult(
        childId: childId,
        strand: Strand.arith,
        floor: 1,
        firstTryCorrect: 3,
      );
      expect(await prog(q), 1);
    });

    test('đấu trường hôm nay', () async {
      const q = Quest(QuestType.arena);
      expect(await prog(q), 0);
      await fulfill(q);
      expect(await prog(q), 1);
    });

    test('làm lại đúng 2 câu sổ ôn tập: chỉ câu ôn tập đúng ngay', () async {
      const q = Quest(QuestType.reviewRetry);
      await attempt();
      await attempt(review: true, first: false);
      await attempt(review: true);
      expect(await prog(q), 1);
      await attempt(review: true);
      expect(await prog(q), 2);
    });

    test('cho pet ăn / chơi với pet', () async {
      await hatchPet();
      const feed = Quest(QuestType.feedPet);
      const play = Quest(QuestType.playPet);
      expect(await prog(feed), 0);
      expect(await prog(play), 0);
      await fulfill(feed);
      expect(await prog(feed), 1);
      expect(await prog(play), 0);
      await fulfill(play);
      expect(await prog(play), 1);
    });

    test('ranh giới ngày Việt Nam: 23:59 và 00:00', () async {
      const q = Quest(QuestType.strandCorrect, Strand.logic);
      clock.set(DateTime(2026, 11, 24, 23, 59, 30));
      await attempt();
      expect(await prog(q), 1);
      clock.set(DateTime(2026, 11, 25, 0, 0, 1));
      expect(await prog(q), 0, reason: 'sang ngày mới thì về 0');
      await attempt();
      await attempt();
      expect(await prog(q), 2);
      expect(await quests.progressOn(childId, q, '2026-11-24'), 1);
    });
  });

  group('nhận thưởng', () {
    test('chưa xong thì không nhận; xong nhận 10 xu một lần', () async {
      final list = (await quests.questsFor(childId))!;
      final q = list.first;
      expect(
        (await quests.claim(childId, q.id)).result,
        QuestClaimResult.notDone,
      );
      expect(await balance(Currency.xu), 0);
      await fulfill(q);
      final before = await balance(Currency.xu);
      final r = await quests.claim(childId, q.id);
      expect(r.ok, isTrue);
      expect(r.xu, QuestConfig.claimXu);
      expect(r.gems, 0);
      final again = await quests.claim(childId, q.id);
      expect(again.result, QuestClaimResult.alreadyClaimed);
      expect(await balance(Currency.xu), before + QuestConfig.claimXu);
    });

    test('hai lần bấm chồng nhau chỉ cộng một lần', () async {
      final q = (await quests.questsFor(childId))!.first;
      await fulfill(q);
      final before = await balance(Currency.xu);
      final results = await Future.wait([
        quests.claim(childId, q.id),
        quests.claim(childId, q.id),
      ]);
      expect(results.where((r) => r.ok).length, 1);
      expect(await balance(Currency.xu), before + QuestConfig.claimXu);
    });

    test('mã lạ / nhiệm vụ không thuộc hôm nay: unknown', () async {
      expect(
        (await quests.claim(childId, 'xyz')).result,
        QuestClaimResult.unknown,
      );
      final today = (await quests.questsFor(childId))!;
      final missing = [
        for (final t in QuestType.values)
          if (!t.needsStrand && !t.needsPet && !today.any((q) => q.type == t))
            t,
      ].first;
      expect(
        (await quests.claim(childId, missing.name)).result,
        QuestClaimResult.unknown,
      );
    });

    test('nhận đủ cả 3: thêm 1 kim cương, một lần', () async {
      final list = (await quests.questsFor(childId))!;
      for (final q in list) {
        await fulfill(q);
      }
      final before = await balance(Currency.xu);
      var gems = 0;
      for (final q in list) {
        gems += (await quests.claim(childId, q.id)).gems;
      }
      expect(gems, QuestConfig.allClaimedGems);
      expect(await balance(Currency.gem), QuestConfig.allClaimedGems);
      expect(await balance(Currency.xu), before + 3 * QuestConfig.claimXu);
      final board = await quests.board(childId);
      expect(board.allClaimed, isTrue);
      expect(board.bonusClaimed, isTrue);
      expect(board.hasClaimable, isFalse);
      for (final q in list) {
        await quests.claim(childId, q.id);
      }
      expect(await balance(Currency.gem), QuestConfig.allClaimedGems);
    });

    test('hasClaimable: có khi một nhiệm vụ xong chưa nhận', () async {
      expect(await quests.hasClaimable(childId), isFalse);
      final q = (await quests.questsFor(childId))!.first;
      await fulfill(q);
      expect(await quests.hasClaimable(childId), isTrue);
      // Có loại kéo theo loại khác (xong đề ngày → xong chặng): nhận hết
      // những gì đã xong thì chấm đỏ tắt.
      for (final s in (await quests.board(childId)).quests) {
        if (s.claimable) await quests.claim(childId, s.quest.id);
      }
      expect(await quests.hasClaimable(childId), isFalse);
    });
  });

  group('chuỗi ngày', () {
    Future<void> nextDay() async {
      clock.set(clock.now().add(const Duration(days: 1)));
    }

    test(
      'đếm ngày liên tiếp; hôm nay chưa xong vẫn giữ chuỗi tới hôm qua',
      () async {
        expect(await quests.streak(childId), 0);
        await completeDay();
        expect(await quests.streak(childId), 1);
        await nextDay();
        expect(await quests.streak(childId), 1, reason: 'hôm nay chưa làm');
        await completeDay();
        expect(await quests.streak(childId), 2);
        await nextDay();
        await completeDay();
        expect(await quests.streak(childId), 3);
      },
    );

    test('chưa xong đủ 3 thì không tính; lỡ một ngày thì về 0', () async {
      await completeDay();
      await nextDay();
      // Chỉ làm một nhiệm vụ (xong đề ngày có thể kéo theo chặng ngày,
      // nhưng không bao giờ đủ cả 3).
      await fulfill((await quests.questsFor(childId))!.first);
      expect((await quests.board(childId)).allCompleted, isFalse);
      expect(await quests.streak(childId), 1);
      await nextDay(); // ngày trước chưa xong đủ
      expect(await quests.streak(childId), 0);
      await completeDay();
      expect(await quests.streak(childId), 1);
    });

    test('không cần bấm nhận vẫn giữ chuỗi', () async {
      await completeDay();
      await nextDay();
      await completeDay();
      expect(await quests.streak(childId), 2);
      expect((await quests.board(childId)).allClaimed, isFalse);
    });

    test(
      'ngày thứ 7: rương 5 kim cương nhận một lần; ngày 14 có rương nữa',
      () async {
        for (var d = 1; d <= 6; d++) {
          await completeDay();
          expect((await quests.board(childId)).pendingChests, isEmpty);
          await nextDay();
        }
        await completeDay();
        var board = await quests.board(childId);
        expect(board.streak, 7);
        expect(board.pendingChests, [clock.today()]);
        expect(board.hasClaimable, isTrue);
        expect(
          await quests.claimStreakChest(childId),
          QuestConfig.streakChestGems,
        );
        expect(await quests.claimStreakChest(childId), 0);
        expect(await balance(Currency.gem), QuestConfig.streakChestGems);
        board = await quests.board(childId);
        expect(board.pendingChests, isEmpty);

        for (var d = 8; d <= 14; d++) {
          await nextDay();
          await completeDay();
        }
        board = await quests.board(childId);
        expect(board.streak, 14);
        expect(board.pendingChests.length, 1);
        expect(
          await quests.claimStreakChest(childId),
          QuestConfig.streakChestGems,
        );
        expect(await balance(Currency.gem), 2 * QuestConfig.streakChestGems);
      },
    );

    test('rương chưa nhận vẫn còn sau ngày 8', () async {
      for (var d = 1; d <= 7; d++) {
        await completeDay();
        await quests.board(childId);
        await nextDay();
      }
      await completeDay();
      final board = await quests.board(childId);
      expect(board.streak, 8);
      expect(board.pendingChests.length, 1);
    });
  });
}
