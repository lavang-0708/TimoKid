/// Chăm pet theo ngày (D): đói / buồn / vui, suất ăn nhận khi học,
/// cho ăn, chơi, vuốt ve.
///
/// Mỗi ngày (giờ Việt Nam, `db.clock.today()`) pet cần [petFeedsPerDay]
/// lần ăn và [petPlaysPerDay] lần chơi: chưa ăn → [PetMood.hungry]; đã
/// ăn mà chưa chơi → [PetMood.sad]; đủ cả hai → [PetMood.happy]. Chỉ
/// ảnh hưởng hình (bong bóng, dáng nhảy): không trừ xp, không ốm, không
/// mất pet.
///
/// Dữ liệu lưu trong `settings` (theo bé), KHÔNG thêm bảng:
/// - `pet_care.<yyyy-mm-dd>`: JSON `{"<petId>": {"feed": n, "play": n}}`;
/// - `pet_food_count.meal`: số suất ăn đang có (cùng kho thức ăn mua);
/// - `pet_meal_ref.<refId>`: đã nhận suất ăn cho lần xong chặng này;
/// - `pet_stages_done.<yyyy-mm-dd>`: số chặng xong hôm nay (cho "vuốt ve").
///
/// API cho tính năng khác (tháp tầng, đấu trường tuần, nhiệm vụ ngày):
/// - [awardMeal] gọi khi xong một chặng/tầng/đấu trường;
/// - [mood], [fedToday], [playedToday] để đọc;
/// - [feed], [play] khi bé chăm pet.
library;

import 'dart:convert';

import '../../core/database/app_database.dart';
import '../room/room_service.dart';
import '../shop/shop_service.dart';
import 'pet_config.dart';
import 'pet_service.dart';

enum PetMood { hungry, sad, happy }

/// Kết quả một lần cho ăn / chơi.
enum CareResult {
  /// Đã ghi nhận.
  done,

  /// Chưa có pet đi theo.
  noPet,

  /// Pet còn là trứng.
  notHatched,

  /// Hết thức ăn / chưa có đồ chơi.
  noItem,

  /// Vuốt ve cần xong ít nhất một chặng hôm nay.
  needStage,
}

/// Số lần chăm trong một ngày của một pet.
class PetCareDay {
  const PetCareDay({this.feeds = 0, this.plays = 0});

  final int feeds;
  final int plays;

  PetMood get mood {
    if (feeds < petFeedsPerDay) return PetMood.hungry;
    if (plays < petPlaysPerDay) return PetMood.sad;
    return PetMood.happy;
  }
}

String petCareKey(String date) => 'pet_care.$date';
String petMealRefKey(String refId) => 'pet_meal_ref.$refId';
String petStagesDoneKey(String date) => 'pet_stages_done.$date';

class PetCareService {
  PetCareService({required this.db});

  final AppDatabase db;

  PetService get _pets => PetService(db: db);
  ShopService get _shop => ShopService(db: db);

  String get _today => db.clock.today();

  // ---------------------------------------------------------------- đọc

  Future<Map<String, Object?>> _readCare(String childId, String date) async {
    final raw = await db.settingsDao.getValue(
      childId: childId,
      key: petCareKey(date),
    );
    if (raw == null) return <String, Object?>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) return decoded;
    } catch (_) {}
    return <String, Object?>{};
  }

  /// Số lần ăn/chơi hôm nay của pet [petId] (pet khác ngày khác: 0).
  Future<PetCareDay> careToday(String childId, String petId) async {
    final entry = (await _readCare(childId, _today))[petId];
    if (entry is Map) {
      return PetCareDay(
        feeds: (entry['feed'] as num?)?.toInt() ?? 0,
        plays: (entry['play'] as num?)?.toInt() ?? 0,
      );
    }
    return const PetCareDay();
  }

  /// Tâm trạng hôm nay của pet đang đi theo; null nếu chưa có pet hoặc
  /// còn là trứng (trứng không đói/buồn).
  Future<PetMood?> mood(String childId) async {
    final a = await _pets.active(childId);
    if (a == null || !a.hatched) return null;
    return (await careToday(childId, a.id)).mood;
  }

  /// Hôm nay bé đã cho pet nào ăn chưa (dùng cho nhiệm vụ ngày).
  Future<bool> fedToday(String childId) => fedOn(childId, _today);

  /// Hôm nay bé đã chơi với pet nào chưa (dùng cho nhiệm vụ ngày).
  Future<bool> playedToday(String childId) => playedOn(childId, _today);

  /// Như [fedToday] nhưng cho ngày [date] (`YYYY-MM-DD`): nhiệm vụ ngày
  /// đếm chuỗi qua các ngày trước.
  Future<bool> fedOn(String childId, String date) =>
      _anyCare(childId, date, 'feed');

  /// Như [playedToday] nhưng cho ngày [date].
  Future<bool> playedOn(String childId, String date) =>
      _anyCare(childId, date, 'play');

  Future<bool> _anyCare(String childId, String date, String field) async {
    for (final v in (await _readCare(childId, date)).values) {
      if (v is Map && ((v[field] as num?) ?? 0) > 0) return true;
    }
    return false;
  }

  /// Số suất ăn đang có.
  Future<int> mealCount(String childId) => _shop.foodCount(childId, petMealId);

  /// Số chặng bé xong hôm nay (chặng ngày + tầng + đấu trường đã gọi
  /// [awardMeal]; không thấp hơn số chặng đề ngày đã xong).
  Future<int> stagesDoneToday(String childId) async {
    final raw = await db.settingsDao.getValue(
      childId: childId,
      key: petStagesDoneKey(_today),
    );
    final counted = int.tryParse(raw ?? '') ?? 0;
    final daily = await RoomService(db: db).doneStageCount(childId);
    return counted > daily ? counted : daily;
  }

  /// "Học xong mới chơi": vuốt ve chỉ được tính sau khi xong ít nhất
  /// [petPatMinStagesToday] chặng hôm nay.
  Future<bool> canPat(String childId) async =>
      await stagesDoneToday(childId) >= petPatMinStagesToday;

  // --------------------------------------------------------------- ghi

  /// Bé vừa xong một chặng (chặng ngày, tầng tháp, đấu trường): nhận
  /// [petMealsPerStage] suất ăn và tính thêm một chặng hôm nay.
  ///
  /// [refId] chống nhận trùng cho cùng một lần xong (vd `stage:<đềId>:<chặng>`,
  /// `arena:<ngày>`, `tower:<mảng>:<tầng>:<ngày>`); null thì luôn nhận
  /// (chặng tự chọn làm được nhiều lần). Trả true nếu vừa nhận.
  Future<bool> awardMeal(String childId, {String? refId}) {
    return db.transaction(() async {
      if (refId != null) {
        final seen = await db.settingsDao.getValue(
          childId: childId,
          key: petMealRefKey(refId),
        );
        if (seen != null) return false;
        await db.settingsDao.setValue(
          childId: childId,
          key: petMealRefKey(refId),
          value: _today,
        );
      }
      final n = await _shop.foodCount(childId, petMealId);
      await db.settingsDao.setValue(
        childId: childId,
        key: petFoodCountKey(petMealId),
        value: '${n + petMealsPerStage}',
      );
      final raw = await db.settingsDao.getValue(
        childId: childId,
        key: petStagesDoneKey(_today),
      );
      await db.settingsDao.setValue(
        childId: childId,
        key: petStagesDoneKey(_today),
        value: '${(int.tryParse(raw ?? '') ?? 0) + 1}',
      );
      return true;
    });
  }

  Future<void> _record(
    String childId,
    String petId, {
    int feed = 0,
    int play = 0,
  }) async {
    final date = _today;
    final all = await _readCare(childId, date);
    final cur = await careToday(childId, petId);
    all[petId] = {'feed': cur.feeds + feed, 'play': cur.plays + play};
    await db.settingsDao.setValue(
      childId: childId,
      key: petCareKey(date),
      value: jsonEncode(all),
    );
  }

  /// Cho pet đang đi theo ăn [foodId] (suất ăn [petMealId] hoặc thức ăn
  /// mua). Trừ một phần và ghi nhận trong CÙNG một transaction.
  Future<CareResult> feed(String childId, {required String foodId}) {
    return db.transaction(() async {
      final a = await _pets.active(childId);
      if (a == null) return CareResult.noPet;
      if (!a.hatched) return CareResult.notHatched;
      if (!await _shop.consumeFood(childId, foodId)) return CareResult.noItem;
      await _record(childId, a.id, feed: 1);
      return CareResult.done;
    });
  }

  /// Chơi với pet đang đi theo: [toyId] là đồ chơi đã mua; null là
  /// "vuốt ve" (luôn có, nhưng cần [canPat]).
  Future<CareResult> play(String childId, {String? toyId}) {
    return db.transaction(() async {
      final a = await _pets.active(childId);
      if (a == null) return CareResult.noPet;
      if (!a.hatched) return CareResult.notHatched;
      if (toyId == null) {
        if (!await canPat(childId)) return CareResult.needStage;
      } else if (!await _shop.isOwned(childId, toyId)) {
        return CareResult.noItem;
      }
      await _record(childId, a.id, play: 1);
      return CareResult.done;
    });
  }
}
