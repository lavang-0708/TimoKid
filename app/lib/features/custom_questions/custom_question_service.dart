/// Câu hỏi tự soạn (T5-03): kiểm tra, chọn câu cho đề ngày, dựng [Question]
/// để màn làm toán hiện như câu thường.
///
/// Câu do bố/mẹ soạn ở web admin, tải về bảng `custom_questions` (chỉ khi
/// `customQuestionsEnabled`). Mỗi chặng của đề ngày có TỐI ĐA 1 câu tự
/// soạn: đúng mảng, đúng bậc hiện tại của bé, câu của riêng bé hoặc của mọi
/// bé (`child_id` null), đang bật. Nhiều câu thì chọn câu bé đã làm ít nhất
/// (hòa thì ngẫu nhiên). Câu được chụp nguyên văn vào đề ngày
/// ([CustomQuestionSnapshot]) nên sửa/tắt câu sau đó không đổi đề đã tạo.
///
/// Trả lời: điền số (số nguyên, tối đa 6 chữ số) hoặc trắc nghiệm (2–6 lựa
/// chọn); chấm, gợi ý, lời giải đi qua đúng luồng của câu thường. Lượt trả
/// lời ghi vào `attempts` với `formId = custom:<id>`; câu tự soạn KHÔNG vào
/// sổ ôn tập và không tính thành thạo dạng bài (không có dạng bài để
/// thành thạo), nhưng vẫn tính vào bậc của mảng như mọi câu trong mảng.
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos.dart';
import '../../core/database/models.dart';
import '../ladder/ladder_config.dart';
import '../questions/question.dart';

/// Số chữ số tối đa của đáp án điền số (bàn phím của bé).
const int customAnswerMaxDigits = 6;
const int customChoicesMin = 2;
const int customChoicesMax = 6;

final RegExp _numberAnswer = RegExp('^[0-9]{1,$customAnswerMaxDigits}\$');

/// Dựng bản chụp từ một dòng đã tải; null nếu dòng không hợp lệ (server
/// đã chặn nhưng máy không tin mù quáng).
CustomQuestionSnapshot? snapshotFromRow(CustomQuestion row) {
  if (row.textVi.trim().isEmpty) return null;
  List<String>? choices;
  final raw = row.choicesJson;
  if (raw != null) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      choices = [for (final c in decoded) '$c'];
    } on FormatException {
      return null;
    }
    if (choices.length < customChoicesMin ||
        choices.length > customChoicesMax ||
        choices.toSet().length != choices.length ||
        choices.any((c) => c.trim().isEmpty) ||
        !choices.contains(row.answer)) {
      return null;
    }
  } else if (!_numberAnswer.hasMatch(row.answer)) {
    return null;
  }
  return CustomQuestionSnapshot(
    id: row.id,
    textVi: row.textVi,
    textEn: row.textEn,
    answer: row.answer,
    choices: choices,
    explanationVi: row.explanationVi,
  );
}

/// Kiểu hiển thị của câu tự soạn: có lựa chọn thì trắc nghiệm, không thì
/// điền số.
AnswerType customAnswerType(CustomQuestionSnapshot c) =>
    c.choices == null ? AnswerType.number : AnswerType.choice;

/// Dựng [Question] từ bản chụp, để [ResolvedQuestion] xử lý như câu thường.
/// Trắc nghiệm: `answer` là chỉ số lựa chọn đúng trong `choices` (trước khi
/// trộn); điền số: `answer` là giá trị số.
Question customToQuestion(DailySetQuestion spec) {
  final c = spec.custom!;
  final choices = c.choices;
  final correct = c.answer;
  return Question(
    formId: spec.formId,
    topic: spec.strand,
    difficulty: spec.level,
    questionVi: c.textVi,
    questionEn: c.textEn ?? '',
    hintVi: 'Đọc kỹ đề rồi thử lại nhé!',
    hintEn: 'Read the question carefully and try again!',
    explanationVi: c.explanationVi.isNotEmpty
        ? c.explanationVi
        : 'Đáp án đúng là $correct.',
    explanationEn: 'The correct answer is $correct.',
    keywords: const <Keyword>[],
    answerType: choices == null ? AnswerType.number : AnswerType.choice,
    answer: choices == null ? int.parse(correct) : choices.indexOf(correct),
    choices: [
      for (final x in choices ?? const <String>[]) Choice(vi: x, en: x),
    ],
    params: {'customId': c.id},
  );
}

class CustomQuestionService {
  CustomQuestionService({required this.db, Random? random})
    : _random = random ?? Random();

  final AppDatabase db;
  final Random _random;

  CustomQuestionsDao get _dao => db.customQuestionsDao;

  /// Số lần bé đã làm mỗi câu tự soạn (mã câu → số lượt).
  Future<Map<String, int>> attemptCounts(String childId) async {
    final rows =
        await (db.select(db.attempts)..where(
              (t) => t.childId.equals(childId) & t.formId.like('custom:%'),
            ))
            .get();
    final out = <String, int>{};
    for (final a in rows) {
      final id = a.formId.substring('custom:'.length);
      out[id] = (out[id] ?? 0) + 1;
    }
    return out;
  }

  /// Chọn tối đa MỘT câu cho chặng [strand] của bé ở bậc [rung]; null nếu
  /// không có câu hợp lệ nào.
  Future<CustomQuestionSnapshot?> pickForStage({
    required String childId,
    required String strand,
    required int rung,
  }) async {
    final rows = await _dao.activeFor(
      childId: childId,
      strand: strand,
      rung: rung,
    );
    final valid = <CustomQuestionSnapshot>[
      for (final r in rows) ?snapshotFromRow(r),
    ];
    if (valid.isEmpty) return null;
    final counts = await attemptCounts(childId);
    final least = valid.map((s) => counts[s.id] ?? 0).reduce(min);
    final pool = valid.where((s) => (counts[s.id] ?? 0) == least).toList();
    return pool[_random.nextInt(pool.length)];
  }

  /// Dựng ô của câu tự soạn trong chặng (kiểu hiển thị theo câu).
  DailySetQuestion build({
    required CustomQuestionSnapshot custom,
    required String strand,
    required int rung,
  }) => DailySetQuestion(
    formId: customFormId(custom.id),
    strand: strand,
    level: LadderConfig.levelForRung(rung),
    rung: rung,
    answerType: customAnswerType(custom).name,
    seed: _random.nextInt(1 << 31),
    custom: custom,
  );
}

/// Chuyển một dòng server (JSON của Data API) thành dòng Drift. Null nếu
/// thiếu trường bắt buộc. [parseTime] đổi ISO của server về giờ app.
CustomQuestionsCompanion? customQuestionFromServer(
  Map<String, Object?> r,
  DateTime Function(String iso) parseTime,
) {
  final id = r['id'] as String?;
  final strand = r['strand'] as String?;
  final rung = (r['rung'] as num?)?.toInt();
  final textVi = r['text_vi'] as String?;
  final answer = r['answer'] as String?;
  final stamp = r['updated_at'] as String?;
  if (id == null ||
      strand == null ||
      rung == null ||
      textVi == null ||
      answer == null ||
      stamp == null) {
    return null;
  }
  final choices = r['choices'];
  return CustomQuestionsCompanion.insert(
    id: id,
    childId: Value(r['child_id'] as String?),
    strand: strand,
    rung: rung,
    grade: Value((r['grade'] as num?)?.toInt() ?? 2),
    textVi: textVi,
    textEn: Value(r['text_en'] as String?),
    answer: answer,
    choicesJson: Value(choices == null ? null : jsonEncode(choices)),
    explanationVi: Value('${r['explanation_vi'] ?? ''}'),
    active: Value(r['active'] as bool? ?? true),
    createdAt: parseTime((r['created_at'] as String?) ?? stamp),
    updatedAt: parseTime(stamp),
  );
}
