/// Đi lại trong Phòng (G): logic thuần (không widget) để test trực tiếp.
///
/// Vùng đi được = đa giác sàn ([roomFloorPolygon]) trừ dấu chân đồ
/// đạc ([roomObstacleFootprints]), co vào một lề nhỏ để chân không
/// chạm mép. Bé chạm vào đâu trên sàn thì nhân vật đi tới đó; chạm
/// ngoài sàn (tường, giường) thì đi tới điểm sàn gần nhất ngay bên
/// dưới chỗ chạm. Đường đi thẳng; nếu cắt qua dấu chân đồ đạc thì
/// vòng xuống phía trước món đó (đi xuống, đi ngang, rồi đi lên); hàng đồ
/// phía trước kín thì vòng lên phía sau.
///
/// Tỉ lệ theo chiều sâu: càng xa (chân y nhỏ) càng nhỏ, đứng ở chân
/// y = 810 (chỗ đứng mặc định) thì đúng cỡ gốc.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/animation.dart' show Curves;

import 'room_assets.dart';

/// Lề an toàn quanh dấu chân đồ đạc và mép sàn (px khung 1600x900).
const double roomWalkMargin = 14;

/// Giới hạn chân y khi đi: không lùi quá sâu (sát tường) và không
/// xuống quá mép dưới (nhân vật bị cắt).
const double roomWalkMinY = 668;
const double roomWalkMaxY = 880;

/// Tốc độ đi đều (px khung / giây). Góp ý v0.0.13: 170 còn nhanh.
const double roomWalkSpeed = 120;

/// Thời gian tăng tốc lúc bắt đầu đi và giảm tốc lúc dừng (giây).
const double roomWalkRamp = 0.3;

/// Thời gian đi hết quãng [length] (giây): đi đều [speed] cộng một
/// [ramp] cho phần tăng/giảm tốc.
double roomWalkDuration(double length, {double speed = roomWalkSpeed}) =>
    length / speed + roomWalkRamp;

/// Quãng đã đi sau [t] giây (0..[length]) theo hồ sơ tốc độ hình
/// thang: tăng tốc đều trong [roomWalkRamp], đi đều, giảm tốc đều để
/// dừng — không khựng ở đầu/cuối, không giật ở các góc đường đi.
double roomWalkDistanceAt(
  double t,
  double length, {
  double speed = roomWalkSpeed,
}) {
  const a = roomWalkRamp;
  final total = roomWalkDuration(length, speed: speed);
  if (t <= 0) return 0;
  if (t >= total) return length;
  if (total < 2 * a) {
    // Quãng ngắn: không kịp đạt tốc độ đều — dùng đường cong êm.
    return length * Curves.easeInOut.transform(t / total);
  }
  if (t < a) return speed * t * t / (2 * a);
  if (t > total - a) {
    final r = total - t;
    return length - speed * r * r / (2 * a);
  }
  return speed * a / 2 + speed * (t - a);
}

/// Điểm trên đường gấp khúc [points] ở quãng [d] tính từ điểm đầu,
/// kèm chỉ số đoạn đang đi ([cumulative] là quãng cộng dồn tới từng
/// điểm, phần tử đầu là 0).
(Offset, int) roomPointAlong(
  List<Offset> points,
  List<double> cumulative,
  double d,
) {
  for (var i = 1; i < points.length; i++) {
    if (d <= cumulative[i] || i == points.length - 1) {
      final segLen = cumulative[i] - cumulative[i - 1];
      final f = segLen <= 0
          ? 1.0
          : ((d - cumulative[i - 1]) / segLen).clamp(0.0, 1.0);
      return (Offset.lerp(points[i - 1], points[i], f)!, i - 1);
    }
  }
  return (points.last, 0);
}

/// Chỗ đứng có hợp lệ không: trong sàn, không đè dấu chân đồ đạc.
/// [extra] = dấu chân thêm (nội thất mua ở Cửa hàng, T2-06b), cũng
/// phình [roomWalkMargin] như dấu chân có sẵn.
bool roomWalkable(Offset p, {List<Rect> extra = const []}) {
  // Dung sai 0,01: nội suy số thực (lerp) có thể lệch 1e-13 khỏi mép.
  if (p.dy < roomWalkMinY - 0.01 || p.dy > roomWalkMaxY + 0.01) return false;
  if (p.dx < roomWalkMargin || p.dx > 1600 - roomWalkMargin) return false;
  if (!roomPointInFloor(p.translate(0, -roomWalkMargin))) return false;
  for (final r in [...roomObstacleFootprints.values, ...extra]) {
    if (r.inflate(roomWalkMargin).contains(p)) return false;
  }
  return true;
}

/// Điểm sàn để đi tới khi bé chạm [tap]: chính chỗ chạm nếu đứng được,
/// không thì dò xuống dần (rồi dò ngang) tới chỗ đứng được gần nhất.
Offset roomWalkTarget(Offset tap, {List<Rect> extra = const []}) {
  final start = Offset(
    tap.dx.clamp(roomWalkMargin + 1, 1600 - roomWalkMargin - 1),
    tap.dy.clamp(roomWalkMinY, roomWalkMaxY),
  );
  if (roomWalkable(start, extra: extra)) return start;
  // Dò xuống (phía trước đồ đạc) trước — tự nhiên nhất khi chạm vào
  // giường/bàn: bé đi tới đứng trước món đó.
  for (var y = start.dy; y <= roomWalkMaxY; y += 4) {
    final p = Offset(start.dx, y);
    if (roomWalkable(p, extra: extra)) return p;
  }
  // Dò ngang hai phía ở hàng thấp nhất có thể.
  for (var d = 4.0; d < 1600; d += 4) {
    for (final x in [start.dx - d, start.dx + d]) {
      for (var y = start.dy; y <= roomWalkMaxY; y += 8) {
        final p = Offset(x, y);
        if (roomWalkable(p, extra: extra)) return p;
      }
    }
  }
  return roomCharacterFeet;
}

/// Đoạn [a]→[b] có cắt qua (phần trong của) [r] không — thuật toán
/// Liang–Barsky, tính chính xác thay vì lấy mẫu (lấy mẫu dễ lọt góc).
bool _segmentHitsRect(Offset a, Offset b, Rect r) {
  var t0 = 0.0;
  var t1 = 1.0;
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  bool clip(double p, double q) {
    if (p == 0) return q > 0;
    final t = q / p;
    if (p < 0) {
      if (t > t1) return false;
      if (t > t0) t0 = t;
    } else {
      if (t < t0) return false;
      if (t < t1) t1 = t;
    }
    return true;
  }

  if (!clip(-dx, a.dx - r.left)) return false;
  if (!clip(dx, r.right - a.dx)) return false;
  if (!clip(-dy, a.dy - r.top)) return false;
  if (!clip(dy, r.bottom - a.dy)) return false;
  return t1 - t0 > 1e-9;
}

/// Đoạn [a]→[b] có đi qua chỗ không đứng được không. Vùng sàn (đa
/// giác sàn, dải y, dải x) là hình lồi nên chỉ cần hai đầu mút đứng
/// được; còn lại kiểm giao chính xác với từng dấu chân đồ đạc.
bool _segmentBlocked(Offset a, Offset b, List<Rect> extra) {
  if (!roomWalkable(a, extra: extra) || !roomWalkable(b, extra: extra)) {
    return true;
  }
  for (final r in [...roomObstacleFootprints.values, ...extra]) {
    if (_segmentHitsRect(a, b, r.inflate(roomWalkMargin))) return true;
  }
  return false;
}

/// Các điểm đi qua từ [from] tới [to] (không gồm [from]). Đi thẳng nếu
/// không vướng; vướng thì vòng xuống trước đồ đạc.
List<Offset> roomWalkPath(
  Offset from,
  Offset to, {
  List<Rect> extra = const [],
}) {
  if (!_segmentBlocked(from, to, extra)) return <Offset>[to];
  // Vòng xuống trước đồ đạc trước, rồi (nếu hàng đồ phía trước kín) vòng
  // lên phía sau.
  final rows = <double>[
    for (var y = math.max(from.dy, to.dy); y <= roomWalkMaxY; y += 6) y,
    for (var y = math.min(from.dy, to.dy) - 6; y >= roomWalkMinY; y -= 6) y,
  ];
  for (final y in rows) {
    final a = Offset(from.dx, y);
    final b = Offset(to.dx, y);
    if (_segmentBlocked(from, a, extra)) continue;
    if (_segmentBlocked(a, b, extra)) continue;
    if (_segmentBlocked(b, to, extra)) continue;
    return <Offset>[if (a != from) a, b, to];
  }
  // Bị kẹp giữa các món (bố cục kín): dò lưới tìm đường vòng.
  return _gridDetour(from, to, extra) ?? <Offset>[to];
}

/// Tìm đường vòng bằng lưới (bước 5 px, Dijkstra 8 hướng) khi đường vòng
/// theo hàng không có — ví dụ đứng giữa các món xếp sát nhau. Trả về điểm
/// đi qua (không gồm [from], cuối là [to]) đã làm thẳng bớt; null nếu
/// không có đường.
List<Offset>? _gridDetour(Offset from, Offset to, List<Rect> extra) {
  const step = 5.0;
  final x0 = roomWalkMargin + 1;
  final cols = ((1600 - 2 * (roomWalkMargin + 1)) / step).floor() + 1;
  final rows = ((roomWalkMaxY - roomWalkMinY) / step).floor() + 1;
  Offset node(int i) =>
      Offset(x0 + (i % cols) * step, roomWalkMinY + (i ~/ cols) * step);
  final ok = List<bool>.generate(
    cols * rows,
    (i) => roomWalkable(node(i), extra: extra),
  );
  // Ô lưới gần [p] nhất mà đi thẳng từ [p] tới được.
  int? attach(Offset p) {
    int? best;
    var bestD = double.infinity;
    for (var i = 0; i < ok.length; i++) {
      if (!ok[i]) continue;
      final d = (node(i) - p).distance;
      if (d < bestD && d <= 60 && !_segmentBlocked(p, node(i), extra)) {
        best = i;
        bestD = d;
      }
    }
    return best;
  }

  final start = attach(from);
  final goal = attach(to);
  if (start == null || goal == null) return null;
  final dist = List<double>.filled(ok.length, double.infinity);
  final prev = List<int>.filled(ok.length, -1);
  final open = <int>{start};
  dist[start] = 0;
  while (open.isNotEmpty) {
    var cur = open.first;
    for (final i in open) {
      if (dist[i] < dist[cur]) cur = i;
    }
    open.remove(cur);
    if (cur == goal) break;
    final cx = cur % cols;
    final cy = cur ~/ cols;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final nx = cx + dx;
        final ny = cy + dy;
        if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) continue;
        final n = ny * cols + nx;
        if (!ok[n]) continue;
        if (_segmentBlocked(node(cur), node(n), extra)) continue;
        final d = dist[cur] + (node(n) - node(cur)).distance;
        if (d < dist[n]) {
          dist[n] = d;
          prev[n] = cur;
          open.add(n);
        }
      }
    }
  }
  if (prev[goal] == -1 && goal != start) return null;
  final cells = <Offset>[to];
  for (var i = goal; i != -1; i = prev[i]) {
    cells.add(node(i));
  }
  final pts = [from, ...cells.reversed];
  // Làm thẳng: từ điểm hiện tại nhảy tới điểm xa nhất nhìn thẳng được.
  final out = <Offset>[];
  var i = 0;
  while (i < pts.length - 1) {
    var j = pts.length - 1;
    while (j > i + 1 && _segmentBlocked(pts[i], pts[j], extra)) {
      j--;
    }
    out.add(pts[j]);
    i = j;
  }
  return out;
}

/// Tỉ lệ cỡ nhân vật/pet theo chân y: y = 810 → 1.0; xa hơn nhỏ dần.
double roomDepthScale(double feetY) =>
    (1 + (feetY - roomCharacterFeet.dy) * 0.0016).clamp(0.72, 1.12);

/// Chỗ pet đứng khi theo bé: sau lưng bé (ngược hướng mặt), cách
/// ~150 px; không đứng được thì thử phía trước, rồi về chỗ gần nhất.
Offset roomPetFollowSpot(
  Offset kidFeet, {
  required bool kidFacingLeft,
  List<Rect> extra = const [],
}) {
  final back = kidFacingLeft ? 150.0 : -150.0;
  for (final dx in [back, -back]) {
    final p = Offset(kidFeet.dx + dx, kidFeet.dy + 6);
    if (roomWalkable(p, extra: extra)) return p;
  }
  return roomWalkTarget(
    Offset(kidFeet.dx + back, kidFeet.dy + 6),
    extra: extra,
  );
}
