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
    case 'logic.classsize':
      return _pInt(q, 'taller') + _pInt(q, 'shorter') + _pInt(q, 'same') + 1;
    case 'logic.seqgrow':
      return _solveSeqGrow(q);
    case 'logic.interleave':
      return _solveInterleave(q);
    case 'logic.cyclepattern':
      return _solveCycle(q);
    case 'logic.laps':
      return _solveLaps(q);
    case 'arith.altsum':
      return _solveAltsum(q);
    case 'arith.runsum':
      return _pInts(q, 'terms').fold(0, (a, b) => a + b);
    case 'arith.cryptarith':
      return _solveCryptarith(q);
    case 'arith.arrowchain':
      return _solveArrow(q);
    case 'arith.flowerx':
      return _solveFlower(q);
    case 'arith.factorout':
      return _pInts(q, 'xs').fold(0, (a, x) => a + _pInt(q, 'm') * x);
    case 'number.digitcond':
      return _solveDigitCond(q);
    case 'number.parityops':
      return _solveParityOps(q);
    case 'number.kth':
      return _solveKth(q);
    case 'number.giveequal':
      return _solveGiveEqual(q);
    case 'number.pages':
      return _solvePages(q);
    case 'number.countsteps':
      return _solveCountSteps(q);
    case 'geo.pointsegs':
      return _solvePointSegs(q);
    case 'geo.shapeparts':
      return _solveShapeParts(q);
    case 'comb.makenumparity':
      return _solveMakeNumParity(q);
    case 'comb.minsum2':
      return _solveMinSum2(q);
    case 'comb.freebie':
      return _solveFreebie(q);
    case 'comb.vases':
      return _solveVases(q);
    case 'comb.pick2':
      return _solvePick2(q);
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

// ------------------------------------------------ dạng bổ sung (gen_timo2.py)

int _solveSeqGrow(Question q) {
  // Đáp án là số tiếp theo sau 6 số đầu: lấy khoảng cách cuối cộng thêm
  // đúng độ tăng của khoảng cách.
  final s = _pInts(q, 'seq');
  final g4 = s[5] - s[4];
  final g3 = s[4] - s[3];
  return s[5] + g4 + (g4 - g3);
}

int _solveInterleave(Question q) {
  final s = _pInts(q, 'seq');
  final n = _pInt(q, 'n');
  // Số ở vị trí n (đếm từ 0) theo cùng dãy với số ở vị trí n - 2.
  return s[n - 2] + (s[n - 2] - s[n - 4]);
}

int _solveCycle(Question q) {
  final pat = _pStrings(q, 'pattern');
  final sym = q.params['sym'] as String;
  var c = 0;
  for (var i = 0; i < _pInt(q, 'n'); i++) {
    if (pat[i % pat.length] == sym) c++;
  }
  return c;
}

int _solveLaps(Question q) {
  var t = 0;
  final n = _pInt(q, 'n');
  for (var i = 1; i <= n; i++) {
    t += _pInt(q, 't');
    if (i < n) t += _pInt(q, 'r');
  }
  return t;
}

int _solveAltsum(Question q) {
  final terms = _pInts(q, 'terms');
  var v = 0;
  for (var i = 0; i < terms.length; i++) {
    v += i.isEven ? terms[i] : -terms[i];
  }
  return v;
}

int _solveCryptarith(Question q) {
  final plus = _pBool(q, 'plus');
  final res = _pInt(q, 'res');
  final found = <int>[];
  for (var a = 1; a <= 9; a++) {
    for (var b = 0; b <= 9; b++) {
      if (a == b) continue;
      final v = plus ? (10 * a + b) + a : (10 * a + b) - a;
      if (v == res) found.add(b);
    }
  }
  if (found.length != 1) throw StateError('Nghiệm không duy nhất: $found');
  return found.single;
}

int _solveArrow(Question q) {
  final plus = (q.params['plus'] as List).cast<bool>();
  final xs = _pInts(q, 'xs');
  for (var start = 0; start <= 200; start++) {
    var v = start;
    for (var i = 0; i < xs.length; i++) {
      v = plus[i] ? v + xs[i] : v - xs[i];
    }
    if (v == _pInt(q, 'end')) return start;
  }
  throw StateError('Không tìm được số ban đầu');
}

int _solveFlower(Question q) {
  for (var x = 0; x <= 200; x++) {
    if (_pInt(q, 'k') * x - _pInt(q, 'a') == x + _pInt(q, 'b')) return x;
  }
  throw StateError('Không có nghiệm');
}

int _solveDigitCond(Question q) {
  final k = _pInt(q, 'k');
  final kind = q.params['kind'] as String;
  var c = 0;
  for (var t = 1; t <= 9; t++) {
    for (var u = 0; u <= 9; u++) {
      final ok = switch (kind) {
        'both_gt' => t > k && u > k,
        'both_lt' => t < k && u < k,
        'unit_lt' => u < k,
        'tens_gt_unit' => t > u,
        'sum_eq' => t + u == k,
        _ => throw StateError(kind),
      };
      if (ok) c++;
    }
  }
  return c;
}

int _solveParityOps(Question q) {
  final a = _pInts(q, 'a');
  final b = _pInts(q, 'b');
  final plus = (q.params['plus'] as List).cast<bool>();
  final even = _pBool(q, 'even');
  var c = 0;
  for (var i = 0; i < a.length; i++) {
    final v = plus[i] ? a[i] + b[i] : a[i] - b[i];
    if ((v % 2 == 0) == even) c++;
  }
  return c;
}

int _solveKth(Question q) {
  final xs = _pInts(q, 'xs');
  final k = _pInt(q, 'k');
  final largest = _pBool(q, 'largest');
  // Số thứ k: có đúng k - 1 số đứng trước nó theo thứ tự đã chọn.
  for (final x in xs) {
    final before = xs.where((y) => largest ? y > x : y < x).length;
    if (before == k - 1) return x;
  }
  throw StateError('Không tìm được');
}

int _solveGiveEqual(Question q) {
  final a = _pInt(q, 'a');
  final b = _pInt(q, 'b');
  for (var g = 0; g <= a; g++) {
    if ((a - g) - (b + g) == _pInt(q, 'c')) return g;
  }
  throw StateError('Không tìm được');
}

int _solvePages(Question q) {
  var pages = 0;
  while (pages * _pInt(q, 'k') < _pInt(q, 'n')) {
    pages++;
  }
  return pages;
}

int _solveCountSteps(Question q) {
  var c = 0;
  for (var v = _pInt(q, 'a'); v <= _pInt(q, 'b'); v += _pInt(q, 'step')) {
    c++;
  }
  return c;
}

int _solvePointSegs(Question q) {
  final n = _pInt(q, 'n');
  var c = 0;
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      c++;
    }
  }
  return c;
}

int _solveShapeParts(Question q) {
  // Cạnh, đỉnh, mặt của: tam giác, hình vuông, hình chữ nhật, lập phương.
  const table = [
    [3, 3, 0],
    [4, 4, 0],
    [4, 4, 0],
    [12, 8, 6],
  ];
  final col = switch (q.params['what'] as String) {
    'cạnh' => 0,
    'đỉnh' => 1,
    _ => 2,
  };
  final items = _pInts(q, 'items');
  final cnts = _pInts(q, 'cnts');
  var total = 0;
  for (var i = 0; i < items.length; i++) {
    total += cnts[i] * table[items[i]][col];
  }
  return total;
}

int _solveMakeNumParity(Question q) {
  final ds = _pInts(q, 'digits');
  final even = _pBool(q, 'even');
  final made = <int>{};
  for (final a in ds) {
    for (final b in ds) {
      if (a != b && a != 0 && (b % 2 == 0) == even) made.add(10 * a + b);
    }
  }
  return made.length;
}

int _solveMinSum2(Question q) {
  final ds = _pInts(q, 'digits');
  final isMin = _pBool(q, 'min');
  int? best;
  for (var i = 0; i < 4; i++) {
    for (var j = 0; j < 4; j++) {
      for (var k = 0; k < 4; k++) {
        for (var l = 0; l < 4; l++) {
          if ({i, j, k, l}.length != 4) continue;
          final v = 10 * ds[i] + ds[j] + 10 * ds[k] + ds[l];
          if (best == null || (isMin ? v < best : v > best)) best = v;
        }
      }
    }
  }
  return best!;
}

int _solveFreebie(Question q) {
  var money = _pInt(q, 'money');
  var bought = 0;
  var got = 0;
  while (money >= _pInt(q, 'p')) {
    money -= _pInt(q, 'p');
    bought++;
    got++;
    if (bought % _pInt(q, 'k') == 0) got++;
  }
  return got;
}

int _solveVases(Question q) {
  final n = _pInt(q, 'n');
  var c = 0;
  for (var a = 1; a <= n; a++) {
    for (var b = 1; b <= n; b++) {
      for (var d = 1; d <= n; d++) {
        if (a + b + d == n) c++;
      }
    }
  }
  return c;
}

int _solvePick2(Question q) {
  final n = _pInt(q, 'n');
  var c = 0;
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < n; j++) {
      if (i == j) continue;
      if (_pBool(q, 'ordered') || i < j) c++;
    }
  }
  return c;
}
