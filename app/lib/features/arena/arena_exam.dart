/// Dựng đề Đấu trường (T2-10) từ ngân hàng câu hỏi của app.
///
/// Dart thuần, không phụ thuộc widget; nhận bậc hiện tại của bé theo
/// mảng (thang ải, T1-07) và một [Random] có seed nên test dựng lại
/// đúng một đề.
///
/// Cấu trúc: 5 phần theo thứ tự [arenaSections], mỗi phần
/// [ArenaFormat.questionsPerSection] câu. Trong một phần các dạng bài
/// khác nhau, độ khó tăng dần: câu đầu đúng bậc hiện tại của bé ở mảng
/// đó, câu cuối cao hơn tối đa 2 bậc (kẹp trong 1–6), các câu giữa
/// chia đều. Đề thi thật là câu điền số nên mọi câu hiện kiểu điền số;
/// riêng các dạng `choiceOnly` (không điền số được) vẫn là trắc nghiệm
/// và chỉ được chọn khi mảng hết dạng khác ở mức đó.
library;

import 'dart:math';

import '../../core/database/models.dart';
import '../daily_set/daily_set_config.dart';
import '../ladder/ladder_config.dart';
import '../questions/question.dart';
import '../questions/question_registry.dart';
import 'arena_config.dart';

/// Số bậc cao hơn bậc hiện tại mà câu cuối của phần được kéo lên.
const int arenaMaxStretchRungs = 2;

/// Bậc của từng ô trong một phần có [count] câu, xuất phát từ [base].
///
/// Với 5 câu: base, base, base+1, base+1, base+2 (kẹp trần 6). Không
/// giảm dần; câu cuối cao hơn câu đầu nếu bậc chưa chạm trần.
List<int> arenaSlotRungs(int base, int count) {
  final start = base.clamp(LadderConfig.minRung, LadderConfig.maxRung);
  return [
    for (var i = 0; i < count; i++)
      min(
        LadderConfig.maxRung,
        start +
            (count <= 1
                ? 0
                : (i * (arenaMaxStretchRungs + 0.5) / (count - 1)).floor()),
      ),
  ];
}

/// Dựng một đề 25 câu (hoặc 30 câu của vòng Chung kết).
///
/// [rungs] là bậc hiện tại theo mảng (thiếu thì bậc 1).
List<DailySetQuestion> buildArenaExam({
  required Map<String, int> rungs,
  required Random random,
  ArenaFormat format = ArenaFormat.heat,
}) {
  final questions = <DailySetQuestion>[];
  for (final section in arenaSections) {
    questions.addAll(
      _buildSection(
        strand: section.strand,
        baseRung: rungs[section.strand] ?? LadderConfig.initialRung,
        count: format.questionsPerSection,
        random: random,
      ),
    );
  }
  return questions;
}

List<DailySetQuestion> _buildSection({
  required String strand,
  required int baseRung,
  required int count,
  required Random random,
}) {
  final used = <String>{};
  final out = <DailySetQuestion>[];
  for (final rung in arenaSlotRungs(baseRung, count)) {
    final level = LadderConfig.levelForRung(rung);
    final generator = _pickGenerator(strand, level, used, random);
    used.add(generator.formId);
    // Dạng choiceOnly luôn trắc nghiệm; còn lại điền số như đề thật.
    final answerType = DailySetConfig.isChoiceOnly(generator.formId)
        ? AnswerType.choice
        : AnswerType.number;
    out.add(
      DailySetQuestion(
        formId: generator.formId,
        strand: strand,
        level: _levelFor(generator, level),
        rung: rung,
        answerType: answerType.name,
        seed: random.nextInt(1 << 31),
      ),
    );
  }
  return out;
}

/// Mức dạng [generator] thực sự hỗ trợ gần [level] nhất.
int _levelFor(QuestionGenerator generator, int level) {
  if (generator.supportedLevels.contains(level)) return level;
  final sorted = generator.supportedLevels.toList()
    ..sort((a, b) => (a - level).abs().compareTo((b - level).abs()));
  return sorted.first;
}

/// Chọn dạng cho một ô: đúng mức, chưa dùng trong phần, ưu tiên dạng
/// điền số được. Hết dạng ở mức đó thì lấy mức gần nhất còn dạng chưa
/// dùng.
QuestionGenerator _pickGenerator(
  String strand,
  int level,
  Set<String> used,
  Random random,
) {
  final inStrand = allQuestionGenerators.where((g) => g.topic == strand);
  for (final offset in const [0, 1, -1, 2, -2]) {
    final lvl = level + offset;
    if (lvl < 1 || lvl > 3) continue;
    final fresh = inStrand
        .where(
          (g) => g.supportedLevels.contains(lvl) && !used.contains(g.formId),
        )
        .toList();
    if (fresh.isEmpty) continue;
    final numeric = fresh
        .where((g) => !DailySetConfig.isChoiceOnly(g.formId))
        .toList();
    final pool = numeric.isNotEmpty ? numeric : fresh;
    return pool[random.nextInt(pool.length)];
  }
  throw StateError('Mảng $strand không đủ dạng bài để dựng một phần của đề');
}
