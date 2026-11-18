import 'dart:math';

import '../question.dart';

/// Mảng Hình học: 9 dạng bài, chuyển từ `gen_geo()` trong `gen.py`.
///
/// Cách diễn đạt đề và lời giải giữ nguyên như `gen.py`. Các câu có hình
/// kèm [FigureSpec] để T1-06 sinh SVG (tham số hình giữ nguyên các hàm
/// `svg_grid`, `svg_fan`, `svg_path_grid` của `gen.py`).

/// Đếm hình vuông trong lưới: mức 1, 2, 3.
class CountSqGenerator extends QuestionGenerator {
  const CountSqGenerator();

  @override
  String get formId => 'geo.countsq';

  @override
  String get topic => 'geo';

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  static const _cases = [
    (1, 3, 1),
    (1, 4, 1),
    (2, 2, 2),
    (2, 3, 2),
    (2, 4, 2),
    (3, 3, 3),
    (3, 4, 3),
    (2, 5, 3),
  ];

  static int _squares(int rows, int cols) {
    var n = 0;
    final m = rows < cols ? rows : cols;
    for (var i = 0; i < m; i++) {
      n += (rows - i) * (cols - i);
    }
    return n;
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
    final n = _squares(r, c);
    final m = r < c ? r : c;
    final parts = [
      for (var k = 2; k <= m; k++)
        'Hình vuông $k×$k ô: ${(r - k + 1) * (c - k + 1)}.',
    ];
    final partsEn = [
      for (var k = 2; k <= m; k++)
        '$k×$k squares: ${(r - k + 1) * (c - k + 1)}.',
    ];
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi: 'Có tất cả bao nhiêu hình vuông trong hình dưới đây?',
      questionEn: 'How many squares are there in the figure below?',
      hintVi: 'Đừng quên các hình vuông to ghép từ nhiều ô.',
      hintEn: "Don't forget the bigger squares made of several small ones.",
      explanationVi:
          'Hình vuông nhỏ (1 ô): ${r * c}. ${parts.join(' ')} Tổng: $n hình vuông.',
      explanationEn: '1×1 squares: ${r * c}. ${partsEn.join(' ')} Total $n.',
      keywords: kws([('square', 'hình vuông'), ('figure', 'hình vẽ')]),
      answerType: AnswerType.number,
      answer: n,
      distractors: makeDistractors(random, n, [r * c, n + 1]),
      figure: FigureSpec.grid(rows: r, cols: c),
      params: {'rows': r, 'cols': c},
    );
  }
}

/// Đếm hình chữ nhật trong một hàng ô: mức 1, 2, 3.
class CountRectGenerator extends QuestionGenerator {
  const CountRectGenerator();

  @override
  String get formId => 'geo.countrect';

  @override
  String get topic => 'geo';

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  static const _cases = [(2, 1), (3, 2), (4, 2), (5, 3), (6, 3)];

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final candidates = [
      for (final c in _cases)
        if (c.$2 == level) c,
    ];
    final picked = pickOne(random, candidates);
    final n = picked.$1;
    final tot = n * (n + 1) ~/ 2;
    final sumText = [for (var k = 0; k < n; k++) '${n - k}'].join(' + ');
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi: 'Có tất cả bao nhiêu hình chữ nhật trong hình dưới đây? (Hình vuông cũng là hình chữ nhật.)',
      questionEn: 'How many rectangles are there in the figure below? (A square is also a rectangle.)',
      hintVi: 'Đếm theo số ô ghép lại: 1 ô, 2 ô, 3 ô...',
      hintEn: 'Count by size: 1 cell, 2 cells, 3 cells...',
      explanationVi:
          'Hình gồm $n ô. Hình chữ nhật 1 ô: $n; 2 ô: ${n - 1}; ...; $n ô: 1. Tổng: $sumText = $tot.',
      explanationEn:
          '1 cell: $n, 2 cells: ${n - 1}, ..., $n cells: 1. Total $tot.',
      keywords: kws([('rectangle', 'hình chữ nhật'), ('square', 'hình vuông')]),
      answerType: AnswerType.number,
      answer: tot,
      distractors: makeDistractors(random, tot, [n, tot - 1]),
      figure: FigureSpec.grid(rows: 1, cols: n),
      params: {'n': n},
    );
  }
}

/// Đếm hình tam giác trong hình quạt: mức 1, 2, 3.
class CountTriGenerator extends QuestionGenerator {
  const CountTriGenerator();

  @override
  String get formId => 'geo.counttri';

  @override
  String get topic => 'geo';

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  static const _cases = [(1, 1), (2, 2), (3, 2), (4, 3), (5, 3)];

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final candidates = [
      for (final c in _cases)
        if (c.$2 == level) c,
    ];
    final picked = pickOne(random, candidates);
    final k = picked.$1;
    final tot = (k + 2) * (k + 1) ~/ 2;
    final sumText = [for (var i = 0; i <= k; i++) '${k + 1 - i}'].join(' + ');
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi: 'Có tất cả bao nhiêu hình tam giác trong hình dưới đây?',
      questionEn: 'How many triangles are there in the figure below?',
      hintVi:
          'Mỗi hình tam giác có chung đỉnh trên cùng. Hãy đếm theo cạnh đáy.',
      hintEn: 'All triangles share the top corner. Count using the base.',
      explanationVi:
          'Cạnh đáy bị chia thành ${k + 1} đoạn nhỏ. Mỗi tam giác ứng với một đoạn trên cạnh đáy (gồm 1 hoặc nhiều đoạn nhỏ liền nhau): $sumText = $tot.',
      explanationEn:
          'The base is split into ${k + 1} parts. Each triangle matches a piece of the base: $sumText = $tot.',
      keywords: kws([('triangle', 'hình tam giác'), ('base', 'cạnh đáy')]),
      answerType: AnswerType.number,
      answer: tot,
      distractors: makeDistractors(random, tot, [k + 1, tot - 1]),
      figure: FigureSpec.fan(segments: k),
      params: {'k': k},
    );
  }
}

/// Chu vi: mức 1, 2, 3.
///
/// Mức 1 có hai biến thể (chu vi hình vuông; chu vi hình chữ nhật).
class PerimGenerator extends QuestionGenerator {
  const PerimGenerator();

  @override
  String get formId => 'geo.perim';

  @override
  String get topic => 'geo';

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 1) {
      if (random.nextBool()) {
        final a = randint(random, 3, 9);
        final ans = 4 * a;
        return Question(
          formId: formId,
          topic: topic,
          difficulty: 1,
          questionVi:
              'Một hình vuông có cạnh dài $a cm. Hỏi chu vi hình vuông đó là bao nhiêu xăng-ti-mét?',
          questionEn:
              'A square has sides of $a cm. What is its perimeter in cm?',
          hintVi: 'Chu vi là tổng độ dài các cạnh.',
          hintEn: 'Perimeter = total length of all sides.',
          explanationVi: 'Hình vuông có 4 cạnh bằng nhau: $a × 4 = $ans cm.',
          explanationEn: '$a × 4 = $ans cm.',
          keywords: kws([('perimeter', 'chu vi'), ('side', 'cạnh')]),
          answerType: AnswerType.number,
          answer: ans,
          distractors: makeDistractors(random, ans, [2 * a, a * a]),
          params: {'variant': 0, 'a': a},
        );
      }
      final l = randint(random, 5, 12);
      final w = randint(random, 2, 4);
      final ans = 2 * (l + w);
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 1,
        questionVi:
            'Một hình chữ nhật có chiều dài $l cm, chiều rộng $w cm. Hỏi chu vi hình chữ nhật là bao nhiêu xăng-ti-mét?',
        questionEn:
            'A rectangle is $l cm long and $w cm wide. What is its perimeter in cm?',
        hintVi: 'Hình chữ nhật có 2 chiều dài và 2 chiều rộng.',
        hintEn: 'A rectangle has 2 lengths and 2 widths.',
        explanationVi: 'Chu vi = $l + $w + $l + $w = $ans cm.',
        explanationEn: '$l + $w + $l + $w = $ans cm.',
        keywords: kws([('length', 'chiều dài'), ('width', 'chiều rộng')]),
        answerType: AnswerType.number,
        answer: ans,
        distractors: makeDistractors(random, ans, [l + w]),
        params: {'variant': 1, 'l': l, 'w': w},
      );
    }
    if (level == 2) {
      final a = randint(random, 3, 9);
      return Question(
        formId: formId,
        topic: topic,
        difficulty: 2,
        questionVi:
            'Một hình vuông có chu vi ${4 * a} cm. Hỏi cạnh của hình vuông dài bao nhiêu xăng-ti-mét?',
        questionEn:
            'A square has a perimeter of ${4 * a} cm. How long is each side?',
        hintVi: 'Hình vuông có 4 cạnh bằng nhau.',
        hintEn: 'All 4 sides are equal.',
        explanationVi: '4 cạnh bằng nhau: ${4 * a} : 4 = $a cm.',
        explanationEn: '${4 * a} ÷ 4 = $a cm.',
        keywords: kws([('perimeter', 'chu vi'), ('side', 'cạnh')]),
        answerType: AnswerType.number,
        answer: a,
        distractors: makeDistractors(random, a, [2 * a]),
        params: {'a': a},
      );
    }
    // Mức 3: tìm chiều rộng khi biết chu vi và chiều dài.
    final l = randint(random, 6, 12);
    final w = randint(random, 2, 5);
    final perim = 2 * (l + w);
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi:
          'Một hình chữ nhật có chu vi $perim cm, chiều dài $l cm. Hỏi chiều rộng là bao nhiêu xăng-ti-mét?',
      questionEn:
          'A rectangle has a perimeter of $perim cm and a length of $l cm. What is its width?',
      hintVi: 'Nửa chu vi = dài + rộng.',
      hintEn: 'Half the perimeter = length + width.',
      explanationVi:
          'Một chiều dài cộng một chiều rộng bằng nửa chu vi: $perim : 2 = ${l + w} cm. Chiều rộng: ${l + w} − $l = $w cm.',
      explanationEn:
          'Half the perimeter is ${l + w}; width = ${l + w} − $l = $w cm.',
      keywords: kws([('width', 'chiều rộng'), ('half', 'một nửa')]),
      answerType: AnswerType.number,
      answer: w,
      distractors: makeDistractors(random, w, [perim - l, l + w]),
      params: {'l': l, 'w': w, 'perim': perim},
    );
  }
}

/// Que diêm: mức 2, 3.
///
/// Mức 2: hàng hình vuông (n = 3, 4, 6) hoặc hàng hình tam giác (n = 3).
/// Mức 3: hàng hình vuông (n = 5), hàng hình tam giác (n = 5),
/// hoặc hình chữ nhật 2 hàng (n = 3, 4).
class MatchesGenerator extends QuestionGenerator {
  const MatchesGenerator();

  @override
  String get formId => 'geo.matches';

  @override
  String get topic => 'geo';

  @override
  Set<int> get supportedLevels => {2, 3};

  Question _squaresRow(int level, Random random, int n) {
    final ans = 3 * n + 1;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi:
          'Dùng que diêm xếp $n hình vuông thành một hàng ngang (hai hình vuông cạnh nhau dùng chung một que). Hỏi cần bao nhiêu que diêm?',
      questionEn:
          'Matchsticks make $n squares in a row (neighbouring squares share a stick). How many matchsticks are needed?',
      hintVi: 'Vẽ 2 hình rồi 3 hình để thấy quy luật.',
      hintEn: 'Draw 2 then 3 squares to see the pattern.',
      explanationVi:
          'Hình vuông đầu cần 4 que, mỗi hình vuông sau chỉ cần thêm 3 que: 4 + 3 × ${n - 1} = $ans que.',
      explanationEn:
          'First square 4 sticks, each next one 3 more: 4 + 3 × ${n - 1} = $ans.',
      keywords: kws([
        ('matchstick', 'que diêm'),
        ('in a row', 'thành một hàng'),
      ]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [4 * n, 3 * n]),
      figure: FigureSpec.grid(rows: 1, cols: n, cell: 40),
      params: {'variant': 0, 'n': n},
    );
  }

  Question _trianglesRow(int level, Random random, int n) {
    final ans = 2 * n + 1;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi:
          'Dùng que diêm xếp $n hình tam giác thành một hàng (hai tam giác cạnh nhau dùng chung một que). Hỏi cần bao nhiêu que diêm?',
      questionEn:
          'Matchsticks make $n triangles in a row (neighbouring triangles share a stick). How many matchsticks are needed?',
      hintVi: 'Mỗi tam giác mới dùng chung 1 que với tam giác trước.',
      hintEn: 'Each new triangle shares one stick.',
      explanationVi:
          'Tam giác đầu cần 3 que, mỗi tam giác sau cần thêm 2 que: 3 + 2 × ${n - 1} = $ans que.',
      explanationEn: '3 + 2 × ${n - 1} = $ans.',
      keywords: kws([('triangle', 'tam giác'), ('share', 'dùng chung')]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [3 * n]),
      // gen.py không gắn hình cho biến thể tam giác.
      params: {'variant': 1, 'n': n},
    );
  }

  Question _twoRowRect(int level, Random random, int n) {
    final ans = 5 * n + 2;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi:
          'Dùng que diêm xếp một hình chữ nhật gồm 2 hàng, mỗi hàng $n ô vuông (các ô cạnh nhau dùng chung que). Hỏi cần bao nhiêu que diêm?',
      questionEn:
          'Matchsticks make a grid of 2 rows with $n squares in each row (shared sides use one stick). How many matchsticks are needed?',
      hintVi: 'Đếm riêng que nằm ngang và que đứng.',
      hintEn: 'Count horizontal and vertical sticks separately.',
      explanationVi:
          'Que nằm ngang: 3 hàng que × $n = ${3 * n}. Que đứng: 2 hàng × ${n + 1} = ${2 * (n + 1)}. Tổng: $ans que.',
      explanationEn: 'Horizontal ${3 * n} + vertical ${2 * (n + 1)} = $ans.',
      keywords: kws([('horizontal', 'nằm ngang'), ('vertical', 'thẳng đứng')]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [8 * n, 6 * n + 1]),
      figure: FigureSpec.grid(rows: 2, cols: n, cell: 40),
      params: {'variant': 2, 'n': n},
    );
  }

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 2) {
      // 3 biến thể mức 2: vuông n=3, 4, 6 hoặc tam giác n=3.
      final variant = random.nextInt(4);
      if (variant < 3) {
        return _squaresRow(2, random, [3, 4, 6][variant]);
      }
      return _trianglesRow(2, random, 3);
    }
    // Mức 3: vuông n=5, tam giác n=5, hoặc chữ nhật 2 hàng n=3, 4.
    final variant = random.nextInt(4);
    if (variant == 0) return _squaresRow(3, random, 5);
    if (variant == 1) return _trianglesRow(3, random, 5);
    return _twoRowRect(3, random, variant == 2 ? 3 : 4);
  }
}

/// Đếm cạnh: chỉ mức 1.
class SidesGenerator extends QuestionGenerator {
  const SidesGenerator();

  @override
  String get formId => 'geo.sides';

  @override
  String get topic => 'geo';

  @override
  Set<int> get supportedLevels => {1};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final a = randint(random, 2, 5);
    final b = randint(random, 1, 4);
    final ans = 3 * a + 4 * b;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 1,
      questionVi:
          'Có $a hình tam giác và $b hình vuông. Hỏi tất cả có bao nhiêu cạnh?',
      questionEn:
          'There are $a triangles and $b squares. How many sides are there in total?',
      hintVi: 'Tam giác có 3 cạnh, hình vuông có 4 cạnh.',
      hintEn: 'A triangle has 3 sides, a square has 4.',
      explanationVi:
          'Tam giác: $a × 3 = ${3 * a}. Hình vuông: $b × 4 = ${4 * b}. Tổng: $ans cạnh.',
      explanationEn: '${3 * a} + ${4 * b} = $ans.',
      keywords: kws([('side', 'cạnh'), ('corner', 'góc, đỉnh')]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [4 * (a + b), 3 * (a + b)]),
      params: {'a': a, 'b': b},
    );
  }
}

/// Tháp khối lập phương: mức 2, 3.
///
/// Mức 3 có thêm một câu cố định (tháp 1 + 4 + 9 = 14 khối).
class CubesGenerator extends QuestionGenerator {
  const CubesGenerator();

  @override
  String get formId => 'geo.cubes';

  @override
  String get topic => 'geo';

  @override
  Set<int> get supportedLevels => {2, 3};

  static const _cases = [(3, 1, 2), (4, 1, 2), (4, 2, 2), (5, 2, 3)];

  Question _tower(int level, Random random, int n, int k) {
    final layers = [for (var i = 0; i < n; i++) 1 + k * i];
    final tot = layers.reduce((a, b) => a + b);
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi:
          'Bé xếp các khối lập phương thành một tháp $n tầng. Tầng trên cùng có 1 khối, mỗi tầng bên dưới có nhiều hơn tầng ngay trên nó $k khối. Hỏi cả tháp có bao nhiêu khối?',
      questionEn:
          'A tower has $n layers of cubes. The top layer has 1 cube, and each layer has $k more cubes than the layer above it. How many cubes are there?',
      hintVi: 'Viết số khối của từng tầng rồi cộng.',
      hintEn: 'Write each layer, then add.',
      explanationVi:
          "Các tầng: ${layers.join(', ')}. Tổng: ${layers.join(' + ')} = $tot khối.",
      explanationEn: "Layers: ${layers.join(', ')}. Total $tot.",
      keywords: kws([('cube', 'khối lập phương'), ('layer', 'tầng')]),
      answerType: AnswerType.number,
      answer: tot,
      distractors: makeDistractors(random, tot, [1 + k * (n - 1), tot + 1]),
      params: {'variant': 0, 'n': n, 'k': k},
    );
  }

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    if (level == 2) {
      final candidates = [
        for (final c in _cases)
          if (c.$3 == 2) c,
      ];
      final picked = pickOne(random, candidates);
      return _tower(2, random, picked.$1, picked.$2);
    }
    // Mức 3: tháp (5, 2) hoặc câu cố định 1 + 4 + 9.
    if (random.nextBool()) {
      return _tower(3, random, 5, 2);
    }
    return Question(
      formId: formId,
      topic: topic,
      difficulty: 3,
      questionVi: 'Bé xếp tháp khối lập phương 3 tầng: tầng trên cùng 1 khối, tầng giữa là hình vuông 2 × 2 khối, tầng dưới cùng là hình vuông 3 × 3 khối. Hỏi tháp có bao nhiêu khối?',
      questionEn: 'A tower has 3 layers: the top is 1 cube, the middle is a 2 × 2 square of cubes, the bottom is a 3 × 3 square. How many cubes are there?',
      hintVi: '2 × 2 = 4, 3 × 3 = 9.',
      hintEn: '2 × 2 = 4, 3 × 3 = 9.',
      explanationVi: '1 + 4 + 9 = 14 khối.',
      explanationEn: '1 + 4 + 9 = 14.',
      keywords: kws([('cube', 'khối lập phương')]),
      answerType: AnswerType.number,
      answer: 14,
      distractors: makeDistractors(random, 14, [6, 13]),
      params: {'variant': 1},
    );
  }
}

/// Chu vi hình ghép: mức 2, 3.
class ShapePerimGenerator extends QuestionGenerator {
  const ShapePerimGenerator();

  @override
  String get formId => 'geo.shapeperim';

  @override
  String get topic => 'geo';

  @override
  Set<int> get supportedLevels => {2, 3};

  static const _cases = [(2, 3), (3, 2), (3, 4), (4, 3)];

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final candidates = [
      for (final c in _cases)
        if ((c.$1 <= 3 && c.$2 <= 3 ? 2 : 3) == level) c,
    ];
    final picked = pickOne(random, candidates);
    final k = picked.$1;
    final s = picked.$2;
    final ans = 2 * (k * s + s);
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi:
          'Ghép $k hình vuông, mỗi hình có cạnh $s cm, thành một hàng như hình dưới. Hỏi chu vi của hình mới là bao nhiêu xăng-ti-mét?',
      questionEn:
          '$k squares with sides of $s cm are joined in a row as shown. What is the perimeter of the new shape?',
      hintVi: 'Các cạnh ghép vào bên trong không tính vào chu vi.',
      hintEn: 'Inside edges are not part of the perimeter.',
      explanationVi:
          'Hình mới là hình chữ nhật dài $k × $s = ${k * s} cm, rộng $s cm. Chu vi: (${k * s} + $s) × 2 = $ans cm.',
      explanationEn:
          'It is a rectangle ${k * s} cm by $s cm. Perimeter (${k * s} + $s) × 2 = $ans cm.',
      keywords: kws([('perimeter', 'chu vi'), ('join', 'ghép')]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [4 * s * k]),
      figure: FigureSpec.grid(rows: 1, cols: k, cell: 45),
      params: {'k': k, 's': s},
    );
  }
}

/// Cắt giấy: mức 1, 2.
class CutPaperGenerator extends QuestionGenerator {
  const CutPaperGenerator();

  @override
  String get formId => 'geo.cutpaper';

  @override
  String get topic => 'geo';

  @override
  Set<int> get supportedLevels => {1, 2};

  static const _cases = [(3, 1), (5, 2), (7, 2)];

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    final candidates = [
      for (final c in _cases)
        if (c.$2 == level) c,
    ];
    final picked = pickOne(random, candidates);
    final n = picked.$1;
    final ans = n + 1;
    return Question(
      formId: formId,
      topic: topic,
      difficulty: level,
      questionVi:
          'Có 1 tờ giấy. Mỗi lần, bé cắt một mảnh giấy thành 2 mảnh. Sau $n lần cắt, bé có bao nhiêu mảnh giấy?',
      questionEn:
          'There is 1 sheet of paper. Each time, you cut one piece into 2. After $n cuts, how many pieces are there?',
      hintVi: 'Thử với 1 lần cắt, 2 lần cắt.',
      hintEn: 'Try 1 cut, then 2 cuts.',
      explanationVi: 'Mỗi lần cắt thêm được 1 mảnh: 1 + $n = $ans mảnh.',
      explanationEn: 'Each cut adds 1 piece: 1 + $n = $ans.',
      keywords: kws([('cut', 'cắt'), ('piece', 'mảnh')]),
      answerType: AnswerType.number,
      answer: ans,
      distractors: makeDistractors(random, ans, [2 * n, n]),
      params: {'n': n},
    );
  }
}

/// Tất cả generator của mảng geo.
const List<QuestionGenerator> geoGenerators = [
  CountSqGenerator(),
  CountRectGenerator(),
  CountTriGenerator(),
  PerimGenerator(),
  MatchesGenerator(),
  SidesGenerator(),
  CubesGenerator(),
  ShapePerimGenerator(),
  CutPaperGenerator(),
];
