import 'dart:math';

import '../question.dart';

/// Mảng Tổ hợp: 11 dạng bài, chuyển từ `gen_comb()` trong `gen.py`.
///
/// Cách diễn đạt đề và lời giải giữ nguyên như `gen.py`.

/// Chọn trang phục: mức 1, 2.
class OutfitGenerator extends QuestionGenerator {
  const OutfitGenerator();

  @override
  String get formId => 'comb.outfit';

  @override
  String get topic => 'comb';

  @override
  Set<int> get supportedLevels => {1, 2};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 1) {
      final a = randint(random, 2, 4);
      final b = randint(random, 2, 4);
      final ans = a * b;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 1,
        questionVi:
            'Bé có $a chiếc áo và $b chiếc váy khác nhau. Mỗi lần bé mặc 1 áo và 1 váy. Hỏi bé có bao nhiêu cách chọn trang phục?',
        questionEn:
            'A girl has $a different tops and $b different skirts. She wears 1 top and 1 skirt. How many different outfits can she make?',
        hintVi: 'Vẽ mỗi áo nối với từng váy.',
        hintEn: 'Draw lines from each top to each skirt.',
        explanationVi:
            'Mỗi chiếc áo đi được với $b chiếc váy: $a × $b = $ans cách.',
        explanationEn: 'Each top goes with $b skirts: $a × $b = $ans.',
        keywords: kws([
          ('outfit', 'bộ trang phục'),
          ('skirt', 'chân váy'),
          ('top', 'áo'),
        ]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [a + b]),
        params: {'a': a, 'b': b},
      );
    }
    // Mức 2.
    final a = randint(random, 2, 3);
    final b = randint(random, 2, 3);
    final c = randint(random, 2, 3);
    final ans = a * b * c;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 2,
      questionVi:
          'Búp bê có $a chiếc mũ, $b chiếc váy và $c đôi giày. Mỗi bộ trang phục gồm 1 mũ, 1 váy và 1 đôi giày. Hỏi có bao nhiêu bộ trang phục khác nhau?',
      questionEn:
          'A doll has $a hats, $b dresses and $c pairs of shoes. An outfit is 1 hat, 1 dress and 1 pair of shoes. How many different outfits are there?',
      hintVi: 'Chọn mũ và váy trước, rồi chọn giày.',
      hintEn: 'Choose hat and dress first, then shoes.',
      explanationVi:
          'Chọn mũ và váy: $a × $b = ${a * b} cách. Mỗi cách đi với $c đôi giày: ${a * b} × $c = $ans.',
      explanationEn: '$a × $b × $c = $ans.',
      keywords: kws([('hat', 'mũ'), ('dress', 'váy'), ('shoes', 'giày')]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [a + b + c, a * b + c]),
      params: {'a': a, 'b': b, 'c': c},
    );
  }
}

/// Bắt tay: mức 1, 2, 3.
class HandshakeGenerator extends QuestionGenerator {
  const HandshakeGenerator();

  @override
  String get formId => 'comb.handshake';

  @override
  String get topic => 'comb';

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  static const _cases = [(3, 1), (4, 2), (5, 2), (6, 2), (7, 3), (8, 3)];

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final candidates = [
      for (final c in _cases)
        if (c.$2 == level) c,
    ];
    final picked = pickOne(random, candidates);
    final n = picked.$1;
    final h = n * (n - 1) ~/ 2;
    final sumText = [for (var i = 0; i < n - 1; i++) '${n - 1 - i}']
        .join(' + ');
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi:
          'Có $n bạn gặp nhau, mỗi bạn bắt tay mỗi bạn khác đúng một lần. Hỏi có tất cả bao nhiêu cái bắt tay?',
      questionEn:
          '$n friends meet. Each one shakes hands with every other friend exactly once. How many handshakes are there?',
      hintVi: 'Cẩn thận đừng đếm một cái bắt tay hai lần.',
      hintEn: "Don't count the same handshake twice.",
      explanationVi:
          'Bạn thứ nhất bắt tay ${n - 1} bạn, bạn thứ hai bắt thêm ${n - 2} bạn, ... Tổng: $sumText = $h.',
      explanationEn: '$sumText = $h.',
      keywords: kws([
        ('shake hands', 'bắt tay'),
        ('exactly once', 'đúng một lần'),
      ]),
      answerType: AnswerType.number,
      answer: h,
      distractors: makeDistractors(random, h, [n * (n - 1), n]),
      params: {'n': n},
    );
  }
}

/// Đấu vòng tròn: mức 2, 3.
class TournamentGenerator extends QuestionGenerator {
  const TournamentGenerator();

  @override
  String get formId => 'comb.tournament';

  @override
  String get topic => 'comb';

  @override
  Set<int> get supportedLevels => {2, 3};

  static const _cases = [(4, 2), (5, 3), (6, 3)];

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final candidates = [
      for (final c in _cases)
        if (c.$2 == level) c,
    ];
    final picked = pickOne(random, candidates);
    final n = picked.$1;
    final h = n * (n - 1) ~/ 2;
    final sumText = [for (var i = 0; i < n - 1; i++) '${n - 1 - i}']
        .join(' + ');
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi:
          'Có $n đội bóng thi đấu, mỗi đội gặp mỗi đội khác đúng một trận. Hỏi có tất cả bao nhiêu trận đấu?',
      questionEn:
          '$n teams play in a tournament. Each team plays every other team exactly once. How many matches are played?',
      hintVi: 'Mỗi trận có 2 đội.',
      hintEn: 'Each match has 2 teams.',
      explanationVi: 'Giống bài bắt tay: $sumText = $h trận.',
      explanationEn: 'Like handshakes: $h matches.',
      keywords: kws([('team', 'đội'), ('match', 'trận đấu')]),
      answerType: AnswerType.number,
      answer: h,
      distractors: makeDistractors(random, h, [n * (n - 1), 2 * n]),
      params: {'n': n},
    );
  }
}

/// Lập số từ chữ số: mức 2, 3.
///
/// Mức 3 có hai biến thể (4 chữ số có số 0; lặp lại chữ số được).
class MakeNumGenerator extends QuestionGenerator {
  const MakeNumGenerator();

  @override
  String get formId => 'comb.makenum';

  @override
  String get topic => 'comb';

  @override
  Set<int> get supportedLevels => {2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 2) {
      final pool = [for (var d = 1; d <= 9; d++) d]..shuffle(random);
      final ds = pool.take(3).toList();
      final nums = <int>[];
      for (final a in ds) {
        for (final b in ds) {
          if (a != b) nums.add(a * 10 + b);
        }
      }
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 2,
        questionVi:
            "Từ ba chữ số ${ds.join(', ')}, lập được bao nhiêu số có hai chữ số khác nhau?",
        questionEn:
            "Using the digits ${ds.join(', ')}, how many 2-digit numbers with different digits can you make?",
        hintVi: 'Chọn chữ số hàng chục trước.',
        hintEn: 'Choose the tens digit first.',
        explanationVi:
            "Hàng chục có 3 cách chọn, hàng đơn vị còn 2 cách: 3 × 2 = 6 số. Đó là ${nums.join(', ')}.",
        explanationEn: '3 choices for tens × 2 for ones = 6.',
        keywords: kws([('digit', 'chữ số'), ('different', 'khác nhau')]),
        answerType: AnswerType.number,
        answer: 6,
        distractors: makeDistractors(random, 6, [9, 3]),
        params: {'variant': 0, 'ds': ds},
      );
    }
    // Mức 3.
    if (random.nextBool()) {
      final pool = [for (var d = 1; d <= 9; d++) d]..shuffle(random);
      final ds = [0, ...pool.take(3)];
      var cnt = 0;
      for (final a in ds) {
        for (final b in ds) {
          if (a != 0 && a != b) cnt++;
        }
      }
      final sortedDs = List<int>.of(ds)..sort();
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 3,
        questionVi:
            "Từ bốn chữ số ${sortedDs.join(', ')}, lập được bao nhiêu số có hai chữ số khác nhau?",
        questionEn:
            "Using the digits ${sortedDs.join(', ')}, how many 2-digit numbers with different digits can you make?",
        hintVi: 'Chữ số 0 không đứng ở hàng chục.',
        hintEn: '0 cannot be in the tens place.',
        explanationVi:
            'Hàng chục không được là 0, nên có 3 cách. Hàng đơn vị còn 3 chữ số (kể cả 0): 3 × 3 = $cnt số.',
        explanationEn:
            'Tens: 3 choices (not 0). Ones: 3 remaining. 3 × 3 = $cnt.',
        keywords: kws([('zero', 'số 0'), ('tens place', 'hàng chục')]),
        answerType: AnswerType.number,
        answer: cnt,
        distractors: makeDistractors(random, cnt, [12, 16]),
        params: {'variant': 0, 'ds': ds},
      );
    }
    final pool = [for (var d = 1; d <= 9; d++) d]..shuffle(random);
    final ds = pool.take(3).toList();
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          "Từ ba chữ số ${ds.join(', ')}, lập được bao nhiêu số có hai chữ số (các chữ số có thể lặp lại)?",
      questionEn:
          "Using the digits ${ds.join(', ')}, how many 2-digit numbers can you make if digits may repeat?",
      hintVi: 'Được dùng lại chữ số đã chọn.',
      hintEn: 'Digits can be used again.',
      explanationVi: 'Hàng chục 3 cách, hàng đơn vị cũng 3 cách: 3 × 3 = 9 số.',
      explanationEn: '3 × 3 = 9.',
      keywords: kws([('repeat', 'lặp lại')]),
      answerType: AnswerType.number,
      answer: 9,
      distractors: makeDistractors(random, 9, [6, 3]),
      params: {'variant': 1, 'ds': ds},
    );
  }
}

/// Đường đi: mức 1, 3.
///
/// Mức 3 có thêm đường đi thẳng không qua B.
class RoutesGenerator extends QuestionGenerator {
  const RoutesGenerator();

  @override
  String get formId => 'comb.routes';

  @override
  String get topic => 'comb';

  @override
  Set<int> get supportedLevels => {1, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 1) {
      final a = randint(random, 2, 4);
      final b = randint(random, 2, 4);
      final ans = a * b;
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 1,
        questionVi:
            'Từ nhà đến trường có $a con đường, từ trường đến công viên có $b con đường. Hỏi có bao nhiêu cách đi từ nhà đến công viên mà phải qua trường?',
        questionEn:
            'There are $a roads from home to school and $b roads from school to the park. How many ways are there to go from home to the park through the school?',
        hintVi: 'Vẽ sơ đồ các con đường.',
        hintEn: 'Draw a map of the roads.',
        explanationVi:
            'Mỗi đường đến trường đi tiếp được $b đường: $a × $b = $ans cách.',
        explanationEn: '$a × $b = $ans.',
        keywords: kws([('road', 'con đường'), ('through', 'đi qua')]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [a + b]),
        params: {'a': a, 'b': b},
      );
    }
    // Mức 3.
    final a = randint(random, 2, 3);
    final b = randint(random, 2, 3);
    final c = randint(random, 1, 3);
    final ans = a * b + c;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          'Từ A đến B có $a con đường, từ B đến C có $b con đường. Ngoài ra còn có $c con đường đi thẳng từ A đến C không qua B. Hỏi có bao nhiêu cách đi từ A đến C?',
      questionEn:
          'There are $a roads from A to B and $b roads from B to C. There are also $c direct roads from A to C. How many ways are there to go from A to C?',
      hintVi: 'Chia thành hai trường hợp: qua B và không qua B.',
      hintEn: 'Two cases: through B or direct.',
      explanationVi:
          'Đi qua B: $a × $b = ${a * b} cách. Đi thẳng: $c cách. Tổng: $ans cách.',
      explanationEn: 'Via B: ${a * b}; direct: $c. Total $ans.',
      keywords: kws([('direct', 'đi thẳng')]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [a + b + c, a * b]),
      params: {'a': a, 'b': b, 'c': c},
    );
  }
}

/// Nguyên lý Dirichlet (lấy tất): mức 2, 3.
class PigeonGenerator extends QuestionGenerator {
  const PigeonGenerator();

  @override
  String get formId => 'comb.pigeon';

  @override
  String get topic => 'comb';

  @override
  Set<int> get supportedLevels => {2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 2) {
      final r = randint(random, 4, 9);
      final g = randint(random, 4, 9);
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 2,
        questionVi:
            'Trong hộp có $r chiếc tất đỏ và $g chiếc tất xanh. Bé nhắm mắt lấy tất. Hỏi phải lấy ít nhất bao nhiêu chiếc để chắc chắn có 2 chiếc cùng màu?',
        questionEn:
            'A box has $r red socks and $g blue socks. Without looking, what is the smallest number of socks you must take to be sure of getting 2 of the same colour?',
        hintVi: 'Hãy nghĩ đến trường hợp xui nhất.',
        hintEn: 'Think about the unluckiest case.',
        explanationVi: 'Nếu xui nhất, 2 chiếc đầu khác màu nhau. Chiếc thứ 3 chắc chắn trùng màu với một trong hai chiếc: cần 3 chiếc.',
        explanationEn:
            'Worst case: first 2 are different colours. The 3rd must match: 3.',
        keywords: kws([('at least', 'ít nhất'), ('be sure', 'chắc chắn')]),
        answerType: AnswerType.number,
        answer: 3,
        distractors: makeDistractors(random, 3, [2, r + 1, g + 1]),
        params: {'r': r, 'g': g},
      );
    }
    // Mức 3.
    final r = randint(random, 3, 6);
    final g = randint(random, 3, 6);
    final y = randint(random, 2, 5);
    final ans = g + y + 2;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          'Trong túi có $r viên kẹo dâu, $g viên kẹo táo và $y viên kẹo cam. Không nhìn vào túi, phải lấy ít nhất bao nhiêu viên để chắc chắn có 2 viên kẹo dâu?',
      questionEn:
          'A bag has $r strawberry, $g apple and $y orange sweets. Without looking, what is the smallest number you must take to be sure of getting 2 strawberry sweets?',
      hintVi: 'Trường hợp xui nhất là lấy hết loại khác trước.',
      hintEn: 'Worst case: take all the other kinds first.',
      explanationVi:
          'Xui nhất là lấy hết $g viên táo và $y viên cam trước (${g + y} viên), sau đó lấy thêm 2 viên chắc chắn là dâu: ${g + y} + 2 = $ans viên.',
      explanationEn:
          'Worst case: all ${g + y} non-strawberry first, then 2 more: $ans.',
      keywords: kws([('strawberry', 'dâu tây'), ('at least', 'ít nhất')]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [3, g + y + 1, 4]),
      params: {'r': r, 'g': g, 'y': y},
    );
  }
}

/// Xếp hàng chụp ảnh: mức 2, 3.
///
/// Mức 2: 3 bạn xếp tự do (6 cách). Mức 3 có hai câu cố định:
/// An đứng giữa (2 cách) hoặc 4 bạn xếp tự do (24 cách).
class ArrangeGenerator extends QuestionGenerator {
  const ArrangeGenerator();

  @override
  String get formId => 'comb.arrange';

  @override
  String get topic => 'comb';

  @override
  Set<int> get supportedLevels => {2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 2) {
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 2,
        questionVi: 'Ba bạn An, Bình, Chi đứng thành một hàng ngang để chụp ảnh. Hỏi có bao nhiêu cách xếp?',
        questionEn: 'An, Binh and Chi stand in a row for a photo. In how many different ways can they stand?',
        hintVi: 'Liệt kê: ABC, ACB, ...',
        hintEn: 'List them: ABC, ACB, ...',
        explanationVi: 'Vị trí đầu có 3 cách chọn, vị trí giữa còn 2, vị trí cuối còn 1: 3 × 2 × 1 = 6 cách.',
        explanationEn: '3 × 2 × 1 = 6.',
        keywords: kws([('row', 'hàng'), ('way', 'cách')]),
        answerType: AnswerType.number,
        answer: 6,
        distractors: makeDistractors(random, 6, [3, 9]),
        params: {'variant': 0},
      );
    }
    // Mức 3.
    if (random.nextBool()) {
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 3,
        questionVi: 'Ba bạn An, Bình, Chi đứng thành một hàng ngang. Hỏi có bao nhiêu cách xếp sao cho An luôn đứng ở giữa?',
        questionEn: 'An, Binh and Chi stand in a row. In how many ways can they stand if An must be in the middle?',
        hintVi: 'Đặt An vào giữa trước.',
        hintEn: 'Put An in the middle first.',
        explanationVi: 'An đứng giữa, hai bạn còn lại đổi chỗ: Bình – An – Chi hoặc Chi – An – Bình. Có 2 cách.',
        explanationEn: 'Binh-An-Chi or Chi-An-Binh: 2 ways.',
        keywords: kws([('middle', 'ở giữa')]),
        answerType: AnswerType.number,
        answer: 2,
        distractors: makeDistractors(random, 2, [6, 3]),
        params: {'variant': 0},
      );
    }
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          'Bốn bạn xếp thành một hàng ngang. Hỏi có bao nhiêu cách xếp?',
      questionEn: 'Four children stand in a row. In how many different ways can they stand?',
      hintVi: 'Chọn lần lượt từng vị trí.',
      hintEn: 'Fill one position at a time.',
      explanationVi: 'Vị trí 1 có 4 cách, vị trí 2 còn 3, vị trí 3 còn 2, vị trí 4 còn 1: 4 × 3 × 2 × 1 = 24 cách.',
      explanationEn: '4 × 3 × 2 × 1 = 24.',
      keywords: kws([('row', 'hàng'), ('way', 'cách')]),
      answerType: AnswerType.number,
      answer: 24,
      distractors: makeDistractors(random, 24, [16, 12]),
      params: {'variant': 1},
    );
  }
}

/// Chọn 2: mức 1, 2.
class Choose2Generator extends QuestionGenerator {
  const Choose2Generator();

  @override
  String get formId => 'comb.choose2';

  @override
  String get topic => 'comb';

  @override
  Set<int> get supportedLevels => {1, 2};

  static const _cases = [(4, 1), (5, 2), (6, 2)];

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final candidates = [
      for (final c in _cases)
        if (c.$2 == level) c,
    ];
    final picked = pickOne(random, candidates);
    final n = picked.$1;
    final h = n * (n - 1) ~/ 2;
    final sumText = [for (var i = 0; i < n - 1; i++) '${n - 1 - i}']
        .join(' + ');
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi:
          'Cửa hàng có $n loại kem khác nhau. Bé được chọn 2 loại khác nhau. Hỏi bé có bao nhiêu cách chọn?',
      questionEn:
          'A shop has $n different ice-cream flavours. You may pick 2 different flavours. How many ways can you choose?',
      hintVi: 'Chọn dâu – vani cũng giống vani – dâu.',
      hintEn: 'Strawberry–vanilla is the same as vanilla–strawberry.',
      explanationVi:
          'Liệt kê theo cặp, mỗi cặp chỉ tính một lần: $sumText = $h cách.',
      explanationEn: '$sumText = $h.',
      keywords: kws([('flavour', 'vị'), ('choose', 'chọn')]),
      answerType: AnswerType.number,
      answer: h,
      distractors: makeDistractors(random, h, [n * (n - 1), 2 * n]),
      params: {'n': n},
    );
  }
}

/// Đường đi trên lưới: mức 2, 3.
class GridPathGenerator extends QuestionGenerator {
  const GridPathGenerator();

  @override
  String get formId => 'comb.gridpath';

  @override
  String get topic => 'comb';

  @override
  Set<int> get supportedLevels => {2, 3};

  static const _cases = [(1, 2, 2), (1, 3, 2), (2, 2, 3), (2, 3, 3)];

  static int _binom(int n, int k) {
    var res = 1;
    for (var i = 1; i <= k; i++) {
      res = res * (n - k + i) ~/ i;
    }
    return res;
  }

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final candidates = [
      for (final c in _cases)
        if (c.$3 == level) c,
    ];
    final picked = pickOne(random, candidates);
    final r = picked.$1;
    final c = picked.$2;
    final tot = _binom(r + c, r);
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi: 'Một chú kiến đi từ A đến B theo các cạnh của ô vuông, mỗi bước chỉ được đi sang phải hoặc đi lên. Hỏi có bao nhiêu đường đi khác nhau?',
      questionEn: 'An ant walks from A to B along the grid lines, only moving right or up. How many different paths are there?',
      hintVi: 'Ghi số đường đi vào từng điểm, bắt đầu từ A.',
      hintEn: 'Write the number of ways at each corner, starting from A.',
      explanationVi:
          'Ghi số cách đi đến từng điểm: mỗi điểm bằng tổng số cách của điểm bên trái và điểm bên dưới. Đến B có $tot cách.',
      explanationEn:
          'Write the number of ways at each point: each is the sum of the point to the left and the point below. B gets $tot.',
      keywords: kws([
        ('path', 'đường đi'),
        ('right / up', 'sang phải / đi lên'),
      ]),
      answerType: AnswerType.number,
      answer: tot,
      distractors: makeDistractors(random, tot, [r + c, tot + 1]),
      figure: FigureSpec.pathGrid(rows: r, cols: c),
      params: {'r': r, 'c': c},
    );
  }
}

/// Tách kẹo thành 2 phần: mức 2, 3.
class SplitGenerator extends QuestionGenerator {
  const SplitGenerator();

  @override
  String get formId => 'comb.split';

  @override
  String get topic => 'comb';

  @override
  Set<int> get supportedLevels => {2, 3};

  static const _cases = [(6, 2), (8, 2), (9, 3), (12, 3)];

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final candidates = [
      for (final c in _cases)
        if (c.$2 == level) c,
    ];
    final picked = pickOne(random, candidates);
    final k = picked.$1;
    var cnt = 0;
    for (var a = 1; a < k; a++) {
      for (var b = a; b < k; b++) {
        if (a + b == k) cnt++;
      }
    }
    final listed = [for (var a = 1; a <= k ~/ 2; a++) '$a + ${k - a}']
        .join(', ');
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi:
          'Có bao nhiêu cách tách $k viên kẹo thành 2 phần, mỗi phần có ít nhất 1 viên? (Tách ${k - 1} và 1 cũng giống tách 1 và ${k - 1}.)',
      questionEn:
          'How many ways can $k sweets be split into 2 groups with at least 1 sweet each? (${k - 1} and 1 is the same as 1 and ${k - 1}.)',
      hintVi: 'Bắt đầu từ phần nhỏ nhất là 1 viên.',
      hintEn: 'Start with 1 sweet in the smaller group.',
      explanationVi: 'Liệt kê: $listed. Có $cnt cách.',
      explanationEn: 'List: $listed. $cnt ways.',
      keywords: kws([('split', 'tách, chia'), ('at least', 'ít nhất')]),
      answerType: AnswerType.number,
      answer: cnt,
      distractors: makeDistractors(random, cnt, [k - 1, cnt + 1]),
      params: {'k': k},
    );
  }
}

/// Đổi tiền 10 nghìn: chỉ mức 3. Câu cố định.
class CoinsGenerator extends QuestionGenerator {
  const CoinsGenerator();

  @override
  String get formId => 'comb.coins';

  @override
  String get topic => 'comb';

  @override
  Set<int> get supportedLevels => {3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    // Đếm số cách đổi 10 nghìn thành tờ 1, 2, 5 nghìn (không bắt buộc
    // đủ cả ba loại), đúng công thức đếm của gen.py.
    var ways = 0;
    for (var a = 0; a <= 10; a++) {
      for (var b = 0; b <= 5; b++) {
        for (var c = 0; c <= 2; c++) {
          if (a + 2 * b + 5 * c == 10) ways++;
        }
      }
    }
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi: 'Có bao nhiêu cách đổi tờ 10 nghìn đồng thành các tờ 1 nghìn, 2 nghìn và 5 nghìn đồng? (Không bắt buộc phải có đủ cả ba loại.)',
      questionEn: "How many ways can you change a 10 thousand dong note into 1, 2 and 5 thousand dong notes? (You don't have to use all three kinds.)",
      hintVi: 'Chia trường hợp theo số tờ 5 nghìn.',
      hintEn: 'Split into cases by the number of 5s.',
      explanationVi: 'Dùng 2 tờ 5 nghìn: 1 cách. Dùng 1 tờ 5 nghìn: 5 nghìn còn lại đổi bằng tờ 2 và 1 nghìn: 3 cách (0, 1, 2 tờ 2 nghìn). Không dùng 5 nghìn: 10 nghìn đổi bằng 2 và 1 nghìn: 6 cách (0 → 5 tờ 2 nghìn). Tổng: 1 + 3 + 6 = 10 cách.',
      explanationEn: 'Two 5s: 1 way. One 5: 3 ways. No 5s: 6 ways. Total 10.',
      keywords: kws([('change money', 'đổi tiền'), ('note', 'tờ tiền')]),
      answerType: AnswerType.number,
      answer: ways,
      distractors: makeDistractors(random, ways, [6, 8]),
      params: {'variant': 0},
    );
  }
}

/// Tất cả generator của mảng comb.
const List<QuestionGenerator> combGenerators = [
  OutfitGenerator(),
  HandshakeGenerator(),
  TournamentGenerator(),
  MakeNumGenerator(),
  RoutesGenerator(),
  PigeonGenerator(),
  ArrangeGenerator(),
  Choose2Generator(),
  GridPathGenerator(),
  SplitGenerator(),
  CoinsGenerator(),
];
