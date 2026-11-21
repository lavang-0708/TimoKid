import 'dart:math';

import '../question.dart';

/// 12 dạng bài bổ sung đợt 3 (21/11), ưu tiên mảng Hình học đang mỏng.
///
/// Dạng bài theo kiểu đề TIMO lớp 2, số và lời văn tự soạn. Khuôn khổ
/// lớp 2: số trong phạm vi 100, nhân trong bảng 2–5, chia hết. Mọi dạng
/// đều là câu điền số (ở bậc lẻ app tự đổi thành trắc nghiệm bằng đáp án
/// nhiễu). Mỗi câu ghi tham số vào [Question.params] để test giải lại độc
/// lập trong `question_solvers.dart`.
class Timo3Generator extends QuestionGenerator {
  const Timo3Generator(this.formId, this.topic, this._build);

  @override
  final String formId;

  @override
  final String topic;

  final Question Function(Timo3Generator g, int level, Random r) _build;

  @override
  Set<int> get supportedLevels => {1, 2, 3};

  @override
  Question generate(int level, Random random) {
    checkLevel(level);
    return _build(this, level, random);
  }
}

Question _mk(
  Timo3Generator g,
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

// ================================================================ HÌNH HỌC

/// Cắm cọc quanh mảnh vườn (đường khép kín: số cọc = số khoảng).
Question _fence(Timo3Generator g, int level, Random r) {
  final d = randint(r, 2, 5);
  if (level == 1) {
    final k = randint(r, 2, 4);
    final s = k * d;
    final ans = 4 * k;
    return _mk(
      g,
      level,
      r,
      qVi:
          'Một mảnh vườn hình vuông có cạnh dài $s m. Người ta cắm cọc quanh vườn, ở cả 4 góc đều có cọc, hai cọc liền nhau cách nhau $d m. Hỏi cần tất cả bao nhiêu cọc?',
      qEn:
          'A square garden has sides of $s m. Posts go all around it, one at each corner, $d m apart. How many posts are needed?',
      hVi: 'Đi quanh vườn một vòng: mỗi khoảng $d m ứng với đúng 1 cọc.',
      hEn: 'Walk once around: each $d m gap matches exactly 1 post.',
      eVi:
          'Chu vi vườn: $s × 4 = ${4 * s} (m). Số khoảng: ${4 * s} : $d = $ans. Đường đi khép kín nên số cọc bằng số khoảng: $ans cọc.',
      eEn:
          'Perimeter ${4 * s} m, ${4 * s} ÷ $d = $ans gaps. A closed loop has as many posts as gaps: $ans.',
      kw: [('post', 'cọc'), ('square', 'hình vuông')],
      ans: ans,
      wrong: [ans + 4, ans + 1],
      params: {'shape': 'square', 'side': s, 'gap': d},
    );
  }
  if (level == 2) {
    final a = randint(r, 3, 5);
    final b = randint(r, 1, a - 1);
    final len = a * d;
    final wid = b * d;
    final per = 2 * (len + wid);
    final ans = per ~/ d;
    return _mk(
      g,
      level,
      r,
      qVi:
          'Một mảnh vườn hình chữ nhật dài $len m, rộng $wid m. Người ta cắm cọc quanh vườn, ở cả 4 góc đều có cọc, hai cọc liền nhau cách nhau $d m. Hỏi cần tất cả bao nhiêu cọc?',
      qEn:
          'A rectangular garden is $len m long and $wid m wide. Posts go all around it, one at each corner, $d m apart. How many posts are needed?',
      hVi: 'Tính chu vi vườn rồi xem có bao nhiêu khoảng $d m.',
      hEn: 'Find the perimeter, then count the $d m gaps.',
      eVi:
          'Chu vi vườn: ($len + $wid) × 2 = $per (m). Số khoảng: $per : $d = $ans. Đường đi khép kín nên số cọc bằng số khoảng: $ans cọc.',
      eEn:
          'Perimeter $per m, $per ÷ $d = $ans gaps, so $ans posts on a closed loop.',
      kw: [('post', 'cọc'), ('rectangle', 'hình chữ nhật')],
      ans: ans,
      wrong: [ans + 4, ans + 1],
      params: {'shape': 'rect', 'length': len, 'width': wid, 'gap': d},
    );
  }
  final k = randint(r, 2, 5);
  final n = 4 * k;
  final ans = k * d;
  return _mk(
    g,
    level,
    r,
    qVi:
        'Quanh một mảnh vườn hình vuông người ta cắm tất cả $n cọc, ở cả 4 góc đều có cọc, hai cọc liền nhau cách nhau $d m. Hỏi cạnh mảnh vườn dài bao nhiêu mét?',
    qEn:
        '$n posts stand around a square garden, one at each corner, $d m apart. How long is one side of the garden?',
    hVi: 'Đường khép kín: $n cọc tạo thành $n khoảng.',
    hEn: 'A closed loop: $n posts make $n gaps.',
    eVi:
        '$n cọc quanh vườn tạo thành $n khoảng, chu vi: $n × $d = ${n * d} (m). Cạnh vườn: ${n * d} : 4 = $ans (m).',
    eEn: 'Perimeter $n × $d = ${n * d} m, side ${n * d} ÷ 4 = $ans m.',
    kw: [('post', 'cọc'), ('side', 'cạnh')],
    ans: ans,
    wrong: [ans - d, n],
    params: {'shape': 'inverse', 'posts': n, 'gap': d},
  );
}

/// Bốn điểm A, B, C, D theo thứ tự trên một đường thẳng.
Question _segline(Timo3Generator g, int level, Random r) {
  final x = randint(r, 2, 9);
  final y = randint(r, 2, 9);
  final z = randint(r, 2, 9);
  const kw = [('segment', 'đoạn thẳng'), ('length', 'độ dài')];
  if (level == 1) {
    final ans = x + y;
    return _mk(
      g,
      level,
      r,
      qVi:
          'Ba điểm A, B, C nằm trên một đường thẳng theo thứ tự đó. Đoạn AB dài $x cm, đoạn BC dài $y cm. Hỏi đoạn AC dài bao nhiêu xăng-ti-mét?',
      qEn:
          'Points A, B, C lie on a line in that order. AB = $x cm, BC = $y cm. How long is AC?',
      hVi: 'Vẽ đoạn thẳng rồi đánh dấu A, B, C.',
      hEn: 'Draw the line and mark A, B, C.',
      eVi: 'AC = AB + BC = $x + $y = $ans (cm).',
      eEn: 'AC = AB + BC = $x + $y = $ans cm.',
      kw: kw,
      ans: ans,
      wrong: [(x - y).abs(), ans + 1],
      params: {'ab': x, 'bc': y},
    );
  }
  final ad = x + y + z;
  if (level == 2) {
    return _mk(
      g,
      level,
      r,
      qVi:
          'Bốn điểm A, B, C, D nằm trên một đường thẳng theo thứ tự đó. Đoạn AD dài $ad cm, đoạn AB dài $x cm, đoạn CD dài $z cm. Hỏi đoạn BC dài bao nhiêu xăng-ti-mét?',
      qEn:
          'Points A, B, C, D lie on a line in that order. AD = $ad cm, AB = $x cm, CD = $z cm. How long is BC?',
      hVi: 'AD gồm ba đoạn AB, BC và CD nối liền nhau.',
      hEn: 'AD is made of AB, BC and CD.',
      eVi: 'BC = AD − AB − CD = $ad − $x − $z = $y (cm).',
      eEn: 'BC = $ad − $x − $z = $y cm.',
      kw: kw,
      ans: y,
      wrong: [ad - x, ad - z],
      params: {'ad': ad, 'ab': x, 'cd': z},
    );
  }
  final ac = x + y;
  final bd = y + z;
  return _mk(
    g,
    level,
    r,
    qVi:
        'Bốn điểm A, B, C, D nằm trên một đường thẳng theo thứ tự đó. Đoạn AC dài $ac cm, đoạn BD dài $bd cm, đoạn AD dài $ad cm. Hỏi đoạn BC dài bao nhiêu xăng-ti-mét?',
    qEn:
        'Points A, B, C, D lie on a line in that order. AC = $ac cm, BD = $bd cm, AD = $ad cm. How long is BC?',
    hVi: 'Cộng AC với BD thì đoạn BC bị tính hai lần.',
    hEn: 'In AC + BD, the part BC is counted twice.',
    eVi:
        'AC + BD = $ac + $bd = ${ac + bd} (cm), bằng AD cộng thêm một lần BC. Vậy BC = ${ac + bd} − $ad = $y (cm).',
    eEn: 'AC + BD = ${ac + bd} = AD + BC, so BC = ${ac + bd} − $ad = $y cm.',
    kw: kw,
    ans: y,
    wrong: [ac + bd, ad - y],
    params: {'ac': ac, 'bd': bd, 'ad': ad},
  );
}

/// Đổi đơn vị đo độ dài m, dm, cm.
Question _units(Timo3Generator g, int level, Random r) {
  const hVi = 'Nhớ: 1 dm = 10 cm, 1 m = 10 dm = 100 cm.';
  const hEn = 'Remember: 1 dm = 10 cm, 1 m = 10 dm = 100 cm.';
  const kw = [('decimetre', 'đề-xi-mét'), ('centimetre', 'xăng-ti-mét')];
  if (level == 1) {
    final a = randint(r, 2, 9);
    final ans = 10 * a;
    return _mk(
      g,
      level,
      r,
      qVi:
          'Một chiếc thước dài $a dm. Hỏi chiếc thước dài bao nhiêu xăng-ti-mét?',
      qEn: 'A ruler is $a dm long. How many centimetres is that?',
      hVi: hVi,
      hEn: hEn,
      eVi: '1 dm = 10 cm nên $a dm = $a × 10 = $ans (cm).',
      eEn: '$a dm = $a × 10 = $ans cm.',
      kw: kw,
      ans: ans,
      wrong: [a + 10, a * 100],
      params: {'dm': a, 'cm': 0, 'mode': 'to_cm'},
    );
  }
  final a = randint(r, 2, 8);
  final b = randint(r, 1, 9);
  final len = 10 * a + b;
  if (level == 2) {
    return _mk(
      g,
      level,
      r,
      qVi:
          'Một sợi ruy băng dài $a dm $b cm. Hỏi sợi ruy băng dài bao nhiêu xăng-ti-mét?',
      qEn: 'A ribbon is $a dm $b cm long. How many centimetres is that?',
      hVi: hVi,
      hEn: hEn,
      eVi:
          '$a dm = ${10 * a} cm, nên $a dm $b cm = ${10 * a} + $b = $len (cm).',
      eEn: '$a dm = ${10 * a} cm, so the ribbon is ${10 * a} + $b = $len cm.',
      kw: kw,
      ans: len,
      wrong: [a + b, 100 * a + b],
      params: {'dm': a, 'cm': b, 'mode': 'to_cm'},
    );
  }
  final ans = 100 - len;
  return _mk(
    g,
    level,
    r,
    qVi:
        'Một sợi dây dài 1 m. Bé cắt đi một đoạn dài $a dm $b cm. Hỏi sợi dây còn lại dài bao nhiêu xăng-ti-mét?',
    qEn:
        'A string is 1 m long. A piece $a dm $b cm long is cut off. How many centimetres are left?',
    hVi: hVi,
    hEn: hEn,
    eVi:
        '1 m = 100 cm; đoạn cắt đi dài $a dm $b cm = $len cm. Còn lại: 100 − $len = $ans (cm).',
    eEn: '1 m = 100 cm, cut $len cm, left 100 − $len = $ans cm.',
    kw: kw,
    ans: ans,
    wrong: [len, 100 - 10 * a + b],
    params: {'dm': a, 'cm': b, 'mode': 'rest_of_1m'},
  );
}

/// Cắt tờ giấy hình chữ nhật thành các hình vuông bằng nhau.
Question _cutsquares(Timo3Generator g, int level, Random r) {
  final s = level == 1 ? 1 : (level == 2 ? randint(r, 2, 3) : randint(r, 4, 5));
  final m = randint(r, 2, 5);
  var n = randint(r, 2, level == 1 ? 4 : 5);
  if (n == m) n = m == 2 ? 3 : m - 1;
  final a = m * s;
  final b = n * s;
  final ans = m * n;
  final sameMsg = s == 1 ? '' : ' (dọc chiều dài và chiều rộng)';
  return _mk(
    g,
    level,
    r,
    qVi:
        'Một tờ giấy hình chữ nhật có hai cạnh dài $a cm và $b cm. Bé cắt tờ giấy thành các hình vuông nhỏ, mỗi hình vuông có cạnh $s cm, không thừa mảnh nào. Hỏi bé được bao nhiêu hình vuông?',
    qEn:
        'A rectangular sheet is $a cm by $b cm. It is cut into small squares of side $s cm with nothing left over. How many squares are there?',
    hVi: 'Đếm xem mỗi cạnh chia được mấy đoạn $s cm$sameMsg.',
    hEn: 'Count how many $s cm pieces fit along each side.',
    eVi:
        'Cạnh $a cm chia được $a : $s = $m đoạn, cạnh $b cm chia được $b : $s = $n đoạn. Số hình vuông: $m × $n = $ans (hình).',
    eEn: '$a ÷ $s = $m and $b ÷ $s = $n, so $m × $n = $ans squares.',
    kw: [('square', 'hình vuông'), ('cut', 'cắt')],
    ans: ans,
    wrong: [m + n, 2 * (m + n)],
    params: {'a': a, 'b': b, 's': s},
  );
}

/// Đếm mặt của các khối lập phương xếp thành một hàng.
Question _cubefaces(Timo3Generator g, int level, Random r) {
  const kw = [('cube', 'khối lập phương'), ('face', 'mặt')];
  if (level == 1) {
    final n = randint(r, 2, 5);
    final ans = 6 * n;
    return _mk(
      g,
      level,
      r,
      qVi: 'Có $n khối lập phương. Hỏi tất cả có bao nhiêu mặt?',
      qEn: 'There are $n cubes. How many faces do they have in total?',
      hVi: 'Mỗi khối lập phương có 6 mặt.',
      hEn: 'A cube has 6 faces.',
      eVi: 'Mỗi khối có 6 mặt: $n × 6 = $ans (mặt).',
      eEn: '$n × 6 = $ans faces.',
      kw: kw,
      ans: ans,
      wrong: [4 * n, 8 * n],
      params: {'n': n, 'mode': 'all'},
    );
  }
  if (level == 2) {
    final n = randint(r, 2, 5);
    final ans = 3 * n + 2;
    return _mk(
      g,
      level,
      r,
      qVi:
          'Bé xếp $n khối lập phương thành một hàng thẳng trên mặt bàn, các khối áp sát nhau. Hỏi có bao nhiêu mặt của các khối không chạm vào bàn và không chạm vào khối khác?',
      qEn:
          '$n cubes stand in a straight row on a table, touching each other. How many faces touch neither the table nor another cube?',
      hVi: 'Mỗi khối lộ mặt trên, mặt trước, mặt sau; hai khối ở hai đầu lộ thêm một mặt bên.',
      hEn: 'Each cube shows its top, front and back; the two end cubes also show one side.',
      eVi:
          'Mỗi khối lộ 3 mặt (trên, trước, sau): $n × 3 = ${3 * n}. Hai đầu hàng lộ thêm 2 mặt bên: ${3 * n} + 2 = $ans (mặt).',
      eEn: '$n × 3 = ${3 * n}, plus 2 end faces: $ans.',
      kw: kw,
      ans: ans,
      wrong: [6 * n, 3 * n],
      params: {'n': n, 'mode': 'on_table'},
    );
  }
  final n = randint(r, 3, 6);
  final ans = 4 * n + 2;
  return _mk(
    g,
    level,
    r,
    qVi:
        'Bé dán $n khối lập phương thành một thanh thẳng rồi sơn toàn bộ mặt ngoài của thanh (cả mặt dưới). Hỏi có bao nhiêu mặt của các khối nhỏ được sơn?',
    qEn:
        '$n cubes are glued into a straight bar and the whole outside is painted (bottom too). How many small faces are painted?',
    hVi: 'Mỗi khối có 4 mặt quanh thân thanh; hai khối ở hai đầu có thêm mặt đầu.',
    hEn: 'Each cube has 4 faces around the bar; the end cubes add one face each.',
    eVi:
        'Quanh thân thanh mỗi khối có 4 mặt được sơn: $n × 4 = ${4 * n}. Thêm 2 mặt ở hai đầu: ${4 * n} + 2 = $ans (mặt).',
    eEn: '$n × 4 = ${4 * n}, plus 2 end faces: $ans.',
    kw: kw,
    ans: ans,
    wrong: [6 * n, 4 * n],
    params: {'n': n, 'mode': 'bar'},
  );
}

/// Chu vi thay đổi khi kéo dài hoặc thu ngắn cạnh.
Question _perimchange(Timo3Generator g, int level, Random r) {
  const kw = [('perimeter', 'chu vi'), ('increase', 'tăng')];
  if (level == 1) {
    final a = randint(r, 3, 9);
    final b = randint(r, 1, 5);
    final ans = 4 * b;
    return _mk(
      g,
      level,
      r,
      qVi:
          'Một hình vuông có cạnh $a cm. Nếu mỗi cạnh dài thêm $b cm thì chu vi hình vuông tăng thêm bao nhiêu xăng-ti-mét?',
      qEn:
          'A square has sides of $a cm. If every side grows by $b cm, by how much does the perimeter grow?',
      hVi: 'Hình vuông có 4 cạnh, cạnh nào cũng dài thêm.',
      hEn: 'A square has 4 sides, and each one grows.',
      eVi:
          'Bốn cạnh, mỗi cạnh dài thêm $b cm nên chu vi tăng: $b × 4 = $ans (cm). (Kiểm: ${4 * (a + b)} − ${4 * a} = $ans.)',
      eEn: '4 sides each grow $b cm: $b × 4 = $ans cm.',
      kw: kw,
      ans: ans,
      wrong: [b, 2 * b],
      params: {'side': a, 'grow': b, 'shrink': 0, 'mode': 'square'},
    );
  }
  final w = randint(r, 4, 9);
  final l = w + randint(r, 2, 9);
  if (level == 2) {
    final b = randint(r, 1, 6);
    final ans = 2 * b;
    return _mk(
      g,
      level,
      r,
      qVi:
          'Một hình chữ nhật dài $l cm, rộng $w cm. Nếu chỉ kéo dài chiều dài thêm $b cm, giữ nguyên chiều rộng, thì chu vi tăng thêm bao nhiêu xăng-ti-mét?',
      qEn:
          'A rectangle is $l cm by $w cm. If only the length grows by $b cm, by how much does the perimeter grow?',
      hVi: 'Hình chữ nhật có 2 chiều dài.',
      hEn: 'A rectangle has 2 lengths.',
      eVi:
          'Hai chiều dài, mỗi chiều dài thêm $b cm nên chu vi tăng: $b × 2 = $ans (cm).',
      eEn: 'Two lengths each grow $b cm: $ans cm.',
      kw: kw,
      ans: ans,
      wrong: [b, 4 * b],
      params: {'length': l, 'width': w, 'grow': b, 'shrink': 0, 'mode': 'rect'},
    );
  }
  final c = randint(r, 1, 3);
  final b = c + randint(r, 1, 5);
  final ans = 2 * (b - c);
  return _mk(
    g,
    level,
    r,
    qVi:
        'Một hình chữ nhật dài $l cm, rộng $w cm. Nếu kéo dài chiều dài thêm $b cm và bớt chiều rộng đi $c cm thì chu vi tăng thêm bao nhiêu xăng-ti-mét?',
    qEn:
        'A rectangle is $l cm by $w cm. The length grows by $b cm and the width shrinks by $c cm. By how much does the perimeter grow?',
    hVi: 'Nửa chu vi là chiều dài cộng chiều rộng. Nửa chu vi đổi thế nào?',
    hEn: 'Half the perimeter is length + width. How does it change?',
    eVi:
        'Nửa chu vi tăng $b − $c = ${b - c} (cm), nên chu vi tăng: ${b - c} × 2 = $ans (cm).',
    eEn: 'Half-perimeter grows $b − $c = ${b - c} cm, perimeter grows $ans cm.',
    kw: kw,
    ans: ans,
    wrong: [b - c, 2 * (b + c)],
    params: {'length': l, 'width': w, 'grow': b, 'shrink': c, 'mode': 'rect'},
  );
}

// ============================================================ TƯ DUY LÔGIC

/// Xem giờ trên đồng hồ 12 giờ.
Question _clock(Timo3Generator g, int level, Random r) {
  late int h;
  late int k;
  late bool back;
  if (level == 1) {
    h = randint(r, 1, 8);
    k = randint(r, 2, 12 - h);
    back = false;
  } else if (level == 2) {
    h = randint(r, 8, 11);
    k = randint(r, 13 - h, 20 - h);
    back = false;
  } else {
    h = randint(r, 1, 5);
    k = randint(r, h + 1, h + 8);
    back = true;
  }
  final raw = back ? h - k : h + k;
  final ans = ((raw - 1) % 12 + 12) % 12 + 1;
  final eVi = back
      ? '$k giờ trước $h giờ: lùi qua 12 giờ. $h + 12 − $k = $ans, vậy lúc đó là $ans giờ.'
      : (h + k > 12
            ? '$h + $k = ${h + k}; quá 12 giờ thì bớt 12: ${h + k} − 12 = $ans, vậy là $ans giờ.'
            : '$h + $k = $ans, vậy là $ans giờ.');
  return _mk(
    g,
    level,
    r,
    qVi: back
        ? 'Đồng hồ đang chỉ $h giờ đúng. Hỏi $k giờ trước, đồng hồ chỉ mấy giờ?'
        : 'Đồng hồ đang chỉ $h giờ đúng. Hỏi $k giờ nữa, đồng hồ chỉ mấy giờ?',
    qEn: back
        ? "The clock shows $h o'clock. What did it show $k hours ago?"
        : "The clock shows $h o'clock. What will it show in $k hours?",
    hVi: 'Kim giờ chạy hết một vòng là 12 giờ rồi quay lại.',
    hEn: 'The hour hand goes round 12 hours and starts again.',
    eVi: eVi,
    eEn: back
        ? '$h + 12 − $k = $ans o\'clock.'
        : '${h + k > 12 ? '${h + k} − 12' : '$h + $k'} = $ans o\'clock.',
    kw: [('clock', 'đồng hồ'), ("o'clock", 'giờ')],
    ans: ans,
    wrong: back
        ? [k - h, h + k]
        : [h + k, (h + k) % 10 == 0 ? 1 : (h + k) % 10],
    params: {'hour': h, 'shift': k, 'back': back},
  );
}

const _monthDays = {
  1: 31,
  3: 31,
  4: 30,
  5: 31,
  6: 30,
  7: 31,
  8: 31,
  9: 30,
  10: 31,
  11: 30,
};

/// Ngày tháng trên lịch.
Question _calendar(Timo3Generator g, int level, Random r) {
  final m = pickOne(r, _monthDays.keys.toList());
  final len = _monthDays[m]!;
  const kw = [('date', 'ngày'), ('month', 'tháng')];
  if (level == 1) {
    final d = randint(r, 1, 15);
    final k = randint(r, 3, 12);
    final ans = d + k;
    return _mk(
      g,
      level,
      r,
      qVi:
          'Hôm nay là ngày $d tháng $m. Hỏi $k ngày nữa là ngày bao nhiêu tháng $m?',
      qEn:
          'Today is day $d of month $m. What day of month $m is it $k days later?',
      hVi: 'Đếm tiếp $k ngày từ ngày $d.',
      hEn: 'Count on $k days from day $d.',
      eVi: '$d + $k = $ans, vậy là ngày $ans tháng $m.',
      eEn: '$d + $k = $ans.',
      kw: kw,
      ans: ans,
      wrong: [ans - 1, ans + 1],
      params: {'month': m, 'day': d, 'after': k, 'mode': 'same'},
    );
  }
  if (level == 2) {
    final d = randint(r, len - 5, len);
    final k = randint(r, len - d + 1, len - d + 12);
    final ans = d + k - len;
    return _mk(
      g,
      level,
      r,
      qVi:
          'Tháng $m có $len ngày. Hôm nay là ngày $d tháng $m. Hỏi $k ngày nữa là ngày bao nhiêu tháng ${m + 1}?',
      qEn:
          'Month $m has $len days. Today is day $d of month $m. What day of month ${m + 1} is it $k days later?',
      hVi: 'Đếm đến hết tháng $m trước, rồi đếm tiếp sang tháng ${m + 1}.',
      hEn: 'Count to the end of month $m first, then go on.',
      eVi:
          'Từ ngày $d đến hết tháng $m còn ${len - d} ngày. Còn lại $k − ${len - d} = $ans ngày sang tháng ${m + 1}, nên là ngày $ans tháng ${m + 1}.',
      eEn: '$d + $k − $len = $ans.',
      kw: kw,
      ans: ans,
      wrong: [d + k - 30 == ans ? d + k - 31 : d + k - 30, ans + 1],
      params: {'month': m, 'day': d, 'after': k, 'mode': 'next'},
    );
  }
  final d = randint(r, 15, len - 2);
  final d2 = randint(r, 1, 10);
  final ans = len - d + d2;
  return _mk(
    g,
    level,
    r,
    qVi:
        'Tháng $m có $len ngày. Hôm nay là ngày $d tháng $m. Hỏi còn bao nhiêu ngày nữa thì đến ngày $d2 tháng ${m + 1}?',
    qEn:
        'Month $m has $len days. Today is day $d of month $m. How many days until day $d2 of month ${m + 1}?',
    hVi: 'Đếm số ngày đến hết tháng $m, rồi cộng thêm số ngày sang tháng sau.',
    hEn: 'Count to the end of the month, then add the days in the next month.',
    eVi:
        'Đến hết tháng $m còn $len − $d = ${len - d} ngày, sang tháng ${m + 1} thêm $d2 ngày: ${len - d} + $d2 = $ans (ngày).',
    eEn: '($len − $d) + $d2 = $ans days.',
    kw: kw,
    ans: ans,
    wrong: [ans - 1, ans + 1],
    params: {'month': m, 'day': d, 'day2': d2, 'mode': 'until'},
  );
}

// ================================================================== SỐ HỌC

/// Tổng và hiệu thay đổi khi thêm bớt các số hạng.
Question _sametotal(Timo3Generator g, int level, Random r) {
  const kw = [('sum', 'tổng'), ('difference', 'hiệu')];
  if (level == 1) {
    final s = randint(r, 20, 60);
    final a = randint(r, 2, 9);
    final ans = s + a;
    return _mk(
      g,
      level,
      r,
      qVi:
          'Tổng của hai số là $s. Nếu thêm vào số thứ nhất $a đơn vị và giữ nguyên số thứ hai thì tổng mới là bao nhiêu?',
      qEn:
          'Two numbers add up to $s. If the first grows by $a and the second stays the same, what is the new sum?',
      hVi: 'Một số hạng tăng bao nhiêu thì tổng tăng bấy nhiêu.',
      hEn: 'When one addend grows, the sum grows by the same amount.',
      eVi: 'Tổng tăng thêm $a: $s + $a = $ans.',
      eEn: '$s + $a = $ans.',
      kw: kw,
      ans: ans,
      wrong: [s, s - a],
      params: {'value': s, 'up': a, 'down': 0, 'mode': 'sum'},
    );
  }
  if (level == 2) {
    final s = randint(r, 30, 80);
    final a = randint(r, 2, 9);
    var b = randint(r, 2, 9);
    if (b == a) b = a == 9 ? 2 : a + 1;
    final ans = s + a - b;
    return _mk(
      g,
      level,
      r,
      qVi:
          'Tổng của hai số là $s. Nếu thêm vào số thứ nhất $a đơn vị và bớt ở số thứ hai $b đơn vị thì tổng mới là bao nhiêu?',
      qEn:
          'Two numbers add up to $s. The first grows by $a and the second shrinks by $b. What is the new sum?',
      hVi: 'Tổng tăng theo số thêm vào, giảm theo số bớt đi.',
      hEn: 'The sum goes up by what is added and down by what is taken.',
      eVi: 'Tổng mới: $s + $a − $b = $ans.',
      eEn: '$s + $a − $b = $ans.',
      kw: kw,
      ans: ans,
      wrong: [s + a + b, s - a + b],
      params: {'value': s, 'up': a, 'down': b, 'mode': 'sum'},
    );
  }
  final d = randint(r, 10, 50);
  final a = randint(r, 2, 9);
  final b = randint(r, 2, 9);
  final ans = d + a + b;
  return _mk(
    g,
    level,
    r,
    qVi:
        'Hiệu của hai số là $d. Nếu thêm vào số bị trừ $a đơn vị và bớt ở số trừ $b đơn vị thì hiệu mới là bao nhiêu?',
    qEn:
        'The difference of two numbers is $d. The larger grows by $a and the smaller shrinks by $b. What is the new difference?',
    hVi: 'Số trừ nhỏ đi thì hiệu lớn lên.',
    hEn: 'A smaller number taken away makes a bigger difference.',
    eVi:
        'Số bị trừ tăng $a làm hiệu tăng $a; số trừ giảm $b cũng làm hiệu tăng $b. Hiệu mới: $d + $a + $b = $ans.',
    eEn: '$d + $a + $b = $ans.',
    kw: kw,
    ans: ans,
    wrong: [d + a - b, d - a + b],
    params: {'value': d, 'up': a, 'down': b, 'mode': 'diff'},
  );
}

/// Phép cộng hai số có hai chữ số bị che chữ số.
Question _missingdigits(Timo3Generator g, int level, Random r) {
  const kw = [('missing digit', 'chữ số bị che'), ('addition', 'phép cộng')];
  if (level == 1) {
    final a = randint(r, 1, 6);
    final u = randint(r, 0, 9);
    final second = randint(r, 11, 99 - 10 * a - u);
    final t = 10 * a + u + second;
    return _mk(
      g,
      level,
      r,
      qVi: 'Tìm chữ số ở ô trống: □$u + $second = $t.',
      qEn: 'Find the missing digit: □$u + $second = $t.',
      hVi: 'Lấy $t trừ $second để tìm số hạng thứ nhất.',
      hEn: 'Work out $t − $second first.',
      eVi:
          'Số hạng thứ nhất: $t − $second = ${10 * a + u}, nên chữ số ở ô trống là $a.',
      eEn: '$t − $second = ${10 * a + u}, so the digit is $a.',
      kw: kw,
      ans: a,
      wrong: [a + 1, (t ~/ 10) - (second ~/ 10)],
      params: {'u': u, 'second': second, 'total': t, 'mode': 'one'},
    );
  }
  // Hai chữ số bị che: □u + v○ = t. Mức 2 không nhớ, mức 3 có nhớ.
  late int a, u, v, b;
  while (true) {
    a = randint(r, 1, 5);
    v = randint(r, 1, 4);
    u = randint(r, 1, 9);
    b = randint(r, 0, 9);
    final carry = u + b >= 10;
    if (carry != (level == 3)) continue;
    if (10 * a + u + 10 * v + b > 99) continue;
    break;
  }
  final t = 10 * a + u + 10 * v + b;
  final ans = a + b;
  return _mk(
    g,
    level,
    r,
    qVi:
        'Cho phép cộng: □$u + $v○ = $t. Tìm hai chữ số ở ô vuông và ô tròn rồi tính tổng của chúng.',
    qEn: 'In □$u + $v○ = $t, find the two missing digits and add them.',
    hVi: level == 3
        ? 'Hàng đơn vị: $u + ○ có tận cùng là ${t % 10}, nhớ 1 sang hàng chục.'
        : 'Hàng đơn vị: $u + ○ = ${t % 10}.',
    hEn: 'Look at the ones column first.',
    eVi: level == 3
        ? 'Hàng đơn vị: $u + $b = ${u + b}, viết ${t % 10} nhớ 1, nên ○ = $b. Hàng chục: □ + $v + 1 = ${t ~/ 10}, nên □ = $a. Tổng: $a + $b = $ans.'
        : 'Hàng đơn vị: $u + $b = ${t % 10}, nên ○ = $b. Hàng chục: □ + $v = ${t ~/ 10}, nên □ = $a. Tổng: $a + $b = $ans.',
    eEn: '□ = $a, ○ = $b, sum $ans.',
    kw: kw,
    ans: ans,
    wrong: level == 3 ? [a + 1 + b, ans + 10] : [ans + 1, (t % 10) + (t ~/ 10)],
    params: {'u': u, 'v': v, 'total': t, 'mode': 'two'},
  );
}

// =========================================================== LÝ THUYẾT SỐ

/// Đếm số nằm giữa hai số.
Question _between(Timo3Generator g, int level, Random r) {
  late int a, b;
  late String kindVi, kindEn;
  if (level == 1) {
    a = randint(r, 10, 80);
    b = a + randint(r, 3, 12);
    kindVi = 'số';
    kindEn = 'numbers';
  } else if (level == 2) {
    a = randint(r, 10, 70);
    b = a + randint(r, 6, 20);
    kindVi = 'số chẵn';
    kindEn = 'even numbers';
  } else {
    a = randint(r, 5, 40);
    b = randint(r, a + 25, 99);
    kindVi = 'số tròn chục';
    kindEn = 'multiples of 10';
  }
  final nums = [
    for (var x = a + 1; x < b; x++)
      if (level == 1 || (level == 2 && x.isEven) || (level == 3 && x % 10 == 0))
        x,
  ];
  final ans = nums.length;
  final listed = nums.length <= 12
      ? nums.join(', ')
      : '${nums.take(3).join(', ')}, ..., ${nums.last}';
  return _mk(
    g,
    level,
    r,
    qVi: 'Có bao nhiêu $kindVi lớn hơn $a và nhỏ hơn $b?',
    qEn: 'How many $kindEn are greater than $a and less than $b?',
    hVi: 'Không tính $a và $b. Viết các số ra rồi đếm.',
    hEn: 'Do not count $a or $b. Write them out and count.',
    eVi: 'Các $kindVi đó là: $listed. Có tất cả $ans số.',
    eEn: 'They are: $listed. That is $ans.',
    kw: [('greater than', 'lớn hơn'), ('less than', 'nhỏ hơn')],
    ans: ans,
    wrong: [ans + 1, ans + 2],
    params: {
      'lo': a,
      'hi': b,
      'kind': ['all', 'even', 'tens'][level - 1],
    },
  );
}

// ================================================================= TỔ HỢP

/// Gieo hai con xúc xắc khác màu.
Question _dice(Timo3Generator g, int level, Random r) {
  final s = switch (level) {
    1 => randint(r, 3, 5),
    2 => randint(r, 6, 8),
    _ => randint(r, 9, 11),
  };
  final atLeast = level == 3;
  final pairs = <String>[];
  for (var x = 1; x <= 6; x++) {
    for (var y = 1; y <= 6; y++) {
      if (atLeast ? x + y >= s : x + y == s) pairs.add('($x, $y)');
    }
  }
  final ans = pairs.length;
  return _mk(
    g,
    level,
    r,
    qVi: atLeast
        ? 'Gieo cùng lúc một con xúc xắc xanh và một con xúc xắc đỏ. Hỏi có bao nhiêu cách để tổng số chấm của hai con từ $s trở lên? (Xanh 5, đỏ 6 khác với xanh 6, đỏ 5.)'
        : 'Gieo cùng lúc một con xúc xắc xanh và một con xúc xắc đỏ. Hỏi có bao nhiêu cách để tổng số chấm của hai con bằng $s? (Xanh 1, đỏ 2 khác với xanh 2, đỏ 1.)',
    qEn: atLeast
        ? 'A blue die and a red die are rolled. In how many ways is the total at least $s? (Blue 5, red 6 differs from blue 6, red 5.)'
        : 'A blue die and a red die are rolled. In how many ways is the total exactly $s? (Blue 1, red 2 differs from blue 2, red 1.)',
    hVi: 'Lần lượt cho xúc xắc xanh ra 1, 2, ..., 6 rồi xem xúc xắc đỏ phải ra mấy.',
    hEn: 'Try blue = 1, 2, ..., 6 and see what red must be.',
    eVi: 'Các cặp (xanh, đỏ): ${pairs.join(', ')}. Có $ans cách.',
    eEn: 'Pairs (blue, red): ${pairs.join(', ')}. $ans ways.',
    kw: [('dice', 'xúc xắc'), ('ways', 'cách')],
    ans: ans,
    wrong: [(ans + 1) ~/ 2, ans + 1],
    params: {'s': s, 'atLeast': atLeast},
  );
}

const List<QuestionGenerator> timo3LogicGenerators = [
  Timo3Generator('logic.clock', 'logic', _clock),
  Timo3Generator('logic.calendar', 'logic', _calendar),
];

const List<QuestionGenerator> timo3ArithGenerators = [
  Timo3Generator('arith.sametotal', 'arith', _sametotal),
  Timo3Generator('arith.missingdigits', 'arith', _missingdigits),
];

const List<QuestionGenerator> timo3NumberGenerators = [
  Timo3Generator('number.between', 'number', _between),
];

const List<QuestionGenerator> timo3GeoGenerators = [
  Timo3Generator('geo.fence', 'geo', _fence),
  Timo3Generator('geo.segline', 'geo', _segline),
  Timo3Generator('geo.units', 'geo', _units),
  Timo3Generator('geo.cutsquares', 'geo', _cutsquares),
  Timo3Generator('geo.cubefaces', 'geo', _cubefaces),
  Timo3Generator('geo.perimchange', 'geo', _perimchange),
];

const List<QuestionGenerator> timo3CombGenerators = [
  Timo3Generator('comb.dice', 'comb', _dice),
];
