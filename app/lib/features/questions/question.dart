import 'dart:math';

/// Kiểu trả lời của một câu hỏi.
enum AnswerType {
  /// Điền số: đáp án là một số nguyên.
  number,

  /// Trắc nghiệm: đáp án là chỉ số của lựa chọn đúng trong [Question.choices].
  choice,
}

/// Một cặp từ khóa song ngữ (tiếng Anh trước, như trong `gen.py`).
class Keyword {
  const Keyword({required this.en, required this.vi});

  final String en;
  final String vi;
}

/// Một lựa chọn trả lời của câu trắc nghiệm.
class Choice {
  const Choice({required this.vi, required this.en});

  final String vi;
  final String en;
}

/// Loại hình vẽ kèm theo câu hỏi. T1-06 sinh SVG từ các tham số này.
enum FigureKind {
  /// Lưới ô vuông [rows] x [cols], mỗi ô [cell] px.
  grid,

  /// Tam giác có đỉnh ở trên, [segments] đoạn thẳng nối đỉnh xuống cạnh đáy.
  fan,

  /// Lưới [rows] x [cols] có đánh dấu điểm A (góc dưới trái) và điểm B
  /// (góc trên phải), dùng cho bài đường đi trên lưới.
  pathGrid,
}

/// Tham số hình vẽ kèm theo câu hỏi (nếu câu có hình).
class FigureSpec {
  const FigureSpec({
    required this.kind,
    this.rows = 0,
    this.cols = 0,
    this.cell = 50,
    this.segments = 0,
  });

  const FigureSpec.grid({required int rows, required int cols, int cell = 50})
    : this(kind: FigureKind.grid, rows: rows, cols: cols, cell: cell);

  const FigureSpec.fan({required int segments})
    : this(kind: FigureKind.fan, segments: segments);

  const FigureSpec.pathGrid({
    required int rows,
    required int cols,
    int cell = 50,
  }) : this(kind: FigureKind.pathGrid, rows: rows, cols: cols, cell: cell);

  final FigureKind kind;
  final int rows;
  final int cols;
  final int cell;
  final int segments;
}

/// Một câu hỏi đã sinh xong, sẵn sàng đưa vào đề.
///
/// [answer] là giá trị đáp án với câu điền số, hoặc chỉ số của lựa chọn
/// đúng (trong [choices]) với câu trắc nghiệm.
///
/// [params] ghi lại các tham số đã dùng để sinh câu (số, tên, ...). Test
/// dùng [params] để giải lại độc lập mà không gọi code sinh câu.
class Question {
  const Question({
    required this.formId,
    required this.topic,
    required this.difficulty,
    required this.questionVi,
    required this.questionEn,
    required this.hintVi,
    required this.hintEn,
    required this.explanationVi,
    required this.explanationEn,
    required this.keywords,
    required this.answerType,
    required this.answer,
    this.distractors = const <int>[],
    this.choices = const <Choice>[],
    this.figure,
    this.params = const <String, Object?>{},
  });

  /// Mã dạng bài, vd 'logic.balance'.
  final String formId;

  /// Mảng: logic, arith, number, geo, comb.
  final String topic;

  /// Mức nội dung: 1 Dễ, 2 Vừa, 3 Khó.
  final int difficulty;

  final String questionVi;
  final String questionEn;
  final String hintVi;
  final String hintEn;
  final String explanationVi;
  final String explanationEn;
  final List<Keyword> keywords;

  final AnswerType answerType;

  /// Câu điền số: giá trị đáp án. Câu trắc nghiệm: chỉ số lựa chọn đúng.
  final int answer;

  /// Câu điền số: đúng 3 đáp án nhiễu. Câu trắc nghiệm: rỗng.
  final List<int> distractors;

  /// Câu trắc nghiệm: các lựa chọn. Câu điền số: rỗng.
  final List<Choice> choices;

  /// Tham số hình vẽ (nếu câu có hình); T1-06 sinh SVG từ đây.
  final FigureSpec? figure;

  /// Tham số đã dùng để sinh câu.
  final Map<String, Object?> params;

  bool get isChoice => answerType == AnswerType.choice;
}

/// Một dạng bài: khuôn sinh câu có tham số, theo `gen.py`.
///
/// Mỗi dạng khai báo các mức nó hỗ trợ và chỉ sinh câu ở các mức đó
/// (không tự soạn thêm mức mới — điểm chốt (a) ngày 17/11).
abstract class QuestionGenerator {
  const QuestionGenerator();

  /// Mã dạng bài, vd 'logic.balance'.
  String get formId;

  /// Mảng: logic, arith, number, geo, comb.
  String get topic;

  /// Các mức nội dung mà dạng này hỗ trợ (tập con của {1, 2, 3}).
  Set<int> get supportedLevels;

  /// Sinh một câu ở [level] bằng [random].
  ///
  /// Ném [ArgumentError] nếu [level] không nằm trong [supportedLevels].
  Question generate(int level, Random random);

  /// Kiểm tra mức hỗ trợ, dùng chung cho mọi generator.
  void checkLevel(int level) {
    if (!supportedLevels.contains(level)) {
      throw ArgumentError('Dạng $formId không hỗ trợ mức $level');
    }
  }
}

/// Danh sách tên dùng trong đề, giữ nguyên như `gen.py`.
const List<String> childNames = [
  'An',
  'Bình',
  'Chi',
  'Dũng',
  'Hà',
  'Lan',
  'Mai',
  'Minh',
  'Nam',
  'Ngọc',
  'Phương',
  'Quân',
  'Thảo',
  'Trang',
  'Tuấn',
  'Vy',
  'Linh',
  'Hùng',
  'Khoa',
  'My',
];

/// Số nguyên ngẫu nhiên trong [min]..[max] (bao cả hai đầu),
/// tương đương `random.randint(min, max)` của Python.
int randint(Random random, int min, int max) =>
    min + random.nextInt(max - min + 1);

/// Lấy [k] tên khác nhau, tương đương `random.sample(NAMES, k)` của Python.
List<String> pickNames(Random random, int k) {
  final pool = List<String>.of(childNames)..shuffle(random);
  return pool.take(k).toList();
}

/// Lấy ngẫu nhiên một phần tử trong [items],
/// tương đương `random.choice(items)` của Python.
T pickOne<T>(Random random, List<T> items) =>
    items[random.nextInt(items.length)];

/// Sinh 3 đáp án nhiễu cho đáp án [answer], giữ nguyên thuật toán của
/// `gen.py`: các đáp án nhiễu gợi ý trong [extra] được giữ đầu tiên
/// (theo đúng thứ tự), phần còn lại lấy từ `answer ± {1, 2, 3, 5, 10}`
/// rồi trộn ngẫu nhiên.
List<int> makeDistractors(
  Random random,
  int answer, [
  List<int> extra = const <int>[],
]) {
  final validExtra = extra.where((e) => e != answer && e > 0).toList();
  final candidates = <int>[...validExtra];
  for (final d in const [1, -1, 2, -2, 10, -10, 3, 5]) {
    candidates.add(answer + d);
  }
  final out = <int>[];
  for (final c in candidates) {
    if (c > 0 && c != answer && !out.contains(c)) {
      out.add(c);
    }
  }
  final first = out.take(validExtra.length).toList();
  final rest = out.where((c) => !first.contains(c)).toList()..shuffle(random);
  return [...first, ...rest].take(3).toList();
}

/// Tạo nhanh danh sách từ khóa từ các cặp (tiếng Anh, tiếng Việt),
/// giữ đúng thứ tự cặp như trong `gen.py`.
List<Keyword> kws(List<(String, String)> pairs) => [
  for (final p in pairs) Keyword(en: p.$1, vi: p.$2),
];

/// Thứ trong tuần, giữ nguyên thứ tự của `gen.py`
/// (0 = Chủ nhật, 6 = Thứ Bảy).
const List<String> daysVi = [
  'Chủ nhật',
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
];

const List<String> daysEn = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];
