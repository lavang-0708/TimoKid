/// Logic của menu QA (T1-13), Dart thuần, không phụ thuộc widget.
///
/// Mọi chức năng trong PLAN mục T1-13 đều đi qua các API đã có
/// (không viết lại luật học):
/// - Nhảy ngày: gắn [DebugClock] vào `db.clock` rồi cộng 1 ngày.
/// - Đặt bậc từng mảng: [SkillProgressDao.setStrandRung] (đặt bậc thì
///   cửa sổ 10 câu cũng reset theo luật của DAO — tốt cho QA vì sau
///   khi đặt bậc thì 10 câu tiếp theo tính từ đầu).
/// - Xem sổ ôn tập: [ReviewBookService.allEntries].
/// - Xem 20 lượt trả lời gần nhất: [AttemptsDao.getAttemptsForChild].
/// - Xem thử dạng bài: bộ sinh câu của T1-05, chỉ sinh để xem — không
///   ghi `attempts`, không động vào bậc/thành thạo/sổ ôn tập.
/// - Xóa dữ liệu: [AppDatabase.resetForQa] (xem ghi chú ở đó).
library;

import 'dart:math';

import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;

import '../../core/database/app_database.dart';
import '../../core/database/daos.dart';
import '../../core/database/models.dart';
import '../daily_set/daily_set_config.dart';
import '../daily_set/daily_set_service.dart';
import '../ladder/ladder_config.dart';
import '../ladder/ladder_service.dart';
import '../onboarding/egg_service.dart';
import '../pet/pet_care_service.dart';
import '../pet/pet_config.dart';
import '../pet/pet_service.dart';
import '../quests/quest_service.dart';
import '../questions/question.dart';
import '../questions/question_registry.dart';
import '../review_book/review_book_service.dart';
import '../rewards/reward_config.dart';
import '../rewards/reward_service.dart';
import '../room/pet_growth.dart';
import '../shop/shop_service.dart';
import 'debug_clock.dart';

/// Các chức năng của menu QA, thao tác trên database của app.
class QaService {
  QaService({required this.db});

  final AppDatabase db;

  /// Id của bé mặc định (tạo nếu chưa có, như lần mở app đầu tiên).
  Future<String> ensureChildId() => db.ensureSeeded();

  // ------------------------------------------------------------------
  // Ngày QA (nhảy sang ngày hôm sau).
  // ------------------------------------------------------------------

  /// Đồng hồ QA đang dùng: gắn [DebugClock] vào database nếu chưa có
  /// (bọc đúng đồng hồ hiện tại của database rồi gán lại — production
  /// không bao giờ tự làm việc này).
  DebugClock _debugClock() {
    final current = db.clock;
    if (current is DebugClock) return current;
    final debug = DebugClock(current);
    db.clock = debug;
    return debug;
  }

  /// Độ lệch ngày hiện tại so với ngày thật (0 nếu chưa nhảy ngày).
  Duration get dayOffset {
    final current = db.clock;
    return current is DebugClock ? current.offset : Duration.zero;
  }

  /// Ngày hiện tại theo đồng hồ QA (`YYYY-MM-DD`, khớp cột `date` của
  /// bảng `daily_sets`).
  String get today => db.clock.today();

  /// Nhảy sang ngày hôm sau (cộng 1 ngày vào độ lệch).
  void advanceOneDay() {
    _debugClock().advanceBy(const Duration(days: 1));
  }

  /// Về lại ngày thật (xóa độ lệch).
  void resetDay() {
    final current = db.clock;
    if (current is DebugClock) current.reset();
  }

  /// Nhảy tới thứ Hai kế tiếp (nếu hôm nay đã là thứ Hai thì sang thứ
  /// Hai tuần sau) để thử rương hạng tuần và chuỗi ngày. Trả số ngày
  /// vừa nhảy.
  int advanceToNextMonday() {
    final weekday = db.clock.now().weekday;
    var days = (DateTime.monday - weekday + 7) % 7;
    if (days == 0) days = 7;
    _debugClock().advanceBy(Duration(days: days));
    return days;
  }

  // ------------------------------------------------------------------
  // Thử mốc pet / đề ngày / nhiệm vụ (dùng cho bản thử).
  // ------------------------------------------------------------------

  /// Đặt xp của pet đang đi theo. Pet đã nở thì đặt luôn giai đoạn
  /// "đã thấy" ngay dưới giai đoạn mới để lần vào Phòng kế tiếp hiện
  /// màn ăn mừng lên lớp. Trả false nếu chưa có pet.
  Future<bool> setActivePetXp(String childId, int xp) async {
    final pet = await PetService(db: db).active(childId);
    if (pet == null) return false;
    final stage = petStageFor(xp: xp, hatched: pet.hatched);
    final seen = switch (stage) {
      PetStage.adult => PetStage.teen,
      _ => PetStage.newborn,
    };
    await db.petsDao.updatePet(
      pet.id,
      PetsCompanion(
        xp: Value(xp),
        stageSeen: pet.hatched ? Value(seen.name) : const Value.absent(),
      ),
    );
    return true;
  }

  /// Cộng [amount] xp cho pet đang đi theo (đường chính của app).
  Future<int?> addPetXp(String childId, int amount) =>
      PetService(db: db).addXp(childId, amount: amount);

  /// Xóa lượt ăn/chơi hôm nay để thử lại tâm trạng pet.
  Future<void> resetPetMoodToday(String childId) => db.settingsDao
      .deleteSetting(childId: childId, key: petCareKey(db.clock.today()));

  /// Cộng [count] suất ăn.
  Future<void> giveMeals(String childId, int count) async {
    final n = await ShopService(db: db).foodCount(childId, petMealId);
    await db.settingsDao.setValue(
      childId: childId,
      key: petFoodCountKey(petMealId),
      value: '${n + count}',
    );
  }

  /// Cho pet-trứng đang đi theo nở ngay (đúng đường chính: đánh dấu
  /// đã nở và xóa cờ chờ nở). Trả false nếu không có trứng chưa nở.
  Future<bool> hatchNow(String childId) async {
    final pet = await PetService(db: db).active(childId);
    if (pet == null || pet.hatched) return false;
    await EggService(db: db).consumeHatchCelebration(childId);
    return true;
  }

  /// Đánh dấu xong cả 5 chặng của đề hôm nay (tạo đề nếu chưa có) và
  /// nhận thưởng xong đề như thường (idempotent).
  Future<void> markDailySetDone(String childId) async {
    final set = await DailySetService(
      dailySetsDao: db.dailySetsDao,
      reviewQueueDao: db.reviewQueueDao,
      customQuestionsDao: db.customQuestionsDao,
      settingsDao: db.settingsDao,
      ladderService: LadderService(
        attemptsDao: db.attemptsDao,
        skillProgressDao: db.skillProgressDao,
      ),
      clock: db.clock,
    ).getOrCreateTodaySet(childId: childId);
    for (var i = 0; i < DailySetConfig.stagesPerDay; i++) {
      await db.dailySetsDao.updateStageStatus(
        id: set.id,
        stageIndex: i,
        status: StageStatus.done,
      );
    }
    await RewardService(
      db: db,
      config: await RewardConfig.load(db),
    ).awardDailyCompleteIfDone(childId: childId, dailySetId: set.id);
    await EggService(db: db).noteStageCompleted(childId);
  }

  /// Xóa dấu đã nhận nhiệm vụ hôm nay (dòng ví có refId nhận nhiệm vụ
  /// và thưởng "đủ cả 3" của hôm nay) để nhận lại. Công cụ QA nên được
  /// phép xóa dòng sổ ví (app thường chỉ thêm). Trả số dòng đã xóa.
  Future<int> clearTodayQuestClaims(String childId) async {
    final date = db.clock.today();
    final quests = await QuestService(db: db).questsFor(childId) ?? const [];
    final refs = <String>[
      for (final q in quests) QuestService.claimRefId(childId, date, q.id),
      QuestService.bonusRefId(childId, date),
    ];
    return (db.delete(
      db.walletLedger,
    )..where((t) => t.childId.equals(childId) & t.refId.isIn(refs))).go();
  }

  // ------------------------------------------------------------------
  // Bậc từng mảng.
  // ------------------------------------------------------------------

  /// Bậc hiện tại của cả 5 mảng (thiếu mảng nào thì bậc 1).
  Future<Map<String, int>> rungs({required String childId}) {
    return LadderService(
      attemptsDao: db.attemptsDao,
      skillProgressDao: db.skillProgressDao,
    ).rungsFor(childId: childId);
  }

  /// Đặt bậc của một mảng (1–6). Ném [ArgumentError] nếu ngoài 1–6.
  Future<void> setRung({
    required String childId,
    required String strand,
    required int rung,
  }) async {
    if (rung < LadderConfig.minRung || rung > LadderConfig.maxRung) {
      throw ArgumentError(
        'Bậc phải từ ${LadderConfig.minRung} đến ${LadderConfig.maxRung}, nhận $rung',
      );
    }
    await db.skillProgressDao.setStrandRung(
      childId: childId,
      strand: strand,
      rung: rung,
    );
  }

  // ------------------------------------------------------------------
  // Sổ ôn tập và lượt trả lời gần nhất (chỉ đọc).
  // ------------------------------------------------------------------

  /// Toàn bộ sổ ôn tập của bé, mục đến hạn sớm nhất trước.
  Future<List<ReviewQueueData>> reviewEntries({required String childId}) {
    return ReviewBookService(
      reviewQueueDao: db.reviewQueueDao,
      clock: db.clock,
    ).allEntries(childId: childId);
  }

  /// Các lượt trả lời gần nhất của bé, mới nhất trước.
  Future<List<Attempt>> recentAttempts({
    required String childId,
    int limit = 20,
  }) {
    return db.attemptsDao.getAttemptsForChild(childId, limit: limit);
  }

  // ------------------------------------------------------------------
  // Xem thử dạng bài (chỉ sinh để xem, không ghi gì vào database).
  // ------------------------------------------------------------------

  /// Sinh một câu của [formId] ở [level] bằng [seed] (ngẫu nhiên nếu
  /// không truyền). Ném [ArgumentError] nếu không có dạng đó hoặc dạng
  /// không hỗ trợ mức đó.
  Question previewQuestion({
    required String formId,
    required int level,
    int? seed,
  }) {
    final generator = questionGeneratorFor(formId);
    if (generator == null) {
      throw ArgumentError('Không có dạng bài nào mang mã $formId');
    }
    return generator.generate(level, Random(seed ?? Random().nextInt(1 << 32)));
  }

  // ------------------------------------------------------------------
  // Xóa dữ liệu.
  // ------------------------------------------------------------------

  /// Xóa toàn bộ dữ liệu về trạng thái mới cài (bé mặc định, bậc 1,
  /// sổ trống, ví trống), rồi đặt lại ngày QA về hôm nay (về ngày
  /// thật trước để dữ liệu gieo lại mang giờ thật).
  Future<void> clearAllData() async {
    resetDay();
    await db.resetForQa();
  }
}
