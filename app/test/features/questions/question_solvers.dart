import 'package:timokid/features/questions/question.dart';

/// Hàm giải độc lập cho test nghiệm thu T1-05.
///
/// Mỗi hàm tính lại đáp án từ các tham số của câu hỏi ([Question.params])
/// bằng công thức viết riêng ở đây — không gọi code sinh câu, không đọc
/// [Question.answer]. Với câu trắc nghiệm, hàm trả về chỉ số của lựa chọn
/// đúng (tìm bằng cách so khớp cả VI và EN), không phải giá trị đáp án.

int _pInt(Question q, String key) => q.params[key] as int;

bool _pBool(Question q, String key) => q.params[key] as bool;

List<int> _pInts(Question q, String key) => (q.params[key] as List).cast<int>();

List<String> _pStrings(Question q, String key) =>
    (q.params[key] as List).cast<String>();

/// Giải độc lập một câu hỏi, trả về đáp án kỳ vọng:
/// - câu điền số: giá trị đáp án.
/// - câu trắc nghiệm: chỉ số của lựa chọn đúng trong [Question.choices].
int solveQuestion(Question q) {
  switch (q.formId) {
    case 'logic.age':
      return _solveAge(q);
    case 'logic.queue':
      return _solveQueue(q);
    case 'logic.balance':
      return _solveBalance(q);
    case 'logic.backward':
      return _solveBackward(q);
    case 'logic.weekday':
      return _solveWeekday(q);
    case 'logic.cut':
      return q.difficulty == 1
          ? _pInt(q, 'n') - 1
          : (_pInt(q, 'n') - 1) * _pInt(q, 't');
    case 'logic.stairs':
      return (_pInt(q, 'f') - 1) * _pInt(q, 'k');
    case 'logic.trees':
      return _pInt(q, 'length') ~/ _pInt(q, 'd') + 1;
    case 'logic.legs':
      return _solveLegs(q);
    case 'logic.compare':
      return _solveCompare(q);
    case 'logic.equalize':
      return _pInt(q, 'a') - 2 * _pInt(q, 'b');
    case 'arith.pattern':
      return _solvePattern(q);
    case 'arith.quick':
      return _solveQuick(q);
    case 'arith.blank':
      return _solveBlank(q);
    case 'arith.symbols':
      return _solveSymbols(q);
    case 'arith.word':
      return _solveWord(q);
    case 'arith.multiply':
      return _solveMultiply(q);
    case 'arith.money':
      return _pInt(q, 'paid') - _pInt(q, 'p') * _pInt(q, 'k');
    case 'number.parity':
      return _solveParity(q);
    case 'number.digitsum':
      return _solveDigitSum(q);
    case 'number.cards':
      return _solveCards(q);
    case 'number.digitcount':
      return _solveDigitCount(q);
    case 'number.digitfreq':
      return _solveDigitFreq(q);
    case 'number.clues':
      return _solveClues(q);
    case 'number.round':
      return _solveRound(q);
    case 'number.place':
      return (_pInt(q, 't') + _pInt(q, 'extra')) * 10 + _pInt(q, 'o');
    case 'number.fixed':
      return _solveFixed(q);
    case 'number.parityrule':
      return _solveParityRule(q);
    case 'geo.countsq':
      return _solveCountSq(q);
    case 'geo.countrect':
      final n = _pInt(q, 'n');
      return n * (n + 1) ~/ 2;
    case 'geo.counttri':
      final k = _pInt(q, 'k');
      return (k + 2) * (k + 1) ~/ 2;
    case 'geo.perim':
      return _solvePerim(q);
    case 'geo.matches':
      return _solveMatches(q);
    case 'geo.sides':
      return 3 * _pInt(q, 'a') + 4 * _pInt(q, 'b');
    case 'geo.cubes':
      return _solveCubes(q);
    case 'geo.shapeperim':
      final k = _pInt(q, 'k');
      final s = _pInt(q, 's');
      return 2 * (k * s + s);
    case 'geo.cutpaper':
      return _pInt(q, 'n') + 1;
    case 'comb.outfit':
      return _solveOutfit(q);
    case 'comb.handshake':
      final n = _pInt(q, 'n');
      return n * (n - 1) ~/ 2;
    case 'comb.tournament':
      final n = _pInt(q, 'n');
      return n * (n - 1) ~/ 2;
    case 'comb.makenum':
      return _solveMakeNum(q);
    case 'comb.routes':
      return _solveRoutes(q);
    case 'comb.pigeon':
      return _solvePigeon(q);
    case 'comb.arrange':
      return _solveArrange(q);
    case 'comb.choose2':
      final n = _pInt(q, 'n');
      return n * (n - 1) ~/ 2;
    case 'comb.gridpath':
      return _solveGridPath(q);
    case 'comb.split':
      return _solveSplit(q);
    case 'comb.coins':
      return _solveCoins();
    default:
      throw StateError('Chưa có hàm giải độc lập cho ${q.formId}');
  }
}

// ------------------------------------------------------------------- logic

int _solveAge(Question q) {
  switch (q.difficulty) {
    case 1:
      return _pInt(q, 'a') + _pInt(q, 'd');
    case 2:
      return _pInt(q, 'c') - _pInt(q, 'gap');
    default:
      return _pInt(q, 'k');
  }
}

int _solveQueue(Question q) {
  if (q.difficulty == 3) {
    return _pInt(q, 'a') + _pInt(q, 'k') + _pInt(q, 'b');
  }
  if (_pInt(q, 'variant') == 0) {
    return _pInt(q, 'a') + _pInt(q, 'b') - 1;
  }
  return _pInt(q, 'n') - _pInt(q, 'a') + 1;
}

int _solveBalance(Question q) {
  return _pInt(q, 'r') *
      _pInt(q, 'p') *
      (q.difficulty == 1 ? 1 : _pInt(q, 'q'));
}

int _solveBackward(Question q) {
  switch (q.difficulty) {
    case 1:
      return _pInt(q, 'b') - _pInt(q, 'a');
    case 2:
      return _pInt(q, 'c') + _pInt(q, 'b') - _pInt(q, 'a');
    default:
      if (_pInt(q, 'variant') == 0) {
        return (_pInt(q, 'c') - _pInt(q, 'a')) ~/ 2;
      }
      return _pInt(q, 'c') ~/ 2 - _pInt(q, 'a');
  }
}

int _solveWeekday(Question q) {
  final ansDay = (_pInt(q, 'start') + _pInt(q, 'plus')) % 7;
  final index = q.choices.indexWhere(
    (c) => c.vi == daysVi[ansDay] && c.en == daysEn[ansDay],
  );
  if (index < 0) {
    throw StateError('Không tìm thấy thứ đúng trong các lựa chọn');
  }
  return index;
}

int _solveLegs(Question q) {
  if (q.difficulty == 1) {
    return 2 * _pInt(q, 'a') + 4 * _pInt(q, 'b');
  }
  return (_pInt(q, 'legs') - 2 * _pInt(q, 'n')) ~/ 2;
}

int _solveCompare(Question q) {
  final people = _pStrings(q, 'people');
  final ansName = _pBool(q, 'askTall') ? people.first : people.last;
  final index = q.choices.indexWhere((c) => c.vi == ansName && c.en == ansName);
  if (index < 0) {
    throw StateError('Không tìm thấy tên đúng trong các lựa chọn');
  }
  return index;
}

// ------------------------------------------------------------------- arith

int _solvePattern(Question q) {
  final seq = _pInts(q, 'seq');
  if (q.difficulty == 1) {
    return seq.last + _pInt(q, 'd');
  }
  if (q.difficulty == 2) {
    final hide = _pInt(q, 'hide');
    return seq[hide - 1] - _pInt(q, 'd');
  }
  if (_pInt(q, 'variant') == 0) {
    return seq.last + _pInt(q, 'd0') + 5;
  }
  return _pInt(q, 'a') + 3;
}

int _solveQuick(Question q) {
  if (q.difficulty == 1) {
    // k số v cộng lại.
    return _pInt(q, 'k') * _pInt(q, 'v');
  }
  final terms = _pInts(q, 'terms');
  return terms.reduce((a, b) => a + b);
}

int _solveBlank(Question q) {
  switch (q.difficulty) {
    case 1:
      // □ + a = x + a  =>  □ = (x + a) − a
      return _pInt(q, 'x') + _pInt(q, 'a') - _pInt(q, 'a');
    case 2:
      return _pInt(q, 'c') + _pInt(q, 'b') - _pInt(q, 'a');
    default:
      return _pInt(q, 'a') + _pInt(q, 'b') - _pInt(q, 'c');
  }
}

int _solveSymbols(Question q) {
  if (q.difficulty == 2) {
    return _pInt(q, 't') - _pInt(q, 's');
  }
  // ★ = s; ▲ = (tri + s) − s = tri; ● = (ci + tri) − tri = ci.
  final tri = _pInt(q, 'tri') + _pInt(q, 's') - _pInt(q, 's');
  return _pInt(q, 'ci') + tri - tri;
}

int _solveWord(Question q) {
  switch (q.difficulty) {
    case 1:
      return _pInt(q, 'a') + _pInt(q, 'b');
    case 2:
      return 2 * _pInt(q, 'a') - _pInt(q, 'b');
    default:
      return (_pInt(q, 's') - _pInt(q, 'd')) ~/ 2;
  }
}

int _solveMultiply(Question q) {
  switch (q.difficulty) {
    case 1:
      return _pInt(q, 'b') * _pInt(q, 'k');
    case 2:
      return _pInt(q, 'tot') ~/ _pInt(q, 'p');
    default:
      return _pInt(q, 't') * _pInt(q, 'c') - _pInt(q, 'broken');
  }
}

// ------------------------------------------------------------------ number

int _solveParity(Question q) {
  final a = _pInt(q, 'a');
  final b = _pInt(q, 'b');
  final parity = _pBool(q, 'odd') ? 1 : 0;
  var cnt = 0;
  for (var v = a; v <= b; v++) {
    if (v % 2 == parity) cnt++;
  }
  return cnt;
}

int _solveDigitSum(Question q) {
  final k = _pInt(q, 'k');
  var cnt = 0;
  for (var v = 10; v <= 99; v++) {
    if (v ~/ 10 + v % 10 == k) cnt++;
  }
  return cnt;
}

int _solveCards(Question q) {
  final ds = _pInts(q, 'ds');
  if (q.difficulty == 1) {
    final sorted = List<int>.of(ds)..sort((a, b) => b.compareTo(a));
    return sorted[0] * 10 + sorted[1];
  }
  if (q.difficulty == 2) {
    // Số nhỏ nhất có 3 chữ số: chữ số khác 0 nhỏ nhất đứng đầu, rồi 0,
    // rồi chữ số còn lại.
    final nonZero = ds.where((d) => d != 0).toList()..sort();
    final first = nonZero.first;
    final rest = ds.where((d) => d != first).toList()..sort();
    return first * 100 + rest[0] * 10 + rest[1];
  }
  // Mức 3: hiệu của số lớn nhất và số nhỏ nhất lập được từ 2 thẻ.
  var mx = -1;
  var mn = 100;
  for (final a in ds) {
    for (final b in ds) {
      if (a == b) continue;
      final v = a * 10 + b;
      if (v > mx) mx = v;
      if (v < mn) mn = v;
    }
  }
  return mx - mn;
}

int _solveDigitCount(Question q) {
  final n = _pInt(q, 'n');
  var tot = 0;
  for (var v = 1; v <= n; v++) {
    tot += '$v'.length;
  }
  return tot;
}

int _solveDigitFreq(Question q) {
  final n = _pInt(q, 'n');
  final d = _pInt(q, 'd');
  var c = 0;
  for (var v = 1; v <= n; v++) {
    for (final ch in '$v'.split('')) {
      if (ch == '$d') c++;
    }
  }
  return c;
}

int _solveClues(Question q) {
  if (q.difficulty == 2) {
    final s = _pInt(q, 's');
    final d = _pInt(q, 'd');
    final tens = (s + d) ~/ 2;
    final ones = s - tens;
    if (tens - ones != d) {
      throw StateError('Cặp (s, d) không cho ra số hợp lệ');
    }
    return tens * 10 + ones;
  }
  final lo = _pInt(q, 'lo');
  final s = _pInt(q, 's');
  final sol = <int>[];
  for (var v = 10; v <= 99; v++) {
    if (v ~/ 10 + v % 10 == s && v % 2 == 1 && v > lo && v ~/ 10 > v % 10) {
      sol.add(v);
    }
  }
  if (sol.length != 1) {
    throw StateError('Mức 3 clues phải có đúng một nghiệm, có ${sol.length}');
  }
  return sol.single;
}

int _solveRound(Question q) {
  final a = _pInt(q, 'a');
  final b = _pInt(q, 'b');
  var cnt = 0;
  for (var v = a; v <= b; v++) {
    if (v % 10 == 0) cnt++;
  }
  return cnt;
}

int _solveFixed(Question q) {
  // Bảng đáp án viết riêng, theo đúng 6 câu cố định của gen.py.
  const answers = [98, 19, 90, 9, 45, 36];
  return answers[_pInt(q, 'variant')];
}

int _solveParityRule(Question q) {
  final expected = _pInt(q, 'variant') == 0
      ? const Choice(vi: 'Số lẻ', en: 'Odd')
      : const Choice(vi: 'Số chẵn', en: 'Even');
  final index = q.choices.indexWhere(
    (c) => c.vi == expected.vi && c.en == expected.en,
  );
  if (index < 0) {
    throw StateError('Không tìm thấy lựa chọn đúng cho parityrule');
  }
  return index;
}

// --------------------------------------------------------------------- geo

int _solveCountSq(Question q) {
  final rows = _pInt(q, 'rows');
  final cols = _pInt(q, 'cols');
  var n = 0;
  final m = rows < cols ? rows : cols;
  for (var size = 1; size <= m; size++) {
    n += (rows - size + 1) * (cols - size + 1);
  }
  return n;
}

int _solvePerim(Question q) {
  if (q.difficulty == 1) {
    if (_pInt(q, 'variant') == 0) {
      return 4 * _pInt(q, 'a');
    }
    return 2 * (_pInt(q, 'l') + _pInt(q, 'w'));
  }
  if (q.difficulty == 2) {
    // Chu vi 4a => cạnh a.
    return 4 * _pInt(q, 'a') ~/ 4;
  }
  return _pInt(q, 'perim') ~/ 2 - _pInt(q, 'l');
}

int _solveMatches(Question q) {
  final n = _pInt(q, 'n');
  switch (_pInt(q, 'variant')) {
    case 0:
      return 3 * n + 1;
    case 1:
      return 2 * n + 1;
    default:
      return 5 * n + 2;
  }
}

int _solveCubes(Question q) {
  if (_pInt(q, 'variant') == 1) {
    return 1 + 4 + 9;
  }
  final n = _pInt(q, 'n');
  final k = _pInt(q, 'k');
  var tot = 0;
  for (var i = 0; i < n; i++) {
    tot += 1 + k * i;
  }
  return tot;
}

// -------------------------------------------------------------------- comb

int _solveOutfit(Question q) {
  if (q.difficulty == 1) {
    return _pInt(q, 'a') * _pInt(q, 'b');
  }
  return _pInt(q, 'a') * _pInt(q, 'b') * _pInt(q, 'c');
}

int _solveMakeNum(Question q) {
  final ds = _pInts(q, 'ds');
  if (q.difficulty == 2) {
    var cnt = 0;
    for (final a in ds) {
      for (final b in ds) {
        if (a != b) cnt++;
      }
    }
    return cnt;
  }
  if (_pInt(q, 'variant') == 0) {
    var cnt = 0;
    for (final a in ds) {
      for (final b in ds) {
        if (a != 0 && a != b) cnt++;
      }
    }
    return cnt;
  }
  // Lặp lại chữ số được: 3 × 3.
  return ds.length * ds.length;
}

int _solveRoutes(Question q) {
  if (q.difficulty == 1) {
    return _pInt(q, 'a') * _pInt(q, 'b');
  }
  return _pInt(q, 'a') * _pInt(q, 'b') + _pInt(q, 'c');
}

int _solvePigeon(Question q) {
  if (q.difficulty == 2) {
    // 2 màu: lấy 3 chiếc thì chắc chắn có 2 chiếc cùng màu.
    return 3;
  }
  return _pInt(q, 'g') + _pInt(q, 'y') + 2;
}

int _solveArrange(Question q) {
  if (q.difficulty == 2) {
    return 3 * 2 * 1;
  }
  return _pInt(q, 'variant') == 0 ? 2 : 4 * 3 * 2 * 1;
}

int _solveGridPath(Question q) {
  // Đếm đường đi bằng bảng quy hoạch động (mỗi ô = ô trái + ô dưới),
  // độc lập với công thức tổ hợp của generator.
  final r = _pInt(q, 'r');
  final c = _pInt(q, 'c');
  final dp = List.generate(r + 1, (_) => List.filled(c + 1, 0));
  for (var i = 0; i <= r; i++) {
    for (var j = 0; j <= c; j++) {
      if (i == 0 && j == 0) {
        dp[i][j] = 1;
      } else {
        dp[i][j] = (i > 0 ? dp[i - 1][j] : 0) + (j > 0 ? dp[i][j - 1] : 0);
      }
    }
  }
  return dp[r][c];
}

int _solveSplit(Question q) {
  final k = _pInt(q, 'k');
  // Cặp (a, b) với 1 <= a <= b < k và a + b == k (kể cả a == b, vd 3 + 3).
  var cnt = 0;
  for (var a = 1; a < k; a++) {
    for (var b = a; b < k; b++) {
      if (a + b == k) cnt++;
    }
  }
  return cnt;
}

int _solveCoins() {
  // Đếm độc lập: số bộ (a, b, c) với a + 2b + 5c = 10.
  var ways = 0;
  for (var c = 0; c <= 2; c++) {
    for (var b = 0; b <= 5; b++) {
      final a = 10 - 2 * b - 5 * c;
      if (a >= 0) ways++;
    }
  }
  return ways;
}
