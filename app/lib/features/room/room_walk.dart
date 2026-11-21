/// Đi lại trong Phòng (G): logic thuần (không widget) để test trực tiếp.
///
/// Vùng đi được = đa giác sàn ([roomFloorPolygon]) trừ dấu chân đồ
/// đạc ([roomObstacleFootprints]), co vào một lề nhỏ để chân không
/// chạm mép. Bé chạm vào đâu trên sàn thì nhân vật đi tới đó; chạm
/// ngoài sàn (tường, giường) thì đi tới điểm sàn gần nhất ngay bên
/// dưới chỗ chạm. Đường đi thẳng; nếu cắt qua dấu chân đồ đạc thì
/// vòng xuống phía trước món đó (đi xuống, đi ngang, rồi đi lên).
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
bool roomWalkable(Offset p) {
  // Dung sai 0,01: nội suy số thực (lerp) có thể lệch 1e-13 khỏi mép.
  if (p.dy < roomWalkMinY - 0.01 || p.dy > roomWalkMaxY + 0.01) return false;
  if (p.dx < roomWalkMargin || p.dx > 1600 - roomWalkMargin) return false;
  if (!roomPointInFloor(p.translate(0, -roomWalkMargin))) return false;
  for (final r in roomObstacleFootprints.values) {
    if (r.inflate(roomWalkMargin).contains(p)) return false;
  }
  return true;
}

/// Điểm sàn để đi tới khi bé chạm [tap]: chính chỗ chạm nếu đứng được,
/// không thì dò xuống dần (rồi dò ngang) tới chỗ đứng được gần nhất.
Offset roomWalkTarget(Offset tap) {
  final start = Offset(
    tap.dx.clamp(roomWalkMargin + 1, 1600 - roomWalkMargin - 1),
    tap.dy.clamp(roomWalkMinY, roomWalkMaxY),
  );
  if (roomWalkable(start)) return start;
  // Dò xuống (phía trước đồ đạc) trước — tự nhiên nhất khi chạm vào
  // giường/bàn: bé đi tới đứng trước món đó.
  for (var y = start.dy; y <= roomWalkMaxY; y += 4) {
    final p = Offset(start.dx, y);
    if (roomWalkable(p)) return p;
  }
  // Dò ngang hai phía ở hàng thấp nhất có thể.
  for (var d = 4.0; d < 1600; d += 4) {
    for (final x in [start.dx - d, start.dx + d]) {
      for (var y = start.dy; y <= roomWalkMaxY; y += 8) {
        final p = Offset(x, y);
        if (roomWalkable(p)) return p;
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
bool _segmentBlocked(Offset a, Offset b) {
  if (!roomWalkable(a) || !roomWalkable(b)) return true;
  for (final r in roomObstacleFootprints.values) {
    if (_segmentHitsRect(a, b, r.inflate(roomWalkMargin))) return true;
  }
  return false;
}

/// Các điểm đi qua từ [from] tới [to] (không gồm [from]). Đi thẳng nếu
/// không vướng; vướng thì vòng xuống trước đồ đạc.
List<Offset> roomWalkPath(Offset from, Offset to) {
  if (!_segmentBlocked(from, to)) return <Offset>[to];
  for (var y = math.max(from.dy, to.dy); y <= roomWalkMaxY; y += 6) {
    final a = Offset(from.dx, y);
    final b = Offset(to.dx, y);
    if (_segmentBlocked(from, a)) continue;
    if (_segmentBlocked(a, b)) continue;
    if (_segmentBlocked(b, to)) continue;
    return <Offset>[if (a != from) a, b, to];
  }
  return <Offset>[to];
}

/// Tỉ lệ cỡ nhân vật/pet theo chân y: y = 810 → 1.0; xa hơn nhỏ dần.
double roomDepthScale(double feetY) =>
    (1 + (feetY - roomCharacterFeet.dy) * 0.0016).clamp(0.72, 1.12);

/// Chỗ pet đứng khi theo bé: sau lưng bé (ngược hướng mặt), cách
/// ~150 px; không đứng được thì thử phía trước, rồi về chỗ gần nhất.
Offset roomPetFollowSpot(Offset kidFeet, {required bool kidFacingLeft}) {
  final back = kidFacingLeft ? 150.0 : -150.0;
  for (final dx in [back, -back]) {
    final p = Offset(kidFeet.dx + dx, kidFeet.dy + 6);
    if (roomWalkable(p)) return p;
  }
  return roomWalkTarget(Offset(kidFeet.dx + back, kidFeet.dy + 6));
}
