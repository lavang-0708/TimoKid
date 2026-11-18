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

import '../../core/database/app_database.dart';
import '../../core/database/daos.dart';
import '../ladder/ladder_config.dart';
import '../ladder/ladder_service.dart';
import '../questions/question.dart';
import '../questions/question_registry.dart';
import '../review_book/review_book_service.dart';
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
