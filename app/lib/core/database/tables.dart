/// 7 bảng Drift của bản 0.1 (theo `docs/PLAN.md` mục T1-04 và mục (e)).
///
/// Quy ước chung cho mọi bảng (PLAN, mục "Chất lượng code"):
/// mỗi dòng có `id` dạng UUID, `created_at`, `updated_at` và cờ `synced`
/// (để bản 0.3 gắn đồng bộ). Ngoại lệ duy nhất: bảng `children` không có
/// cột `child_id` (nó chính là hồ sơ bé), bù lại có `family_id` để trống
/// tới bản 0.3.
///
/// `attempts` và `wallet_ledger` chỉ thêm dòng, không sửa, không xóa:
/// DAO của hai bảng này không có hàm sửa/xóa, và database còn chặn bằng
/// trigger SQLite (xem `app_database.dart`).
library;

import 'package:drift/drift.dart';

/// 5 mảng TIMO. `formId` của dạng bài luôn bắt đầu bằng tiền tố mảng
/// (vd: `logic.balance`), nhưng cột `strand` riêng giúp T1-07 truy vấn
/// theo mảng mà không phải tách chuỗi.
class Strand {
  static const logic = 'logic';
  static const arith = 'arith';
  static const number = 'number';
  static const geo = 'geo';
  static const comb = 'comb';

  static const all = [logic, arith, number, geo, comb];
}

/// Kiểu trả lời của một câu: trắc nghiệm 4 lựa chọn hoặc điền số.
/// Do bậc của câu quyết định (bậc lẻ trắc nghiệm, bậc chẵn điền số),
/// trừ các dạng `choiceOnly` luôn là trắc nghiệm.
class AnswerType {
  static const choice = 'choice';
  static const number = 'number';
}

/// Loại tiền trong ví: xu mua đồ thường, kim cương mua đồ hiếm và pet mới.
class Currency {
  static const xu = 'xu';
  static const gem = 'gem';
}

/// Phạm vi của một dòng `skill_progress`: bậc theo mảng, hoặc trạng thái
/// thành thạo theo dạng bài.
class SkillScope {
  static const strand = 'strand';
  static const form = 'form';
}

/// Hồ sơ từng bé: tên, lớp, nhân vật đã tạo (nhân vật làm ở T2-03).
/// Không có cột `child_id`. `family_id` để trống tới bản 0.3.
class Children extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  /// Lớp của bé (bản 0.1: lớp 2). Thang ải 6 bậc không vượt quá lớp này.
  IntColumn get grade => integer().withDefault(const Constant(2))();

  /// Tài khoản phụ huynh, để trống tới bản 0.3.
  TextColumn get familyId => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mỗi lượt trả lời: dạng bài, mức, đúng hay sai, số lần thử, thời gian.
/// Chỉ thêm dòng, không sửa, không xóa.
class Attempts extends Table {
  TextColumn get id => text()();

  TextColumn get childId => text()();

  /// Dạng bài, vd: `logic.balance`.
  TextColumn get formId => text()();

  /// Mảng của dạng bài (`logic`, `arith`, `number`, `geo`, `comb`).
  TextColumn get strand => text()();

  /// Mức nội dung của câu: 1 Dễ, 2 Vừa, 3 Khó.
  IntColumn get level => integer()();

  /// Bậc của câu trong thang ải 1–6 (ghép mức + kiểu trả lời).
  IntColumn get rung => integer()();

  /// Kiểu trả lời: `choice` (trắc nghiệm) hoặc `number` (điền số).
  TextColumn get answerType => text()();

  /// Đúng ngay lần đầu hay không. Mọi luật lên/xuống bậc và thành thạo
  /// chỉ tính "đúng ngay lần đầu" (PLAN mục (f)).
  BoolColumn get correctFirstTry => boolean()();

  /// Số lần thử của lượt này: 1 (đúng ngay) hoặc 2 (đúng sau gợi ý
  /// hoặc sai cả hai lần).
  IntColumn get attemptsCount => integer()();

  /// Thời gian bé làm câu này, tính bằng mili-giây.
  IntColumn get durationMs => integer()();

  /// Câu này có phải câu ôn tập từ sổ (`review_queue`) không.
  /// Câu ôn tập được gấp đôi xu (T1-11).
  BoolColumn get isReview => boolean().withDefault(const Constant(false))();

  /// Đề ngày chứa câu này, để trống nếu là chặng tự chọn.
  TextColumn get dailySetId => text().nullable()();

  /// Chặng 1–5 trong đề ngày, để trống nếu là chặng tự chọn.
  IntColumn get stage => integer().nullable()();

  /// Seed sinh câu (để tái hiện lại đúng câu hỏi khi cần tra cứu).
  IntColumn get questionSeed => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mức hiện tại theo mảng và trạng thái thành thạo theo dạng bài.
/// Một bảng, hai loại dòng phân biệt bằng `scope`:
/// - `scope = 'strand'`, `key` = mã mảng: `rung` là bậc hiện tại (1–6),
///   `windowStartedAt` là mốc bắt đầu cửa sổ 10 câu mới sau lần đổi bậc
///   gần nhất (PLAN mục (f)).
/// - `scope = 'form'`, `key` = `formId`: `mastered` + `masteredAt` ghi
///   trạng thái thành thạo (đúng ngay 4/5 câu gần nhất ở mức cao nhất
///   dạng hỗ trợ, không thấp hơn Vừa — PLAN mục (b)).
class SkillProgress extends Table {
  TextColumn get id => text()();

  TextColumn get childId => text()();

  TextColumn get scope => text()();

  /// Mã mảng (`logic`, ...) nếu scope là `strand`;
  /// `formId` nếu scope là `form`.
  TextColumn get key => text()();

  /// Bậc hiện tại 1–6, chỉ có nghĩa với dòng `strand`.
  IntColumn get rung => integer().nullable()();

  /// Đã thành thạo hay chưa, chỉ có nghĩa với dòng `form`.
  BoolColumn get mastered => boolean().withDefault(const Constant(false))();

  DateTimeColumn get masteredAt => dateTime().nullable()();

  /// Mốc bắt đầu cửa sổ 10 câu sau lần đổi bậc gần nhất.
  DateTimeColumn get windowStartedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {childId, scope, key},
  ];
}

/// Sổ ôn tập: dạng bài, ngày hỏi lại, số lần đã đúng.
/// Một dạng bài chỉ có một mục trong sổ (unique theo `child_id` + `form_id`).
/// Hỏi lại sau 1, 3 và 7 ngày; đúng ngay đủ 3 lần thì ra khỏi sổ,
/// sai thì quay lại mốc 1 ngày (T1-10).
class ReviewQueue extends Table {
  TextColumn get id => text()();

  TextColumn get childId => text()();

  TextColumn get formId => text()();

  /// Bậc đã lưu của dạng bài lúc vào sổ; câu ôn tập (câu 4 của chặng)
  /// dùng bậc này (PLAN mục (g)).
  IntColumn get rung => integer()();

  /// Ngày hỏi lại (giờ Việt Nam).
  DateTimeColumn get dueDate => dateTime()();

  /// Số lần đã đúng ngay lần đầu liên tiếp (0–3). Đủ 3 thì xóa mục.
  IntColumn get correctStreak => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {childId, formId},
  ];
}

/// Đề từng ngày và tiến độ 5 chặng.
/// `questions` là JSON: danh sách 25 câu theo đúng thứ tự chặng, mỗi câu
/// gồm `formId`, `strand`, `level`, `rung`, `answerType`, `isReview`,
/// `seed` (xem [DailySetQuestion] trong `models.dart`).
/// `stageStatus` là JSON: danh sách 5 trạng thái chặng
/// (`not_started`, `in_progress`, `done`).
/// Đề được lưu lại khi tạo nên tắt app giữa chừng mở lại vẫn đúng câu
/// đang làm (T1-08). Một bé chỉ có một đề mỗi ngày.
class DailySets extends Table {
  TextColumn get id => text()();

  TextColumn get childId => text()();

  /// Ngày của đề, dạng `YYYY-MM-DD` theo giờ Việt Nam.
  TextColumn get date => text()();

  /// JSON: 25 câu của đề.
  TextColumn get questions => text()();

  /// JSON: trạng thái 5 chặng.
  TextColumn get stageStatus => text()();

  /// Đã xong cả 5 chặng hay chưa.
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  DateTimeColumn get completedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {childId, date},
  ];
}

/// Mọi lần cộng trừ xu và kim cương, kèm lý do.
/// Chỉ thêm dòng, không sửa, không xóa. Số dư = tổng cột `amount`
/// theo từng loại tiền (xem `WalletDao.balance`).
/// `amount` dương là cộng, âm là trừ (vd: mua đồ ở T2-06).
class WalletLedger extends Table {
  TextColumn get id => text()();

  TextColumn get childId => text()();

  /// Loại tiền: `xu` hoặc `gem`.
  TextColumn get currency => text()();

  /// Số tiền cộng/trừ, có dấu.
  IntColumn get amount => integer()();

  /// Lý do, vd: `answer_first_try`, `answer_after_hint`, `review`,
  /// `stage_complete`, `daily_complete`, `mastery`, `purchase`.
  TextColumn get reason => text()();

  /// Dòng liên quan, vd: id của `attempts` hoặc `daily_sets`.
  TextColumn get refId => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Món đồ bé đã sở hữu (T2-06, schema v2). Một dòng là một món của một
/// bé; `item_id` là mã món trong danh mục cửa hàng (`shop_catalog.dart`,
/// vd `girl_top_02`, `head_hat`). Không mua trùng: unique (child_id,
/// item_id). `source`: `shop` (mua), `starter` (bộ đồ chọn ở mở đầu),
/// `grandfather` (máy cài trước bản có cửa hàng: đồ đang mặc được giữ).
class Inventory extends Table {
  TextColumn get id => text()();

  TextColumn get childId => text()();

  TextColumn get itemId => text()();

  DateTimeColumn get acquiredAt => dateTime()();

  /// Nguồn có món: `shop`, `starter` hoặc `grandfather`.
  TextColumn get source => text()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {childId, itemId},
  ];
}

/// Mức thưởng, khóa mức khó và các cài đặt khác.
/// Một dòng là một khóa: `key` + `value` (JSON, để lưu được mọi kiểu:
/// số, chuỗi, danh sách, map). `child_id` để trống (null) nghĩa là
/// cài đặt chung cho cả app; có `child_id` nghĩa là cài đặt riêng của bé.
/// Hạt giống mặc định (bảng thưởng T1-11, âm thanh) xem `ensureSeeded`.
class Settings extends Table {
  TextColumn get id => text()();

  /// null = cài đặt chung; có giá trị = cài đặt riêng của bé đó.
  TextColumn get childId => text().nullable()();

  TextColumn get key => text()();

  /// Giá trị dạng JSON.
  TextColumn get value => text()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mỗi bài thi Đấu trường đã nộp (T2-10, schema v3): ngày thi, số câu
/// đúng, điểm, huy chương, thời gian làm, kim cương đã thưởng. Bài bỏ
/// dở (thoát giữa chừng) không được lưu. Không lưu đáp án từng câu:
/// bé và phụ huynh chỉ cần kết quả (yêu cầu chủ dự án).
class ArenaAttempts extends Table {
  TextColumn get id => text()();

  TextColumn get childId => text()();

  /// Ngày thi, dạng `YYYY-MM-DD` theo giờ Việt Nam.
  TextColumn get date => text()();

  /// Vòng thi: `heat` (vòng Chọn 25 câu) hoặc `final` (Chung kết).
  TextColumn get mode => text().withDefault(const Constant('heat'))();

  /// Số câu đúng.
  IntColumn get correctCount => integer()();

  /// Điểm (đúng x điểm mỗi câu).
  IntColumn get score => integer()();

  /// Huy chương: `gold`, `silver`, `bronze`, `participant`.
  TextColumn get medal => text()();

  /// Thời gian làm bài, giây.
  IntColumn get durationSec => integer()();

  /// Kim cương thưởng cho bài này (0 nếu hôm đó đã nhận thưởng).
  IntColumn get gemsAwarded => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Pet của bé (D, schema v4). Một dòng là một pet (trứng hoặc đã nở).
/// Mỗi bé chỉ có TỐI ĐA một pet mỗi loài (unique child_id + species) và
/// ĐÚNG MỘT pet `active` (đi theo bé; chỉ mục unique từng phần
/// `pets_one_active` chặn hai pet active ở tầng SQLite).
/// `xp` = số câu đúng ngay lần đầu tích lũy khi pet đi theo (quyết định
/// giai đoạn, xem `pet_growth.dart`); `stage_seen` = giai đoạn bé đã
/// thấy lần cuối (`egg`/`newborn`/`teen`/`adult`), để chiếu màn ăn mừng
/// khi pet lớn hơn.
class Pets extends Table {
  TextColumn get id => text()();

  TextColumn get childId => text()();

  /// Mã loài: `dog`, `cat`, `rabbit`, `squirrel`, `capybara`, `dragon`.
  TextColumn get species => text()();

  IntColumn get xp => integer().withDefault(const Constant(0))();

  TextColumn get stageSeen => text().withDefault(const Constant('egg'))();

  /// Đã nở khỏi trứng chưa.
  BoolColumn get hatched => boolean().withDefault(const Constant(false))();

  /// Pet đang đi theo bé (đúng một pet mỗi bé).
  BoolColumn get active => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {childId, species},
  ];
}
