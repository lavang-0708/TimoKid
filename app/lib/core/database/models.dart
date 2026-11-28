/// Model Dart thuần cho các cột JSON của bảng `daily_sets`.
///
/// Đề ngày được lưu lại khi tạo (T1-08) nên 25 câu hỏi phải nằm gọn trong
/// một dòng: cột `questions` lưu danh sách [DailySetQuestion] dạng JSON,
/// cột `stage_status` lưu danh sách 5 trạng thái chặng.
library;

/// Một câu trong đề ngày đã tạo: đủ thông tin để T1-08/T1-09 sinh lại
/// đúng câu hỏi đó (qua bộ sinh câu T1-05) mà không cần lưu cả đề văn bản.
class DailySetQuestion {
  const DailySetQuestion({
    required this.formId,
    required this.strand,
    required this.level,
    required this.rung,
    required this.answerType,
    this.isReview = false,
    this.seed,
    this.custom,
  });

  /// Dạng bài, vd: `logic.balance`.
  final String formId;

  /// Mảng của dạng bài.
  final String strand;

  /// Mức nội dung: 1 Dễ, 2 Vừa, 3 Khó.
  final int level;

  /// Bậc 1–6 của câu.
  final int rung;

  /// Kiểu trả lời: `choice` hoặc `number` (xem [AnswerType]).
  final String answerType;

  /// Câu ôn tập từ sổ (`review_queue`) hay không.
  final bool isReview;

  /// Seed sinh câu, để tái hiện đúng câu hỏi.
  final int? seed;

  /// Nội dung câu tự soạn (T5-03), chụp lại lúc tạo đề để đề ngày tự đủ
  /// (sửa hay tắt câu sau đó không làm đổi đề đã tạo). Có thì [formId] là
  /// `custom:<id>` và câu KHÔNG sinh từ generator.
  final CustomQuestionSnapshot? custom;

  /// Câu tự soạn hay không.
  bool get isCustom => custom != null;

  Map<String, Object?> toJson() => {
    'formId': formId,
    'strand': strand,
    'level': level,
    'rung': rung,
    'answerType': answerType,
    'isReview': isReview,
    if (seed != null) 'seed': seed,
    if (custom != null) 'custom': custom!.toJson(),
  };

  factory DailySetQuestion.fromJson(Map<String, Object?> json) {
    return DailySetQuestion(
      formId: json['formId'] as String,
      strand: json['strand'] as String,
      level: json['level'] as int,
      rung: json['rung'] as int,
      answerType: json['answerType'] as String,
      isReview: json['isReview'] as bool? ?? false,
      seed: json['seed'] as int?,
      custom: json['custom'] == null
          ? null
          : CustomQuestionSnapshot.fromJson(
              (json['custom'] as Map).cast<String, Object?>(),
            ),
    );
  }
}

/// Mã `formId` của câu tự soạn: `custom:<id>`.
String customFormId(String id) => 'custom:$id';

/// Nội dung một câu tự soạn trong đề ngày. [choices] null = câu điền số
/// ([answer] là số nguyên); có = trắc nghiệm ([answer] là một trong
/// [choices]).
class CustomQuestionSnapshot {
  const CustomQuestionSnapshot({
    required this.id,
    required this.textVi,
    required this.answer,
    this.textEn,
    this.choices,
    this.explanationVi = '',
  });

  final String id;
  final String textVi;
  final String? textEn;
  final String answer;
  final List<String>? choices;
  final String explanationVi;

  Map<String, Object?> toJson() => {
    'id': id,
    'textVi': textVi,
    if (textEn != null) 'textEn': textEn,
    'answer': answer,
    if (choices != null) 'choices': choices,
    if (explanationVi.isNotEmpty) 'explanationVi': explanationVi,
  };

  factory CustomQuestionSnapshot.fromJson(Map<String, Object?> json) {
    return CustomQuestionSnapshot(
      id: json['id'] as String,
      textVi: json['textVi'] as String,
      textEn: json['textEn'] as String?,
      answer: json['answer'] as String,
      choices: (json['choices'] as List?)?.cast<String>(),
      explanationVi: json['explanationVi'] as String? ?? '',
    );
  }
}

/// Trạng thái một chặng trong đề ngày.
class StageStatus {
  static const notStarted = 'not_started';
  static const inProgress = 'in_progress';
  static const done = 'done';

  static const all = [notStarted, inProgress, done];
}
