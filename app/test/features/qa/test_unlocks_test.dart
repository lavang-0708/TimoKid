import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/test_build.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/core/widgets/test_build_badge.dart';
import 'package:timokid/features/pet/pet_care_service.dart';
import 'package:timokid/features/pet/pet_config.dart';
import 'package:timokid/features/pet/pet_service.dart';
import 'package:timokid/features/qa/qa_config.dart';
import 'package:timokid/features/qa/qa_service.dart';
import 'package:timokid/features/qa/test_grant_service.dart';
import 'package:timokid/features/room/pet_growth.dart';
import 'package:timokid/features/room/room_service.dart';

void main() {
  late AppDatabase db;
  late String childId;

  setUp(() async {
    // Thứ Năm 19/11/2026.
    db = AppDatabase(
      executor: NativeDatabase.memory(),
      clock: FakeClock(DateTime.utc(2026, 11, 19, 20, 0)),
    );
    addTearDown(db.close);
    childId = await db.ensureSeeded();
  });
  tearDown(() => TestUnlocks.debugOverride = null);

  group('cổng TestUnlocks', () {
    test('mặc định tắt (cờ build không bật trong test)', () {
      expect(testUnlocks, isFalse);
      expect(TestUnlocks.enabled, isFalse);
    });

    test('tắt: Phòng khóa và vuốt ve cần xong chặng (như cũ)', () async {
      expect(await RoomService(db: db).isPlayUnlocked(childId), isFalse);
      expect(await PetCareService(db: db).canPat(childId), isFalse);
    });

    test('bật: Phòng mở và vuốt ve được dù chưa xong chặng nào', () async {
      TestUnlocks.debugOverride = true;
      expect(await RoomService(db: db).isPlayUnlocked(childId), isTrue);
      expect(await PetCareService(db: db).canPat(childId), isTrue);
    });

    test('QA menu bật theo cờ (debug test luôn bật)', () {
      expect(QaConfig.enabled, isTrue);
    });
  });

  group('tặng xu/kim cương', () {
    test('tặng 10.000 mỗi loại đúng một lần', () async {
      final s = TestGrantService(db: db);
      expect(await s.grantIfNeeded(childId), isTrue);
      expect(await s.grantIfNeeded(childId), isFalse);
      final b = await db.walletDao.balances(childId);
      expect(b[Currency.xu], testGrantAmount);
      expect(b[Currency.gem], testGrantAmount);
      expect(
        await db.walletDao.hasEntryWithRefId(
          childId: childId,
          refId: TestGrantService.grantRefId,
        ),
        isTrue,
      );
    });

    test('dưới 1.000 thì nạp lại, mỗi lần một refId mới', () async {
      final s = TestGrantService(db: db);
      await s.grantIfNeeded(childId);
      await db.walletDao.addEntry(
        childId: childId,
        currency: Currency.xu,
        amount: -9500,
        reason: 'spend',
      );
      expect(await s.grantIfNeeded(childId), isTrue);
      var b = await db.walletDao.balances(childId);
      expect(b[Currency.xu], 10500);
      expect(b[Currency.gem], testGrantAmount);
      expect(await s.grantIfNeeded(childId), isFalse);
      expect(
        await db.walletDao.hasEntryWithRefId(
          childId: childId,
          refId: TestGrantService.topUpRefId(1),
        ),
        isTrue,
      );
    });
  });

  group('QA mốc pet / ngày', () {
    late QaService qa;
    late PetService pets;

    setUp(() async {
      qa = QaService(db: db);
      pets = PetService(db: db);
      final egg = await pets.createEgg(
        childId: childId,
        species: 'dog',
        makeActive: true,
      );
      await pets.markHatched(egg!.id);
    });

    test('đặt xp theo mốc và +50', () async {
      await qa.setActivePetXp(childId, petTeenXp);
      var a = (await pets.active(childId))!;
      expect(a.stage, PetStage.teen);
      expect(a.stageSeen, PetStage.newborn);
      await qa.setActivePetXp(childId, petAdultXp);
      a = (await pets.active(childId))!;
      expect(a.stage, PetStage.adult);
      expect(a.stageSeen, PetStage.teen);
      await qa.setActivePetXp(childId, 0);
      expect((await pets.active(childId))!.stage, PetStage.newborn);
      await qa.addPetXp(childId, 50);
      expect((await pets.active(childId))!.xp, 50);
    });

    test('reset tâm trạng, +10 suất ăn', () async {
      final care = PetCareService(db: db);
      await qa.giveMeals(childId, 10);
      expect(await care.mealCount(childId), 10);
      TestUnlocks.debugOverride = true;
      final pet = (await pets.active(childId))!;
      await care.feed(childId, foodId: petMealId);
      expect((await care.careToday(childId, pet.id)).feeds, 1);
      await qa.resetPetMoodToday(childId);
      expect((await care.careToday(childId, pet.id)).feeds, 0);
    });

    test('xong đề ngày mở Phòng, nhảy tới thứ Hai kế tiếp', () async {
      expect(await RoomService(db: db).isPlayUnlocked(childId), isFalse);
      await qa.markDailySetDone(childId);
      expect(await RoomService(db: db).isPlayUnlocked(childId), isTrue);
      expect(qa.advanceToNextMonday(), 4);
      expect(qa.today, '2026-11-23');
      // Đang thứ Hai thì nhảy sang thứ Hai tuần sau.
      expect(qa.advanceToNextMonday(), 7);
      expect(qa.today, '2026-11-30');
    });

    test('nở trứng ngay và xóa dấu nhận nhiệm vụ', () async {
      expect(await qa.hatchNow(childId), isFalse); // pet đã nở sẵn
      expect(await qa.clearTodayQuestClaims(childId), 0);
    });
  });

  testWidgets('nhãn BẢN THỬ chỉ hiện khi bật cờ', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: TestBuildBadge(),
      ),
    );
    expect(find.byKey(const Key('test-build-badge')), findsNothing);
    TestUnlocks.debugOverride = true;
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: TestBuildBadge(key: Key('x')),
      ),
    );
    expect(find.byKey(const Key('test-build-badge')), findsOneWidget);
  });
}
