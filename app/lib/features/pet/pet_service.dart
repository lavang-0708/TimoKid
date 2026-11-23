/// Dịch vụ pet (D): bảng `pets`, pet đang đi theo, cộng xp, đổi pet,
/// nhận trứng mới.
///
/// Luật:
/// - Mỗi bé có tối đa một pet mỗi loài và ĐÚNG MỘT pet `active` (khi đã
///   có pet). Mọi chỗ đổi pet active đi qua [setActive]/[createEgg]
///   trong một transaction nên không bao giờ có hai pet active.
/// - [addXp] cộng xp cho pet đang đi theo (trứng cũng tích xp: câu đúng
///   trong chặng đầu tiên không bị mất). Gọi ở MỌI nơi bé trả lời đúng
///   ngay lần đầu (đề ngày, tháp, đấu trường) — xem `StageSession` và
///   `ArenaService.submit`.
/// - Pet trưởng thành → [canClaimStarterEgg]: bé chọn trứng khởi đầu
///   (chó/mèo/thỏ) chưa có bằng [claimStarterEgg]; trứng mới thành pet
///   đi theo và nở theo luồng cũ ([EggService]).
library;

import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart';

import '../room/pet_growth.dart';
import 'pet_config.dart';

/// Pet cùng giai đoạn tính từ xp (tiện cho giao diện).
class PetInfo {
  PetInfo(this.pet) : stage = petStageFor(xp: pet.xp, hatched: pet.hatched);

  final Pet pet;
  final PetStage stage;

  String get id => pet.id;
  String get species => pet.species;
  int get xp => pet.xp;
  bool get hatched => pet.hatched;
  bool get active => pet.active;

  /// Giai đoạn bé đã thấy lần cuối (null nếu giá trị lạ).
  PetStage? get stageSeen => petStageFromName(pet.stageSeen);

  /// Còn bao nhiêu câu đúng nữa thì lên giai đoạn sau (null: đã lớn
  /// hết hoặc còn là trứng).
  int? get xpToNext => hatched ? petXpToNextStage(xp) : null;
}

class PetService {
  PetService({required this.db});

  final AppDatabase db;

  /// Mọi pet của bé, theo thứ tự có pet.
  Future<List<PetInfo>> pets(String childId) async => [
    for (final p in await db.petsDao.getAll(childId)) PetInfo(p),
  ];

  /// Pet đang đi theo; null nếu chưa có pet nào (chưa chọn trứng).
  Future<PetInfo?> active(String childId) async {
    final p = await db.petsDao.getActive(childId);
    return p == null ? null : PetInfo(p);
  }

  /// Bé có pet loài [species] chưa.
  Future<bool> owns(String childId, String species) async =>
      await db.petsDao.getBySpecies(childId, species) != null;

  /// Thêm một trứng loài [species]. [makeActive] true thì trứng thành
  /// pet đi theo (pet active cũ về không active, trong cùng transaction).
  /// Trả null nếu bé đã có loài này hoặc mã loài không hợp lệ.
  Future<PetInfo?> createEgg({
    required String childId,
    required String species,
    required bool makeActive,
  }) {
    return db.transaction(() async {
      if (!petSpeciesDisplayNames.containsKey(species)) return null;
      if (await owns(childId, species)) return null;
      if (makeActive) await db.petsDao.clearActive(childId);
      final p = await db.petsDao.insertPet(
        childId: childId,
        species: species,
        active: makeActive,
      );
      return PetInfo(p);
    });
  }

  /// Cho pet [petId] đi theo bé (pet khác thôi đi theo). Trả false nếu
  /// pet không tồn tại hoặc không phải của bé.
  Future<bool> setActive(String childId, String petId) {
    return db.transaction(() async {
      final p = await db.petsDao.getById(petId);
      if (p == null || p.childId != childId) return false;
      if (p.active) return true;
      await db.petsDao.clearActive(childId);
      await db.petsDao.updatePet(petId, PetsCompanion(active: Value(true)));
      return true;
    });
  }

  /// Cộng [amount] xp (số câu đúng ngay lần đầu) cho pet đang đi theo.
  /// Không có pet thì bỏ qua. Trả xp mới (null nếu không có pet).
  Future<int?> addXp(String childId, {int amount = 1}) async {
    if (amount <= 0) return (await active(childId))?.xp;
    return db.transaction(() async {
      final p = await db.petsDao.getActive(childId);
      if (p == null) return null;
      final xp = p.xp + amount;
      await db.petsDao.updatePet(p.id, PetsCompanion(xp: Value(xp)));
      return xp;
    });
  }

  /// Ghi giai đoạn bé đã thấy (sau màn ăn mừng / khi nở xong).
  Future<void> markStageSeen(String petId, PetStage stage) =>
      db.petsDao.updatePet(petId, PetsCompanion(stageSeen: Value(stage.name)));

  /// Đánh dấu pet đã nở (xong màn nở trứng): hatched = true, giai đoạn
  /// đã thấy = mới nở (hoặc cao hơn nếu xp đã tích đủ trong lúc là trứng
  /// — bé vẫn được ăn mừng lên lớp sau đó).
  Future<void> markHatched(String petId) async {
    await db.petsDao.updatePet(
      petId,
      PetsCompanion(
        hatched: Value(true),
        stageSeen: Value(PetStage.newborn.name),
      ),
    );
  }

  /// Pet đang đi theo đã trưởng thành chưa.
  Future<bool> isActiveAdult(String childId) async {
    final a = await active(childId);
    return a != null && a.stage == PetStage.adult;
  }

  /// Loài khởi đầu bé chưa có.
  Future<List<String>> availableStarterSpecies(String childId) async {
    final owned = {for (final p in await pets(childId)) p.species};
    return [
      for (final s in starterSpecies)
        if (!owned.contains(s)) s,
    ];
  }

  /// Phòng có nên mời "Nhận trứng mới" không: pet đi theo đã trưởng
  /// thành và còn loài khởi đầu chưa có.
  Future<bool> canClaimStarterEgg(String childId) async =>
      await isActiveAdult(childId) &&
      (await availableStarterSpecies(childId)).isNotEmpty;

  /// Nhận trứng khởi đầu [species]; trứng thành pet đi theo. Trả null
  /// (không đổi gì) nếu chưa đủ điều kiện hoặc loài không hợp lệ.
  Future<PetInfo?> claimStarterEgg(String childId, String species) async {
    return db.transaction(() async {
      if (!await canClaimStarterEgg(childId)) return null;
      if (!starterSpecies.contains(species)) return null;
      return createEgg(childId: childId, species: species, makeActive: true);
    });
  }
}

/// Mọi loài hợp lệ (khởi đầu + bán).
