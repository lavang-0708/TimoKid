import 'dart:math';

import '../question.dart';

/// Mảng Số học / Đại số: 7 dạng bài, chuyển từ `gen_arith()` trong `gen.py`.
///
/// Cách diễn đạt đề và lời giải giữ nguyên như `gen.py`.

/// Dãy số: mức 1, 2, 3.
///
/// Mức 3 có hai biến thể (khoảng cách tăng dần; hai dãy xen kẽ).
class PatternGenerator extends QuestionGenerator {
  const PatternGenerator();

  @override
  String get formId => 'arith.pattern';

  @override
  String get topic => 'arith';

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 1) {
      final s = randint(random, 1, 20);
      final d = randint(random, 2, 5);
      final seq = [for (var i = 0; i < 5; i++) s + d * i];
      final ans = s + 5 * d;
      final seqText = seq.join(', ');
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 1,
        questionVi: 'Tìm số tiếp theo của dãy: $seqText, ...',
        questionEn: 'Find the next number: $seqText, ...',
        hintVi: 'Lấy số sau trừ số trước xem hơn nhau bao nhiêu.',
        hintEn: 'Look at the difference between neighbours.',
        explanationVi:
            'Mỗi số hơn số trước $d đơn vị. Số tiếp theo: ${seq.last} + $d = $ans.',
        explanationEn:
            'Each number is $d more than the one before: ${seq.last} + $d = $ans.',
        keywords: kws([
          ('next number', 'số tiếp theo'),
          ('pattern', 'quy luật'),
        ]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [
          seq.last + d + 1,
          seq.last + d - 1,
        ]),
        params: {'variant': 0, 's': s, 'd': d, 'seq': seq},
      );
    }
    if (level == 2) {
      final s = randint(random, 60, 99);
      final d = randint(random, 3, 9);
      final seq = [for (var i = 0; i < 6; i++) s - d * i];
      final hide = randint(random, 1, 4);
      final shown = [
        for (var i = 0; i < seq.length; i++) i == hide ? '__' : '${seq[i]}',
      ].join(', ');
      final ans = seq[hide];
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 2,
        questionVi: 'Điền số còn thiếu vào chỗ trống: $shown',
        questionEn: 'Fill in the missing number: $shown',
        hintVi: 'Dãy số đang giảm dần đều.',
        hintEn: 'The numbers go down by the same amount.',
        explanationVi:
            'Mỗi số kém số trước $d đơn vị. Số còn thiếu: ${seq[hide - 1]} − $d = $ans.',
        explanationEn: 'Each number is $d less: ${seq[hide - 1]} − $d = $ans.',
        keywords: kws([('missing', 'còn thiếu'), ('blank', 'chỗ trống')]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [ans + d, ans - d]),
        params: {'variant': 0, 's': s, 'd': d, 'seq': seq, 'hide': hide},
      );
    }
    // Mức 3.
    if (random.nextBool()) {
      final s = randint(random, 1, 5);
      final d0 = randint(random, 1, 3);
      final seq = <int>[s];
      for (var i = 0; i < 5; i++) {
        seq.add(seq.last + d0 + i);
      }
      final ans = seq.last + d0 + 5;
      final seqText = seq.join(', ');
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 3,
        questionVi: 'Tìm số tiếp theo của dãy: $seqText, ...',
        questionEn: 'Find the next number: $seqText, ...',
        hintVi: 'Viết ra khoảng cách giữa hai số liền nhau.',
        hintEn: 'Write down the gaps between neighbours.',
        explanationVi:
            'Khoảng cách giữa các số tăng dần: +$d0, +${d0 + 1}, +${d0 + 2}, +${d0 + 3}, +${d0 + 4}. Tiếp theo là +${d0 + 5}: ${seq.last} + ${d0 + 5} = $ans.',
        explanationEn:
            'Differences grow by 1 each time; next add ${d0 + 5}: ${seq.last} + ${d0 + 5} = $ans.',
        keywords: kws([
          ('increase', 'tăng'),
          ('difference', 'hiệu, khoảng cách'),
        ]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [
          seq.last + d0 + 4,
          seq.last + d0 + 6,
        ]),
        params: {'variant': 0, 's': s, 'd0': d0, 'seq': seq},
      );
    }
    final a = randint(random, 1, 4);
    final b = pickOne(random, [10, 20, 5]);
    final seq = <int>[];
    for (var i = 0; i < 3; i++) {
      seq.addAll([a + i, b * (i + 1)]);
    }
    final ans = a + 3;
    final seqText = seq.join(', ');
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi: 'Tìm số tiếp theo của dãy: $seqText, ...',
      questionEn: 'Find the next number: $seqText, ...',
      hintVi: 'Thử nhìn các số ở vị trí lẻ và vị trí chẵn riêng.',
      hintEn: 'Look at every other number.',
      explanationVi:
          'Dãy gồm hai dãy xen kẽ: $a, ${a + 1}, ${a + 2}, ... và $b, ${2 * b}, ${3 * b}, ... Số tiếp theo thuộc dãy thứ nhất: $ans.',
      explanationEn:
          'Two patterns take turns: $a, ${a + 1}, ${a + 2}, ... and $b, ${2 * b}, ${3 * b}, ... Next is $ans.',
      keywords: kws([('alternate', 'xen kẽ'), ('pattern', 'quy luật')]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [4 * b, a + 4]),
      params: {'variant': 1, 'a': a, 'b': b, 'seq': seq},
    );
  }
}

/// Tính nhanh: mức 1, 2, 3.
class QuickGenerator extends QuestionGenerator {
  const QuickGenerator();

  @override
  String get formId => 'arith.quick';

  @override
  String get topic => 'arith';

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 1) {
      final k = randint(random, 4, 7);
      final v = randint(random, 2, 9);
      final ans = k * v;
      final expr = List.filled(k, '$v').join(' + ');
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 1,
        questionVi: 'Tính: $expr = ?',
        questionEn: 'Calculate: $expr = ?',
        hintVi: 'Cộng nhiều số giống nhau là phép nhân.',
        hintEn: 'Adding the same number many times is multiplication.',
        explanationVi: 'Có $k số $v: $v × $k = $ans.',
        explanationEn: '$k lots of $v: $v × $k = $ans.',
        keywords: kws([('calculate', 'tính'), ('plus', 'cộng')]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [k * v + v, k + v]),
        params: {'k': k, 'v': v},
      );
    }
    if (level == 2) {
      final a = randint(random, 11, 39);
      final b = randint(random, 11, 39);
      final c = 100 - a;
      final d = 100 - b;
      final terms = [a, b, c, d]..shuffle(random);
      final expr = terms.join(' + ');
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 2,
        questionVi: 'Tính nhanh: $expr = ?',
        questionEn: 'Calculate quickly: $expr = ?',
        hintVi: 'Tìm hai số cộng lại tròn 100.',
        hintEn: 'Find pairs that make 100.',
        explanationVi:
            'Ghép cặp tròn trăm: ($a + $c) + ($b + $d) = 100 + 100 = 200.',
        explanationEn: 'Pair to make hundreds: ($a + $c) + ($b + $d) = 200.',
        keywords: kws([('quickly', 'nhanh'), ('pair', 'cặp')]),
        answerType: AnswerType.number,
        answer: 200,
        distractors: makeDistractors(random, 200, [190, 210]),
        params: {'a': a, 'b': b, 'c': c, 'd': d, 'terms': terms},
      );
    }
    // Mức 3: cộng dãy cách đều.
    final st = pickOne(random, [1, 2]);
    final step = st == 1 ? pickOne(random, [1, 2]) : 2;
    final n = randint(random, 5, 10);
    final terms = [for (var i = 0; i < n; i++) st + step * i];
    final tot = terms.reduce((a, b) => a + b);
    final pairSum = terms.first + terms.last;
    final explanationVi =
        'Ghép số đầu với số cuối: ${terms.first} + ${terms.last} = $pairSum. Có $n số nên có $n : 2 cặp như vậy'
        '${n % 2 == 0 ? ': $pairSum × ${n ~/ 2} = $tot.' : ' (số ở giữa là ${terms[n ~/ 2]}). Tổng = $tot.'}';
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          'Tính: ${terms[0]} + ${terms[1]} + ${terms[2]} + ... + ${terms.last} = ? (cộng các số cách đều $step đơn vị)',
      questionEn:
          'Calculate: ${terms[0]} + ${terms[1]} + ${terms[2]} + ... + ${terms.last} = ? (numbers go up by $step)',
      hintVi: 'Ghép số đầu với số cuối, số thứ hai với số kế cuối...',
      hintEn:
          'Pair the first with the last, the second with the second last...',
      explanationVi: explanationVi,
      explanationEn:
          'Pair first and last: each pair is $pairSum. Total = $tot.',
      keywords: kws([('sum', 'tổng'), ('first / last', 'đầu / cuối')]),
      answerType: AnswerType.number,
      answer: tot,
      distractors: makeDistractors(random, tot, [tot - terms.last, tot + step]),
      params: {'st': st, 'step': step, 'n': n, 'terms': terms},
    );
  }
}

/// Điền vào ô trống: mức 1, 2, 3.
class BlankGenerator extends QuestionGenerator {
  const BlankGenerator();

  @override
  String get formId => 'arith.blank';

  @override
  String get topic => 'arith';

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 1) {
      final a = randint(random, 5, 40);
      final x = randint(random, 5, 50);
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 1,
        questionVi: 'Điền số thích hợp vào ô trống: □ + $a = ${x + a}',
        questionEn: 'Fill in the box: □ + $a = ${x + a}',
        hintVi: 'Muốn tìm số hạng, lấy tổng trừ số hạng kia.',
        hintEn: 'Missing addend = total − other addend.',
        explanationVi: '□ = ${x + a} − $a = $x.',
        explanationEn: '□ = ${x + a} − $a = $x.',
        keywords: kws([('fill in', 'điền'), ('box', 'ô trống')]),
        answerType: AnswerType.number,
        answer: x,
        distractors: makeDistractors(random, x, [x + 2 * a]),
        params: {'a': a, 'x': x},
      );
    }
    if (level == 2) {
      final a = randint(random, 10, 30);
      final b = randint(random, 3, 15);
      final x = randint(random, 5, 40);
      final c = x + a - b;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 2,
        questionVi: 'Điền số thích hợp vào ô trống: □ + $a − $b = $c',
        questionEn: 'Fill in the box: □ + $a − $b = $c',
        hintVi: 'Làm ngược từ phải sang trái.',
        hintEn: 'Work backwards from the right.',
        explanationVi:
            '□ + $a = $c + $b = ${c + b}, nên □ = ${c + b} − $a = $x.',
        explanationEn: '□ + $a = ${c + b}, so □ = $x.',
        keywords: kws([
          ('equation', 'phép tính, đẳng thức'),
          ('correct', 'đúng'),
        ]),
        answerType: AnswerType.number,
        answer: x,
        distractors: makeDistractors(random, x, [c - a + b, c + a - b]),
        params: {'a': a, 'b': b, 'x': x, 'c': c},
      );
    }
    // Mức 3.
    final a = randint(random, 30, 60);
    final x = randint(random, 5, 25);
    final b = randint(random, 5, 20);
    final c = a - x + b;
    // gen.py: a - c - b nếu > 0, nếu không thì x + 7.
    final wrongFirst = a - c - b > 0 ? a - c - b : x + 7;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi: 'Điền số thích hợp vào ô trống: $a − □ + $b = $c',
      questionEn: 'Fill in the box: $a − □ + $b = $c',
      hintVi: 'Tìm $a − □ bằng bao nhiêu trước.',
      hintEn: 'First find what $a − □ equals.',
      explanationVi: '$a − □ = $c − $b = ${c - b}, nên □ = $a − ${c - b} = $x.',
      explanationEn: '$a − □ = ${c - b}, so □ = $a − ${c - b} = $x.',
      keywords: kws([('minus', 'trừ'), ('equals', 'bằng')]),
      answerType: AnswerType.number,
      answer: x,
      distractors: makeDistractors(random, x, [wrongFirst, x + 2 * b]),
      params: {'a': a, 'b': b, 'x': x, 'c': c},
    );
  }
}

/// Hình đại diện số (★ ▲ ●): mức 2, 3.
class SymbolsGenerator extends QuestionGenerator {
  const SymbolsGenerator();

  @override
  String get formId => 'arith.symbols';

  @override
  String get topic => 'arith';

  @override
  Set<int> get supportedLevels => {2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 2) {
      final s = randint(random, 3, 12);
      final t = s + randint(random, 2, 10);
      final ans = t - s;
      final wrongFirst = t > 2 * s ? t - 2 * s : t;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 2,
        questionVi:
            'Biết: ★ + ★ = ${2 * s} và ★ + ▲ = $t. Hỏi ▲ bằng bao nhiêu?',
        questionEn: '★ + ★ = ${2 * s} and ★ + ▲ = $t. What is ▲?',
        hintVi: 'Tìm ★ trước.',
        hintEn: 'Find ★ first.',
        explanationVi: '★ = ${2 * s} : 2 = $s. ▲ = $t − $s = $ans.',
        explanationEn: '★ = $s, so ▲ = $t − $s = $ans.',
        keywords: kws([('star', 'ngôi sao'), ('triangle', 'tam giác')]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [wrongFirst, s]),
        params: {'s': s, 't': t},
      );
    }
    // Mức 3.
    final s = randint(random, 2, 8);
    final tri = randint(random, 3, 10);
    final ci = randint(random, 2, 9);
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          'Biết: ★ + ★ + ★ = ${3 * s}; ▲ + ★ = ${tri + s}; ● + ▲ = ${ci + tri}. Hỏi ● bằng bao nhiêu?',
      questionEn:
          '★ + ★ + ★ = ${3 * s}; ▲ + ★ = ${tri + s}; ● + ▲ = ${ci + tri}. What is ●?',
      hintVi: 'Tìm lần lượt ★, rồi ▲, rồi ●.',
      hintEn: 'Find ★, then ▲, then ●.',
      explanationVi:
          '★ = ${3 * s} : 3 = $s. ▲ = ${tri + s} − $s = $tri. ● = ${ci + tri} − $tri = $ci.',
      explanationEn: '★ = $s, ▲ = $tri, ● = $ci.',
      keywords: kws([('circle', 'hình tròn'), ('star', 'ngôi sao')]),
      answerType: AnswerType.number,
      answer: ci,
      distractors: makeDistractors(random, ci, [tri, ci + s]),
      params: {'s': s, 'tri': tri, 'ci': ci},
    );
  }
}

/// Lời văn hơn kém: mức 1, 2, 3.
class WordGenerator extends QuestionGenerator {
  const WordGenerator();

  @override
  String get formId => 'arith.word';

  @override
  String get topic => 'arith';

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 1) {
      final names = pickNames(random, 2);
      final x = names[0];
      final y = names[1];
      final a = randint(random, 10, 40);
      final b = randint(random, 3, 15);
      final ans = a + b;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 1,
        questionVi:
            '$x có $a cái kẹo. $y có nhiều hơn $x $b cái kẹo. Hỏi $y có bao nhiêu cái kẹo?',
        questionEn:
            '$x has $a candies. $y has $b more candies than $x. How many candies does $y have?',
        hintVi: "'Nhiều hơn' thì làm phép cộng.",
        hintEn: "'More than' means add.",
        explanationVi: '$y có: $a + $b = $ans cái kẹo.',
        explanationEn: '$a + $b = $ans.',
        keywords: kws([('more than', 'nhiều hơn'), ('candy', 'cái kẹo')]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [a - b]),
        params: {'x': x, 'y': y, 'a': a, 'b': b},
      );
    }
    if (level == 2) {
      final names = pickNames(random, 2);
      final x = names[0];
      final y = names[1];
      final a = randint(random, 20, 45);
      final b = randint(random, 3, 12);
      final ans = 2 * a - b;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 2,
        questionVi:
            '$x có $a quyển truyện. $y có ít hơn $x $b quyển. Hỏi cả hai bạn có bao nhiêu quyển truyện?',
        questionEn:
            '$x has $a storybooks. $y has $b fewer than $x. How many storybooks do they have altogether?',
        hintVi: 'Tìm số truyện của $y trước.',
        hintEn: 'First find how many $y has.',
        explanationVi:
            '$y có $a − $b = ${a - b} quyển. Cả hai: $a + ${a - b} = $ans quyển.',
        explanationEn: '$y has ${a - b}. Altogether $a + ${a - b} = $ans.',
        keywords: kws([
          ('fewer than', 'ít hơn'),
          ('altogether', 'cả hai, tất cả'),
        ]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [a - b, 2 * a + b, a + b]),
        params: {'x': x, 'y': y, 'a': a, 'b': b},
      );
    }
    // Mức 3.
    final names = pickNames(random, 2);
    final x = names[0];
    final y = names[1];
    final small = randint(random, 10, 30);
    final d = randint(random, 2, 12);
    final s = 2 * small + d;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          '$x và $y có tất cả $s viên bi. $x có nhiều hơn $y $d viên. Hỏi $y có bao nhiêu viên bi?',
      questionEn:
          '$x and $y have $s marbles altogether. $x has $d more than $y. How many marbles does $y have?',
      hintVi: 'Bớt phần hơn đi để hai phần bằng nhau.',
      hintEn: 'Remove the difference so both parts are equal.',
      explanationVi:
          'Nếu bớt đi $d viên của $x thì hai bạn có số bi bằng nhau: $s − $d = ${s - d}. Số bi của $y: ${s - d} : 2 = $small viên.',
      explanationEn:
          'Take away the extra $d: ${s - d}, then split in half: $small.',
      keywords: kws([('altogether', 'tất cả'), ('more than', 'nhiều hơn')]),
      answerType: AnswerType.number,
      answer: small,
      distractors: makeDistractors(random, small, [
        small + d,
        (s + d) ~/ 2 + 1,
        s - d,
      ]),
      params: {'x': x, 'y': y, 'small': small, 'd': d, 's': s},
    );
  }
}

/// Nhân chia lớp 2: mức 1, 2, 3.
class MultiplyGenerator extends QuestionGenerator {
  const MultiplyGenerator();

  @override
  String get formId => 'arith.multiply';

  @override
  String get topic => 'arith';

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 1) {
      final b = pickOne(random, [2, 3, 4, 5]);
      final k = randint(random, 3, 9);
      final ans = b * k;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 1,
        questionVi:
            'Mỗi hộp có $b cái bút. Hỏi $k hộp như thế có bao nhiêu cái bút?',
        questionEn: 'Each box has $b pens. How many pens are in $k boxes?',
        hintVi: 'Lấy số bút một hộp nhân với số hộp.',
        hintEn: 'Pens per box × number of boxes.',
        explanationVi: '$b × $k = $ans cái bút.',
        explanationEn: '$b × $k = $ans.',
        keywords: kws([('each', 'mỗi'), ('box', 'hộp')]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [b + k]),
        params: {'b': b, 'k': k},
      );
    }
    if (level == 2) {
      final p = pickOne(random, [2, 3, 4, 5]);
      final each = randint(random, 3, 9);
      final tot = p * each;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 2,
        questionVi:
            'Cô giáo chia đều $tot quả cam cho $p bạn. Hỏi mỗi bạn được mấy quả cam?',
        questionEn:
            'The teacher shares $tot oranges equally among $p children. How many oranges does each child get?',
        hintVi: 'Chia đều là làm phép chia.',
        hintEn: 'Share equally means divide.',
        explanationVi: '$tot : $p = $each quả.',
        explanationEn: '$tot ÷ $p = $each.',
        keywords: kws([('share equally', 'chia đều'), ('each', 'mỗi')]),
        answerType: AnswerType.number,
        answer: each,
        distractors: makeDistractors(random, each, [tot - p]),
        params: {'p': p, 'each': each, 'tot': tot},
      );
    }
    // Mức 3.
    final t = randint(random, 4, 8);
    final c = pickOne(random, [2, 4]);
    final broken = randint(random, 2, 5);
    final ans = t * c - broken;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          'Lớp học có $t cái bàn, mỗi bàn kê $c cái ghế. Có $broken cái ghế bị hỏng được mang đi sửa. Hỏi trong lớp còn bao nhiêu cái ghế?',
      questionEn:
          'A classroom has $t tables with $c chairs at each table. $broken chairs are broken and taken away. How many chairs are left?',
      hintVi: 'Tính số ghế lúc đầu trước.',
      hintEn: 'First find how many chairs there were.',
      explanationVi:
          'Lúc đầu có $t × $c = ${t * c} ghế. Còn lại: ${t * c} − $broken = $ans ghế.',
      explanationEn: '$t × $c = ${t * c}; ${t * c} − $broken = $ans.',
      keywords: kws([('chair', 'cái ghế'), ('left', 'còn lại')]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [t * c, t + c - broken]),
      params: {'t': t, 'c': c, 'broken': broken},
    );
  }
}

/// Tiền: chỉ mức 2.
class MoneyGenerator extends QuestionGenerator {
  const MoneyGenerator();

  @override
  String get formId => 'arith.money';

  @override
  String get topic => 'arith';

  @override
  Set<int> get supportedLevels => {2};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final p = pickOne(random, [2, 3, 4, 5]);
    final k = randint(random, 2, 4);
    final paid = p * k < 20 ? pickOne(random, [20, 50]) : 50;
    final ans = paid - p * k;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 2,
      questionVi:
          'Một quyển vở giá $p nghìn đồng. Mẹ mua $k quyển và đưa cô bán hàng $paid nghìn đồng. Hỏi cô bán hàng trả lại mẹ bao nhiêu nghìn đồng?',
      questionEn:
          'A notebook costs $p thousand dong. Mom buys $k notebooks and pays with $paid thousand dong. How much change (in thousand dong) does she get?',
      hintVi: 'Tính tiền mua vở trước.',
      hintEn: 'First find the cost.',
      explanationVi:
          'Tiền vở: $p × $k = ${p * k} nghìn. Trả lại: $paid − ${p * k} = $ans nghìn đồng.',
      explanationEn: 'Cost ${p * k}; change $paid − ${p * k} = $ans.',
      keywords: kws([('cost', 'giá'), ('change', 'tiền thối lại')]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [p * k, paid - p]),
      params: {'p': p, 'k': k, 'paid': paid},
    );
  }
}

/// Tất cả generator của mảng arith.
const List<QuestionGenerator> arithGenerators = [
  PatternGenerator(),
  QuickGenerator(),
  BlankGenerator(),
  SymbolsGenerator(),
  WordGenerator(),
  MultiplyGenerator(),
  MoneyGenerator(),
];
