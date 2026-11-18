import 'dart:math';

import '../question.dart';

/// Mảng Tư duy lôgic: 11 dạng bài, chuyển từ `gen_logic()` trong `gen.py`.
///
/// Cách diễn đạt đề và lời giải giữ nguyên như `gen.py`. Mỗi generator
/// ghi các tham số đã dùng vào [Question.params] để test giải lại độc lập.

/// Tuổi: mức 1, 2, 3.
class AgeGenerator extends QuestionGenerator {
  const AgeGenerator();

  @override
  String get formId => 'logic.age';

  @override
  String get topic => 'logic';

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 1) {
      final n = pickNames(random, 1)[0];
      final a = randint(random, 6, 9);
      final d = randint(random, 24, 32);
      final ans = a + d;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 1,
        questionVi:
            'Năm nay $n $a tuổi. Mẹ hơn $n $d tuổi. Hỏi năm nay mẹ bao nhiêu tuổi?',
        questionEn:
            'This year $n is $a years old. Mom is $d years older than $n. How old is Mom this year?',
        hintVi: 'Mẹ hơn bao nhiêu tuổi thì cộng thêm bấy nhiêu.',
        hintEn: "'Older by' means add.",
        explanationVi: 'Tuổi mẹ = $a + $d = $ans (tuổi).',
        explanationEn: "Mom's age = $a + $d = $ans.",
        keywords: kws([('years old', 'tuổi'), ('older than', 'lớn tuổi hơn')]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [ans - 10, d - a]),
        params: {'name': n, 'a': a, 'd': d},
      );
    }
    if (level == 2) {
      final n = pickNames(random, 1)[0];
      final a = randint(random, 3, 6);
      final gap = randint(random, 24, 30);
      final b = a + gap;
      final c = randint(random, b + 3, b + 12);
      final ans = c - gap;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 2,
        questionVi:
            'Khi $n $a tuổi thì mẹ $b tuổi. Khi mẹ $c tuổi thì $n bao nhiêu tuổi?',
        questionEn:
            'When $n was $a years old, Mom was $b. When Mom is $c, how old will $n be?',
        hintVi: 'Hai người hơn kém nhau bao nhiêu tuổi thì mãi mãi hơn kém nhau bấy nhiêu.',
        hintEn: 'The age difference never changes.',
        explanationVi:
            'Mẹ luôn hơn $n: $b − $a = $gap tuổi. Khi mẹ $c tuổi thì $n: $c − $gap = $ans tuổi.',
        explanationEn:
            'Mom is always $b − $a = $gap years older. So $n is $c − $gap = $ans.',
        keywords: kws([('years old', 'tuổi'), ('when', 'khi')]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [c - b + a + 1, c - a]),
        params: {'name': n, 'a': a, 'gap': gap, 'b': b, 'c': c},
      );
    }
    // Mức 3.
    final m = randint(random, 28, 36);
    final c = randint(random, 5, 9);
    final k = randint(random, 2, 6);
    final t = m + c + 2 * k;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          'Năm nay mẹ $m tuổi, con $c tuổi. Hỏi sau mấy năm nữa thì tổng số tuổi của hai mẹ con là $t tuổi?',
      questionEn:
          'This year Mom is $m and her child is $c. In how many years will the sum of their ages be $t?',
      hintVi: 'Mỗi năm, cả hai người đều thêm 1 tuổi.',
      hintEn: 'Every year, both people get 1 year older.',
      explanationVi:
          'Hiện tổng tuổi là $m + $c = ${m + c}. Mỗi năm tổng tăng 2 tuổi (mỗi người 1 tuổi). Cần tăng $t − ${m + c} = ${t - m - c}, nên cần ${t - m - c} : 2 = $k năm.',
      explanationEn:
          'Now the sum is ${m + c}. Each year the sum grows by 2. It must grow by ${t - m - c}, so ${t - m - c} ÷ 2 = $k years.',
      keywords: kws([('sum', 'tổng'), ('in ... years', 'sau ... năm')]),
      answerType: AnswerType.number,
      answer: k,
      distractors: makeDistractors(random, k, [2 * k, k + 1]),
      params: {'m': m, 'c': c, 'k': k, 't': t},
    );
  }
}

/// Xếp hàng: mức 1, 3.
///
/// Mức 1 có hai biến thể (đếm cả hàng; tính vị trí từ cuối), chọn ngẫu nhiên.
class QueueGenerator extends QuestionGenerator {
  const QueueGenerator();

  @override
  String get formId => 'logic.queue';

  @override
  String get topic => 'logic';

  @override
  Set<int> get supportedLevels => {1, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 1) {
      if (random.nextBool()) {
        final n = pickNames(random, 1)[0];
        final a = randint(random, 3, 9);
        final b = randint(random, 3, 9);
        final ans = a + b - 1;
        return Question(
          formId: formId,
          topic: topic,
          difficulty: 1,
          questionVi:
              'Trong một hàng, $n đứng thứ $a tính từ đầu hàng và đứng thứ $b tính từ cuối hàng. Hỏi hàng có bao nhiêu bạn?',
          questionEn:
              'In a line, $n is ${a}th from the front and ${b}th from the back. How many children are in the line?',
          hintVi: 'Thử vẽ hàng ra giấy và đếm.',
          hintEn: 'Draw the line and count.',
          explanationVi:
              'Đếm cả hai phía thì $n bị đếm 2 lần: $a + $b − 1 = $ans bạn.',
          explanationEn: '$n is counted twice: $a + $b − 1 = $ans.',
          keywords: kws([
            ('line', 'hàng'),
            ('front', 'đầu hàng'),
            ('back', 'cuối hàng'),
          ]),
          answerType: AnswerType.number,
          answer: ans,
          distractors: makeDistractors(random, ans, [a + b, a + b - 2]),
          params: {'variant': 0, 'name': n, 'a': a, 'b': b},
        );
      }
      final n = pickNames(random, 1)[0];
      final total = randint(random, 10, 25);
      final a = randint(random, 2, total - 2);
      final ans = total - a + 1;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 1,
        questionVi:
            'Một hàng có $total bạn. $n đứng thứ $a tính từ đầu hàng. Hỏi $n đứng thứ mấy tính từ cuối hàng?',
        questionEn:
            'There are $total children in a line. $n is ${a}th from the front. What position is $n from the back?',
        hintVi: 'Đếm số bạn đứng sau.',
        hintEn: 'Count the children behind.',
        explanationVi:
            'Phía sau $n có $total − $a = ${total - a} bạn, nên $n đứng thứ ${total - a} + 1 = $ans tính từ cuối.',
        explanationEn:
            'There are ${total - a} children behind $n, so $n is ${total - a + 1}th from the back.',
        keywords: kws([
          ('position', 'vị trí, thứ tự'),
          ('from the back', 'tính từ cuối'),
        ]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [total - a, total - a + 2]),
        params: {'variant': 1, 'name': n, 'n': total, 'a': a},
      );
    }
    // Mức 3.
    final names = pickNames(random, 2);
    final x = names[0];
    final y = names[1];
    final a = randint(random, 3, 7);
    final k = randint(random, 2, 6);
    final b = randint(random, 3, 7);
    final ans = a + k + b;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          'Các bạn xếp một hàng dọc. $x đứng thứ $a tính từ đầu hàng. $y đứng sau $x và đứng thứ $b tính từ cuối hàng. Giữa $x và $y có $k bạn. Hỏi hàng có bao nhiêu bạn?',
      questionEn:
          'Children stand in a column. $x is ${a}th from the front. $y is behind $x and is ${b}th from the back. There are $k children between $x and $y. How many children are there?',
      hintVi: 'Chia hàng thành 3 phần rồi cộng lại.',
      hintEn: 'Split the line into 3 parts.',
      explanationVi:
          'Tính từ đầu đến $x: $a bạn. Giữa hai bạn: $k bạn. Tính từ $y đến cuối: $b bạn. Tổng: $a + $k + $b = $ans bạn.',
      explanationEn:
          'Front to $x: $a. Between: $k. $y to the back: $b. Total $ans.',
      keywords: kws([
        ('between', 'ở giữa'),
        ('column', 'hàng dọc'),
        ('behind', 'phía sau'),
      ]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [ans - 1, ans + 1, ans - 2]),
      params: {'x': x, 'y': y, 'a': a, 'k': k, 'b': b},
    );
  }
}

/// Cái cân: mức 1, 2, 3.
class BalanceGenerator extends QuestionGenerator {
  const BalanceGenerator();

  @override
  String get formId => 'logic.balance';

  @override
  String get topic => 'logic';

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  static const _fruits = [
    ('quả dưa hấu', 'watermelon'),
    ('quả bưởi', 'pomelo'),
    ('quả dứa', 'pineapple'),
  ];
  static const _small = [
    ('quả táo', 'apples'),
    ('quả cam', 'oranges'),
    ('quả chanh', 'lemons'),
  ];

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 1) {
      final fruit = pickOne(random, _fruits);
      final small = pickOne(random, _small);
      final p = randint(random, 2, 5);
      final r = randint(random, 2, 4);
      final ans = r * p;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 1,
        questionVi:
            '1 ${fruit.$1} nặng bằng $p ${small.$1}. Hỏi $r ${fruit.$1} nặng bằng bao nhiêu ${small.$1}?',
        questionEn:
            '1 ${fruit.$2} weighs the same as $p ${small.$2}. $r ${fruit.$2}s weigh the same as how many ${small.$2}?',
        hintVi: 'Đổi từng quả một.',
        hintEn: 'Swap one at a time.',
        explanationVi:
            'Mỗi ${fruit.$1} đổi được $p ${small.$1}, nên $r ${fruit.$1} bằng $r × $p = $ans ${small.$1}.',
        explanationEn: '$r × $p = $ans.',
        keywords: kws([('weigh', 'cân nặng'), ('the same as', 'bằng với')]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [r + p]),
        params: {
          'fruitVi': fruit.$1,
          'fruitEn': fruit.$2,
          'smallVi': small.$1,
          'smallEn': small.$2,
          'p': p,
          'r': r,
        },
      );
    }
    if (level == 2) {
      final p = randint(random, 2, 4);
      final q = randint(random, 2, 4);
      final r = randint(random, 1, 2);
      final ans = r * p * q;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 2,
        questionVi:
            '1 quả dưa hấu nặng bằng $p quả cam. 1 quả cam nặng bằng $q quả táo. Hỏi $r quả dưa hấu nặng bằng bao nhiêu quả táo?',
        questionEn:
            '1 watermelon weighs the same as $p oranges. 1 orange weighs the same as $q apples. $r watermelon(s) weigh the same as how many apples?',
        hintVi: 'Đổi dưa ra cam trước, rồi đổi cam ra táo.',
        hintEn: 'Change watermelon to oranges first, then to apples.',
        explanationVi:
            '1 dưa = $p cam = $p × $q = ${p * q} táo. Vậy $r dưa = $r × ${p * q} = $ans táo.',
        explanationEn: '1 watermelon = ${p * q} apples, so $r = $ans apples.',
        keywords: kws([('balance', 'cái cân'), ('weigh', 'cân nặng')]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [p + q, r * (p + q)]),
        params: {'p': p, 'q': q, 'r': r},
      );
    }
    // Mức 3.
    final p = randint(random, 2, 3);
    final q = randint(random, 2, 4);
    final k = randint(random, 2, 3);
    final m = randint(random, 2, 3);
    final r = randint(random, 2, 3);
    final ans = r * p * q;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          '$k quả bưởi nặng bằng ${k * p} quả cam. $m quả cam nặng bằng ${m * q} quả chanh. Hỏi $r quả bưởi nặng bằng bao nhiêu quả chanh?',
      questionEn:
          '$k pomelos weigh the same as ${k * p} oranges. $m oranges weigh the same as ${m * q} lemons. $r pomelos weigh the same as how many lemons?',
      hintVi: 'Tìm xem 1 quả bưởi bằng mấy quả cam.',
      hintEn: 'First find how many oranges 1 pomelo weighs.',
      explanationVi:
          '1 bưởi = ${k * p} : $k = $p cam. 1 cam = ${m * q} : $m = $q chanh. 1 bưởi = ${p * q} chanh, nên $r bưởi = $ans chanh.',
      explanationEn:
          '1 pomelo = $p oranges, 1 orange = $q lemons, so 1 pomelo = ${p * q} lemons and $r pomelos = $ans.',
      keywords: kws([('pomelo', 'quả bưởi'), ('lemon', 'quả chanh')]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [k * p * q, r * p + q]),
      params: {'p': p, 'q': q, 'k': k, 'm': m, 'r': r},
    );
  }
}

/// Tính ngược: mức 1, 2, 3.
///
/// Mức 3 có hai biến thể (nhân rồi cộng; cộng rồi nhân), chọn ngẫu nhiên.
class BackwardGenerator extends QuestionGenerator {
  const BackwardGenerator();

  @override
  String get formId => 'logic.backward';

  @override
  String get topic => 'logic';

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 1) {
      final a = randint(random, 5, 20);
      final x = randint(random, 5, 40);
      final b = x + a;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 1,
        questionVi:
            'Mai nghĩ ra một số. Lấy số đó cộng $a thì được $b. Hỏi Mai nghĩ ra số nào?',
        questionEn:
            'Mai thinks of a number. She adds $a and gets $b. What is her number?',
        hintVi: 'Làm ngược: cộng thì đổi thành trừ.',
        hintEn: 'Undo adding by subtracting.',
        explanationVi: 'Làm ngược lại: $b − $a = $x.',
        explanationEn: 'Work backwards: $b − $a = $x.',
        keywords: kws([
          ('think of a number', 'nghĩ ra một số'),
          ('add', 'cộng'),
        ]),
        answerType: AnswerType.number,
        answer: x,
        distractors: makeDistractors(random, x, [b + a]),
        params: {'name': 'Mai', 'a': a, 'x': x, 'b': b},
      );
    }
    if (level == 2) {
      final a = randint(random, 5, 25);
      final b = randint(random, 3, 15);
      final x = randint(random, 10, 40);
      final c = x + a - b;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 2,
        questionVi:
            'Nam nghĩ ra một số. Lấy số đó cộng $a, rồi trừ đi $b thì được $c. Hỏi Nam nghĩ ra số nào?',
        questionEn:
            'Nam thinks of a number. He adds $a, then subtracts $b, and gets $c. What is his number?',
        hintVi: 'Bắt đầu từ kết quả và làm ngược từng bước.',
        hintEn: 'Start from the result and undo each step.',
        explanationVi:
            'Làm ngược từ cuối: $c + $b = ${c + b}; ${c + b} − $a = $x.',
        explanationEn:
            'Backwards: $c + $b = ${c + b}, then ${c + b} − $a = $x.',
        keywords: kws([('subtract', 'trừ'), ('then', 'rồi')]),
        answerType: AnswerType.number,
        answer: x,
        distractors: makeDistractors(random, x, [c - b + a, c + a - b]),
        params: {'name': 'Nam', 'a': a, 'b': b, 'x': x, 'c': c},
      );
    }
    // Mức 3.
    final x = randint(random, 3, 15);
    final a = randint(random, 3, 12);
    if (random.nextBool()) {
      final c = 2 * x + a;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 3,
        questionVi:
            'Lan nghĩ ra một số. Lấy số đó nhân 2, rồi cộng $a thì được $c. Hỏi Lan nghĩ ra số nào?',
        questionEn:
            'Lan thinks of a number. She multiplies it by 2, then adds $a, and gets $c. What is her number?',
        hintVi: 'Nhân thì ngược lại là chia.',
        hintEn: 'Undo multiplying by dividing.',
        explanationVi: 'Ngược lại: $c − $a = ${c - a}; ${c - a} : 2 = $x.',
        explanationEn: '$c − $a = ${c - a}; ${c - a} ÷ 2 = $x.',
        keywords: kws([('multiply', 'nhân'), ('double', 'gấp đôi')]),
        answerType: AnswerType.number,
        answer: x,
        distractors: makeDistractors(random, x, [c - a, (c + a) ~/ 2]),
        params: {'variant': 0, 'name': 'Lan', 'x': x, 'a': a, 'c': c},
      );
    }
    final c = 2 * (x + a);
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          'Lan nghĩ ra một số. Lấy số đó cộng $a, rồi nhân với 2 thì được $c. Hỏi Lan nghĩ ra số nào?',
      questionEn:
          'Lan thinks of a number. She adds $a, then multiplies by 2, and gets $c. What is her number?',
      hintVi: 'Bước cuối làm ngược trước.',
      hintEn: 'Undo the last step first.',
      explanationVi: 'Ngược lại: $c : 2 = ${c ~/ 2}; ${c ~/ 2} − $a = $x.',
      explanationEn: '$c ÷ 2 = ${c ~/ 2}; ${c ~/ 2} − $a = $x.',
      keywords: kws([('multiply', 'nhân'), ('add', 'cộng')]),
      answerType: AnswerType.number,
      answer: x,
      distractors: makeDistractors(random, x, [c ~/ 2, c - a]),
      params: {'variant': 1, 'name': 'Lan', 'x': x, 'a': a, 'c': c},
    );
  }
}

/// Thứ trong tuần: mức 1, 2, 3. Câu trắc nghiệm (choiceOnly).
class WeekdayGenerator extends QuestionGenerator {
  const WeekdayGenerator();

  @override
  String get formId => 'logic.weekday';

  @override
  String get topic => 'logic';

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  Question _dayQuestion(
    int level,
    Random random,
    int start,
    int plus,
    String qvi,
    String qen,
  ) {
    final ansDay = (start + plus) % 7;
    final others = [
      for (var d = 0; d < 7; d++)
        if (d != ansDay) d,
    ]..shuffle(random);
    final opts = [ansDay, ...others.take(3)]..shuffle(random);
    final answerIndex = opts.indexOf(ansDay);
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi: qvi,
      questionEn: qen,
      hintVi: 'Một tuần có 7 ngày.',
      hintEn: 'A week has 7 days.',
      explanationVi:
          'Cứ 7 ngày lại quay về thứ cũ. $plus = 7 × ${plus ~/ 7} + ${plus % 7}, nên chỉ cần đếm thêm ${plus % 7} ngày từ ${daysVi[start]}: được ${daysVi[ansDay]}.',
      explanationEn:
          'Every 7 days the weekday repeats. Count ${plus % 7} more days from ${daysEn[start]}: ${daysEn[ansDay]}.',
      keywords: kws([('week', 'tuần'), ('day', 'ngày')]),
      answerType: AnswerType.choice,
      answer: answerIndex,
      choices: [for (final o in opts) Choice(vi: daysVi[o], en: daysEn[o])],
      params: {'start': start, 'plus': plus, 'ansDay': ansDay},
    );
  }

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final start = randint(random, 0, 6);
    if (level == 1) {
      final p = randint(random, 2, 5);
      return _dayQuestion(
        1,
        random,
        start,
        p,
        'Hôm nay là ${daysVi[start]}. Hỏi $p ngày nữa là thứ mấy?',
        'Today is ${daysEn[start]}. What day is it in $p days?',
      );
    }
    if (level == 2) {
      final p = randint(random, 8, 16);
      return _dayQuestion(
        2,
        random,
        start,
        p,
        'Hôm nay là ${daysVi[start]}. Hỏi $p ngày nữa là thứ mấy?',
        'Today is ${daysEn[start]}. What day is it in $p days?',
      );
    }
    final dd = randint(random, 15, 30);
    return _dayQuestion(
      3,
      random,
      start,
      dd - 1,
      'Ngày 1 của một tháng là ${daysVi[start]}. Hỏi ngày $dd của tháng đó là thứ mấy?',
      'The 1st of a month is a ${daysEn[start]}. What day of the week is the ${dd}th of that month?',
    );
  }
}

/// Cưa gỗ: mức 1, 2.
class CutGenerator extends QuestionGenerator {
  const CutGenerator();

  @override
  String get formId => 'logic.cut';

  @override
  String get topic => 'logic';

  @override
  Set<int> get supportedLevels => {1, 2};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 1) {
      final n = randint(random, 3, 9);
      final ans = n - 1;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 1,
        questionVi:
            'Bác thợ cưa một khúc gỗ thành $n đoạn. Hỏi bác phải cưa bao nhiêu lần?',
        questionEn:
            'A carpenter saws a log into $n pieces. How many cuts does he make?',
        hintVi: 'Vẽ khúc gỗ và các vết cưa.',
        hintEn: 'Draw the log and the cuts.',
        explanationVi:
            'Mỗi lần cưa thêm được 1 đoạn. Từ 1 đoạn lên $n đoạn cần $n − 1 = $ans lần cưa.',
        explanationEn: 'Each cut adds one piece, so $n − 1 = $ans cuts.',
        keywords: kws([('saw / cut', 'cưa / cắt'), ('piece', 'đoạn, mảnh')]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [n, n + 1]),
        params: {'n': n},
      );
    }
    final n = randint(random, 4, 8);
    final t = randint(random, 2, 5);
    final ans = (n - 1) * t;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 2,
      questionVi:
          'Mỗi lần cưa mất $t phút. Hỏi cưa một khúc gỗ thành $n đoạn mất bao nhiêu phút?',
      questionEn:
          'Each cut takes $t minutes. How long does it take to saw a log into $n pieces?',
      hintVi: 'Số lần cưa ít hơn số đoạn 1.',
      hintEn: 'Cuts = pieces − 1.',
      explanationVi:
          'Cần $n − 1 = ${n - 1} lần cưa, mỗi lần $t phút: ${n - 1} × $t = $ans phút.',
      explanationEn: '${n - 1} cuts × $t minutes = $ans minutes.',
      keywords: kws([('minute', 'phút'), ('each', 'mỗi')]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [n * t]),
      params: {'n': n, 't': t},
    );
  }
}

/// Bậc thang: chỉ mức 2.
class StairsGenerator extends QuestionGenerator {
  const StairsGenerator();

  @override
  String get formId => 'logic.stairs';

  @override
  String get topic => 'logic';

  @override
  Set<int> get supportedLevels => {2};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final f = randint(random, 3, 6);
    final k = randint(random, 8, 15);
    final ans = (f - 1) * k;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 2,
      questionVi:
          'Đi từ tầng 1 lên tầng 2 phải bước $k bậc thang. Hỏi đi từ tầng 1 lên tầng $f phải bước bao nhiêu bậc? (Các tầng có số bậc bằng nhau.)',
      questionEn:
          'It takes $k steps to go from floor 1 to floor 2. How many steps from floor 1 to floor $f? (Each floor has the same number of steps.)',
      hintVi: 'Lên tầng 2 chỉ cần 1 đoạn cầu thang.',
      hintEn: 'Going to floor 2 is only 1 flight.',
      explanationVi:
          'Từ tầng 1 lên tầng $f phải đi qua $f − 1 = ${f - 1} đoạn cầu thang: ${f - 1} × $k = $ans bậc.',
      explanationEn:
          'Floor 1 to floor $f is ${f - 1} flights: ${f - 1} × $k = $ans steps.',
      keywords: kws([('floor', 'tầng'), ('step', 'bậc thang')]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [f * k]),
      params: {'f': f, 'k': k},
    );
  }
}

/// Trồng cây: chỉ mức 3.
class TreesGenerator extends QuestionGenerator {
  const TreesGenerator();

  @override
  String get formId => 'logic.trees';

  @override
  String get topic => 'logic';

  @override
  Set<int> get supportedLevels => {3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final d = pickOne(random, [2, 3, 5]);
    final n = randint(random, 4, 9);
    final length = d * n;
    final ans = n + 1;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          'Một con đường dài $length m. Người ta trồng cây ở một bên đường, cây nọ cách cây kia $d m, ở cả hai đầu đường đều có cây. Hỏi trồng bao nhiêu cây?',
      questionEn:
          'A road is $length m long. Trees are planted on one side, $d m apart, with a tree at both ends. How many trees are there?',
      hintVi: 'Vẽ thử con đường ngắn và đếm cây, đếm khoảng.',
      hintEn: 'Draw a short road and count trees vs gaps.',
      explanationVi:
          'Có $length : $d = $n khoảng cách. Trồng cả hai đầu nên số cây nhiều hơn số khoảng 1: $n + 1 = $ans cây.',
      explanationEn: '$length ÷ $d = $n gaps; trees = gaps + 1 = $ans.',
      keywords: kws([('apart', 'cách nhau'), ('both ends', 'cả hai đầu')]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [n, n - 1]),
      params: {'d': d, 'n': n, 'length': length},
    );
  }
}

/// Chân gà chó: mức 1, 3.
class LegsGenerator extends QuestionGenerator {
  const LegsGenerator();

  @override
  String get formId => 'logic.legs';

  @override
  String get topic => 'logic';

  @override
  Set<int> get supportedLevels => {1, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 1) {
      final a = randint(random, 2, 6);
      final b = randint(random, 2, 5);
      final ans = 2 * a + 4 * b;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 1,
        questionVi:
            'Trong sân có $a con gà và $b con chó. Hỏi có tất cả bao nhiêu cái chân?',
        questionEn:
            'In the yard there are $a chickens and $b dogs. How many legs are there in total?',
        hintVi: 'Gà có 2 chân, chó có 4 chân.',
        hintEn: 'A chicken has 2 legs, a dog has 4.',
        explanationVi:
            'Gà: $a × 2 = ${2 * a} chân. Chó: $b × 4 = ${4 * b} chân. Tổng: $ans chân.',
        explanationEn: 'Chickens ${2 * a} legs + dogs ${4 * b} legs = $ans.',
        keywords: kws([
          ('leg', 'chân'),
          ('chicken', 'con gà'),
          ('dog', 'con chó'),
        ]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [2 * (a + b), 4 * (a + b)]),
        params: {'a': a, 'b': b},
      );
    }
    // Mức 3: gà và thỏ.
    final n = randint(random, 5, 10);
    final d = randint(random, 1, n - 1);
    final totalLegs = 2 * n + 2 * d;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          'Trong chuồng có $n con gà và thỏ, đếm được tất cả $totalLegs cái chân. Hỏi có bao nhiêu con thỏ?',
      questionEn:
          'There are $n chickens and rabbits, with $totalLegs legs in total. How many rabbits are there?',
      hintVi: 'Thử giả sử tất cả đều là gà.',
      hintEn: 'Pretend they are all chickens first.',
      explanationVi:
          'Nếu cả $n con đều là gà thì có ${2 * n} chân, thiếu $totalLegs − ${2 * n} = ${totalLegs - 2 * n} chân. Mỗi con thỏ có thêm 2 chân, nên số thỏ là ${totalLegs - 2 * n} : 2 = $d con.',
      explanationEn:
          'If all $n were chickens: ${2 * n} legs. Extra ${totalLegs - 2 * n} legs ÷ 2 = $d rabbits.',
      keywords: kws([('rabbit', 'con thỏ'), ('in total', 'tất cả')]),
      answerType: AnswerType.number,
      answer: d,
      distractors: makeDistractors(random, d, [n - d, totalLegs ~/ 4]),
      params: {'n': n, 'd': d, 'legs': totalLegs},
    );
  }
}

/// So sánh cao thấp: mức 1, 2, 3. Câu trắc nghiệm (choiceOnly).
class CompareGenerator extends QuestionGenerator {
  const CompareGenerator();

  @override
  String get formId => 'logic.compare';

  @override
  String get topic => 'logic';

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final k = level == 1 ? 3 : (level == 2 ? 4 : 5);
    // Thứ tự từ cao nhất -> thấp nhất.
    final people = pickNames(random, k);
    // Mỗi quan hệ là một cặp (vi, en); trộn các cặp cùng nhau như gen.py.
    final rels = <(String, String)>[];
    for (var i = 0; i < k - 1; i++) {
      final hi = people[i];
      final lo = people[i + 1];
      if (random.nextBool()) {
        rels.add(('$hi cao hơn $lo', '$hi is taller than $lo'));
      } else {
        rels.add(('$lo thấp hơn $hi', '$lo is shorter than $hi'));
      }
    }
    rels.shuffle(random);
    final askTall = random.nextBool();
    final ansName = askTall ? people[0] : people[k - 1];
    final opts = List<String>.of(people)..shuffle(random);
    final order = people.join(' > ');
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi:
          '${rels.map((r) => r.$1).join('. ')}. ${askTall ? 'Ai cao nhất?' : 'Ai thấp nhất?'}',
      questionEn:
          '${rels.map((r) => r.$2).join('. ')}. ${askTall ? 'Who is the tallest?' : 'Who is the shortest?'}',
      hintVi: 'Xếp các bạn thành một hàng từ cao đến thấp.',
      hintEn: 'Put everyone in order from tallest to shortest.',
      explanationVi:
          'Xếp từ cao đến thấp: $order. Vậy ${askTall ? 'cao nhất' : 'thấp nhất'} là $ansName.',
      explanationEn:
          'From tallest to shortest: $order. So the answer is $ansName.',
      keywords: kws([
        ('taller', 'cao hơn'),
        ('shorter', 'thấp hơn'),
        ('tallest', 'cao nhất'),
      ]),
      answerType: AnswerType.choice,
      answer: opts.indexOf(ansName),
      choices: [for (final o in opts) Choice(vi: o, en: o)],
      params: {'people': people, 'askTall': askTall, 'ansName': ansName},
    );
  }
}

/// Chia bi bằng nhau: chỉ mức 3.
class EqualizeGenerator extends QuestionGenerator {
  const EqualizeGenerator();

  @override
  String get formId => 'logic.equalize';

  @override
  String get topic => 'logic';

  @override
  Set<int> get supportedLevels => {3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final names = pickNames(random, 2);
    final x = names[0];
    final y = names[1];
    final b = randint(random, 2, 8);
    final yv = randint(random, 5, 20);
    final a = yv + 2 * b;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          '$x có $a viên bi. Nếu $x cho $y $b viên thì số bi của hai bạn bằng nhau. Hỏi lúc đầu $y có bao nhiêu viên bi?',
      questionEn:
          '$x has $a marbles. If $x gives $y $b marbles, they will have the same number. How many marbles did $y have at first?',
      hintVi: 'Tính số bi của $x sau khi cho trước.',
      hintEn: 'First find how many $x has after giving.',
      explanationVi:
          'Sau khi cho, $x còn $a − $b = ${a - b} viên. Lúc đó $y cũng có ${a - b} viên, nên lúc đầu $y có ${a - b} − $b = $yv viên.',
      explanationEn:
          'After giving, $x has ${a - b}. $y also has ${a - b} after receiving $b, so at first $y had $yv.',
      keywords: kws([
        ('marble', 'viên bi'),
        ('give', 'cho'),
        ('at first', 'lúc đầu'),
      ]),
      answerType: AnswerType.number,
      answer: yv,
      distractors: makeDistractors(random, yv, [
        a - b,
        a - 2 * b + 1,
        a - b + b,
      ]),
      params: {'x': x, 'y': y, 'a': a, 'b': b, 'yv': yv},
    );
  }
}

/// Tất cả generator của mảng logic.
const List<QuestionGenerator> logicGenerators = [
  AgeGenerator(),
  QueueGenerator(),
  BalanceGenerator(),
  BackwardGenerator(),
  WeekdayGenerator(),
  CutGenerator(),
  StairsGenerator(),
  TreesGenerator(),
  LegsGenerator(),
  CompareGenerator(),
  EqualizeGenerator(),
];
