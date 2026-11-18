/// Phiên làm một chặng (5 câu) của màn làm toán (T1-09).
///
/// Dart thuần, không phụ thuộc widget: màn hình ([MathScreen]) chỉ vẽ
/// theo trạng thái ở đây và gọi các hàm trả lời. Logic này cũng là thứ
/// test (widget/integration) dùng để tính đáp án đúng.
///
/// Một câu trong chặng được sinh lại từ [DailySetQuestion.seed] qua bộ
/// sinh câu của T1-05 nên đúng y câu trong đề đã lưu. Kiểu hiển thị
/// lấy theo [DailySetQuestion.answerType] lưu trong đề (mục ghi chú
/// của Claude), không theo `Question.answerType` thô của generator.
/// Trắc nghiệm trộn thứ tự lựa chọn xác định theo seed nên test tính
/// lại được vị trí đáp án đúng trên màn hình.
///
/// Mỗi câu đã giải quyết (đúng lần 1, đúng sau gợi ý, hoặc sai cả hai
/// lần) ghi đúng một dòng `attempts` (số lần thử, đúng ngay lần đầu,
/// thời gian làm), rồi gọi `LadderService.evaluateStrand` và
/// `evaluateFormMastery` để cập nhật bậc/thành thạo, và ghi sổ ôn tập
/// qua `ReviewBookService` (câu thường → `recordAnswer`, câu ôn tập →
/// `recordReviewAnswer`). Xu cộng vào `wallet_ledger` qua `WalletDao`
/// theo [RewardConfig].
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos.dart';
import '../../core/database/models.dart';
import '../../core/database/tables.dart' hide AnswerType;
import '../ladder/ladder_service.dart';
import '../questions/question.dart';
import '../questions/question_registry.dart';
import '../review_book/review_book_service.dart';
import '../rewards/reward_config.dart';

/// Tên tiếng Việt của từng mảng, hiện trên thanh tiêu đề màn làm toán
/// và màn kết quả chặng.
const Map<String, String> strandNames = {
  Strand.logic: 'Lôgic',
  Strand.arith: 'Số học',
  Strand.number: 'Con số',
  Strand.geo: 'Hình học',
  Strand.comb: 'Tổ hợp',
};

/// Trạng thái trả lời của câu hiện tại.
enum QuestionState {
  /// Đang chờ bé trả lời (lần 1, hoặc lần 2 sau gợi ý).
  answering,

  /// Sai lần đầu: đã hiện gợi ý, bé làm lại.
  hint,

  /// Sai lần hai: đã hiện lời giải từng bước.
  solution,

  /// Đã trả lời đúng (lần 1 hoặc lần 2).
  correct,
}

/// Thứ tự hiển thị các lựa chọn của một câu trắc nghiệm, trộn xác định
/// theo seed của câu. Vị trí hiển thị `i` cho thấy lựa chọn gốc
/// `order[i]`; vị trí đáp án đúng là `order.indexOf(question.answer)`.
List<int> shuffledChoiceOrder(Question question, int seed) {
  final order = List<int>.generate(question.choices.length, (i) => i)
    ..shuffle(Random(seed));
  return order;
}

/// Một câu trong chặng đã sinh lại xong từ seed, sẵn sàng hiển thị.
///
/// Kiểu hiển thị lấy theo đề đã lưu. Dạng thường của generator luôn
/// sinh đáp án số (xem DECISIONS mục T1-08) nên ô trắc nghiệm của dạng
/// thường không có sẵn lựa chọn: 4 lựa chọn hiển thị được dựng từ đáp
/// án đúng + 3 đáp án nhiễu của câu, trộn xác định theo seed. Dạng
/// `choiceOnly` thì dùng đúng các lựa chọn song ngữ của generator,
/// cũng trộn theo seed.
class ResolvedQuestion {
  ResolvedQuestion._({
    required this.spec,
    required this.question,
    required this.choiceTextsVi,
    required this.choiceTextsEn,
    required this.correctDisplayIndex,
  });

  factory ResolvedQuestion.resolve(DailySetQuestion spec) {
    final generator = questionGeneratorFor(spec.formId);
    if (generator == null) {
      throw ArgumentError('Không có dạng bài nào mang mã ${spec.formId}');
    }
    final question = generator.generate(spec.level, Random(spec.seed ?? 0));
    final displayType = AnswerType.values.byName(spec.answerType);
    if (displayType != AnswerType.choice) {
      return ResolvedQuestion._(
        spec: spec,
        question: question,
        choiceTextsVi: const <String>[],
        choiceTextsEn: const <String>[],
        correctDisplayIndex: -1,
      );
    }
    final seed = spec.seed ?? 0;
    if (question.choices.isNotEmpty) {
      final order = shuffledChoiceOrder(question, seed);
      return ResolvedQuestion._(
        spec: spec,
        question: question,
        choiceTextsVi: [for (final i in order) question.choices[i].vi],
        choiceTextsEn: [for (final i in order) question.choices[i].en],
        correctDisplayIndex: order.indexOf(question.answer),
      );
    }
    final pool = <int>[question.answer, ...question.distractors]
      ..shuffle(Random(seed));
    final texts = pool.map((n) => '$n').toList();
    return ResolvedQuestion._(
      spec: spec,
      question: question,
      choiceTextsVi: texts,
      choiceTextsEn: texts,
      correctDisplayIndex: pool.indexOf(question.answer),
    );
  }

  final DailySetQuestion spec;
  final Question question;

  /// Các lựa chọn hiển thị, theo thứ tự đã trộn (chỉ câu trắc nghiệm).
  /// Dạng `choiceOnly` là chữ song ngữ; dạng thường là các số.
  final List<String> choiceTextsVi;
  final List<String> choiceTextsEn;

  /// Vị trí hiển thị của lựa chọn đúng (chỉ câu trắc nghiệm).
  final int correctDisplayIndex;

  /// Kiểu hiển thị của câu, theo đề đã lưu.
  AnswerType get displayType => AnswerType.values.byName(spec.answerType);

  /// Số lựa chọn hiển thị (chỉ câu trắc nghiệm).
  int get choiceCount => choiceTextsVi.length;
}

/// Trạng thái và logic của một chặng đang làm. Màn hình đăng ký
/// listener (qua [ChangeNotifier]) để vẽ lại khi trạng thái đổi.
class StageSession extends ChangeNotifier {
  StageSession({
    required AppDatabase db,
    required this.childId,
    required this.dailySetId,
    required this.stageIndex,
    required List<DailySetQuestion> questions,
  }) : _db = db,
       _attemptsDao = db.attemptsDao,
       _walletDao = db.walletDao,
       _ladder = LadderService(
         attemptsDao: db.attemptsDao,
         skillProgressDao: db.skillProgressDao,
       ),
       _reviewBook = ReviewBookService(
         reviewQueueDao: db.reviewQueueDao,
         clock: db.clock,
       ),
       resolved = questions.map(ResolvedQuestion.resolve).toList() {
    _questionStartedAt = _db.clock.now();
  }

  final AppDatabase _db;
  final AttemptsDao _attemptsDao;
  final WalletDao _walletDao;
  final LadderService _ladder;
  final ReviewBookService _reviewBook;

  final String childId;

  /// Id đề ngày chứa chặng này; null với chặng tự chọn (T1-08).
  final String? dailySetId;

  /// Chỉ số chặng trong đề ngày (0–4); -1 với chặng tự chọn.
  final int stageIndex;

  /// 5 câu của chặng, đã sinh lại xong.
  final List<ResolvedQuestion> resolved;

  int currentIndex = 0;
  QuestionState state = QuestionState.answering;
  int triesUsed = 0;
  String typedAnswer = '';
  int? selectedDisplayIndex;
  int? lastEarnedXu;
  int correctCount = 0;
  int firstTryCorrectCount = 0;
  int xuEarned = 0;
  bool finished = false;

  late DateTime _questionStartedAt;

  ResolvedQuestion get current => resolved[currentIndex];

  bool get isLastQuestion => currentIndex == resolved.length - 1;

  /// Ghi trạng thái chặng là đang làm (chỉ chặng trong đề ngày).
  Future<void> markStageInProgress() async {
    if (dailySetId == null) return;
    await _db.dailySetsDao.updateStageStatus(
      id: dailySetId!,
      stageIndex: stageIndex,
      status: StageStatus.inProgress,
    );
  }

  void appendDigit(String digit) {
    if (finished ||
        (state != QuestionState.answering && state != QuestionState.hint)) {
      return;
    }
    if (typedAnswer.length >= 6) return;
    typedAnswer += digit;
    notifyListeners();
  }

  void deleteDigit() {
    if (typedAnswer.isEmpty) return;
    typedAnswer = typedAnswer.substring(0, typedAnswer.length - 1);
    notifyListeners();
  }

  /// Trả lời trắc nghiệm bằng vị trí hiển thị đã chọn. Trả về true
  /// nếu đúng. Lần 1 sai thì chuyển sang trạng thái gợi ý; lần 2 sai
  /// thì ghi lượt và hiện lời giải.
  Future<bool> submitChoice(int displayIndex) async {
    if (finished ||
        (state != QuestionState.answering && state != QuestionState.hint)) {
      return false;
    }
    if (displayIndex < 0 || displayIndex >= current.choiceCount) {
      return false;
    }
    selectedDisplayIndex = displayIndex;
    triesUsed++;
    final correct = displayIndex == current.correctDisplayIndex;
    if (correct) {
      await _resolveQuestion(correct: true);
      return true;
    }
    if (triesUsed == 1) {
      state = QuestionState.hint;
      notifyListeners();
    } else {
      await _resolveQuestion(correct: false);
    }
    return false;
  }

  /// Trả lời điền số bằng số bé đã gõ. Trả về true nếu đúng; số chưa
  /// gõ thì không làm gì.
  Future<bool> submitNumber() async {
    if (finished ||
        (state != QuestionState.answering && state != QuestionState.hint)) {
      return false;
    }
    final value = int.tryParse(typedAnswer);
    if (value == null) return false;
    triesUsed++;
    final correct = value == current.question.answer;
    if (correct) {
      await _resolveQuestion(correct: true);
      return true;
    }
    if (triesUsed == 1) {
      state = QuestionState.hint;
      notifyListeners();
    } else {
      await _resolveQuestion(correct: false);
    }
    return false;
  }

  /// Sang câu tiếp theo; câu cuối thì kết thúc chặng (thưởng xong chặng
  /// và đánh dấu chặng đã xong trong đề ngày).
  Future<void> next() async {
    if (finished) return;
    if (isLastQuestion) {
      await _finishStage();
      finished = true;
    } else {
      currentIndex++;
      state = QuestionState.answering;
      triesUsed = 0;
      typedAnswer = '';
      selectedDisplayIndex = null;
      lastEarnedXu = null;
      _questionStartedAt = _db.clock.now();
    }
    notifyListeners();
  }

  /// Ghi một câu đã giải quyết: một dòng `attempts` (đúng ngay lần đầu,
  /// số lần thử, thời gian làm), rồi cập nhật bậc của mảng và thành
  /// thạo của dạng, và ghi sổ ôn tập. Đúng thì cộng xu theo bảng thưởng.
  Future<void> _resolveQuestion({required bool correct}) async {
    final spec = current.spec;
    final firstTry = triesUsed == 1;
    final firstTryCorrect = correct && firstTry;
    final durationMs = _db.clock
        .now()
        .difference(_questionStartedAt)
        .inMilliseconds;
    await _attemptsDao.recordAttempt(
      childId: childId,
      formId: spec.formId,
      strand: spec.strand,
      level: spec.level,
      rung: spec.rung,
      answerType: spec.answerType,
      correctFirstTry: firstTryCorrect,
      attemptsCount: triesUsed,
      durationMs: durationMs,
      isReview: spec.isReview,
      dailySetId: dailySetId,
      stage: stageIndex >= 0 ? stageIndex : null,
      questionSeed: spec.seed,
    );
    await _ladder.evaluateStrand(childId: childId, strand: spec.strand);
    await _ladder.evaluateFormMastery(childId: childId, formId: spec.formId);
    // Sổ ôn tập (T1-10): câu thường ghi qua recordAnswer (sai hoặc
    // đúng sau gợi ý thì vào sổ), câu ôn tập ghi qua recordReviewAnswer
    // (đúng ngay thì tăng chuỗi, sai thì quay về mốc 1 ngày).
    if (spec.isReview) {
      await _reviewBook.recordReviewAnswer(
        childId: childId,
        formId: spec.formId,
        rung: spec.rung,
        correctFirstTry: firstTryCorrect,
      );
    } else {
      await _reviewBook.recordAnswer(
        childId: childId,
        formId: spec.formId,
        rung: spec.rung,
        correctFirstTry: firstTryCorrect,
      );
    }
    if (correct) {
      correctCount++;
      if (firstTry) firstTryCorrectCount++;
      final xu = RewardConfig.xuForQuestion(
        rung: spec.rung,
        correctFirstTry: firstTry,
        isReview: spec.isReview,
      );
      lastEarnedXu = xu;
      xuEarned += xu;
      await _walletDao.addEntry(
        childId: childId,
        currency: Currency.xu,
        amount: xu,
        reason: spec.isReview
            ? (firstTry ? 'review_correct' : 'review_correct_after_hint')
            : (firstTry ? 'question_correct' : 'question_correct_after_hint'),
        refId: dailySetId,
      );
      state = QuestionState.correct;
    } else {
      lastEarnedXu = 0;
      state = QuestionState.solution;
    }
    notifyListeners();
  }

  /// Kết thúc chặng: thưởng xong chặng và đánh dấu chặng đã xong
  /// trong đề ngày (chặng tự chọn không lưu trạng thái).
  Future<void> _finishStage() async {
    xuEarned += RewardConfig.stageCompleteBonusXu;
    await _walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: RewardConfig.stageCompleteBonusXu,
      reason: 'stage_complete',
      refId: dailySetId,
    );
    if (dailySetId != null) {
      await _db.dailySetsDao.updateStageStatus(
        id: dailySetId!,
        stageIndex: stageIndex,
        status: StageStatus.done,
      );
    }
  }
}
