/// Đề ngày (T1-08): mỗi ngày theo giờ Việt Nam một đề 25 câu.
///
/// Dart thuần, không phụ thuộc widget. Đọc/ghi qua DAO của T1-04
/// (`DailySetsDao`, `ReviewQueueDao`); bậc hiện tại qua `LadderService`
/// của T1-07; ngày/giờ qua `Clock`.
///
/// Cấu trúc đề (PLAN mục T1-08): 5 chặng theo 5 mảng, mỗi chặng 5 câu.
/// Câu 1 và 2 thấp hơn bậc hiện tại một bậc (không dưới bậc 1), câu 3
/// đúng bậc, câu 4 lấy từ sổ ôn tập nếu đến hạn (nếu không thì đúng
/// bậc), câu 5 cao hơn một bậc (không quá bậc 6). Mức và kiểu trả lời
/// của mỗi câu lấy từ bậc qua `LadderConfig`.
///
/// Đề được lưu vào `daily_sets` ngay khi tạo nên tắt app giữa chừng mở
/// lại vẫn đúng câu đang làm: [getOrCreateTodaySet] trả lại đề đã lưu
/// thay vì sinh đề mới. Sang ngày mới (0 giờ Việt Nam) thì tạo đề mới.
///
/// [DailySetQuestion.answerType] lưu trong đề là kiểu HIỂN THỊ của câu:
/// theo bậc (bậc lẻ trắc nghiệm, bậc chẵn điền số), trừ dạng `choiceOnly`
/// luôn là trắc nghiệm ở mọi bậc. Màn làm toán (T1-09) vẽ giao diện theo
/// kiểu này, không theo `Question.answerType` thô của generator.
library;

import 'dart:math';

import '../../core/database/app_database.dart';
import '../../core/database/daos.dart';
import '../../core/database/models.dart';
import '../../core/database/tables.dart' hide AnswerType;
import '../../core/time/clock.dart';
import '../ladder/ladder_config.dart';
import '../ladder/ladder_service.dart';
import '../questions/question.dart';
import '../questions/question_registry.dart';
import 'daily_set_config.dart';

/// Chọn dạng bài cho một ô trong chặng (luật chọn dạng, thuần túy).
///
/// Thứ tự ưu tiên (xem `docs/DECISIONS.md` mục T1-08 — điểm chờ
/// Claude chốt):
/// 1. Đúng mức trước: chỉ xét các dạng hỗ trợ đúng mức của ô.
/// 2. Chưa dùng trong chặng trước: không lặp dạng nếu mảng còn dạng khác;
///    trong các dạng chưa dùng, ưu tiên dạng ít gặp nhất trong 7 ngày qua.
/// 3. Đúng kiểu sau: trong các dạng còn lại, ưu tiên dạng điền số được
///    khi ô cần điền số; dạng `choiceOnly` chỉ dùng khi không còn dạng
///    điền số nào (ô trắc nghiệm thì mọi dạng như nhau).
/// 4. Hết dạng mới thì lặp lại dạng ít gặp nhất trong 7 ngày qua
///    (mục (g)); hòa nhau thì ngẫu nhiên.
class StageFormPicker {
  const StageFormPicker();

  /// Chọn một `formId` trong [candidates] (các dạng hỗ trợ đúng mức).
  ///
  /// [usedFormIds] là các dạng đã dùng trong chặng này (kể cả dạng ôn
  /// tập đã giữ ở câu 4). [usageLast7Days] đếm số lần mỗi dạng đã xuất
  /// hiện trong các đề ngày của bé 7 ngày qua (thiếu thì coi như 0).
  String pick({
    required List<QuestionGenerator> candidates,
    required Set<String> usedFormIds,
    required AnswerType neededType,
    required Map<String, int> usageLast7Days,
    required Random random,
  }) {
    assert(candidates.isNotEmpty, 'Không có dạng nào hỗ trợ mức này');

    /// Trong [forms], ưu tiên dạng điền số được khi ô cần điền số;
    /// nếu không còn dạng điền số nào thì giữ nguyên cả danh sách.
    List<QuestionGenerator> preferNumberCapable(List<QuestionGenerator> forms) {
      if (neededType != AnswerType.number) return forms;
      final numberCapable = forms
          .where((g) => !DailySetConfig.isChoiceOnly(g.formId))
          .toList();
      return numberCapable.isNotEmpty ? numberCapable : forms;
    }

    final fresh = preferNumberCapable(
      candidates.where((g) => !usedFormIds.contains(g.formId)).toList(),
    );
    if (fresh.isNotEmpty) {
      // Trong các dạng mới, ưu tiên dạng bé ít gặp nhất 7 ngày qua để
      // các dạng được xoay vòng đều, bé không gặp lại mãi vài dạng quen.
      final freshMin = fresh
          .map((g) => usageLast7Days[g.formId] ?? 0)
          .reduce(min);
      final freshLeast = fresh
          .where((g) => (usageLast7Days[g.formId] ?? 0) == freshMin)
          .toList();
      return freshLeast[random.nextInt(freshLeast.length)].formId;
    }

    // Hết dạng mới: lặp dạng ít gặp nhất trong 7 ngày qua, ưu tiên
    // dạng điền số được khi ô cần điền số; hòa nhau thì ngẫu nhiên.
    final repeatPool = preferNumberCapable(candidates);
    final minUsage = repeatPool
        .map((g) => usageLast7Days[g.formId] ?? 0)
        .reduce(min);
    final least = repeatPool
        .where((g) => (usageLast7Days[g.formId] ?? 0) == minUsage)
        .toList();
    return least[random.nextInt(least.length)].formId;
  }
}

/// Sinh và lưu đề ngày, cộng chặng tự chọn sau khi xong đề ngày.
class DailySetService {
  DailySetService({
    required this._dailySetsDao,
    required this._reviewQueueDao,
    required this._ladderService,
    required this._clock,
    Random? random,
  }) : _random = random ?? Random();

  final DailySetsDao _dailySetsDao;
  final ReviewQueueDao _reviewQueueDao;
  final LadderService _ladderService;

  /// Đồng hồ của app (giờ Việt Nam). Phải là cùng một `Clock` mà
  /// database dùng để ghi `createdAt`, để test dùng `FakeClock`
  /// điều khiển được cả hai.
  final Clock _clock;
  final Random _random;

  static const _picker = StageFormPicker();

  /// Đề ngày hôm nay: có rồi thì trả lại đề đã lưu (kể cả trạng thái
  /// chặng đã đổi sau khi bé làm), chưa có thì tạo mới, lưu ngay vào
  /// `daily_sets` rồi trả lại. Sang ngày mới (0 giờ Việt Nam) thì
  /// [Clock.today] đổi nên đề hôm qua không còn khớp, tự tạo đề mới.
  Future<DailySet> getOrCreateTodaySet({required String childId}) async {
    final today = _clock.today();
    final existing = await _dailySetsDao.getDailySet(childId, today);
    if (existing != null) return existing;
    final questions = await _buildDailyQuestions(childId: childId);
    await _dailySetsDao.createDailySet(
      childId: childId,
      date: today,
      questions: questions,
    );
    final created = await _dailySetsDao.getDailySet(childId, today);
    return created!;
  }

  /// Sinh thêm một chặng tự chọn cho mảng [strand] (bé làm sau khi
  /// xong đề ngày, không giới hạn số chặng). Cùng cấu trúc 5 câu như
  /// chặng trong đề ngày (kể cả câu ôn tập nếu đến hạn), nhưng KHÔNG
  /// lưu vào `daily_sets`: mỗi lần gọi sinh mới. Lượt trả lời ở chặng
  /// này ghi vào `attempts` với `daily_set_id`/`stage` để trống
  /// (theo schema T1-04).
  Future<List<DailySetQuestion>> buildExtraStage({
    required String childId,
    required String strand,
  }) async {
    if (!Strand.all.contains(strand)) {
      throw ArgumentError('Không có mảng nào mang mã $strand');
    }
    final rung = await _ladderService.rungFor(childId: childId, strand: strand);
    final usage = await _formUsageLast7Days(childId: childId);
    final dueByStrand = await _dueReviewByStrand(childId: childId);
    return _buildStage(
      strand: strand,
      rung: rung,
      reviewEntry: dueByStrand[strand],
      usageLast7Days: usage,
    );
  }

  /// Sinh [DailySetConfig.questionsPerStage] câu cho một tầng tháp của
  /// mảng [strand] (tuần 23/11, mục A): TẤT CẢ câu cùng bậc [rung]
  /// (bậc của tầng, xem `TowerConfig.rungForFloor`), không có câu ôn
  /// tập. Kiểu trả lời theo bậc như thang ải. Không lưu vào
  /// `daily_sets`; mỗi lần gọi sinh câu mới nên thử lại tầng luôn có
  /// câu mới.
  Future<List<DailySetQuestion>> buildTowerFloor({
    required String childId,
    required String strand,
    required int rung,
  }) async {
    if (!Strand.all.contains(strand)) {
      throw ArgumentError('Không có mảng nào mang mã $strand');
    }
    final usage = await _formUsageLast7Days(childId: childId);
    final level = LadderConfig.levelForRung(rung);
    final answerType = LadderConfig.answerTypeForRung(rung);
    final usedFormIds = <String>{};
    final questions = <DailySetQuestion>[];
    for (var i = 0; i < DailySetConfig.questionsPerStage; i++) {
      var useLevel = level;
      var candidates = _formsSupporting(strand, useLevel);
      if (candidates.isEmpty) {
        useLevel = _nearestLevelWithForms(strand, useLevel);
        candidates = _formsSupporting(strand, useLevel);
      }
      final formId = _picker.pick(
        candidates: candidates,
        usedFormIds: usedFormIds,
        neededType: answerType,
        usageLast7Days: usage,
        random: _random,
      );
      usedFormIds.add(formId);
      questions.add(
        _makeQuestion(
          formId: formId,
          strand: strand,
          level: useLevel,
          rung: rung,
          answerType: answerType,
        ),
      );
    }
    return questions;
  }

  /// Sinh 25 câu của đề ngày: 5 chặng theo thứ tự 5 mảng
  /// ([Strand.all]); bé chọn thứ tự chặng tùy ý là việc của giao diện
  /// (T1-09), thứ tự lưu ở đây chỉ là thứ tự mặc định.
  Future<List<DailySetQuestion>> _buildDailyQuestions({
    required String childId,
  }) async {
    final rungs = await _ladderService.rungsFor(childId: childId);
    final usage = await _formUsageLast7Days(childId: childId);
    final dueByStrand = await _dueReviewByStrand(childId: childId);
    final questions = <DailySetQuestion>[];
    for (final strand in Strand.all) {
      questions.addAll(
        _buildStage(
          strand: strand,
          rung: rungs[strand] ?? LadderConfig.initialRung,
          reviewEntry: dueByStrand[strand],
          usageLast7Days: usage,
        ),
      );
    }
    return questions;
  }

  /// Các mục sổ ôn tập đến hạn, mỗi mảng giữ một mục (mục đến hạn sớm
  /// nhất). Chỉ giữ mục mà dạng của nó hỗ trợ mức của bậc đã lưu
  /// trong sổ (câu ôn tập dùng bậc này — mục (g)); mục không đủ điều
  /// kiện thì bỏ qua để mục đến hạn sau của cùng mảng còn cơ hội.
  Future<Map<String, ReviewQueueData>> _dueReviewByStrand({
    required String childId,
  }) async {
    final due = await _reviewQueueDao.getDueEntries(
      childId: childId,
      now: _clock.now(),
    );
    final byStrand = <String, ReviewQueueData>{};
    for (final entry in due) {
      final generator = questionGeneratorFor(entry.formId);
      if (generator == null) continue;
      if (!generator.supportedLevels.contains(
        LadderConfig.levelForRung(entry.rung),
      )) {
        continue;
      }
      byStrand.putIfAbsent(generator.topic, () => entry);
    }
    return byStrand;
  }

  /// Số lần mỗi dạng đã xuất hiện trong các đề ngày của bé 7 ngày qua
  /// (tính cả đề hôm nay nếu đã có — chặng tự chọn sinh sau đề ngày
  /// cũng tính đề hôm nay vào lịch sử). Đếm từ đề đã lưu, không đếm
  /// `attempts`, vì "gặp" ở đây nghĩa là dạng đã xuất hiện trong đề.
  Future<Map<String, int>> _formUsageLast7Days({
    required String childId,
  }) async {
    final today = _clock.today();
    final now = _clock.now();
    final fromDate = _dateString(
      DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: DailySetConfig.recentDaysForLeastSeen)),
    );
    final usage = <String, int>{};
    for (final set in await _dailySetsDao.getDailySetsForChild(childId)) {
      if (set.date.compareTo(fromDate) < 0 || set.date.compareTo(today) > 0) {
        continue;
      }
      for (final question in _dailySetsDao.readQuestions(set)) {
        usage[question.formId] = (usage[question.formId] ?? 0) + 1;
      }
    }
    return usage;
  }

  static String _dateString(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Sinh 5 câu của một chặng theo bậc hiện tại [rung] của mảng.
  /// Bậc từng ô: [rung - 1, rung - 1, rung, rung ôn tập, rung + 1],
  /// kẹp trong 1–6. Dạng ôn tập (nếu có) được giữ trước nên các ô
  /// khác tự tránh dạng đó (mục (g): giữ câu ôn tập, đổi dạng câu kia).
  List<DailySetQuestion> _buildStage({
    required String strand,
    required int rung,
    required ReviewQueueData? reviewEntry,
    required Map<String, int> usageLast7Days,
  }) {
    final slotRungs = <int>[
      max(LadderConfig.minRung, rung - 1),
      max(LadderConfig.minRung, rung - 1),
      rung,
      reviewEntry?.rung ?? rung,
      min(LadderConfig.maxRung, rung + 1),
    ];
    final usedFormIds = <String>{};
    if (reviewEntry != null) {
      usedFormIds.add(reviewEntry.formId);
    }
    final questions = <DailySetQuestion>[];
    for (var i = 0; i < DailySetConfig.questionsPerStage; i++) {
      final slotRung = slotRungs[i];
      var level = LadderConfig.levelForRung(slotRung);
      final answerType = LadderConfig.answerTypeForRung(slotRung);
      if (i == DailySetConfig.reviewSlotIndex && reviewEntry != null) {
        questions.add(
          _makeQuestion(
            formId: reviewEntry.formId,
            strand: strand,
            level: level,
            rung: slotRung,
            answerType: answerType,
            isReview: true,
          ),
        );
        continue;
      }
      var candidates = _formsSupporting(strand, level);
      if (candidates.isEmpty) {
        // Phòng thủ: nội dung thiếu dạng ở mức này thì lấy mức gần
        // nhất còn dạng (ưu tiên mức thấp hơn), ghi đúng mức đã lấy.
        // Test phủ dạng bảo vệ để trường hợp này không xảy ra với
        // 48 dạng hiện tại.
        level = _nearestLevelWithForms(strand, level);
        candidates = _formsSupporting(strand, level);
      }
      final formId = _picker.pick(
        candidates: candidates,
        usedFormIds: usedFormIds,
        neededType: answerType,
        usageLast7Days: usageLast7Days,
        random: _random,
      );
      usedFormIds.add(formId);
      questions.add(
        _makeQuestion(
          formId: formId,
          strand: strand,
          level: level,
          rung: slotRung,
          answerType: answerType,
        ),
      );
    }
    return questions;
  }

  DailySetQuestion _makeQuestion({
    required String formId,
    required String strand,
    required int level,
    required int rung,
    required AnswerType answerType,
    bool isReview = false,
  }) {
    // Dạng choiceOnly luôn hiển thị trắc nghiệm dù bậc của ô là chẵn.
    final displayType = DailySetConfig.isChoiceOnly(formId)
        ? AnswerType.choice
        : answerType;
    return DailySetQuestion(
      formId: formId,
      strand: strand,
      level: level,
      rung: rung,
      answerType: displayType.name,
      isReview: isReview,
      seed: _random.nextInt(1 << 31),
    );
  }

  /// Các dạng của [strand] hỗ trợ [level].
  List<QuestionGenerator> _formsSupporting(String strand, int level) =>
      allQuestionGenerators
          .where((g) => g.topic == strand && g.supportedLevels.contains(level))
          .toList();

  /// Mức gần [level] nhất mà [strand] còn dạng (ưu tiên mức thấp hơn
  /// khi cách đều). Ném [StateError] nếu mảng không có dạng nào.
  int _nearestLevelWithForms(String strand, int level) {
    for (final offset in const [1, 2]) {
      for (final candidate in [level - offset, level + offset]) {
        if (candidate < 1 || candidate > 3) continue;
        if (_formsSupporting(strand, candidate).isNotEmpty) {
          return candidate;
        }
      }
    }
    throw StateError('Mảng $strand không có dạng bài nào');
  }
}
