import 'dart:math';

import '../question.dart';

/// 24 dạng bài bổ sung theo đề vòng loại TIMO lớp 2 (2026–2027 và 4 đề ôn),
/// chuyển từ `tools/question_bank/gen_timo2.py` (bản điền số).
///
/// Chỉ lấy dạng bài từ đề thật, số và lời văn tự soạn. Khuôn khổ lớp 2:
/// số trong phạm vi 100 (dãy số tới 200), nhân trong bảng 2–5, chia hết.
/// Mọi dạng đều là câu điền số (ở bậc lẻ app tự đổi thành trắc nghiệm
/// bằng đáp án nhiễu), nên không có dạng nào thuộc `choiceOnly`.
/// Mỗi câu ghi tham số vào [Question.params] để test giải lại độc lập.
class Timo2Generator extends QuestionGenerator {
  const Timo2Generator(this.formId, this.topic, this._build);

  @override
  final String formId;

  @override
  final String topic;

  final Question Function(Timo2Generator g, int level, Random r) _build;

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    return _build(this, level, random);
  }
}

Question _mk(
  Timo2Generator g,
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

String _join(List<int> xs, [String sep = ', ']) => xs.join(sep);

// ============================================================ TƯ DUY LÔGIC

Question _classsize(Timo2Generator g, int level, Random r) {
  final (lo, hi) = switch (level) {
    1 => (3, 9),
    2 => (6, 15),
    _ => (10, 20),
  };
  final a = randint(r, lo, hi);
  final b = randint(r, lo, hi);
  final c = level == 1 ? 0 : randint(r, 1, 3);
  final x = pickNames(r, 1)[0];
  final ans = a + b + c + 1;
  final sameVi = c > 0 ? ', $c bạn cao bằng $x' : '';
  final sameEn = c > 0 ? ', and $c are as tall as $x' : '';
  return _mk(
    g,
    level,
    r,
    qVi:
        'Trong lớp của $x, có $a bạn cao hơn $x, $b bạn thấp hơn $x$sameVi. Hỏi lớp có tất cả bao nhiêu học sinh?',
    qEn:
        "In $x's class, $a classmates are taller than $x, $b are shorter$sameEn. How many students are in the class?",
    hVi: 'Đừng quên đếm chính $x.',
    hEn: "Don't forget to count $x.",
    eVi:
        'Số bạn khác $x: $a + $b + $c = ${a + b + c}. Cộng thêm chính $x: ${a + b + c} + 1 = $ans (học sinh).',
    eEn: 'Classmates other than $x: ${a + b + c}. Add $x: $ans.',
    kw: [('taller', 'cao hơn'), ('shorter', 'thấp hơn')],
    ans: ans,
    wrong: [a + b + c, a + b],
    params: {'taller': a, 'shorter': b, 'same': c},
  );
}

Question _seqGrow(Timo2Generator g, int level, Random r) {
  final dd0 = randint(r, 1, 3);
  final step = level == 1 ? 1 : randint(r, 1, 2);
  final down = level == 3;
  final total = [for (var i = 0; i < 6; i++) dd0 + i * step]
      .reduce((a, b) => a + b);
  final a0 = down ? total + randint(r, 1, 15) : randint(r, 1, 10);
  final seq = <int>[a0];
  var diff = dd0;
  for (var i = 0; i < 6; i++) {
    seq.add(down ? seq.last - diff : seq.last + diff);
    diff += step;
  }
  final shown = seq.sublist(0, 6);
  final ans = seq[6];
  final gaps = [for (var i = 0; i < 6; i++) (seq[i + 1] - seq[i]).abs()];
  return _mk(
    g,
    level,
    r,
    qVi: 'Tìm số tiếp theo của dãy: ${_join(shown)}, ...',
    qEn: 'Find the next number: ${_join(shown)}, ...',
    hVi: 'Viết khoảng cách giữa hai số liền nhau.',
    hEn: 'Write down the gaps between neighbours.',
    eVi:
        'Khoảng cách giữa hai số liền nhau là ${_join(gaps.sublist(0, 5))}: mỗi lần thêm $step. Khoảng cách tiếp theo là ${gaps[5]}, nên số tiếp theo là $ans.',
    eEn:
        'The gaps are ${_join(gaps.sublist(0, 5))}, growing by $step. Next gap ${gaps[5]}: $ans.',
    kw: [('sequence', 'dãy số'), ('next', 'tiếp theo')],
    ans: ans,
    wrong: [down ? shown.last - gaps[4] : shown.last + gaps[4]],
    params: {'seq': seq},
  );
}

Question _interleave(Timo2Generator g, int level, Random r) {
  final a = randint(r, 40, 60);
  final da = randint(r, 2, 5);
  final b = randint(r, 1, 5);
  final db = randint(r, 2, 3);
  final n = level == 1 ? 6 : randint(r, 6, 7);
  final seq = [
    for (var i = 0; i <= n; i++)
      i.isEven ? a - (i ~/ 2) * da : b + (i ~/ 2) * db,
  ];
  final ans = seq[n];
  return _mk(
    g,
    level,
    r,
    qVi: 'Tìm số tiếp theo của dãy: ${_join(seq.sublist(0, n))}, ...',
    qEn: 'Find the next number: ${_join(seq.sublist(0, n))}, ...',
    hVi: 'Tách các số ở vị trí lẻ và vị trí chẵn thành hai dãy.',
    hEn: 'Split odd and even positions into two sequences.',
    eVi:
        'Đây là hai dãy xen kẽ: các số ở vị trí lẻ giảm $da, các số ở vị trí chẵn tăng $db. Số tiếp theo là $ans.',
    eEn:
        'Two sequences are mixed: odd places go down by $da, even places go up by $db. Next: $ans.',
    kw: [('sequence', 'dãy số'), ('alternate', 'xen kẽ')],
    ans: ans,
    wrong: [seq[n - 1] + db, seq[n - 1] - da],
    params: {'seq': seq, 'n': n},
  );
}

const _shapes = ['▲', '■', '●', '★'];
const _shapeVi = {
  '▲': 'tam giác',
  '■': 'hình vuông',
  '●': 'hình tròn',
  '★': 'ngôi sao',
};
const _shapeEn = {'▲': 'triangle', '■': 'square', '●': 'circle', '★': 'star'};

Question _cyclepattern(Timo2Generator g, int level, Random r) {
  final len = level + 2;
  late List<String> pat;
  do {
    pat = [for (var i = 0; i < len; i++) pickOne(r, _shapes)];
  } while (pat.toSet().length < 2);
  final n = randint(r, 10, 25);
  // Hình xuất hiện nhiều nhất trong một nhóm (hòa thì lấy hình gặp trước).
  var sym = pat[0];
  for (final s in pat) {
    if (pat.where((x) => x == s).length > pat.where((x) => x == sym).length) {
      sym = s;
    }
  }
  final per = pat.where((x) => x == sym).length;
  final full = n ~/ len;
  final rem = n % len;
  final extra = pat.sublist(0, rem).where((x) => x == sym).length;
  final ans = full * per + extra;
  final shown = [...pat, ...pat].join(' ');
  return _mk(
    g,
    level,
    r,
    qVi:
        'Các hình được xếp lặp lại theo quy luật: $shown ... Hỏi trong $n hình đầu tiên có bao nhiêu ${_shapeVi[sym]} $sym?',
    qEn:
        'The shapes repeat: $shown ... How many ${_shapeEn[sym]}s $sym are in the first $n shapes?',
    hVi: 'Đếm theo từng nhóm lặp lại.',
    hEn: 'Count group by group.',
    eVi:
        'Mỗi nhóm $len hình có $per ${_shapeVi[sym]}. $n hình gồm $full nhóm và $rem hình. Số ${_shapeVi[sym]}: $full × $per + $extra = $ans.',
    eEn:
        'Each group of $len has $per. $n = $full groups + $rem shapes. Total $ans.',
    kw: [('pattern', 'quy luật'), ('repeat', 'lặp lại')],
    ans: ans,
    wrong: [full * per, ans + 1],
    params: {'pattern': pat, 'n': n, 'sym': sym},
  );
}

Question _laps(Timo2Generator g, int level, Random r) {
  final n = level == 1 ? randint(r, 2, 4) : randint(r, 4, level == 2 ? 6 : 8);
  final t = pickOne(r, level == 1 ? [2, 3, 5] : [3, 5, 10]);
  final rest = randint(r, 1, 2);
  final x = pickNames(r, 1)[0];
  final ans = n * t + (n - 1) * rest;
  return _mk(
    g,
    level,
    r,
    qVi:
        '$x chạy $n vòng quanh sân. Mỗi vòng chạy hết $t phút. Chạy xong mỗi vòng thì nghỉ $rest phút rồi mới chạy tiếp (chạy xong vòng cuối thì không nghỉ). Hỏi $x mất tất cả bao nhiêu phút?',
    qEn:
        '$x runs $n laps. Each lap takes $t minutes, with a $rest-minute rest between laps (no rest after the last one). How many minutes in total?',
    hVi: 'Số lần nghỉ ít hơn số vòng 1 lần.',
    hEn: 'There is one fewer rest than laps.',
    eVi:
        'Thời gian chạy: $n × $t = ${n * t} phút. Số lần nghỉ: $n − 1 = ${n - 1}, nghỉ ${(n - 1) * rest} phút. Tổng: ${n * t} + ${(n - 1) * rest} = $ans (phút).',
    eEn:
        'Running ${n * t}, resting ${n - 1} times = ${(n - 1) * rest}. Total $ans.',
    kw: [('lap', 'vòng'), ('rest', 'nghỉ')],
    ans: ans,
    wrong: [n * (t + rest), n * t],
    params: {'n': n, 't': t, 'r': rest},
  );
}

// ============================================================ SỐ HỌC

Question _altsum(Timo2Generator g, int level, Random r) {
  final s = randint(r, 2, 3);
  final n = switch (level) {
    1 => 5,
    2 => 7,
    _ => 8,
  };
  final a = randint(r, s * (n + 2), 50);
  final terms = [for (var i = 0; i < n; i++) a - i * s];
  final buf = StringBuffer('${terms[0]}');
  var ans = terms[0];
  for (var i = 1; i < n; i++) {
    buf.write(i.isOdd ? ' − ${terms[i]}' : ' + ${terms[i]}');
    ans += i.isOdd ? -terms[i] : terms[i];
  }
  final pairs = n ~/ 2;
  final tailVi = n.isOdd ? ' và còn số ${terms.last}' : '';
  final tailEn = n.isOdd ? ' plus ${terms.last}' : '';
  return _mk(
    g,
    level,
    r,
    qVi: 'Tính nhanh: $buf = ?',
    qEn: 'Calculate quickly: ${buf.toString().replaceAll('−', '-')} = ?',
    hVi: 'Ghép hai số liền nhau thành một cặp.',
    hEn: 'Group neighbours into pairs.',
    eVi:
        'Ghép từng cặp (số trước trừ số sau), mỗi cặp bằng $s. Có $pairs cặp$tailVi. Kết quả: $ans.',
    eEn: 'Each pair equals $s. $pairs pairs$tailEn = $ans.',
    kw: [('calculate quickly', 'tính nhanh'), ('pair', 'cặp')],
    ans: ans,
    wrong: [ans + s, ans - s],
    params: {'terms': terms},
  );
}

Question _runsum(Timo2Generator g, int level, Random r) {
  final step = level == 1 ? 1 : (level == 2 ? randint(r, 1, 2) : 2);
  final n = switch (level) {
    1 => 6,
    2 => pickOne(r, [6, 8]),
    _ => pickOne(r, [8, 9]),
  };
  final a = step == 1 ? randint(r, 1, 9) : randint(r, 1, 2);
  final terms = [for (var i = 0; i < n; i++) a + i * step];
  final ans = terms.reduce((x, y) => x + y);
  final pair = terms.first + terms.last;
  final midVi = n.isOdd ? ', còn số giữa ${terms[n ~/ 2]}' : '';
  final midEn = n.isOdd ? ' plus ${terms[n ~/ 2]}' : '';
  return _mk(
    g,
    level,
    r,
    qVi: 'Tính nhanh: ${_join(terms, ' + ')} = ?',
    qEn: 'Calculate quickly: ${_join(terms, ' + ')} = ?',
    hVi: 'Ghép số đầu với số cuối, số thứ hai với số kế cuối, ...',
    hEn: 'Pair the first with the last, ...',
    eVi:
        'Ghép số đầu với số cuối: ${terms.first} + ${terms.last} = $pair. Có ${n ~/ 2} cặp như vậy$midVi. Tổng: $ans.',
    eEn: 'Each pair is $pair, ${n ~/ 2} pairs$midEn. Total $ans.',
    kw: [('sum', 'tổng'), ('calculate quickly', 'tính nhanh')],
    ans: ans,
    wrong: [ans - step, ans + 10],
    params: {'terms': terms},
  );
}

int _abOp(int a, int b, bool plus) => plus ? 10 * a + b + a : 10 * a + b - a;

Question _cryptarith(Timo2Generator g, int level, Random r) {
  late int a, b, res;
  late bool plus;
  while (true) {
    a = randint(r, 1, 9);
    b = randint(r, 1, 9);
    plus = level == 1 ? true : r.nextBool();
    res = _abOp(a, b, plus);
    if (a == b || res < 10 || res > 99) continue;
    var sols = 0;
    for (var x = 1; x <= 9; x++) {
      for (var y = 0; y <= 9; y++) {
        if (x != y && _abOp(x, y, plus) == res) sols++;
      }
    }
    if (sols == 1) break;
  }
  final op = plus ? '+' : '−';
  return _mk(
    g,
    level,
    r,
    qVi:
        'Biết A và B là hai chữ số khác nhau và số có hai chữ số AB $op A = $res. Hỏi B bằng mấy?',
    qEn:
        'A and B are different digits and the 2-digit number AB ${plus ? '+' : '-'} A = $res. Find B.',
    hVi: 'Chữ số hàng chục của kết quả gợi ý giá trị của A.',
    hEn: 'The tens digit of the result hints at A.',
    eVi:
        'Thử từng giá trị của A: chỉ có A = $a cho AB = ${10 * a + b} và ${10 * a + b} $op $a = $res. Vậy B = $b.',
    eEn: 'Try each A: only A = $a works, giving AB = ${10 * a + b}. So B = $b.',
    kw: [('digit', 'chữ số'), ('different', 'khác nhau')],
    ans: b,
    wrong: [a, res % 10],
    params: {'A': a, 'plus': plus, 'res': res},
  );
}

Question _arrowchain(Timo2Generator g, int level, Random r) {
  final k = level + 1;
  final start = randint(r, 5, 40);
  final ops = <(bool, int)>[];
  var v = start;
  for (var i = 0; i < k; i++) {
    var plus = r.nextBool();
    final x = randint(r, 3, 25);
    if (!plus && v - x < 1) plus = true;
    if (plus && v + x > 99) plus = false;
    v = plus ? v + x : v - x;
    ops.add((plus, x));
  }
  final chainVi = ops.map((o) => '${o.$1 ? '+' : '−'}${o.$2}').join(' → ');
  final chainEn = ops.map((o) => '${o.$1 ? '+' : '-'}${o.$2}').join(' → ');
  final back = ops.reversed.map((o) => '${o.$1 ? '−' : '+'} ${o.$2}').join(' ');
  return _mk(
    g,
    level,
    r,
    qVi:
        'Một số đi qua các phép tính theo mũi tên: ? → $chainVi → $v. Tìm số ở dấu ?',
    qEn: 'A number goes through: ? → $chainEn → $v. Find ?.',
    hVi: 'Đi ngược từ cuối lên: cộng thành trừ, trừ thành cộng.',
    hEn: 'Work backwards: plus becomes minus.',
    eVi: 'Đi ngược từ $v và làm phép tính ngược lại: $v $back = $start.',
    eEn: 'Go backwards from $v with the opposite operations: $start.',
    kw: [('arrow', 'mũi tên'), ('backwards', 'ngược lại')],
    ans: start,
    wrong: [v],
    params: {
      'plus': [for (final o in ops) o.$1],
      'xs': [for (final o in ops) o.$2],
      'end': v,
    },
  );
}

Question _flowerx(Timo2Generator g, int level, Random r) {
  final k = level < 3 ? 2 : 3;
  final a = randint(r, 5, 25);
  var b = randint(r, 5, 25);
  if (k == 3 && (a + b).isOdd) b += 1;
  final lhs = List.filled(k, '✿').join(' + ');
  final ans = k == 2 ? a + b : (a + b) ~/ 2;
  final ex = k == 2
      ? 'Bớt một ✿ ở cả hai bên: ✿ − $a = $b, nên ✿ = $b + $a = $ans.'
      : 'Bớt một ✿ ở cả hai bên: ✿ + ✿ − $a = $b, nên ✿ + ✿ = ${a + b}, ✿ = $ans.';
  final exEn = k == 2
      ? 'Remove one ✿ from both sides: ✿ - $a = $b, so ✿ = $ans.'
      : 'Remove one ✿ from both sides: ✿ + ✿ - $a = $b, so ✿ + ✿ = ${a + b}, ✿ = $ans.';
  return _mk(
    g,
    level,
    r,
    qVi: 'Biết $lhs − $a = ✿ + $b. Hỏi ✿ bằng bao nhiêu?',
    qEn: '$lhs - $a = ✿ + $b. What is ✿?',
    hVi: 'Bớt đi cùng một bông hoa ở hai bên dấu bằng.',
    hEn: 'Take one flower away from both sides.',
    eVi: ex,
    eEn: exEn,
    kw: [('equal', 'bằng nhau')],
    ans: ans,
    wrong: [(a - b).abs(), ans * 2],
    params: {'k': k, 'a': a, 'b': b},
  );
}

Question _factorOut(Timo2Generator g, int level, Random r) {
  final m = switch (level) {
    1 => 2,
    2 => randint(r, 2, 3),
    _ => randint(r, 3, 5),
  };
  final n = level == 1 ? 3 : 4;
  late List<int> xs;
  do {
    xs = [for (var i = 0; i < n; i++) randint(r, 2, 15)];
  } while (xs.reduce((a, b) => a + b) < 10 ||
      m * xs.reduce((a, b) => a + b) > 100);
  final sum = xs.reduce((a, b) => a + b);
  final parts = [for (final x in xs) r.nextBool() ? '$m × $x' : '$x × $m'];
  final ans = m * sum;
  return _mk(
    g,
    level,
    r,
    qVi: 'Tính nhanh: ${parts.join(' + ')} = ?',
    qEn: 'Calculate quickly: ${parts.join(' + ')} = ?',
    hVi: 'Tìm thừa số chung $m.',
    hEn: 'Find the common factor $m.',
    eVi:
        'Mỗi tích đều có thừa số $m: $m × (${_join(xs, ' + ')}) = $m × $sum = $ans.',
    eEn: 'Each product has a factor $m: $m × $sum = $ans.',
    kw: [('product', 'tích'), ('factor', 'thừa số')],
    ans: ans,
    wrong: [sum, ans + m],
    params: {'m': m, 'xs': xs},
  );
}

// ============================================================ LÝ THUYẾT SỐ

Question _digitcond(Timo2Generator g, int level, Random r) {
  final kinds = switch (level) {
    1 => ['both_gt', 'both_lt'],
    2 => ['both_gt', 'both_lt', 'unit_lt'],
    _ => ['unit_lt', 'tens_gt_unit', 'sum_eq'],
  };
  final kind = pickOne(r, kinds);
  final k = switch (kind) {
    'both_gt' => randint(r, 5, 7),
    'both_lt' => randint(r, 3, 5),
    'unit_lt' => randint(r, 2, 5),
    'sum_eq' => randint(r, 5, 12),
    _ => 0,
  };
  bool ok(int t, int u) => switch (kind) {
    'both_gt' => t > k && u > k,
    'both_lt' => t < k && u < k,
    'unit_lt' => u < k,
    'tens_gt_unit' => t > u,
    _ => t + u == k,
  };
  var ans = 0;
  for (var nn = 10; nn < 100; nn++) {
    if (ok(nn ~/ 10, nn % 10)) ans++;
  }
  final cVi = switch (kind) {
    'both_gt' => 'cả hai chữ số đều lớn hơn $k',
    'both_lt' => 'cả hai chữ số đều nhỏ hơn $k',
    'unit_lt' => 'chữ số hàng đơn vị nhỏ hơn $k',
    'tens_gt_unit' => 'chữ số hàng chục lớn hơn chữ số hàng đơn vị',
    _ => 'tổng hai chữ số bằng $k',
  };
  final cEn = switch (kind) {
    'both_gt' => 'both digits greater than $k',
    'both_lt' => 'both digits less than $k',
    'unit_lt' => 'a units digit less than $k',
    'tens_gt_unit' => 'a tens digit greater than the units digit',
    _ => 'a digit sum of $k',
  };
  return _mk(
    g,
    level,
    r,
    qVi: 'Có bao nhiêu số có hai chữ số mà $cVi?',
    qEn: 'How many 2-digit numbers have $cEn?',
    hVi: 'Liệt kê theo chữ số hàng chục. Hàng chục không thể là 0.',
    hEn: 'List by the tens digit. The tens digit cannot be 0.',
    eVi:
        'Liệt kê theo chữ số hàng chục (từ 1 đến 9), đếm các chữ số hàng đơn vị phù hợp. Có tất cả $ans số.',
    eEn:
        'List by the tens digit (1 to 9) and count the units digits that fit. There are $ans.',
    kw: [('digit', 'chữ số'), ('2-digit number', 'số có hai chữ số')],
    ans: ans,
    wrong: [ans + 1, ans + 9],
    params: {'kind': kind, 'k': k},
  );
}

Question _parityOps(Timo2Generator g, int level, Random r) {
  final count = level + 3;
  final wantEven = r.nextBool();
  late List<(int, bool, int)> ops;
  late int ans;
  do {
    ops = [];
    for (var i = 0; i < count; i++) {
      final plus = r.nextBool();
      final a = randint(r, 11, 70);
      final b = plus ? randint(r, 3, 29) : randint(r, 3, a - 1);
      ops.add((a, plus, b));
    }
    ans = ops
        .map((o) => o.$2 ? o.$1 + o.$3 : o.$1 - o.$3)
        .where((v) => v.isEven == wantEven)
        .length;
  } while (ans == 0 || ans == count);
  final vals = [for (final o in ops) o.$2 ? o.$1 + o.$3 : o.$1 - o.$3];
  final lstVi = ops
      .map((o) => '${o.$1} ${o.$2 ? '+' : '−'} ${o.$3}')
      .join(';  ');
  final lstEn = ops
      .map((o) => '${o.$1} ${o.$2 ? '+' : '-'} ${o.$3}')
      .join(';  ');
  final wVi = wantEven ? 'chẵn' : 'lẻ';
  final wEn = wantEven ? 'even' : 'odd';
  return _mk(
    g,
    level,
    r,
    qVi:
        'Trong các phép tính sau, có bao nhiêu phép tính có kết quả là số $wVi?  $lstVi',
    qEn: 'How many of these results are $wEn?  $lstEn',
    hVi: 'Chỉ cần xem chữ số hàng đơn vị của hai số là chẵn hay lẻ.',
    hEn: 'Only look at the units digits.',
    eVi:
        'Hai số cùng chẵn hoặc cùng lẻ thì tổng (hiệu) là số chẵn; một chẵn một lẻ thì là số lẻ. Kết quả: ${_join(vals)}. Có $ans phép tính có kết quả là số $wVi.',
    eEn:
        'Same parity gives even, different parity gives odd. Results: ${_join(vals)}. $ans are $wEn.',
    kw: [('even', 'chẵn'), ('odd', 'lẻ')],
    ans: ans,
    wrong: [count - ans, ans + 1],
    params: {
      'a': [for (final o in ops) o.$1],
      'plus': [for (final o in ops) o.$2],
      'b': [for (final o in ops) o.$3],
      'even': wantEven,
    },
  );
}

Question _kth(Timo2Generator g, int level, Random r) {
  final n = level == 1 ? 6 : 8;
  final pool = [for (var i = 10; i < 100; i++) i]..shuffle(r);
  final xs = pool.take(n).toList();
  final k = level == 1 ? 2 : randint(r, 2, 3);
  final largest = r.nextBool();
  final sorted = [...xs]..sort((a, b) => largest ? b - a : a - b);
  final ans = sorted[k - 1];
  final kVi = largest ? 'lớn' : 'bé';
  final kEn = largest ? 'largest' : 'smallest';
  final ord = k == 2 ? '2nd' : '3rd';
  return _mk(
    g,
    level,
    r,
    qVi: 'Cho các số: ${_join(xs)}. Hỏi số $kVi thứ $k là số nào?',
    qEn: 'Numbers: ${_join(xs)}. Which is the $ord $kEn?',
    hVi: 'Sắp xếp các số trước.',
    hEn: 'Sort the numbers first.',
    eVi:
        'Sắp xếp ${largest ? 'từ lớn đến bé' : 'từ bé đến lớn'}: ${_join(sorted)}. Số thứ $k là $ans.',
    eEn: 'Sorted: ${_join(sorted)}. Number $k is $ans.',
    kw: [('largest', 'lớn nhất'), ('smallest', 'bé nhất')],
    ans: ans,
    wrong: [sorted[0], sorted[k]],
    params: {'xs': xs, 'k': k, 'largest': largest},
  );
}

Question _giveequal(Timo2Generator g, int level, Random r) {
  late int a, b, c;
  do {
    a = randint(r, 20, 90);
    b = randint(r, 10, 60);
    c = level < 3 ? 0 : pickOne(r, [2, 4, 6, 10]);
  } while (a <= b || a - b - c <= 0 || (a - b - c).isOdd);
  final names = pickNames(r, 2);
  final x = names[0];
  final y = names[1];
  final ans = (a - b - c) ~/ 2;
  final qVi = c == 0
      ? '$x có $a viên bi, $y có $b viên bi. $x phải cho $y bao nhiêu viên để số bi của hai bạn bằng nhau?'
      : '$x có $a viên bi, $y có $b viên bi. $x phải cho $y bao nhiêu viên để $x còn nhiều hơn $y $c viên?';
  final qEn = c == 0
      ? '$x has $a marbles and $y has $b. How many must $x give $y so they have the same?'
      : '$x has $a marbles and $y has $b. How many must $x give $y so that $x has $c more than $y?';
  return _mk(
    g,
    level,
    r,
    qVi: qVi,
    qEn: qEn,
    hVi: 'Cho đi 1 viên thì khoảng cách giữa hai bạn giảm 2 viên.',
    hEn: 'Giving 1 marble closes the gap by 2.',
    eVi:
        'Lúc đầu $x hơn $y $a − $b = ${a - b} viên. Mỗi viên $x cho đi làm khoảng cách giảm 2. Cần giảm ${a - b} − $c = ${a - b - c} viên, nên $x cho $y ${a - b - c} : 2 = $ans (viên).',
    eEn:
        'The gap is ${a - b}; each marble given shrinks it by 2. It must shrink by ${a - b - c}, so give $ans.',
    kw: [('give', 'cho'), ('the same', 'bằng nhau')],
    ans: ans,
    wrong: [a - b, a - b - c],
    params: {'a': a, 'b': b, 'c': c},
  );
}

Question _pages(Timo2Generator g, int level, Random r) {
  final k = randint(r, 4, 9);
  final a = randint(r, 10, 30);
  final b = level == 1 ? 0 : randint(r, 5, 20);
  final x = pickNames(r, 1)[0];
  final n = a + b;
  final ans = (n + k - 1) ~/ k;
  final qVi = b > 0
      ? '$x có $a con tem, bạn của $x có $b con tem. Mỗi trang album dán được nhiều nhất $k con tem. Hỏi cần ít nhất bao nhiêu trang để dán hết tem của hai bạn?'
      : 'Có $a quả trứng, mỗi hộp đựng được nhiều nhất $k quả. Hỏi cần ít nhất bao nhiêu hộp để đựng hết số trứng?';
  final qEn = b > 0
      ? '$x has $a stamps and a friend has $b. Each album page holds at most $k. At least how many pages are needed for all of them?'
      : 'There are $a eggs and each box holds at most $k. At least how many boxes are needed?';
  final eVi = n % k == 0
      ? 'Có $n vật. $n : $k = ${n ~/ k}, vừa đủ $ans.'
      : 'Có $n vật. Xếp đầy được ${n ~/ k} lần, còn thừa ${n % k} vật nên cần thêm 1 nữa. Tất cả $ans.';
  return _mk(
    g,
    level,
    r,
    qVi: qVi,
    qEn: qEn,
    hVi: 'Phần còn thừa vẫn cần thêm một chỗ nữa.',
    hEn: 'Leftovers still need one more.',
    eVi: eVi,
    eEn: '$n items, $k each: $ans needed.',
    kw: [('at most', 'nhiều nhất'), ('at least', 'ít nhất')],
    ans: ans,
    wrong: [n ~/ k, ans + 1],
    params: {'n': n, 'k': k},
  );
}

Question _countsteps(Timo2Generator g, int level, Random r) {
  final step = level < 3 ? 2 : pickOne(r, [3, 5]);
  var a = randint(r, 2, 20);
  a -= a % step;
  if (a == 0) a = step;
  if (level == 2 && step == 2) a += 1; // mức 2: dãy số lẻ
  var b = randint(r, a + 20, 90);
  b -= (b - a) % step;
  final ans = (b - a) ~/ step + 1;
  final sVi = step == 2
      ? (a.isEven ? 'các số chẵn' : 'các số lẻ')
      : 'các số cách nhau $step đơn vị';
  return _mk(
    g,
    level,
    r,
    qVi:
        'Các quả bóng được đánh số bằng $sVi liên tiếp từ $a đến $b. Hỏi có bao nhiêu quả bóng?',
    qEn:
        'Balls are numbered every $step from $a to $b. How many balls are there?',
    hVi: 'Số quả bóng nhiều hơn số khoảng cách 1.',
    hEn: 'There is one more ball than gaps.',
    eVi:
        'Số khoảng cách: ($b − $a) : $step = ${(b - a) ~/ step}. Số quả bóng nhiều hơn số khoảng cách 1: $ans.',
    eEn:
        'Gaps: ($b - $a) ÷ $step = ${(b - a) ~/ step}. Balls = gaps + 1 = $ans.',
    kw: [('from ... to ...', 'từ ... đến ...'), ('consecutive', 'liên tiếp')],
    ans: ans,
    wrong: [ans - 1, b - a],
    params: {'a': a, 'b': b, 'step': step},
  );
}

// ============================================================ HÌNH HỌC

Question _pointsegs(Timo2Generator g, int level, Random r) {
  final n = switch (level) {
    1 => randint(r, 3, 4),
    2 => randint(r, 4, 5),
    _ => randint(r, 5, 6),
  };
  final ans = n * (n - 1) ~/ 2;
  return _mk(
    g,
    level,
    r,
    qVi:
        'Cho $n điểm, không có ba điểm nào thẳng hàng. Nối hai điểm bất kỳ được một đoạn thẳng. Hỏi vẽ được nhiều nhất bao nhiêu đoạn thẳng?',
    qEn:
        'There are $n points, no three in a line. Joining any two makes a segment. At most how many segments?',
    hVi: 'Đặt tên các điểm rồi liệt kê từng đoạn thẳng.',
    hEn: 'Name the points and list the segments.',
    eVi:
        'Mỗi điểm nối với $n − 1 = ${n - 1} điểm còn lại, nhưng mỗi đoạn được đếm 2 lần: $n × ${n - 1} : 2 = $ans (đoạn thẳng).',
    eEn:
        'Each point joins ${n - 1} others; each segment is counted twice: $ans.',
    kw: [('point', 'điểm'), ('segment', 'đoạn thẳng')],
    ans: ans,
    wrong: [n * (n - 1), n],
    params: {'n': n},
  );
}

const _shapeParts = [
  // (tên VI, tên EN, cạnh, đỉnh, mặt)
  ('hình tam giác', 'triangle', 3, 3, 0),
  ('hình vuông', 'square', 4, 4, 0),
  ('hình chữ nhật', 'rectangle', 4, 4, 0),
  ('hình lập phương', 'cube', 12, 8, 6),
];

Question _shapeparts(Timo2Generator g, int level, Random r) {
  final whatOpts = level < 3 ? ['cạnh', 'đỉnh'] : ['cạnh', 'đỉnh', 'mặt'];
  final what = pickOne(r, whatOpts);
  late List<int> items;
  late List<int> cnts;
  if (what == 'mặt') {
    items = [3];
    cnts = [randint(r, 2, 4)];
  } else {
    final idx = [0, 1, 2, 3]..shuffle(r);
    items = idx.take(level < 3 ? 2 : 3).toList();
    cnts = [for (final _ in items) randint(r, 1, 3)];
  }
  int part(int i) => switch (what) {
    'cạnh' => _shapeParts[i].$3,
    'đỉnh' => _shapeParts[i].$4,
    _ => _shapeParts[i].$5,
  };
  var ans = 0;
  for (var j = 0; j < items.length; j++) {
    ans += cnts[j] * part(items[j]);
  }
  final lVi = [
    for (var j = 0; j < items.length; j++)
      '${cnts[j]} ${_shapeParts[items[j]].$1}',
  ].join(' và ');
  final lEn = [
    for (var j = 0; j < items.length; j++)
      '${cnts[j]} ${_shapeParts[items[j]].$2}${cnts[j] > 1 ? 's' : ''}',
  ].join(' and ');
  final wEn = switch (what) {
    'cạnh' => 'sides/edges',
    'đỉnh' => 'vertices',
    _ => 'faces',
  };
  final calc = [
    for (var j = 0; j < items.length; j++) '${cnts[j]} × ${part(items[j])}',
  ].join(' + ');
  return _mk(
    g,
    level,
    r,
    qVi: 'Có $lVi. Hỏi tất cả có bao nhiêu $what?',
    qEn: 'There are $lEn. How many $wEn in total?',
    hVi: 'Nhớ: hình lập phương có 12 cạnh, 8 đỉnh, 6 mặt.',
    hEn: 'A cube has 12 edges, 8 vertices and 6 faces.',
    eVi: '$calc = $ans ($what).',
    eEn: '$calc = $ans.',
    kw: [('side / edge', 'cạnh'), ('vertex', 'đỉnh'), ('face', 'mặt')],
    ans: ans,
    wrong: [ans + 1, ans - 1],
    params: {'items': items, 'cnts': cnts, 'what': what},
  );
}

// ============================================================ TỔ HỢP

Question _makenumParity(Timo2Generator g, int level, Random r) {
  final k = level + 2;
  late List<int> ds;
  late bool wantEven;
  late List<int> nums;
  do {
    final pool = [for (var i = 0; i <= 9; i++) i]..shuffle(r);
    ds = pool.take(k).toList()..sort();
    wantEven = r.nextBool();
    nums = [
      for (final a in ds)
        for (final b in ds)
          if (a != b && a != 0 && b.isEven == wantEven) 10 * a + b,
    ]..sort();
  } while ((level == 1 && ds.contains(0)) || nums.isEmpty);
  final ans = nums.length;
  final wVi = wantEven ? 'chẵn' : 'lẻ';
  final wEn = wantEven ? 'even' : 'odd';
  return _mk(
    g,
    level,
    r,
    qVi:
        'Chọn 2 chữ số khác nhau từ các chữ số ${_join(ds)} để lập số có hai chữ số. Hỏi lập được bao nhiêu số $wVi?',
    qEn:
        'Choose 2 different digits from ${_join(ds)} to make 2-digit numbers. How many $wEn numbers can be made?',
    hVi: 'Chọn chữ số hàng đơn vị trước; hàng chục không được là 0.',
    hEn: "Choose the units digit first; the tens digit can't be 0.",
    eVi:
        'Chọn chữ số hàng đơn vị là số $wVi trước, rồi chọn hàng chục (khác 0, khác hàng đơn vị). Các số: ${_join(nums)}. Có $ans số.',
    eEn:
        'Units digit first, then tens (not 0, not the same). Numbers: ${_join(nums)}. $ans numbers.',
    kw: [('digit', 'chữ số'), (wEn, wVi)],
    ans: ans,
    wrong: [ans + 1, k * (k - 1)],
    params: {'digits': ds, 'even': wantEven},
  );
}

Question _minsum2(Timo2Generator g, int level, Random r) {
  final pool = [for (var i = 1; i <= 9; i++) i]..shuffle(r);
  final ds = pool.take(4).toList()..sort();
  final isMin = level < 3 ? true : r.nextBool();
  final a = ds[0], b = ds[1], c = ds[2], e = ds[3];
  final best = isMin ? 10 * (a + b) + c + e : 10 * (e + c) + b + a;
  final ex = isMin
      ? 'Hai chữ số nhỏ nhất $a, $b đặt ở hàng chục, $c, $e ở hàng đơn vị: ${10 * a + c} + ${10 * b + e} = $best.'
      : 'Hai chữ số lớn nhất $e, $c đặt ở hàng chục, $b, $a ở hàng đơn vị: ${10 * e + b} + ${10 * c + a} = $best.';
  final kVi = isMin ? 'nhỏ nhất' : 'lớn nhất';
  final kEn = isMin ? 'smallest' : 'largest';
  return _mk(
    g,
    level,
    r,
    qVi:
        'Dùng cả bốn chữ số ${_join(ds)} (mỗi chữ số dùng một lần) để lập hai số có hai chữ số rồi cộng lại. Hỏi tổng $kVi là bao nhiêu?',
    qEn:
        'Use each of the digits ${_join(ds)} once to make two 2-digit numbers, then add them. What is the $kEn sum?',
    hVi: 'Chữ số ở hàng chục có giá trị gấp 10 lần.',
    hEn: 'Tens digits count 10 times more.',
    eVi: ex,
    eEn: ex,
    kw: [(kEn, kVi), ('digit', 'chữ số')],
    ans: best,
    wrong: [10 * a + b + 10 * c + e, best + 9],
    params: {'digits': ds, 'min': isMin},
  );
}

Question _freebie(Timo2Generator g, int level, Random r) {
  final p = pickOne(r, [2, 3, 5]);
  final k = randint(r, 3, 5);
  final buy = level == 1 ? pickOne(r, [k, 2 * k]) : randint(r, k, 10);
  final money = buy * p;
  final free = buy ~/ k;
  final ans = buy + free;
  return _mk(
    g,
    level,
    r,
    qVi:
        'Mỗi chiếc bút chì giá $p nghìn đồng. Cứ mua $k chiếc thì được tặng thêm 1 chiếc. Với $money nghìn đồng, bạn có được nhiều nhất bao nhiêu chiếc bút chì?',
    qEn:
        'Each pencil costs $p thousand dong. For every $k you buy you get 1 free. With $money thousand dong, at most how many pencils can you get?',
    hVi: 'Tính số bút mua được trước, rồi đến số bút được tặng.',
    hEn: 'Count bought pencils first, then free ones.',
    eVi:
        'Mua được $money : $p = $buy chiếc. Mỗi $k chiếc được tặng 1: được tặng $free chiếc. Tổng: $buy + $free = $ans (chiếc).',
    eEn: 'Buy $buy, get $free free. Total $ans.',
    kw: [('free', 'tặng'), ('at most', 'nhiều nhất')],
    ans: ans,
    wrong: [buy, ans + 1],
    params: {'p': p, 'k': k, 'money': money},
  );
}

Question _vases(Timo2Generator g, int level, Random r) {
  final n = switch (level) {
    1 => randint(r, 4, 5),
    2 => randint(r, 5, 6),
    _ => randint(r, 6, 7),
  };
  var ans = 0;
  for (var a = 1; a < n; a++) {
    for (var b = 1; b < n; b++) {
      if (n - a - b >= 1) ans++;
    }
  }
  return _mk(
    g,
    level,
    r,
    qVi:
        'Có $n bông hoa giống nhau cắm vào 3 lọ khác nhau, lọ nào cũng có ít nhất 1 bông. Hỏi có bao nhiêu cách cắm?',
    qEn:
        '$n identical flowers go into 3 different vases, each vase gets at least 1. How many ways?',
    hVi: 'Chia trường hợp theo số hoa ở lọ thứ nhất.',
    hEn: 'Split by how many are in the first vase.',
    eVi:
        'Lọ thứ nhất có từ 1 đến ${n - 2} bông; với mỗi trường hợp, đếm cách chia số hoa còn lại cho hai lọ kia (mỗi lọ ít nhất 1 bông). Cộng lại được $ans cách.',
    eEn:
        'The first vase gets 1 to ${n - 2}; split the rest between the other two. Total $ans ways.',
    kw: [('identical', 'giống nhau'), ('at least', 'ít nhất')],
    ans: ans,
    wrong: [ans - 1, n],
    params: {'n': n},
  );
}

Question _pick2(Timo2Generator g, int level, Random r) {
  final n = switch (level) {
    1 => randint(r, 3, 4),
    2 => randint(r, 4, 5),
    _ => randint(r, 5, 6),
  };
  final ordered = level == 3 && r.nextBool();
  final ans = ordered ? n * (n - 1) : n * (n - 1) ~/ 2;
  return _mk(
    g,
    level,
    r,
    qVi: ordered
        ? 'Nhóm có $n bạn. Cần chọn 1 bạn làm nhóm trưởng và 1 bạn khác làm nhóm phó. Hỏi có bao nhiêu cách chọn?'
        : 'Lớp có $n bạn giỏi toán. Cô cần chọn 2 bạn đi thi. Hỏi cô có bao nhiêu cách chọn?',
    qEn: ordered
        ? 'A group has $n children. Pick a leader and a different deputy. How many ways?'
        : 'There are $n good maths students. The teacher picks 2 for a contest. How many ways?',
    hVi: 'Đặt tên các bạn rồi liệt kê từng cách chọn.',
    hEn: 'Name the children and list the choices.',
    eVi: ordered
        ? 'Có $n cách chọn nhóm trưởng, rồi ${n - 1} cách chọn nhóm phó: $n × ${n - 1} = $ans (cách).'
        : 'Mỗi bạn ghép được với ${n - 1} bạn khác, mỗi cặp bị đếm 2 lần: $n × ${n - 1} : 2 = $ans (cách).',
    eEn: ordered
        ? '$n × ${n - 1} = $ans ways.'
        : '$n × ${n - 1} ÷ 2 = $ans ways.',
    kw: [('choose', 'chọn'), ('ways', 'cách')],
    ans: ans,
    wrong: [ordered ? ans ~/ 2 : ans * 2, ans + 1],
    params: {'n': n, 'ordered': ordered},
  );
}

const List<QuestionGenerator> timo2LogicGenerators = [
  Timo2Generator('logic.classsize', 'logic', _classsize),
  Timo2Generator('logic.seqgrow', 'logic', _seqGrow),
  Timo2Generator('logic.interleave', 'logic', _interleave),
  Timo2Generator('logic.cyclepattern', 'logic', _cyclepattern),
  Timo2Generator('logic.laps', 'logic', _laps),
];

const List<QuestionGenerator> timo2ArithGenerators = [
  Timo2Generator('arith.altsum', 'arith', _altsum),
  Timo2Generator('arith.runsum', 'arith', _runsum),
  Timo2Generator('arith.cryptarith', 'arith', _cryptarith),
  Timo2Generator('arith.arrowchain', 'arith', _arrowchain),
  Timo2Generator('arith.flowerx', 'arith', _flowerx),
  Timo2Generator('arith.factorout', 'arith', _factorOut),
];

const List<QuestionGenerator> timo2NumberGenerators = [
  Timo2Generator('number.digitcond', 'number', _digitcond),
  Timo2Generator('number.parityops', 'number', _parityOps),
  Timo2Generator('number.kth', 'number', _kth),
  Timo2Generator('number.giveequal', 'number', _giveequal),
  Timo2Generator('number.pages', 'number', _pages),
  Timo2Generator('number.countsteps', 'number', _countsteps),
];

const List<QuestionGenerator> timo2GeoGenerators = [
  Timo2Generator('geo.pointsegs', 'geo', _pointsegs),
  Timo2Generator('geo.shapeparts', 'geo', _shapeparts),
];

const List<QuestionGenerator> timo2CombGenerators = [
  Timo2Generator('comb.makenumparity', 'comb', _makenumParity),
  Timo2Generator('comb.minsum2', 'comb', _minsum2),
  Timo2Generator('comb.freebie', 'comb', _freebie),
  Timo2Generator('comb.vases', 'comb', _vases),
  Timo2Generator('comb.pick2', 'comb', _pick2),
];
