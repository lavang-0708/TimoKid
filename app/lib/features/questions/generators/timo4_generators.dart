import 'dart:math';

import '../question.dart';

/// 6 dạng bài bổ sung đợt 4 (24/11): mỗi mảng thêm 1 dạng, Hình học
/// thêm 2 (khối chóp, khối lăng trụ — đề thử TIMO lớp 2 có hỏi số cạnh
/// của hình chóp khi biết số đỉnh).
///
/// Dạng bài theo kiểu đề TIMO lớp 2, số và lời văn tự soạn. Khuôn khổ
/// lớp 2: số trong phạm vi 100, nhân trong bảng 2–5, chia hết. Mọi dạng
/// là câu điền số; tham số ghi vào [Question.params] để test giải lại
/// độc lập trong `question_solvers.dart`.
class Timo4Generator extends QuestionGenerator {
  const Timo4Generator(this.formId, this.topic, this._build);

  @override
  final String formId;

  @override
  final String topic;

  final Question Function(Timo4Generator g, int level, Random r) _build;

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    return _build(this, level, random);
  }
}

Question _mk(
  Timo4Generator g,
  int level,
  Random r, {
  required String qVi,
  required String qEn,
  required String hVi,
  required String hEn,
  required String eVi,
  required String eEn,
  required List<(String, String)> kw,
  required int ans,
  List<int> wrong = const <int>[],
  required Map<String, Object?> params,
}) {
  return Question(
    formId: g.formId,
    topic: g.topic,
    difficulty: level,
    questionVi: qVi,
    questionEn: qEn,
    hintVi: hVi,
    hintEn: hEn,
    explanationVi: eVi,
    explanationEn: eEn,
    keywords: kws(kw),
    answerType: AnswerType.number,
    answer: ans,
    distractors: makeDistractors(r, ans, wrong),
    params: params,
  );
}

// ================================================================== LÔGIC

/// Bảng số theo quy luật hàng: 3 hàng đủ, hàng 4 thiếu một ô.
/// Mức 1: cột 3 = cột 1 + cột 2. Mức 2: cột 3 = cột 1 × cột 2.
/// Mức 3: cột 3 = cột 1 × cột 2, thiếu ô cột 2.
Question _table(Timo4Generator g, int level, Random r) {
  final mul = level >= 2;
  int c3(int a, int b) => mul ? a * b : a + b;
  final rows = <List<int>>[];
  final seen = <String>{};
  while (rows.length < 4) {
    final a = mul ? randint(r, 2, 5) : randint(r, 5, 40);
    final b = mul ? randint(r, 2, 9) : randint(r, 5, 40);
    if (!seen.add('$a-$b')) continue;
    rows.add([a, b, c3(a, b)]);
  }
  final last = rows.last;
  final missCol = level == 3 ? 1 : 2;
  final ans = last[missCol];
  String show(List<int> row, bool hide) =>
      [for (var i = 0; i < 3; i++) (hide && i == missCol) ? '?' : '${row[i]}']
          .join(' | ');
  final lines = [for (var i = 0; i < 4; i++) show(rows[i], i == 3)];
  final table = lines.join('\n');
  final ruleVi = mul
      ? 'số thứ ba bằng số thứ nhất nhân số thứ hai'
      : 'số thứ ba bằng số thứ nhất cộng số thứ hai';
  final ruleEn = mul
      ? 'the third number is the first times the second'
      : 'the third number is the first plus the second';
  final eVi = level == 3
      ? 'Mỗi hàng: $ruleVi. Hàng cuối: ${last[0]} × ? = ${last[2]}, nên ? = ${last[2]} : ${last[0]} = $ans.'
      : 'Mỗi hàng: $ruleVi. Hàng cuối: ${last[0]} ${mul ? '×' : '+'} ${last[1]} = $ans.';
  final eEn = level == 3
      ? 'In each row, $ruleEn. Last row: ${last[0]} × ? = ${last[2]}, so ? = ${last[2]} ÷ ${last[0]} = $ans.'
      : 'In each row, $ruleEn. Last row: ${last[0]} ${mul ? '×' : '+'} ${last[1]} = $ans.';
  return _mk(
    g,
    level,
    r,
    qVi:
        'Các số trong mỗi hàng của bảng theo cùng một quy luật. Tìm số thích hợp thay cho dấu ?\n$table',
    qEn:
        'The numbers in each row follow the same rule. What number replaces the "?"\n$table',
    hVi: 'Xem ở các hàng đã đủ, số thứ ba có quan hệ gì với hai số đầu.',
    hEn: 'In the complete rows, how is the third number made from the first two?',
    eVi: eVi,
    eEn: eEn,
    kw: [('rule', 'quy luật'), ('row', 'hàng')],
    ans: ans,
    wrong: [
      if (mul) last[0] + last[1] else (last[0] - last[1]).abs(),
      if (level == 3) last[2] - last[0],
    ],
    params: {
      'rows': [for (final row in rows) ...row],
      'mul': mul,
      'missCol': missCol,
    },
  );
}

// ================================================================= SỐ HỌC

/// Tổng các số cách đều (ghép cặp đầu–cuối).
/// Mức 1: 1 + 2 + ... + n. Mức 2: 2 + 4 + ... + 2n. Mức 3: a, a+d, ...
Question _pairsum(Timo4Generator g, int level, Random r) {
  late int start, step, count;
  switch (level) {
    case 1:
      start = 1;
      step = 1;
      count = randint(r, 5, 12);
    case 2:
      start = 2;
      step = 2;
      count = randint(r, 4, 9);
    default:
      do {
        start = randint(r, 3, 15);
        step = randint(r, 3, 5);
        count = randint(r, 4, 6);
      } while (start + step * (count - 1) > 60);
  }
  final terms = [for (var i = 0; i < count; i++) start + step * i];
  final ans = terms.fold<int>(0, (s, t) => s + t);
  final expr = terms.length <= 6
      ? terms.join(' + ')
      : '${terms.take(3).join(' + ')} + ... + ${terms.last}';
  final first = terms.first, lastT = terms.last;
  final pairs = count ~/ 2;
  final mid = count.isOdd ? terms[count ~/ 2] : null;
  final eVi = mid == null
      ? 'Ghép số đầu với số cuối: $first + $lastT = ${first + lastT}. Có $pairs cặp như vậy nên tổng là ${first + lastT} × $pairs = $ans.'
      : 'Ghép số đầu với số cuối: $first + $lastT = ${first + lastT}. Có $pairs cặp và thừa số giữa $mid, nên tổng là ${first + lastT} × $pairs + $mid = $ans.';
  final eEn = mid == null
      ? 'Pair first with last: $first + $lastT = ${first + lastT}. There are $pairs such pairs, so the sum is ${first + lastT} × $pairs = $ans.'
      : 'Pair first with last: $first + $lastT = ${first + lastT}. There are $pairs pairs plus the middle $mid, so the sum is ${first + lastT} × $pairs + $mid = $ans.';
  return _mk(
    g,
    level,
    r,
    qVi: 'Tính nhanh: $expr = ?',
    qEn: 'Work out quickly: $expr = ?',
    hVi: 'Ghép số đầu với số cuối, số thứ hai với số kế cuối… các cặp có tổng bằng nhau.',
    hEn: 'Pair the first with the last, the second with the second-to-last… each pair has the same sum.',
    eVi: eVi,
    eEn: eEn,
    kw: [('sum', 'tổng'), ('pair', 'cặp')],
    ans: ans,
    wrong: [ans - lastT, ans + step],
    params: {'start': start, 'step': step, 'count': count},
  );
}

// ============================================================ LÝ THUYẾT SỐ

/// Đếm số chia hết cho k trong một khoảng.
Question _multiples(Timo4Generator g, int level, Random r) {
  final k = randint(r, 2, 5);
  late int lo, hi;
  switch (level) {
    case 1:
      lo = 1;
      hi = randint(r, 12, 30);
    case 2:
      lo = 1;
      hi = randint(r, 31, 60);
    default:
      lo = randint(r, 11, 30);
      hi = randint(r, lo + 20, 90);
  }
  final list = [
    for (var x = lo; x <= hi; x++)
      if (x % k == 0) x,
  ];
  final ans = list.length;
  final shown = list.length <= 8
      ? list.join(', ')
      : '${list.take(3).join(', ')}, ..., ${list.last}';
  return _mk(
    g,
    level,
    r,
    qVi:
        'Từ $lo đến $hi có bao nhiêu số chia hết cho $k? (Tính cả $lo và $hi nếu chúng chia hết cho $k.)',
    qEn:
        'How many numbers from $lo to $hi are divisible by $k? (Include $lo and $hi if they are divisible by $k.)',
    hVi:
        'Tìm số nhỏ nhất và số lớn nhất chia hết cho $k trong khoảng, rồi đếm cách $k.',
    hEn:
        'Find the smallest and largest multiples of $k in the range, then count in steps of $k.',
    eVi: 'Các số chia hết cho $k: $shown. Có $ans số.',
    eEn: 'Multiples of $k: $shown. There are $ans numbers.',
    kw: [('divisible', 'chia hết'), ('multiple', 'bội')],
    ans: ans,
    wrong: [hi ~/ k, ans + 1],
    params: {'k': k, 'lo': lo, 'hi': hi},
  );
}

// ================================================================ HÌNH HỌC

const List<String> _polyVi = [
  '',
  '',
  '',
  'tam giác',
  'tứ giác',
  'ngũ giác',
  'lục giác',
  'thất giác',
  'bát giác',
];
const List<String> _polyEn = [
  '',
  '',
  '',
  'triangle',
  'quadrilateral',
  'pentagon',
  'hexagon',
  'heptagon',
  'octagon',
];

/// Khối chóp đáy là đa giác n cạnh: đỉnh n + 1, cạnh 2n, mặt n + 1.
/// Mức 1: hỏi số đỉnh. Mức 2: hỏi số cạnh. Mức 3: biết số đỉnh, hỏi số
/// cạnh (như đề thử: chóp 16 đỉnh có bao nhiêu cạnh).
Question _pyramid(Timo4Generator g, int level, Random r) {
  final n = level == 3 ? randint(r, 6, 20) : randint(r, 3, 8);
  late String qVi, qEn, eVi, eEn;
  late int ans;
  final wrong = <int>[];
  switch (level) {
    case 1:
      ans = n + 1;
      qVi =
          'Một khối chóp có đáy là hình ${_polyVi[n]} ($n cạnh). Khối chóp đó có bao nhiêu đỉnh?';
      qEn =
          'A pyramid has a ${_polyEn[n]} base ($n sides). How many vertices does it have?';
      eVi = 'Đáy có $n đỉnh, cộng thêm 1 đỉnh chóp ở trên: $n + 1 = $ans.';
      eEn = 'The base has $n vertices, plus 1 apex on top: $n + 1 = $ans.';
      wrong.addAll([n, 2 * n]);
    case 2:
      ans = 2 * n;
      qVi =
          'Một khối chóp có đáy là hình ${_polyVi[n]} ($n cạnh). Khối chóp đó có bao nhiêu cạnh?';
      qEn =
          'A pyramid has a ${_polyEn[n]} base ($n sides). How many edges does it have?';
      eVi =
          'Đáy có $n cạnh, mỗi đỉnh đáy nối lên đỉnh chóp thêm 1 cạnh: $n + $n = $ans.';
      eEn =
          'The base has $n edges, and each base vertex joins the apex with one more edge: $n + $n = $ans.';
      wrong.addAll([n + 1, 3 * n]);
    default:
      final v = n + 1;
      ans = 2 * n;
      qVi = 'Một khối chóp có $v đỉnh. Khối chóp đó có bao nhiêu cạnh?';
      qEn = 'A pyramid has $v vertices. How many edges does it have?';
      eVi =
          'Bỏ đỉnh chóp, đáy có $v − 1 = $n đỉnh nên đáy có $n cạnh; thêm $n cạnh nối lên đỉnh chóp: $n + $n = $ans.';
      eEn =
          'Without the apex the base has $v − 1 = $n vertices, so $n base edges; plus $n edges up to the apex: $n + $n = $ans.';
      wrong.addAll([2 * v, v + n]);
  }
  return _mk(
    g,
    level,
    r,
    qVi: qVi,
    qEn: qEn,
    hVi: 'Khối chóp gồm một mặt đáy và một đỉnh chóp nối với mọi đỉnh của đáy.',
    hEn: 'A pyramid is a base plus one apex joined to every base vertex.',
    eVi: eVi,
    eEn: eEn,
    kw: [('pyramid', 'khối chóp'), ('vertex', 'đỉnh'), ('edge', 'cạnh')],
    ans: ans,
    wrong: wrong,
    params: {'n': n, 'ask': level},
  );
}

/// Khối lăng trụ đáy là đa giác n cạnh: đỉnh 2n, cạnh 3n, mặt n + 2.
/// Mức 1: hỏi số đỉnh. Mức 2: hỏi số cạnh. Mức 3: biết số đỉnh, hỏi cạnh.
Question _prism(Timo4Generator g, int level, Random r) {
  final n = randint(r, 3, level == 3 ? 12 : 8);
  late String qVi, qEn, eVi, eEn;
  late int ans;
  final wrong = <int>[];
  switch (level) {
    case 1:
      ans = 2 * n;
      qVi =
          'Một khối lăng trụ có hai đáy là hình ${_polyVi[n]} ($n cạnh). Khối đó có bao nhiêu đỉnh?';
      qEn =
          'A prism has two ${_polyEn[n]} bases ($n sides each). How many vertices does it have?';
      eVi = 'Mỗi đáy có $n đỉnh, hai đáy: $n + $n = $ans.';
      eEn = 'Each base has $n vertices; two bases: $n + $n = $ans.';
      wrong.addAll([n + 1, 3 * n]);
    case 2:
      ans = 3 * n;
      qVi =
          'Một khối lăng trụ có hai đáy là hình ${_polyVi[n]} ($n cạnh). Khối đó có bao nhiêu cạnh?';
      qEn =
          'A prism has two ${_polyEn[n]} bases ($n sides each). How many edges does it have?';
      eVi =
          'Đáy trên $n cạnh, đáy dưới $n cạnh, và $n cạnh đứng nối hai đáy: $n + $n + $n = $ans.';
      eEn =
          'Top base $n edges, bottom base $n edges, and $n upright edges joining them: $n + $n + $n = $ans.';
      wrong.addAll([2 * n, 2 * n + 2]);
    default:
      final v = 2 * n;
      ans = 3 * n;
      qVi =
          'Một khối lăng trụ (hai đáy giống nhau, các mặt bên là hình chữ nhật) có $v đỉnh. Khối đó có bao nhiêu cạnh?';
      qEn =
          'A prism (two equal bases, rectangular side faces) has $v vertices. How many edges does it have?';
      eVi =
          'Mỗi đáy có $v : 2 = $n đỉnh nên $n cạnh. Hai đáy và $n cạnh đứng: $n × 3 = $ans.';
      eEn =
          'Each base has $v ÷ 2 = $n vertices, so $n edges. Two bases plus $n upright edges: $n × 3 = $ans.';
      wrong.addAll([v, v + 2]);
  }
  return _mk(
    g,
    level,
    r,
    qVi: qVi,
    qEn: qEn,
    hVi: 'Khối lăng trụ có đáy trên, đáy dưới giống nhau và các cạnh đứng nối hai đáy.',
    hEn: 'A prism has equal top and bottom bases joined by upright edges.',
    eVi: eVi,
    eEn: eEn,
    kw: [('prism', 'khối lăng trụ'), ('vertex', 'đỉnh'), ('edge', 'cạnh')],
    ans: ans,
    wrong: wrong,
    params: {'n': n, 'ask': level},
  );
}

// ================================================================== TỔ HỢP

/// Tô lá cờ 3 sọc ngang.
/// Mức 1: 3 màu, mỗi sọc một màu khác nhau. Mức 2: 3 màu, hai sọc liền
/// nhau khác màu (sọc trên và dưới được trùng). Mức 3: 4 màu, hai sọc
/// liền nhau khác màu.
Question _flag(Timo4Generator g, int level, Random r) {
  final k = level == 3 ? 4 : 3;
  final allDiff = level == 1;
  final colorsVi = ['đỏ', 'vàng', 'xanh', 'tím'].take(k).join(', ');
  final colorsEn = ['red', 'yellow', 'blue', 'purple'].take(k).join(', ');
  final ans = allDiff ? k * (k - 1) * (k - 2) : k * (k - 1) * (k - 1);
  final qVi = allDiff
      ? 'Bé tô một lá cờ có 3 sọc ngang bằng các màu: $colorsVi. Mỗi sọc một màu và 3 sọc phải khác màu nhau. Hỏi bé tô được bao nhiêu lá cờ khác nhau?'
      : 'Bé tô một lá cờ có 3 sọc ngang bằng các màu: $colorsVi. Mỗi sọc một màu, hai sọc nằm cạnh nhau phải khác màu (sọc trên cùng và dưới cùng được tô cùng màu). Hỏi bé tô được bao nhiêu lá cờ khác nhau?';
  final qEn = allDiff
      ? 'A flag has 3 horizontal stripes coloured with: $colorsEn. Each stripe is one colour and all 3 stripes must be different. How many different flags can be made?'
      : 'A flag has 3 horizontal stripes coloured with: $colorsEn. Each stripe is one colour and neighbouring stripes must differ (top and bottom may match). How many different flags can be made?';
  final eVi = allDiff
      ? 'Sọc trên: $k cách; sọc giữa: ${k - 1} cách; sọc dưới: ${k - 2} cách. Tất cả $k × ${k - 1} × ${k - 2} = $ans.'
      : 'Sọc trên: $k cách; sọc giữa khác sọc trên: ${k - 1} cách; sọc dưới khác sọc giữa: ${k - 1} cách. Tất cả $k × ${k - 1} × ${k - 1} = $ans.';
  final eEn = allDiff
      ? 'Top: $k ways; middle: ${k - 1}; bottom: ${k - 2}. Total $k × ${k - 1} × ${k - 2} = $ans.'
      : 'Top: $k ways; middle (not the top colour): ${k - 1}; bottom (not the middle colour): ${k - 1}. Total $k × ${k - 1} × ${k - 1} = $ans.';
  return _mk(
    g,
    level,
    r,
    qVi: qVi,
    qEn: qEn,
    hVi:
        'Tô lần lượt từ sọc trên xuống, mỗi sọc đếm xem còn mấy màu được chọn.',
    hEn: 'Colour from the top down, counting how many colours are allowed each time.',
    eVi: eVi,
    eEn: eEn,
    kw: [('flag', 'lá cờ'), ('stripe', 'sọc'), ('colour', 'màu')],
    ans: ans,
    wrong: [k * k * k, k * (k - 1)],
    params: {'k': k, 'allDiff': allDiff},
  );
}

const List<QuestionGenerator> timo4LogicGenerators = [
  Timo4Generator('logic.table', 'logic', _table),
];

const List<QuestionGenerator> timo4ArithGenerators = [
  Timo4Generator('arith.pairsum', 'arith', _pairsum),
];

const List<QuestionGenerator> timo4NumberGenerators = [
  Timo4Generator('number.multiples', 'number', _multiples),
];

const List<QuestionGenerator> timo4GeoGenerators = [
  Timo4Generator('geo.pyramid', 'geo', _pyramid),
  Timo4Generator('geo.prism', 'geo', _prism),
];

const List<QuestionGenerator> timo4CombGenerators = [
  Timo4Generator('comb.flag', 'comb', _flag),
];
