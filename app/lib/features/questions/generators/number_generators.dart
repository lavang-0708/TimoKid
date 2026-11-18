import 'dart:math';

import '../question.dart';

/// Mảng Lý thuyết số: 10 dạng bài, chuyển từ `gen_number()` trong `gen.py`.
///
/// Cách diễn đạt đề và lời giải giữ nguyên như `gen.py`.

/// Đếm chẵn lẻ: mức 1, 2.
class ParityGenerator extends QuestionGenerator {
  const ParityGenerator();

  @override
  String get formId => 'number.parity';

  @override
  String get topic => 'number';

  @override
  Set<int> get supportedLevels => {1, 2};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 1) {
      final a = randint(random, 1, 10);
      final b = a + randint(random, 8, 14);
      final odd = random.nextBool();
      final parity = odd ? 1 : 0;
      final listed = [
        for (var v = a; v <= b; v++)
          if (v % 2 == parity) v,
      ];
      final cnt = listed.length;
      final wrongFirst = b - a + 1 - cnt + ((b - a) % 2 == 1 ? 1 : 0) + 1;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 1,
        questionVi: 'Từ $a đến $b có bao nhiêu số ${odd ? 'lẻ' : 'chẵn'}?',
        questionEn:
            'How many ${odd ? 'odd' : 'even'} numbers are there from $a to $b?',
        hintVi: 'Số chẵn có chữ số tận cùng 0, 2, 4, 6, 8.',
        hintEn: 'Even numbers end in 0, 2, 4, 6, 8.',
        explanationVi:
            "Liệt kê các số ${odd ? 'lẻ' : 'chẵn'}: ${listed.join(', ')}. Có $cnt số.",
        explanationEn: "List them: ${listed.join(', ')}. That is $cnt.",
        keywords: kws([('odd number', 'số lẻ'), ('even number', 'số chẵn')]),
        answerType: AnswerType.number,
        answer: cnt,
        distractors: makeDistractors(random, cnt, [wrongFirst, cnt + 1]),
        params: {'a': a, 'b': b, 'odd': odd},
      );
    }
    // Mức 2.
    final a = randint(random, 10, 40);
    final b = randint(random, 60, 99);
    final odd = random.nextBool();
    final parity = odd ? 1 : 0;
    final listed = [
      for (var v = a; v <= b; v++)
        if (v % 2 == parity) v,
    ];
    final cnt = listed.length;
    final first = listed.first;
    final last = listed.last;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 2,
      questionVi:
          "Có bao nhiêu số ${odd ? 'lẻ' : 'chẵn'} lớn hơn ${a - 1} và nhỏ hơn ${b + 1}?",
      questionEn:
          "How many ${odd ? 'odd' : 'even'} numbers are greater than ${a - 1} and less than ${b + 1}?",
      hintVi: 'Số các số cách đều = (số cuối − số đầu) : khoảng cách + 1.',
      hintEn: 'Count = (last − first) ÷ gap + 1.',
      explanationVi:
          "Ta đếm các số ${odd ? 'lẻ' : 'chẵn'} từ $a đến $b. Số đầu là $first, số cuối là $last, hai số liền nhau cách 2 đơn vị: ($last − $first) : 2 + 1 = $cnt số.",
      explanationEn: 'Count from $a to $b: (last − first) ÷ 2 + 1 = $cnt.',
      keywords: kws([('greater than', 'lớn hơn'), ('less than', 'nhỏ hơn')]),
      answerType: AnswerType.number,
      answer: cnt,
      distractors: makeDistractors(random, cnt, [cnt - 1, cnt + 1]),
      params: {'a': a, 'b': b, 'odd': odd},
    );
  }
}

/// Tổng chữ số: mức 2, 3.
class DigitSumGenerator extends QuestionGenerator {
  const DigitSumGenerator();

  @override
  String get formId => 'number.digitsum';

  @override
  String get topic => 'number';

  @override
  Set<int> get supportedLevels => {2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final k = level == 2
        ? pickOne(random, [3, 5, 7, 9])
        : pickOne(random, [11, 12, 15, 16]);
    final nums = [
      for (var v = 10; v <= 99; v++)
        if (v ~/ 10 + v % 10 == k) v,
    ];
    final ans = nums.length;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi:
          'Có bao nhiêu số có hai chữ số mà tổng hai chữ số của nó bằng $k?',
      questionEn: 'How many 2-digit numbers have digits that add up to $k?',
      hintVi:
          'Cho chữ số hàng chục chạy từ 1 đến 9 rồi tìm chữ số hàng đơn vị.',
      hintEn: 'Try tens digit 1, 2, 3, ... and find the ones digit.',
      explanationVi: "Đó là các số: ${nums.join(', ')}. Có $ans số.",
      explanationEn: "They are: ${nums.join(', ')}. So $ans.",
      keywords: kws([
        ('2-digit number', 'số có hai chữ số'),
        ('digit', 'chữ số'),
        ('add up to', 'có tổng bằng'),
      ]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [ans + 1, ans - 1]),
      params: {'k': k, 'nums': nums},
    );
  }
}

/// Lập số lớn nhất / nhỏ nhất từ thẻ: mức 1, 2, 3.
class CardsGenerator extends QuestionGenerator {
  const CardsGenerator();

  @override
  String get formId => 'number.cards';

  @override
  String get topic => 'number';

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 1) {
      final pool = [for (var d = 1; d <= 9; d++) d]..shuffle(random);
      final ds = pool.take(3).toList();
      final sortedDesc = List<int>.of(ds)..sort((a, b) => b.compareTo(a));
      final mx = int.parse('${sortedDesc[0]}${sortedDesc[1]}');
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 1,
        questionVi:
            "Từ ba tấm thẻ ghi số ${ds.join(', ')}, hãy lập số lớn nhất có hai chữ số (mỗi thẻ dùng một lần).",
        questionEn:
            "Using cards ${ds.join(', ')}, make the greatest 2-digit number (use each card once).",
        hintVi: 'Chữ số hàng chục quan trọng hơn chữ số hàng đơn vị.',
        hintEn: 'The tens digit matters more.',
        explanationVi:
            'Hàng chục chọn số lớn nhất, hàng đơn vị chọn số lớn thứ hai: $mx.',
        explanationEn:
            'Biggest digit in the tens place, next biggest in the ones place: $mx.',
        keywords: kws([('greatest', 'lớn nhất'), ('card', 'tấm thẻ')]),
        answerType: AnswerType.number,
        answer: mx,
        distractors: makeDistractors(random, mx, [
          int.parse('$mx'.split('').reversed.join()),
        ]),
        params: {'ds': ds},
      );
    }
    if (level == 2) {
      final pool = [for (var d = 1; d <= 9; d++) d]..shuffle(random);
      final ds = [0, ...pool.take(2)];
      // Mọi hoán vị 3 chữ số, chữ số đầu khác 0.
      final perms = <int>[];
      for (final a in ds) {
        for (final b in ds) {
          for (final c in ds) {
            if (a != 0 && a != b && b != c && a != c) {
              perms.add(a * 100 + b * 10 + c);
            }
          }
        }
      }
      final mn = perms.reduce((a, b) => a < b ? a : b);
      final sortedDs = List<int>.of(ds)..sort();
      // Đáp án nhiễu của gen.py: các chữ số khác 0 xếp tăng dần rồi thêm 0.
      final wrongDigits = [...sortedDs.where((d) => d != 0), 0];
      final wrongFirst = int.parse(wrongDigits.join());
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 2,
        questionVi:
            "Từ ba tấm thẻ ghi số ${sortedDs.join(', ')}, hãy lập số nhỏ nhất có ba chữ số (mỗi thẻ dùng một lần).",
        questionEn:
            "Using cards ${sortedDs.join(', ')}, make the smallest 3-digit number (use each card once).",
        hintVi: 'Số có ba chữ số không bắt đầu bằng 0.',
        hintEn: 'A 3-digit number cannot start with 0.',
        explanationVi:
            'Chữ số 0 không đứng đầu được, nên hàng trăm là chữ số nhỏ nhất khác 0, sau đó đặt 0, rồi chữ số còn lại: $mn.',
        explanationEn:
            '0 cannot go first, so start with the smallest non-zero digit, then 0: $mn.',
        keywords: kws([
          ('smallest', 'nhỏ nhất'),
          ('3-digit number', 'số có ba chữ số'),
        ]),
        answerType: AnswerType.number,
        answer: mn,
        distractors: makeDistractors(random, mn, [wrongFirst, mn + 9]),
        params: {'ds': ds},
      );
    }
    // Mức 3: hiệu của số lớn nhất và số nhỏ nhất lập được.
    final pool = [for (var d = 1; d <= 9; d++) d]..shuffle(random);
    final ds = pool.take(3).toList();
    final perms = <int>[];
    for (final a in ds) {
      for (final b in ds) {
        if (a != b) perms.add(a * 10 + b);
      }
    }
    final mx = perms.reduce((a, b) => a > b ? a : b);
    final mn = perms.reduce((a, b) => a < b ? a : b);
    final ans = mx - mn;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          "Từ ba tấm thẻ ghi số ${ds.join(', ')}, lập các số có hai chữ số khác nhau (mỗi số dùng hai thẻ khác nhau). Hỏi hiệu của số lớn nhất và số nhỏ nhất lập được là bao nhiêu?",
      questionEn:
          "Using cards ${ds.join(', ')}, make 2-digit numbers with two different cards. What is the difference between the greatest and the smallest?",
      hintVi: 'Tìm số lớn nhất và số nhỏ nhất trước.',
      hintEn: 'Find the greatest and the smallest first.',
      explanationVi:
          'Số lớn nhất: $mx. Số nhỏ nhất: $mn. Hiệu: $mx − $mn = $ans.',
      explanationEn: 'Greatest $mx, smallest $mn, difference $ans.',
      keywords: kws([
        ('difference', 'hiệu'),
        ('greatest / smallest', 'lớn nhất / nhỏ nhất'),
      ]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [mx + mn, ans + 9]),
      params: {'ds': ds},
    );
  }
}

/// Số chữ số viết từ 1 đến n: mức 2, 3.
class DigitCountGenerator extends QuestionGenerator {
  const DigitCountGenerator();

  @override
  String get formId => 'number.digitcount';

  @override
  String get topic => 'number';

  @override
  Set<int> get supportedLevels => {2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final n = level == 2
        ? pickOne(random, [12, 15, 20, 25])
        : pickOne(random, [30, 45, 60, 99]);
    var tot = 0;
    for (var v = 1; v <= n; v++) {
      tot += '$v'.length;
    }
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi:
          'Bạn Vy viết liền các số từ 1 đến $n. Hỏi Vy đã viết tất cả bao nhiêu chữ số?',
      questionEn:
          'Vy writes all the numbers from 1 to $n. How many digits does she write in total?',
      hintVi: 'Tách thành số có một chữ số và số có hai chữ số.',
      hintEn: 'Split into 1-digit and 2-digit numbers.',
      explanationVi:
          'Từ 1 đến 9 có 9 số, mỗi số 1 chữ số: 9 chữ số. Từ 10 đến $n có ${n - 9} số, mỗi số 2 chữ số: ${2 * (n - 9)} chữ số. Tổng: 9 + ${2 * (n - 9)} = $tot.',
      explanationEn:
          '1–9: 9 digits. 10–$n: ${n - 9} numbers × 2 = ${2 * (n - 9)}. Total $tot.',
      keywords: kws([('digit', 'chữ số'), ('in total', 'tất cả')]),
      answerType: AnswerType.number,
      answer: tot,
      distractors: makeDistractors(random, tot, [n, 2 * n]),
      params: {'n': n},
    );
  }
}

/// Đếm số lần xuất hiện của một chữ số: chỉ mức 3.
class DigitFreqGenerator extends QuestionGenerator {
  const DigitFreqGenerator();

  @override
  String get formId => 'number.digitfreq';

  @override
  String get topic => 'number';

  @override
  Set<int> get supportedLevels => {3};

  static const _pairs = [(20, 1), (30, 2), (40, 3), (50, 1), (35, 5), (45, 4)];

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final pair = pickOne(random, _pairs);
    final n = pair.$1;
    final d = pair.$2;
    var c = 0;
    for (var v = 1; v <= n; v++) {
      c += '$v'.split('').where((ch) => ch == '$d').length;
    }
    final containing = [
      for (var v = 1; v <= n; v++)
        if ('$v'.contains('$d')) v,
    ];
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          'Viết các số từ 1 đến $n. Hỏi chữ số $d được viết bao nhiêu lần?',
      questionEn:
          'Write the numbers from 1 to $n. How many times is the digit $d written?',
      hintVi: 'Đếm riêng hàng đơn vị, rồi hàng chục.',
      hintEn: 'Count the ones place, then the tens place.',
      explanationVi:
          "Đếm ở hàng đơn vị và hàng chục: các số chứa chữ số $d là ${containing.join(', ')}. Số $d$d (nếu có) được tính 2 lần. Tổng: $c lần.",
      explanationEn:
          'Count in the ones place and the tens place separately. Total $c.',
      keywords: kws([('times', 'lần'), ('digit', 'chữ số')]),
      answerType: AnswerType.number,
      answer: c,
      distractors: makeDistractors(random, c, [c - 1, c + 1]),
      params: {'n': n, 'd': d},
    );
  }
}

/// Tìm số theo dấu hiệu: mức 2, 3.
class CluesGenerator extends QuestionGenerator {
  const CluesGenerator();

  @override
  String get formId => 'number.clues';

  @override
  String get topic => 'number';

  @override
  Set<int> get supportedLevels => {2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 2) {
      // Mọi cặp (tổng, hiệu) có đúng một số hai chữ số thỏa mãn.
      final pool = <(int, int, int)>[];
      for (var s = 3; s <= 16; s++) {
        for (var d = 1; d <= 8; d++) {
          final sol = [
            for (var v = 10; v <= 99; v++)
              if (v ~/ 10 + v % 10 == s && v ~/ 10 - v % 10 == d) v,
          ];
          if (sol.length == 1) pool.add((s, d, sol[0]));
        }
      }
      final picked = pickOne(random, pool);
      final s = picked.$1;
      final d = picked.$2;
      final v = picked.$3;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 2,
        questionVi:
            'Tìm số có hai chữ số, biết tổng hai chữ số bằng $s và chữ số hàng chục hơn chữ số hàng đơn vị $d.',
        questionEn:
            'Find the 2-digit number whose digits add up to $s and whose tens digit is $d more than its ones digit.',
        hintVi: 'Thử các cặp chữ số có tổng bằng $s.',
        hintEn: 'Try pairs of digits that add up to $s.',
        explanationVi:
            'Chữ số hàng chục: ($s + $d) : 2 = ${v ~/ 10}. Chữ số hàng đơn vị: $s − ${v ~/ 10} = ${v % 10}. Số cần tìm: $v.',
        explanationEn:
            'Tens digit ($s + $d) ÷ 2 = ${v ~/ 10}, ones digit ${v % 10}. The number is $v.',
        keywords: kws([
          ('tens digit', 'chữ số hàng chục'),
          ('ones digit', 'chữ số hàng đơn vị'),
        ]),
        answerType: AnswerType.number,
        answer: v,
        distractors: makeDistractors(random, v, [
          int.parse('$v'.split('').reversed.join()),
          v + 9,
        ]),
        params: {'s': s, 'd': d, 'v': v},
      );
    }
    // Mức 3: lẻ, lớn hơn một mốc, tổng chữ số cho trước, chục > đơn vị.
    final pool = <(int, int, int)>[];
    for (var lo = 40; lo <= 70; lo += 10) {
      for (var s = 5; s <= 15; s++) {
        final sol = [
          for (var v = 10; v <= 99; v++)
            if (v ~/ 10 + v % 10 == s &&
                v % 2 == 1 &&
                v > lo &&
                v ~/ 10 > v % 10)
              v,
        ];
        if (sol.length == 1) pool.add((lo, s, sol[0]));
      }
    }
    final picked = pickOne(random, pool);
    final lo = picked.$1;
    final s = picked.$2;
    final v = picked.$3;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          'Tìm số có hai chữ số thỏa mãn: là số lẻ, lớn hơn $lo, tổng hai chữ số bằng $s, và chữ số hàng chục lớn hơn chữ số hàng đơn vị.',
      questionEn:
          'Find the 2-digit number that is odd, greater than $lo, has digits adding up to $s, and has a tens digit greater than its ones digit.',
      hintVi: 'Liệt kê rồi gạch bỏ các số không thỏa mãn.',
      hintEn: 'List them, then cross out.',
      explanationVi:
          'Liệt kê các số có tổng chữ số bằng $s, rồi loại dần theo từng điều kiện. Chỉ còn lại số $v.',
      explanationEn:
          'List numbers with digit sum $s, then cross out by each clue. Only $v is left.',
      keywords: kws([('odd', 'lẻ'), ('greater than', 'lớn hơn')]),
      answerType: AnswerType.number,
      answer: v,
      distractors: makeDistractors(random, v, [
        int.parse('$v'.split('').reversed.join()),
        v - 9,
      ]),
      params: {'lo': lo, 's': s, 'v': v},
    );
  }
}

/// Số tròn chục: chỉ mức 1.
class RoundGenerator extends QuestionGenerator {
  const RoundGenerator();

  @override
  String get formId => 'number.round';

  @override
  String get topic => 'number';

  @override
  Set<int> get supportedLevels => {1};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final a = randint(random, 1, 4) * 10;
    final b = randint(random, 6, 9) * 10;
    final ans = (b - a) ~/ 10 + 1;
    final listed = [for (var v = a; v <= b; v += 10) v];
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 1,
      questionVi: 'Có bao nhiêu số tròn chục từ $a đến $b?',
      questionEn: 'How many multiples of ten are there from $a to $b?',
      hintVi: 'Số tròn chục có chữ số tận cùng là 0.',
      hintEn: 'Multiples of ten end in 0.',
      explanationVi: "Đó là: ${listed.join(', ')}. Có $ans số.",
      explanationEn: "${listed.join(', ')}: $ans numbers.",
      keywords: kws([('multiple of ten', 'số tròn chục')]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [(b - a) ~/ 10]),
      params: {'a': a, 'b': b},
    );
  }
}

/// Giá trị chữ số (chục, đơn vị): chỉ mức 1.
class PlaceGenerator extends QuestionGenerator {
  const PlaceGenerator();

  @override
  String get formId => 'number.place';

  @override
  String get topic => 'number';

  @override
  Set<int> get supportedLevels => {1};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final t = randint(random, 2, 9);
    final o = randint(random, 0, 9);
    final extra = randint(random, 1, 3);
    // gen.py giữ nguyên công thức này cả khi t + extra > 9.
    final ans = (t + extra) * 10 + o;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 1,
      questionVi:
          'Số gồm $t chục và $o đơn vị cộng thêm $extra chục nữa là số nào?',
      questionEn: 'What number is $t tens and $o ones, plus $extra more tens?',
      hintVi: '1 chục = 10.',
      hintEn: '1 ten = 10.',
      explanationVi:
          '$t chục $o đơn vị là ${10 * t + o}. Thêm $extra chục (${10 * extra}): ${10 * t + o} + ${10 * extra} = $ans.',
      explanationEn: '${10 * t + o} + ${10 * extra} = $ans.',
      keywords: kws([('tens', 'chục'), ('ones', 'đơn vị')]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [10 * t + o + extra]),
      params: {'t': t, 'o': o, 'extra': extra},
    );
  }
}

/// Các câu cố định về số có hai chữ số: mức 1, 2, 3.
class FixedGenerator extends QuestionGenerator {
  const FixedGenerator();

  @override
  String get formId => 'number.fixed';

  @override
  String get topic => 'number';

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  static const _questions = [
    (
      difficulty: 1,
      qvi: 'Số lớn nhất có hai chữ số khác nhau là số nào?',
      qen: 'What is the greatest 2-digit number with two different digits?',
      ans: 98,
      evi: 'Hàng chục là 9, hàng đơn vị lớn nhất khác 9 là 8: 98.',
      een: 'Tens 9, ones the largest digit that is not 9: 98.',
      wrong: [99],
    ),
    (
      difficulty: 2,
      qvi: 'Số bé nhất có hai chữ số mà tổng hai chữ số bằng 10 là số nào?',
      qen: 'What is the smallest 2-digit number whose digits add up to 10?',
      ans: 19,
      evi: 'Muốn số bé nhất thì hàng chục nhỏ nhất: hàng chục 1, hàng đơn vị 9. Số 19.',
      een: 'Make the tens digit as small as possible: 19.',
      wrong: [91, 28],
    ),
    (
      difficulty: 2,
      qvi: 'Có bao nhiêu số có hai chữ số?',
      qen: 'How many 2-digit numbers are there?',
      ans: 90,
      evi: 'Từ 10 đến 99: 99 − 10 + 1 = 90 số.',
      een: 'From 10 to 99: 99 − 10 + 1 = 90.',
      wrong: [89, 99],
    ),
    (
      difficulty: 2,
      qvi: 'Có bao nhiêu số có hai chữ số mà hai chữ số giống nhau?',
      qen: 'How many 2-digit numbers have two identical digits?',
      ans: 9,
      evi: '11, 22, 33, 44, 55, 66, 77, 88, 99: có 9 số.',
      een: '11, 22, ..., 99: 9 numbers.',
      wrong: [10],
    ),
    (
      difficulty: 3,
      qvi: 'Có bao nhiêu số có hai chữ số mà chữ số hàng chục lớn hơn chữ số hàng đơn vị?',
      qen: 'How many 2-digit numbers have a tens digit greater than the ones digit?',
      ans: 45,
      evi: 'Hàng chục 1: 1 số (10); hàng chục 2: 2 số; ...; hàng chục 9: 9 số. Tổng 1 + 2 + ... + 9 = 45.',
      een: 'Tens 1 gives 1 number, tens 2 gives 2, ..., tens 9 gives 9: 1 + 2 + ... + 9 = 45.',
      wrong: [36, 44],
    ),
    (
      difficulty: 3,
      qvi: 'Có bao nhiêu số có hai chữ số mà chữ số hàng đơn vị lớn hơn chữ số hàng chục?',
      qen: 'How many 2-digit numbers have a ones digit greater than the tens digit?',
      ans: 36,
      evi: 'Hàng chục 1: 8 số (12 → 19); hàng chục 2: 7 số; ...; hàng chục 8: 1 số (89). Tổng 8 + 7 + ... + 1 = 36.',
      een: 'Tens 1 gives 8, tens 2 gives 7, ..., tens 8 gives 1: 36.',
      wrong: [45, 35],
    ),
  ];

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final candidates = [
      for (var i = 0; i < _questions.length; i++)
        if (_questions[i].difficulty == level) i,
    ];
    final index = pickOne(random, candidates);
    final q = _questions[index];
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi: q.qvi,
      questionEn: q.qen,
      hintVi: 'Thử liệt kê một vài số để tìm quy luật.',
      hintEn: 'List a few to see the pattern.',
      explanationVi: q.evi,
      explanationEn: q.een,
      keywords: kws([
        ('digit', 'chữ số'),
        ('2-digit number', 'số có hai chữ số'),
      ]),
      answerType: AnswerType.number,
      answer: q.ans,
      distractors: makeDistractors(random, q.ans, q.wrong),
      params: {'variant': index},
    );
  }
}

/// Quy tắc chẵn lẻ của tổng: chỉ mức 2. Câu trắc nghiệm (choiceOnly),
/// chỉ có 3 lựa chọn (không phải 4 như các dạng chọn khác).
class ParityRuleGenerator extends QuestionGenerator {
  const ParityRuleGenerator();

  @override
  String get formId => 'number.parityrule';

  @override
  String get topic => 'number';

  @override
  Set<int> get supportedLevels => {2};

  static const _choices = [
    Choice(vi: 'Số lẻ', en: 'Odd'),
    Choice(vi: 'Số chẵn', en: 'Even'),
    Choice(vi: 'Có thể chẵn hoặc lẻ', en: 'It depends'),
  ];

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final variant = random.nextInt(2);
    if (variant == 0) {
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 2,
        questionVi:
            'Cộng ba số lẻ với nhau thì được kết quả là số chẵn hay số lẻ?',
        questionEn: 'If you add three odd numbers, is the answer odd or even?',
        hintVi: 'Thử với ba số lẻ nhỏ.',
        hintEn: 'Try three small odd numbers.',
        explanationVi:
            'Lẻ + lẻ = chẵn; chẵn + lẻ = lẻ. Ví dụ 1 + 3 + 5 = 9 là số lẻ.',
        explanationEn:
            'Odd + odd = even; even + odd = odd. Example: 1 + 3 + 5 = 9 (odd).',
        keywords: kws([('odd', 'lẻ'), ('even', 'chẵn')]),
        answerType: AnswerType.choice,
        answer: 0,
        choices: _choices,
        params: {'variant': 0},
      );
    }
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 2,
      questionVi:
          'Cộng bốn số lẻ với nhau thì được kết quả là số chẵn hay số lẻ?',
      questionEn: 'If you add four odd numbers, is the answer odd or even?',
      hintVi: 'Ghép thành từng cặp.',
      hintEn: 'Make pairs.',
      explanationVi: 'Hai số lẻ cộng lại được số chẵn. Bốn số lẻ là hai cặp, mỗi cặp chẵn, nên tổng chẵn. Ví dụ 1 + 3 + 5 + 7 = 16.',
      explanationEn: 'Two odds make an even; four odds are two pairs, so the sum is even. Example: 1 + 3 + 5 + 7 = 16.',
      keywords: kws([('odd', 'lẻ'), ('even', 'chẵn')]),
      answerType: AnswerType.choice,
      answer: 1,
      choices: _choices,
      params: {'variant': 1},
    );
  }
}

/// Tất cả generator của mảng number.
const List<QuestionGenerator> numberGenerators = [
  ParityGenerator(),
  DigitSumGenerator(),
  CardsGenerator(),
  DigitCountGenerator(),
  DigitFreqGenerator(),
  CluesGenerator(),
  RoundGenerator(),
  PlaceGenerator(),
  FixedGenerator(),
  ParityRuleGenerator(),
];
