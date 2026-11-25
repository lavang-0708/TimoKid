/// Đường đi + hướng/lật cho bản đồ Thị trấn v3b (PR (C)).
///
/// Logic thuần (không widget) để test được trực tiếp:
/// - 2 đoạn đường C1/C2 đo từ mặt nhựa thật của `town_v3.webp` (khung
///   nền 1600x900, nửa rộng vùng đường [townRoadHalfWidth] = 60 px;
///   xem `docs/ASSETS.md` mục "Đường đi C1/C2"). Ghi chú D1–D6 ở dưới
///   là lịch sử các vòng sửa trước khi đo lại;
/// - tuyến xe/người chạy tới-lui trên các đoạn đó (ping-pong);
/// - chọn biến thể lớp (dr/ur) + lật ngang theo hướng di chuyển;
/// - khung bước chân người đi bộ.
///
/// Hướng mặt của từng biến thể lớp là DỮ KIỆN ĐO BẰNG MẮT trên PNG
/// thật (xem bằng mắt từng lớp, đối chiếu ghi chú của Claude khi
/// review decode lần 2) — KHÔNG suy từ tên file, vì tên "ur" dễ gây
/// nhầm:
/// - Xe `dr`: góc 3/4 trước, đầu xe ↘. Xe `ur`: NHÌN TỪ SAU, đầu
///   xe ↖ (đuôi xe ở phía dưới-phải) — tức `ur` đi ↖ khi không lật,
///   và đi ↗ khi lật ngang. Đây chính là điểm Claude dặn riêng.
/// - Người `dr`: góc 3/4 trước, mặt ↘. Người `ur`: NHÌN TỪ SAU,
///   mặt ↗ (lưng quay về phía người xem, tai phải lộ ở mép phải) —
///   tức `ur` đi ↗ khi không lật, và đi ↖ khi lật ngang.
/// Test hướng (`town_roads_test.dart`) khóa lại bảng này: nếu ai
/// "sửa" map theo tên file thì test đỏ.
library;

import 'dart:ui';

/// Khung nền thị trấn v3b (1600x900, xem `docs/C_IMAGES.md`).
const double townFrameWidth = 1600;
const double townFrameHeight = 900;

/// Nửa rộng vùng đường (mặt đường + vỉa hè), px theo khung nền.
const double townRoadHalfWidth = 60;

/// Người đi bộ lệch khỏi tâm đường (lên vỉa hè), px theo khung nền.
const double townSidewalkOffset = 46;

/// Một đoạn đường: polyline theo hướng đường isometric, tâm đường +
/// nửa rộng vùng đường (xem `docs/C_IMAGES.md`).
class TownRoadSegment {
  const TownRoadSegment({
    required this.name,
    required this.points,
    this.halfWidth = townRoadHalfWidth,
  });

  /// Tên đoạn (C1/C2).
  final String name;

  /// Các điểm của polyline, tọa độ px theo khung nền 1600x900.
  final List<Offset> points;

  /// Nửa rộng vùng đường (mặt đường + vỉa hè).
  final double halfWidth;
}

/// 6 đoạn đường v3b (đo từ nền thật; gần đúng ±40 px — xem
/// `docs/C_IMAGES.md`).
///
/// Vòng sửa PR #31 (21/11): D2 đo lại từ nền thật (đoạn khai báo cũ
/// (880, 70) → (1120, 220) cắt qua khối lều Hội chợ — xe hồng ở
/// t = 0 nằm trên cỏ (990, 90)); ngã giao D1×D2 dời về đúng tâm làn
/// (865, 125) (điểm cũ (880, 70) nằm trên cỏ, trên vạch sang
/// đường). D2 mới uốn theo đường nhựa thật: qua phải tháp Con số,
/// giữa lều và vòng quay Hội chợ, ra mép phải ở y ≈ 430.
const List<TownRoadSegment> townRoads = [
  // C1: đường chéo xuống-phải, từ giữa Tiệm bánh/Tháp qua ngã tư lớn
  // (1090, 650) ra mép phải dưới. Tâm đường đo từ mặt nhựa của
  // town_v3.webp (nửa rộng mặt nhựa ~32 px, cộng vỉa hè ~28 px).
  TownRoadSegment(name: 'C1', points: [Offset(700, 459), Offset(1600, 904)]),
  // C2: đường chéo lên-phải, từ ngã ba dưới (770, 810) qua ngã tư lớn
  // lên mép phải giữa.
  TownRoadSegment(name: 'C2', points: [Offset(770, 810), Offset(1560, 416)]),
];

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  final len2 = dx * dx + dy * dy;
  if (len2 == 0) return (p - a).distance;
  var t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / len2;
  t = t.clamp(0.0, 1.0);
  return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
}

/// Khoảng cách ngắn nhất từ [point] tới polyline của [segment].
double distanceToSegmentPolyline(Offset point, TownRoadSegment segment) {
  var best = double.infinity;
  for (var i = 0; i + 1 < segment.points.length; i++) {
    final d = _distanceToSegment(
      point,
      segment.points[i],
      segment.points[i + 1],
    );
    if (d < best) best = d;
  }
  return best;
}

/// Khoảng cách ngắn nhất từ [point] tới bất kỳ đoạn đường nào.
double distanceToRoads(Offset point) {
  var best = double.infinity;
  for (final road in townRoads) {
    final d = distanceToSegmentPolyline(point, road);
    if (d < best) best = d;
  }
  return best;
}

/// Điểm có nằm trong vùng đường đã khai báo không (tâm đường +
/// nửa rộng [townRoadHalfWidth], cộng thêm [margin] nếu cần dung sai).
bool isOnRoad(Offset point, [double margin = 0]) {
  return distanceToRoads(point) <= townRoadHalfWidth + margin;
}

/// 4 hướng di chuyển trên đường chéo isometric (tọa độ khung nền:
/// x tăng = sang phải, y tăng = xuống dưới).
enum TownTravelDirection {
  /// Xuống-phải (x tăng, y tăng): chạy xuôi C1.
  downRight,

  /// Xuống-trái (x giảm, y tăng): chạy ngược C2.
  downLeft,

  /// Lên-phải (x tăng, y giảm): chạy xuôi C2.
  upRight,

  /// Lên-trái (x giảm, y giảm): chạy ngược C1.
  upLeft,
}

/// Hướng sau khi lật ngang (đổi dấu x, giữ nguyên y).
TownTravelDirection flipDirection(TownTravelDirection direction) {
  return switch (direction) {
    TownTravelDirection.downRight => TownTravelDirection.downLeft,
    TownTravelDirection.downLeft => TownTravelDirection.downRight,
    TownTravelDirection.upRight => TownTravelDirection.upLeft,
    TownTravelDirection.upLeft => TownTravelDirection.upRight,
  };
}

/// Vectơ đơn vị của một hướng, theo khung nền (mỗi thành phần
/// ±1/√2 — đường chéo isometric nên x và y cùng độ lớn).
Offset directionUnit(TownTravelDirection direction) {
  const k = 0.7071067811865476; // 1/√2
  return switch (direction) {
    TownTravelDirection.downRight => const Offset(k, k),
    TownTravelDirection.downLeft => const Offset(-k, k),
    TownTravelDirection.upRight => const Offset(k, -k),
    TownTravelDirection.upLeft => const Offset(-k, -k),
  };
}

/// Hướng mặt của biến thể xe, đo bằng mắt trên PNG thật:
/// `dr` đầu xe ↘, `ur` nhìn từ sau nên đầu xe ↖.
const Map<String, TownTravelDirection> carVariantFacing = {
  'dr': TownTravelDirection.downRight,
  'ur': TownTravelDirection.upLeft,
};

/// Hướng mặt của biến thể người, đo bằng mắt trên PNG thật:
/// `dr` mặt ↘, `ur` nhìn từ sau nên mặt ↗.
const Map<String, TownTravelDirection> personVariantFacing = {
  'dr': TownTravelDirection.downRight,
  'ur': TownTravelDirection.upRight,
};

/// Lớp xe/người được chọn cho một hướng di chuyển: đường dẫn asset
/// + có lật ngang hay không.
class TownSpriteChoice {
  const TownSpriteChoice({required this.asset, required this.flipHorizontal});

  /// Đường dẫn asset PNG (vd `assets/images/town/car_01_dr.webp`).
  final String asset;

  /// true = lật ngang ảnh (dùng cho 2 hướng còn lại).
  final bool flipHorizontal;
}

/// Chọn biến thể xe cho [direction]: `dr` đi ↘ (lật → ↙),
/// `ur` (nhìn từ sau, đầu ↖) đi ↖ (lật → ↗).
TownSpriteChoice carSpriteFor(String model, TownTravelDirection direction) {
  return switch (direction) {
    TownTravelDirection.downRight => TownSpriteChoice(
      asset: 'assets/images/town/${model}_dr.webp',
      flipHorizontal: false,
    ),
    TownTravelDirection.downLeft => TownSpriteChoice(
      asset: 'assets/images/town/${model}_dr.webp',
      flipHorizontal: true,
    ),
    TownTravelDirection.upLeft => TownSpriteChoice(
      asset: 'assets/images/town/${model}_ur.webp',
      flipHorizontal: false,
    ),
    TownTravelDirection.upRight => TownSpriteChoice(
      asset: 'assets/images/town/${model}_ur.webp',
      flipHorizontal: true,
    ),
  };
}

/// Chọn biến thể người cho [direction] và khung bước chân [frameB]:
/// `dr` đi ↘ (lật → ↙), `ur` (nhìn từ sau, mặt ↗) đi ↗ (lật → ↖).
TownSpriteChoice personSpriteFor(
  String model,
  TownTravelDirection direction,
  bool frameB,
) {
  final frame = frameB ? 'b' : 'a';
  return switch (direction) {
    TownTravelDirection.downRight => TownSpriteChoice(
      asset: 'assets/images/town/${model}_dr_$frame.webp',
      flipHorizontal: false,
    ),
    TownTravelDirection.downLeft => TownSpriteChoice(
      asset: 'assets/images/town/${model}_dr_$frame.webp',
      flipHorizontal: true,
    ),
    TownTravelDirection.upRight => TownSpriteChoice(
      asset: 'assets/images/town/${model}_ur_$frame.webp',
      flipHorizontal: false,
    ),
    TownTravelDirection.upLeft => TownSpriteChoice(
      asset: 'assets/images/town/${model}_ur_$frame.webp',
      flipHorizontal: true,
    ),
  };
}

/// Hướng mặt thực tế của một biến thể sau khi lật (để test kiểm):
/// lật ngang đổi dấu x của hướng mặt gốc.
TownTravelDirection effectiveFacing(TownTravelDirection facing, bool flip) {
  return flip ? flipDirection(facing) : facing;
}

/// Khung bước chân người đi bộ theo quãng đường đã đi: đổi khung
/// mỗi 30 px (khung a/b xen kẽ thành dáng đi). Ở t = 0 cả hai người
/// đều ở khung a (quãng đường tại t = 0: ~440 px và ~254 px, chia
/// 30 đều chẵn) nên golden/test xác định được.
bool walkFrameB(double distance) {
  return (distance ~/ 30) % 2 == 1;
}

/// Một điểm trên tuyến đường: vị trí + hướng di chuyển + vectơ đơn
/// vị của đoạn đang đi (theo hướng di chuyển).
class TownRouteSample {
  const TownRouteSample({
    required this.point,
    required this.direction,
    required this.legUnit,
  });

  /// Vị trí, tọa độ px theo khung nền 1600x900.
  final Offset point;

  /// Hướng di chuyển tại điểm đó.
  final TownTravelDirection direction;

  /// Vectơ đơn vị của đoạn đường đang đi (theo hướng di chuyển),
  /// dùng để tính điểm lệch vỉa hè.
  final Offset legUnit;
}

/// Một tuyến đường: polyline xe/người chạy tới-lui (ping-pong).
class TownRoute {
  TownRoute(this.waypoints)
    : assert(waypoints.length >= 2, 'tuyến cần ít nhất 2 điểm'),
      totalLength = _computeLength(waypoints);

  /// Các điểm của tuyến, tọa độ px theo khung nền 1600x900.
  final List<Offset> waypoints;

  /// Tổng chiều dài tuyến (px khung nền).
  final double totalLength;

  static double _computeLength(List<Offset> points) {
    var total = 0.0;
    for (var i = 0; i + 1 < points.length; i++) {
      total += (points[i + 1] - points[i]).distance;
    }
    return total;
  }

  /// Lấy mẫu tại [distance] px từ đầu tuyến (0..[totalLength]):
  /// [forward] = true thì đi theo thứ tự điểm, false thì đi ngược
  /// lại. Hướng di chuyển trả về là hướng của đoạn đang đi.
  TownRouteSample sample(double distance, bool forward) {
    final d = distance.clamp(0.0, totalLength);
    var remaining = d;
    for (var i = 0; i + 1 < waypoints.length; i++) {
      final a = waypoints[i];
      final b = waypoints[i + 1];
      final leg = (b - a).distance;
      if (remaining <= leg || i + 2 == waypoints.length) {
        final t = leg == 0 ? 0.0 : (remaining / leg).clamp(0.0, 1.0);
        final point = Offset(
          a.dx + (b.dx - a.dx) * t,
          a.dy + (b.dy - a.dy) * t,
        );
        final unit = leg == 0
            ? const Offset(1, 0)
            : Offset((b.dx - a.dx) / leg, (b.dy - a.dy) / leg);
        final dir = _directionOf(unit, forward);
        return TownRouteSample(
          point: point,
          direction: dir,
          legUnit: forward ? unit : Offset(-unit.dx, -unit.dy),
        );
      }
      remaining -= leg;
    }
    // Không tới được (chỉ khi totalLength = 0): trả điểm cuối.
    return TownRouteSample(
      point: waypoints.last,
      direction: forward
          ? TownTravelDirection.downRight
          : TownTravelDirection.upLeft,
      legUnit: const Offset(1, 1),
    );
  }

  static TownTravelDirection _directionOf(Offset unit, bool forward) {
    final dx = forward ? unit.dx : -unit.dx;
    final dy = forward ? unit.dy : -unit.dy;
    if (dx >= 0 && dy >= 0) return TownTravelDirection.downRight;
    if (dx < 0 && dy >= 0) return TownTravelDirection.downLeft;
    if (dx >= 0) return TownTravelDirection.upRight;
    return TownTravelDirection.upLeft;
  }
}

/// Điểm trên vỉa hè: lệch [townSidewalkOffset] px khỏi [point] sang
/// phía nam của đường (pháp tuyến có y > 0 của [legUnit]).
Offset sidewalkPoint(Offset point, Offset legUnit) {
  // Hai pháp tuyến của vectơ đơn vị; lấy phía có y > 0 (phía nam,
  // tức phía dưới màn hình — vỉa hè phía gần người xem).
  final nx = -legUnit.dy;
  final ny = legUnit.dx;
  final sign = ny >= 0 ? 1.0 : -1.0;
  return Offset(
    point.dx + sign * nx * townSidewalkOffset,
    point.dy + sign * ny * townSidewalkOffset,
  );
}

/// Sóng tam giác cho chuyển động tới-lui: [progress] 0..1 (vị trí
/// trong chu kỳ) → 0..1..0 (quãng đường tính theo tỉ lệ tổng dài).
/// `progress < 0.5` là đi xuôi, còn lại là đi ngược.
double pingPongProgress(double progress) {
  final p = progress % 1.0;
  return p < 0.5 ? p * 2 : (1 - p) * 2;
}

/// Có đang đi xuôi (theo thứ tự điểm) tại [progress] không.
bool pingPongForward(double progress) {
  return (progress % 1.0) < 0.5;
}

/// Tuyến xe 1 (xe hồng): làn phía nam của C1, tới-lui giữa (774, 511)
/// và (1524, 882). Đã đối chiếu từng điểm (mỗi 5 px) với mặt nhựa của
/// town_v3.webp: chỉ lệch ở vạch qua đường của ngã tư.
final TownRoute car1Route = TownRoute(const [
  Offset(774, 511),
  Offset(1524, 882),
]);

/// Vùng chân công trình (footprint KHÍT, chỉ thân/khối chính — KHÔNG
/// phải vùng bấm trong `town_assets.dart`): dùng để test độc lập
/// "tuyến đường không cắt qua công trình" (vòng sửa PR #31).
///
/// Vùng bấm cố tình rộng (bao cả sân/vườn để bé bấm dễ) nên KHÔNG
/// dùng được cho test này — đường chạy dọc mép sân/vườn của Tháp,
/// Hội chợ, Vườn, Nhà hồng, Công viên, Hồ nên rect bấm rộng sẽ báo
/// sai. Các rect dưới đây chỉ lấy phần khối chính, và có CHỪA CHỖ
/// ở những chỗ đường chạy sát (kiểm bằng code, không đoán — test
/// `town_roads_test.dart` khóa lại: tuyến mới phải xanh, D2 cũ phải
/// đỏ ở lều):
/// - Lâu đài, Tháp: nhà cao nên rect toàn thân sẽ phủ cả mặt đường
///   chạy sau lưng nó — chỉ lấy phần trên (mái/tháp) + chân đế
///   (chỗ thân chạm đất). Tường trước lâu đài không lấy vì đường D1
///   chạy dọc chân tường (D1 còn lệch ~40 px, chưa đo lại — việc
///   còn lại).
/// - Hội chợ: TÁCH THÀNH 2 rect — lều và bệ vòng quay — vì đường D2
///   chạy GIỮA hai khối (rect gộp cũ bao cả đường nên test không bắt
///   được lỗi xe cắt qua lều). Quầy hàng ven đường không lấy.
/// - Tiệm bánh: mép trái + dải mái không lấy vì đường D1 chạy dọc
///   tường trái (D1 còn lệch, chưa đo lại — việc còn lại).
/// - Vườn Hình học: góc trên-trái không lấy vì đường D3 + vỉa hè
///   chạy dọc hàng rào trên (D3 còn lệch, chưa đo lại — việc còn
///   lại); chỉ lấy phần trong có đồ chơi khối.
/// - Nhà hồng: chỉ mái + tường trên (y 545–675); tường dưới không lấy
///   vì đường D3 chạy dọc mặt trước nhà.
/// - Công viên: dải dưới không lấy vì đường D4 chạy dọc hàng rào dưới.
/// - Hồ: chỉ lòng nước giữa; bờ trái không lấy vì đường D5 + vỉa hè
///   chạy dọc bờ.
const List<Rect> townBuildingFootprints = [
  // Lâu đài Lôgic: tháp + thân trên (x 230–620, y 0–150).
  Rect.fromLTWH(230, 0, 390, 150),
  // Tháp Con số: thân trên (x 670–785, y 5–105).
  Rect.fromLTWH(670, 5, 115, 100),
  // Tháp Con số: chân đế (x 670–785, y 295–335).
  Rect.fromLTWH(670, 295, 115, 40),
  // Hội chợ Tổ hợp — lều (x 1050–1350, y 0–195).
  Rect.fromLTWH(1050, 0, 300, 195),
  // Hội chợ Tổ hợp — bệ vòng quay (x 1340–1520, y 150–280).
  Rect.fromLTWH(1340, 150, 180, 130),
  // Tiệm bánh Số học: mặt trước chính (x 350–570, y 340–540).
  Rect.fromLTWH(350, 340, 220, 200),
  // Vườn Hình học: phần trong có đồ chơi khối (x 570–900, y 620–745).
  Rect.fromLTWH(570, 620, 330, 125),
  // Nhà của bé: mái + tường trên (x 75–310, y 545–675).
  Rect.fromLTWH(75, 545, 235, 130),
  // Công viên (trang trí): sân chơi (x 850–1300, y 340–520).
  Rect.fromLTWH(850, 340, 450, 180),
  // Hồ: lòng nước giữa (x 1320–1540, y 590–760).
  Rect.fromLTWH(1320, 590, 220, 170),
];

/// Có điểm nào của [route] (đã lệch vỉa hè nếu [sidewalk]) nằm trong
/// vùng chân công trình nào không — kiểm tra độc lập với vùng đường
/// đã khai báo (vùng khai báo sai thì test đường vẫn xanh).
bool routeHitsBuilding(TownRoute route, {required bool sidewalk}) {
  for (var d = 0.0; d <= route.totalLength; d += 5) {
    for (final forward in [true, false]) {
      final sample = route.sample(d, forward);
      var point = sample.point;
      if (sidewalk) {
        point = sidewalkPoint(point, sample.legUnit);
      }
      for (final building in townBuildingFootprints) {
        if (building.contains(point)) return true;
      }
    }
  }
  return false;
}

/// Tuyến xe 2 (xe xanh nhạt): làn phía nam của C2, tới-lui giữa
/// (856, 783) và (1536, 443).
final TownRoute car2Route = TownRoute(const [
  Offset(856, 783),
  Offset(1536, 443),
]);

/// Tuyến người 1 (bé gái): theo tâm C2, vẽ lệch xuống vỉa hè phía nam
/// ([townSidewalkOffset]).
final TownRoute walker1Route = TownRoute(const [
  Offset(820, 785),
  Offset(1250, 570),
]);

/// Tuyến người 2 (bé trai): theo tâm C1, vẽ lệch xuống vỉa hè phía nam.
final TownRoute walker2Route = TownRoute(const [
  Offset(1150, 681),
  Offset(1540, 874),
]);
