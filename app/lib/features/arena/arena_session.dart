/// Phiên làm bài Đấu trường (T2-10): giữ đáp án của 25 câu, cho đổi tới
/// khi nộp bài, và chấm điểm. KHÔNG báo đúng/sai, không gợi ý, không
/// lời giải trong lúc thi (yêu cầu của chủ dự án): chỉ khi nộp bài mới
/// chấm, và kết quả chỉ trả số câu đúng — không lộ câu nào đúng/sai.
///
/// Dart thuần + [ChangeNotifier], không đụng database; lưu điểm và
/// thưởng ở `ArenaService`.
library;

import 'package:flutter/foundation.dart';

import '../../core/database/models.dart';
import '../math/math_session.dart';
import '../questions/question.dart';
import 'arena_config.dart';

/// Kết quả chấm một bài: chỉ số lượng, không lộ câu nào đúng.
class ArenaScore {
  const ArenaScore({
    required this.correct,
    required this.total,
    required this.sectionCorrect,
    required this.sectionTotal,
    required this.points,
    required this.maxPoints,
    required this.medal,
  });

  /// Tổng số câu đúng.
  final int correct;

  /// Tổng số câu của đề.
  final int total;

  /// Số câu đúng của từng phần, theo thứ tự [arenaSections].
  final List<int> sectionCorrect;

  /// Số câu của mỗi phần.
  final int sectionTotal;

  /// Điểm (đúng x điểm mỗi câu).
  final int points;

  /// Điểm tối đa.
  final int maxPoints;

  /// Huy chương theo số câu đúng.
  final ArenaMedal medal;
}

/// Phiên làm bài: đáp án nhập/chọn tới khi nộp.
class ArenaSession extends ChangeNotifier {
  ArenaSession({
    required List<DailySetQuestion> questions,
    this.format = ArenaFormat.heat,
  }) : resolved = questions.map(ResolvedQuestion.resolve).toList(),
       _typed = List<String>.filled(questions.length, ''),
       _selected = List<int?>.filled(questions.length, null);

  /// Định dạng vòng thi.
  final ArenaFormat format;

  /// Các câu đã dựng (đáp án đúng nằm trong đây nhưng màn thi không
  /// bao giờ hiện).
  final List<ResolvedQuestion> resolved;

  final List<String> _typed;
  final List<int?> _selected;

  int _currentIndex = 0;

  /// Câu đang làm (0-based).
  int get currentIndex => _currentIndex;

  /// Tổng số câu.
  int get total => resolved.length;

  /// Câu đang làm.
  ResolvedQuestion get current => resolved[_currentIndex];

  /// Phần của câu [index] (0-based).
  int sectionOf(int index) => index ~/ format.questionsPerSection;

  /// Số đã gõ của câu [index] (điền số).
  String typedAt(int index) => _typed[index];

  /// Đáp án trắc nghiệm đã chọn của câu [index] (chỉ số hiển thị).
  int? selectedAt(int index) => _selected[index];

  /// Câu [index] đã có đáp án chưa.
  bool isAnswered(int index) => resolved[index].displayType == AnswerType.choice
      ? _selected[index] != null
      : _typed[index].isNotEmpty;

  /// Số câu đã có đáp án.
  int get answeredCount => [
    for (var i = 0; i < total; i++)
      if (isAnswered(i)) i,
  ].length;

  /// Số câu chưa có đáp án.
  int get unansweredCount => total - answeredCount;

  /// Nhảy tới câu [index].
  void goTo(int index) {
    if (index < 0 || index >= total || index == _currentIndex) return;
    _currentIndex = index;
    notifyListeners();
  }

  /// Sang câu sau (không vượt câu cuối).
  void next() => goTo(_currentIndex + 1);

  /// Về câu trước (không vượt câu đầu).
  void previous() => goTo(_currentIndex - 1);

  /// Gõ thêm một chữ số vào câu hiện tại (tối đa 6 chữ số).
  void appendDigit(String digit) {
    if (current.displayType != AnswerType.number) return;
    if (_typed[_currentIndex].length >= 6) return;
    _typed[_currentIndex] += digit;
    notifyListeners();
  }

  /// Xóa chữ số cuối của câu hiện tại.
  void deleteDigit() {
    final text = _typed[_currentIndex];
    if (text.isEmpty) return;
    _typed[_currentIndex] = text.substring(0, text.length - 1);
    notifyListeners();
  }

  /// Xóa hết đáp án của câu hiện tại (điền số hoặc trắc nghiệm).
  void clearAnswer() {
    if (!isAnswered(_currentIndex)) return;
    _typed[_currentIndex] = '';
    _selected[_currentIndex] = null;
    notifyListeners();
  }

  /// Chọn đáp án trắc nghiệm cho câu hiện tại; chọn lại đáp án đang
  /// chọn thì bỏ chọn.
  void selectChoice(int displayIndex) {
    if (current.displayType != AnswerType.choice) return;
    if (displayIndex < 0 || displayIndex >= current.choiceCount) return;
    _selected[_currentIndex] = _selected[_currentIndex] == displayIndex
        ? null
        : displayIndex;
    notifyListeners();
  }

  bool _isCorrect(int index) {
    final q = resolved[index];
    if (q.displayType == AnswerType.choice) {
      return _selected[index] != null &&
          _selected[index] == q.correctDisplayIndex;
    }
    final value = int.tryParse(_typed[index]);
    return value != null && value == q.question.answer;
  }

  /// Chấm bài với đáp án hiện có.
  ArenaScore score() {
    final per = format.questionsPerSection;
    final sectionCorrect = List<int>.filled(format.sections, 0);
    var correct = 0;
    for (var i = 0; i < total; i++) {
      if (_isCorrect(i)) {
        correct++;
        sectionCorrect[i ~/ per]++;
      }
    }
    return ArenaScore(
      correct: correct,
      total: total,
      sectionCorrect: sectionCorrect,
      sectionTotal: per,
      points: correct * format.pointsPerQuestion,
      maxPoints: format.maxScore,
      medal: arenaMedalFor(correct),
    );
  }
}
