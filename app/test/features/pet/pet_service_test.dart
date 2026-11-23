/// Test PetService (D): bảng pets, một pet active, cộng xp, ngưỡng
/// giai đoạn, nhận trứng mới khi pet trưởng thành, luồng nở.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/features/onboarding/egg_service.dart';
import 'package:timokid/features/pet/pet_config.dart';
import 'package:timokid/features/pet/pet_service.dart';
import 'package:timokid/features/room/pet_growth.dart';

void main() {
  late AppDatabase db;
  late String childId;
  late PetService pets;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    pets = PetService(db: db);
  });

  Future<PetInfo> hatchedDog() async {
    await EggService(db: db).selectEgg(childId: childId, species: 'dog');
    await EggService(db: db).noteStageCompleted(childId);
    await EggService(db: db).consumeHatchCelebration(childId);
    return (await pets.active(childId))!;
  }

  group('ngưỡng giai đoạn (thuần hàm)', () {
    test('mới nở 0, tuổi nhỡ ≥ 80, trưởng thành ≥ 250', () {
      expect(petTeenXp, 80);
      expect(petAdultXp, 250);
      expect(petStageFor(xp: 0, hatched: true), PetStage.newborn);
      expect(petStageFor(xp: 79, hatched: true), PetStage.newborn);
      expect(petStageFor(xp: 80, hatched: true), PetStage.teen);
      expect(petStageFor(xp: 249, hatched: true), PetStage.teen);
      expect(petStageFor(xp: 250, hatched: true), PetStage.adult);
      expect(petStageFor(xp: 500, hatched: false), PetStage.egg);
    });
  });

  group('xp', () {
    test(
      'addXp cộng cho pet đang đi theo, giai đoạn đổi đúng ngưỡng',
      () async {
        await hatchedDog();
        expect((await pets.active(childId))!.stage, PetStage.newborn);
        for (var i = 0; i < 79; i++) {
          await pets.addXp(childId);
        }
        expect((await pets.active(childId))!.xp, 79);
        expect((await pets.active(childId))!.stage, PetStage.newborn);
        await pets.addXp(childId);
        expect((await pets.active(childId))!.stage, PetStage.teen);
        await pets.addXp(childId, amount: 170);
        expect((await pets.active(childId))!.xp, 250);
        expect((await pets.active(childId))!.stage, PetStage.adult);
      },
    );

    test('pet không đi theo không được cộng xp', () async {
      await hatchedDog();
      final cat = await pets.createEgg(
        childId: childId,
        species: 'cat',
        makeActive: false,
      );
      await pets.addXp(childId, amount: 5);
      expect(
        (await pets.pets(childId)).firstWhere((p) => p.id == cat!.id).xp,
        0,
      );
      expect((await pets.active(childId))!.xp, 5);
    });

    test('chưa có pet thì addXp bỏ qua; amount ≤ 0 không đổi', () async {
      expect(await pets.addXp(childId), isNull);
      await hatchedDog();
      await pets.addXp(childId, amount: 0);
      await pets.addXp(childId, amount: -3);
      expect((await pets.active(childId))!.xp, 0);
    });

    test('trứng chưa nở cũng tích xp (không mất câu đúng chặng đầu)', () async {
      await EggService(db: db).selectEgg(childId: childId, species: 'cat');
      await pets.addXp(childId, amount: 4);
      final p = (await pets.active(childId))!;
      expect(p.xp, 4);
      expect(p.stage, PetStage.egg);
    });
  });

  group('một pet active', () {
    test('createEgg active đổi pet cũ về không active', () async {
      await hatchedDog();
      await pets.createEgg(childId: childId, species: 'cat', makeActive: true);
      final all = await pets.pets(childId);
      expect(all.where((p) => p.active), hasLength(1));
      expect((await pets.active(childId))!.species, 'cat');
    });

    test('setActive đổi pet và luôn đúng một pet active', () async {
      final dog = await hatchedDog();
      final cat = (await pets.createEgg(
        childId: childId,
        species: 'cat',
        makeActive: false,
      ))!;
      expect((await pets.active(childId))!.id, dog.id);
      expect(await pets.setActive(childId, cat.id), isTrue);
      expect((await pets.active(childId))!.id, cat.id);
      expect((await pets.pets(childId)).where((p) => p.active), hasLength(1));
      expect(await pets.setActive(childId, 'khong-co'), isFalse);
    });

    test('không có hai pet cùng loài; loài lạ bị từ chối', () async {
      await hatchedDog();
      expect(
        await pets.createEgg(
          childId: childId,
          species: 'dog',
          makeActive: false,
        ),
        isNull,
      );
      expect(
        await pets.createEgg(
          childId: childId,
          species: 'fox',
          makeActive: false,
        ),
        isNull,
      );
      expect(await pets.pets(childId), hasLength(1));
    });
  });

  group('pet trưởng thành → trứng mới', () {
    test('chưa trưởng thành thì không nhận được trứng mới', () async {
      await hatchedDog();
      await pets.addXp(childId, amount: 249);
      expect(await pets.canClaimStarterEgg(childId), isFalse);
      expect(await pets.claimStarterEgg(childId, 'cat'), isNull);
    });

    test(
      'trưởng thành: chọn loài khởi đầu chưa có, trứng thành pet đi theo',
      () async {
        final dog = await hatchedDog();
        await pets.addXp(childId, amount: 250);
        expect(await pets.canClaimStarterEgg(childId), isTrue);
        expect(await pets.availableStarterSpecies(childId), ['cat', 'rabbit']);
        // Loài đã có hoặc không phải loài khởi đầu thì bị từ chối.
        expect(await pets.claimStarterEgg(childId, 'dog'), isNull);
        expect(await pets.claimStarterEgg(childId, 'squirrel'), isNull);
        final egg = await pets.claimStarterEgg(childId, 'rabbit');
        expect(egg, isNotNull);
        expect((await pets.active(childId))!.species, 'rabbit');
        expect((await pets.active(childId))!.hatched, isFalse);
        // Pet lớn vẫn còn trong danh sách, chỉ thôi đi theo.
        final all = await pets.pets(childId);
        expect(all, hasLength(2));
        expect(all.firstWhere((p) => p.id == dog.id).active, isFalse);
        // Trứng mới (đang đi theo) hết cho nhận thêm.
        expect(await pets.canClaimStarterEgg(childId), isFalse);
      },
    );

    test('đủ cả 3 loài khởi đầu thì hết trứng để nhận', () async {
      await hatchedDog();
      await pets.createEgg(childId: childId, species: 'cat', makeActive: false);
      await pets.createEgg(
        childId: childId,
        species: 'rabbit',
        makeActive: false,
      );
      await pets.addXp(childId, amount: 250);
      expect(await pets.availableStarterSpecies(childId), isEmpty);
      expect(await pets.canClaimStarterEgg(childId), isFalse);
    });
  });

  group('luồng nở với bảng pets', () {
    test('trứng mới đang đi theo nở ở chặng xong kế tiếp', () async {
      await hatchedDog();
      await pets.addXp(childId, amount: 250);
      await pets.claimStarterEgg(childId, 'cat');
      final eggs = EggService(db: db);
      expect(await eggs.isHatched(childId), isFalse);
      expect(await eggs.noteStageCompleted(childId), isTrue);
      expect(await eggs.isHatchPending(childId), isTrue);
      await eggs.consumeHatchCelebration(childId);
      final cat = (await pets.active(childId))!;
      expect(cat.species, 'cat');
      expect(cat.hatched, isTrue);
      expect(cat.pet.stageSeen, 'newborn');
      expect(await eggs.noteStageCompleted(childId), isFalse);
    });
  });
}
