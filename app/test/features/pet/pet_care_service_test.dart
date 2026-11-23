/// Test PetCareService (D): tâm trạng theo ngày Việt Nam, suất ăn khi
/// xong chặng, cho ăn / chơi / vuốt ve.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/onboarding/egg_service.dart';
import 'package:timokid/features/pet/pet_care_service.dart';
import 'package:timokid/features/pet/pet_config.dart';
import 'package:timokid/features/pet/pet_service.dart';
import 'package:timokid/features/shop/shop_service.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late PetCareService care;
  late ShopService shop;

  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 23, 9, 0));
    db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    care = PetCareService(db: db);
    shop = ShopService(db: db);
  });

  Future<void> hatch() async {
    final eggs = EggService(db: db);
    await eggs.selectEgg(childId: childId, species: 'dog');
    await eggs.noteStageCompleted(childId);
    await eggs.consumeHatchCelebration(childId);
  }

  Future<void> buyFoodAndToy() async {
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: 200,
      reason: 'test',
    );
    expect(
      await shop.buy(childId: childId, gender: 'girl', itemId: 'pet_food_bone'),
      BuyResult.bought,
    );
    expect(
      await shop.buy(childId: childId, gender: 'girl', itemId: 'pet_toy_ball'),
      BuyResult.bought,
    );
  }

  group('tâm trạng theo ngày', () {
    test('chưa có pet hoặc còn là trứng: không có tâm trạng', () async {
      expect(await care.mood(childId), isNull);
      await EggService(db: db).selectEgg(childId: childId, species: 'cat');
      expect(await care.mood(childId), isNull);
    });

    test('chưa ăn → đói; ăn chưa chơi → buồn; đủ cả hai → vui', () async {
      await hatch();
      await buyFoodAndToy();
      expect(await care.mood(childId), PetMood.hungry);
      expect(
        await care.feed(childId, foodId: 'pet_food_bone'),
        CareResult.done,
      );
      expect(await care.mood(childId), PetMood.sad);
      expect(await care.play(childId, toyId: 'pet_toy_ball'), CareResult.done);
      expect(await care.mood(childId), PetMood.happy);
      expect(await care.fedToday(childId), isTrue);
      expect(await care.playedToday(childId), isTrue);
    });

    test('sang ngày mới (giờ Việt Nam) pet lại đói; xp không bị trừ', () async {
      await hatch();
      await buyFoodAndToy();
      await PetService(db: db).addXp(childId, amount: 12);
      await care.feed(childId, foodId: 'pet_food_bone');
      await care.play(childId, toyId: 'pet_toy_ball');
      expect(await care.mood(childId), PetMood.happy);
      // 23:59 cùng ngày vẫn vui; 00:00 ngày sau đói lại.
      clock.set(DateTime(2026, 11, 23, 23, 59));
      expect(await care.mood(childId), PetMood.happy);
      clock.set(DateTime(2026, 11, 24, 0, 0));
      expect(await care.mood(childId), PetMood.hungry);
      expect(await care.fedToday(childId), isFalse);
      expect((await PetService(db: db).active(childId))!.xp, 12);
    });

    test('mỗi pet có tâm trạng riêng trong ngày', () async {
      await hatch();
      await buyFoodAndToy();
      await care.feed(childId, foodId: 'pet_food_bone');
      final pets = PetService(db: db);
      final cat = (await pets.createEgg(
        childId: childId,
        species: 'cat',
        makeActive: false,
      ))!;
      await db.petsDao.updatePet(
        cat.id,
        PetsCompanion(hatched: const Value(true)),
      );
      await pets.setActive(childId, cat.id);
      expect(await care.mood(childId), PetMood.hungry);
    });
  });

  group('suất ăn', () {
    test('mỗi lần xong chặng được một suất; refId chống nhận trùng', () async {
      expect(await care.mealCount(childId), 0);
      expect(await care.awardMeal(childId, refId: 'stage:a:0'), isTrue);
      expect(await care.awardMeal(childId, refId: 'stage:a:0'), isFalse);
      expect(await care.awardMeal(childId, refId: 'stage:a:1'), isTrue);
      expect(await care.mealCount(childId), 2);
      // Chặng tự chọn/tầng không có refId: luôn nhận.
      expect(await care.awardMeal(childId), isTrue);
      expect(await care.awardMeal(childId), isTrue);
      expect(await care.mealCount(childId), 4);
    });

    test('suất ăn dùng để cho ăn; hết thì không cho ăn được', () async {
      await hatch();
      expect(await care.feed(childId, foodId: petMealId), CareResult.noItem);
      await care.awardMeal(childId);
      expect(await care.feed(childId, foodId: petMealId), CareResult.done);
      expect(await care.mealCount(childId), 0);
      expect(await care.feed(childId, foodId: petMealId), CareResult.noItem);
      expect(await care.mood(childId), PetMood.sad);
    });

    test('thức ăn mua cũng cho ăn được, số lượng không âm', () async {
      await hatch();
      await buyFoodAndToy();
      expect(await shop.foodCount(childId, 'pet_food_bone'), 1);
      await care.feed(childId, foodId: 'pet_food_bone');
      expect(await shop.foodCount(childId, 'pet_food_bone'), 0);
      expect(
        await care.feed(childId, foodId: 'pet_food_bone'),
        CareResult.noItem,
      );
      expect(await shop.foodCount(childId, 'pet_food_bone'), 0);
    });

    test('trứng chưa nở không ăn được và không bị trừ suất', () async {
      await EggService(db: db).selectEgg(childId: childId, species: 'cat');
      await care.awardMeal(childId);
      expect(
        await care.feed(childId, foodId: petMealId),
        CareResult.notHatched,
      );
      expect(await care.mealCount(childId), 1);
    });
  });

  group('vuốt ve (học xong mới chơi)', () {
    test('chưa xong chặng nào hôm nay thì không vuốt ve được', () async {
      await hatch();
      expect(await care.canPat(childId), isFalse);
      expect(await care.play(childId), CareResult.needStage);
      expect(await care.mood(childId), PetMood.hungry);
    });

    test(
      'xong một chặng (awardMeal) thì vuốt ve được và tính là chơi',
      () async {
        await hatch();
        await care.awardMeal(childId);
        expect(await care.stagesDoneToday(childId), 1);
        expect(await care.canPat(childId), isTrue);
        await care.awardMeal(childId, refId: 'x');
        await care.feed(childId, foodId: petMealId);
        expect(await care.play(childId), CareResult.done);
        expect(await care.mood(childId), PetMood.happy);
      },
    );

    test('sang ngày mới phải học xong một chặng nữa mới vuốt ve', () async {
      await hatch();
      await care.awardMeal(childId);
      expect(await care.canPat(childId), isTrue);
      clock.set(DateTime(2026, 11, 24, 8, 0));
      expect(await care.canPat(childId), isFalse);
    });

    test('đồ chơi chưa mua thì không chơi được', () async {
      await hatch();
      expect(
        await care.play(childId, toyId: 'pet_toy_ball'),
        CareResult.noItem,
      );
    });
  });
}
