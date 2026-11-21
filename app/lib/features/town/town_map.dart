/// Bản đồ Thị trấn phong cách v3b (C): nền + lớp động + vùng bấm.
///
/// Nền `town_v3.png` (1600x900, isometric) vẽ đủ 6 công trình; 5 khu
/// toán là vùng bấm đặt đúng hình chữ nhật công trình (xem
/// [townAreas] trong `town_assets.dart`), nhà hồng là nút về Phòng.
/// 17 lớp động (mây, xe, cây, người đi bộ) là PNG trong suốt
/// 512x512 đặt theo tỉ lệ khung nền, chuyển động bằng Flutter
/// animation.
///
/// Tọa độ lớp động và vùng bấm đều tính theo tỉ lệ khung nền
/// 1600x900 (x theo chiều rộng, y theo chiều cao): bản đồ hiển thị
/// trong hộp đúng tỉ lệ 16:9 (`AspectRatio`) nên vị trí không lệch
/// dù màn to hay nhỏ. Ảnh nền vẽ bằng `BoxFit.fill` trong hộp đó
/// (không `cover` như màn Phòng — `cover` cắt nền sẽ làm lệch vùng
/// bấm).
///
/// Xe chạy GIỮA làn, người đi trên vỉa hè (lệch tâm đường
/// [townSidewalkOffset] = 46 px), theo các tuyến khai báo trong
/// `town_roads.dart` (đường C1/C2, nửa rộng vùng đường 60 px). Xe/người chọn biến thể lớp
/// (dr/ur) + lật ngang theo hướng di chuyển (xem `town_roads.dart`
/// — `ur` của xe là xe nhìn từ sau, đầu xe ↖). Lớp động vẽ theo
/// thứ tự chiều sâu: càng ở dưới màn hình (y chân lớn) càng vẽ sau
/// (che lớp ở trên). Xe/người có bóng đổ ellipse mềm do app vẽ
/// dưới chân (mẫu `_SoftShadow` ở màn Phòng); PNG lớp động không
/// có bóng sẵn.
///
/// Chuyển động chỉ chạy khi cổng [AnimationGate] bật (máy thật);
/// khi chạy test thì mọi lớp đứng yên ở vị trí ban đầu để
/// `pumpAndSettle` dừng được và ảnh golden xác định (mẫu
/// `_RoomEggWiggle` ở màn Phòng).
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/animation/animation_gate.dart';
import '../../core/database/models.dart';
import '../../core/widgets/press_bounce.dart';
import 'town_assets.dart';
import 'town_roads.dart';

/// Bản đồ Thị trấn: nền + lớp động + vùng bấm 5 khu + nhà hồng.
///
/// [statuses] là trạng thái 5 chặng hôm nay (cùng thứ tự
/// [townAreas]); [onAreaTap] nhận chỉ số chặng khi bé bấm công
/// trình của khu; [onRoomTap] khi bé bấm nhà hồng.
class TownMap extends StatefulWidget {
  const TownMap({
    super.key,
    required this.statuses,
    required this.onAreaTap,
    required this.onRoomTap,
  });

  final List<String> statuses;
  final ValueChanged<int> onAreaTap;
  final VoidCallback onRoomTap;

  @override
  State<TownMap> createState() => _TownMapState();
}

/// Mây trôi ngang qua bầu trời, lặp với wrap (hai đầu ngoài khung
/// nên lúc quay lại không thấy).
class _CloudSpec {
  const _CloudSpec({
    required this.asset,
    required this.top,
    required this.width,
    required this.rightward,
    required this.speed,
    required this.phase,
    required this.opacity,
  });

  /// Đường dẫn asset PNG của mây.
  final String asset;

  /// Mép trên của hộp mây, tỉ lệ chiều cao bản đồ.
  final double top;

  /// Bề rộng hộp mây (hộp vuông), tỉ lệ chiều rộng bản đồ.
  final double width;

  /// true = trôi sang phải, false = trôi sang trái.
  final bool rightward;

  /// Tốc độ: số vòng trên một chu kỳ bộ điều khiển mây (90 giây).
  final double speed;

  /// Vị trí ban đầu 0..1 (cũng là vị trí khi cổng tắt).
  final double phase;

  /// Độ mờ của mây (1.0 = đặc; vòng sửa PR #31: mây nhỏ + mờ hơn,
  /// chỉ ở dải trời).
  final double opacity;
}

const List<_CloudSpec> _clouds = [
  // Vòng sửa PR #31 (21/11): mây cũ to + thấp (mép dưới tới y ≈ 150–
  // 210 khung nền) đè lều Hội chợ và cỏ. Mây mới CHỈ ở dải trời
  // y < 120: mép dưới phần mây nhìn thấy = top*900 +
  // (đáy alpha/512)*width*1600 — đo từ PNG thật (cloud_01 alpha
  // y 117–394, cloud_02 y 156–356, cloud_03 y 100–411):
  // mây 1: 0 + 0,770*0,09*1600 ≈ 111; mây 2: 18 + 0,695*0,085*1600
  // ≈ 112; mây 3: 0 + 0,803*0,07*1600 ≈ 90 — đều < 120. Nhãn dán ở
  // cuối vùng bấm (y ≥ 250) nên mây không bao giờ chạm nhãn.
  _CloudSpec(
    asset: 'assets/images/town/cloud_01.png',
    top: 0.00,
    width: 0.09,
    rightward: true,
    speed: 1.0,
    phase: 0.0,
    opacity: 0.75,
  ),
  _CloudSpec(
    asset: 'assets/images/town/cloud_02.png',
    top: 0.02,
    width: 0.085,
    rightward: false,
    speed: 0.7,
    phase: 0.3,
    opacity: 0.75,
  ),
  _CloudSpec(
    asset: 'assets/images/town/cloud_03.png',
    top: 0.00,
    width: 0.07,
    rightward: true,
    speed: 1.3,
    phase: 0.6,
    opacity: 0.75,
  ),
];

/// Xe/người chạy tới-lui trên một tuyến đường ([TownRoute]).
class _RouteActor {
  const _RouteActor({
    required this.model,
    required this.isCar,
    required this.route,
    required this.width,
    required this.anchorRow,
    required this.speed,
    required this.phase,
    required this.sidewalk,
  });

  /// Mẫu xe/người: `car_01`, `car_02`, `person_01`, `person_02`.
  final String model;

  /// true = xe (chạy giữa làn), false = người (đi trên vỉa hè).
  final bool isCar;

  /// Tuyến đường (xem `town_roads.dart`).
  final TownRoute route;

  /// Bề rộng hộp (hộp vuông), tỉ lệ chiều rộng bản đồ.
  final double width;

  /// Hàng đáy (chân/bánh xe) trong khung ảnh 512: xe 390, người
  /// 470 (đo từ PNG thật, xem `docs/C_IMAGES.md`).
  final double anchorRow;

  /// Tốc độ: số vòng ping-pong trên một chu kỳ bộ điều khiển.
  final double speed;

  /// Vị trí ban đầu 0..1 (cũng là vị trí khi cổng tắt).
  final double phase;

  /// true = người đi bộ: lệch [townSidewalkOffset] px sang vỉa hè phía nam đường.
  final bool sidewalk;
}

// Xe chạy giữa làn (xe hồng trên C1, xe xanh nhạt trên C2, hai
// đường chéo cắt nhau ở ngã tư lớn); người đi trên vỉa hè phía nam
// (bé gái dọc C2, bé trai dọc C1). Pha chọn sao cho ở t = 0 cả 4 đều ở giữa đường, hướng ↘/↗
// (xe 1 ↘, xe 2 ↘, người 1 ↗, người 2 ↙ — xem test hướng).
// (Không `const`: tuyến đường tính tổng dài bằng code nên không
// phải biểu thức hằng.)
final List<_RouteActor> _actors = [
  _RouteActor(
    model: 'car_01',
    isCar: true,
    route: car1Route,
    width: 0.105,
    anchorRow: 390,
    speed: 1.0,
    phase: 0.31,
    sidewalk: false,
  ),
  _RouteActor(
    model: 'car_02',
    isCar: true,
    route: car2Route,
    width: 0.105,
    anchorRow: 390,
    speed: 1.0,
    phase: 0.27,
    sidewalk: false,
  ),
  _RouteActor(
    model: 'person_01',
    isCar: false,
    route: walker1Route,
    width: 0.04,
    anchorRow: 470,
    speed: 1.0,
    phase: 0.27,
    sidewalk: true,
  ),
  _RouteActor(
    model: 'person_02',
    isCar: false,
    route: walker2Route,
    width: 0.04,
    anchorRow: 470,
    speed: 1.0,
    phase: 0.16,
    sidewalk: true,
  ),
];

/// Cây đung đưa nhẹ: xoay ±2° quanh gốc thân. Neo theo chân cây
/// (tọa độ khung nền 1600x900) + hàng đáy trong khung ảnh 512
/// (đo từ PNG thật: cây xanh 484, cây anh đào 469).
class _TreeSpec {
  const _TreeSpec({
    required this.asset,
    required this.feet,
    required this.width,
    required this.anchorRow,
    required this.phase,
  });

  /// Đường dẫn asset PNG của cây.
  final String asset;

  /// Chân cây (gốc thân), tọa độ px theo khung nền 1600x900.
  final Offset feet;

  /// Bề rộng hộp cây (hộp vuông), tỉ lệ chiều rộng bản đồ.
  final double width;

  /// Hàng đáy (gốc thân) trong khung ảnh 512.
  final double anchorRow;

  /// Pha đung đưa 0..1 (hai cây lệch pha nhau).
  final double phase;
}

const List<_TreeSpec> _trees = [
  _TreeSpec(
    asset: 'assets/images/town/tree_01.png',
    // Cây xanh ở góc cỏ trên-trái, đè khít cây vẽ sẵn (gốc thân ở
    // (130, 230)) — vòng sửa PR #31: chân cũ (72, 200) đặt trên
    // mép lối đi sáng màu, không bóng đổ nên nhìn như nổi trên vỉa
    // hè; chân mới đúng gốc cây vẽ sẵn, trên cỏ, có bóng đổ neo
    // đúng chân (xem _treeLayer).
    feet: Offset(130, 230),
    width: 0.08,
    anchorRow: 484,
    phase: 0.0,
  ),
  _TreeSpec(
    asset: 'assets/images/town/tree_02.png',
    // Cây anh đào ở dải cỏ đáy, giữa đường D5 và mép dưới —
    // không chồng công trình, không chặn đường xe/người.
    feet: Offset(1000, 865),
    width: 0.09,
    anchorRow: 469,
    phase: 0.5,
  ),
];

class _TownMapState extends State<TownMap> with TickerProviderStateMixin {
  AnimationController? _cloudsController;
  AnimationController? _carsController;
  AnimationController? _peopleController;
  AnimationController? _treesController;

  @override
  void initState() {
    super.initState();
    // Hiệu ứng lặp chỉ chạy khi cổng bật (máy thật); khi chạy test
    // thì không tạo bộ điều khiển nào, mọi lớp đứng yên ở vị trí
    // ban đầu để `pumpAndSettle` dừng được.
    if (!AnimationGate.enabled) return;
    _cloudsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 90),
    )..repeat();
    _carsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _peopleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
    _treesController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _cloudsController?.dispose();
    _carsController?.dispose();
    _peopleController?.dispose();
    _treesController?.dispose();
    super.dispose();
  }

  double get _cloudT => _cloudsController?.value ?? 0;
  double get _carT => _carsController?.value ?? 0;
  double get _peopleT => _peopleController?.value ?? 0;
  double get _treeT => _treesController?.value ?? 0;

  @override
  Widget build(BuildContext context) {
    // Vẽ lại bản đồ mỗi khung hình khi hiệu ứng chạy; khi cổng tắt
    // thì vẽ một lần tĩnh. Cây widget dựng mới mỗi lần vẽ nên vị trí
    // lớp động đọc đúng giá trị bộ điều khiển hiện tại.
    Widget buildMap() {
      return Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(townBackgroundAsset, fit: BoxFit.fill),
                  ),
                  ..._dynamicLayers(w, h),
                  ..._tapZones(w, h),
                ],
              );
            },
          ),
        ),
      );
    }

    final controllers = [
      _cloudsController,
      _carsController,
      _peopleController,
      _treesController,
    ];
    if (controllers.every((c) => c == null)) return buildMap();
    return AnimatedBuilder(
      animation: Listenable.merge(
        controllers.whereType<AnimationController>().toList(),
      ),
      builder: (context, child) => buildMap(),
    );
  }

  /// 17 lớp động, vẽ theo thứ tự dưới lên trên: lớp mặt đất (cây,
  /// xe, người) sắp theo chiều sâu — càng ở dưới màn hình (y chân
  /// lớn) càng vẽ sau, che lớp ở trên — rồi mây trên trời.
  List<Widget> _dynamicLayers(double w, double h) {
    final ground = <_GroundLayer>[];
    for (final tree in _trees) {
      ground.add(_GroundLayer(tree.feet.dy, _treeLayer(tree, w, h)));
    }
    for (final actor in _actors) {
      final state = _routeState(actor, actor.isCar ? _carT : _peopleT);
      ground.add(
        _GroundLayer(state.point.dy, _routeWidget(actor, state, w, h)),
      );
    }
    ground.sort((a, b) => a.feetY.compareTo(b.feetY));
    return [
      for (final layer in ground) layer.widget,
      for (final cloud in _clouds)
        Positioned(
          key: Key('town-layer-${_keyOf(cloud.asset)}'),
          left: w * _cloudX(cloud),
          top: h * cloud.top,
          width: w * cloud.width,
          height: w * cloud.width,
          child: Image.asset(
            cloud.asset,
            fit: BoxFit.contain,
            opacity: AlwaysStoppedAnimation(cloud.opacity),
          ),
        ),
    ];
  }

  /// Vị trí x hiện tại của một đám mây (tỉ lệ chiều rộng bản đồ).
  double _cloudX(_CloudSpec cloud) {
    final p = (_cloudT * cloud.speed + cloud.phase) % 1.0;
    return cloud.rightward ? -0.16 + p * 1.20 : 1.04 - p * 1.20;
  }

  /// Trạng thái hiện tại của một xe/người trên tuyến: vị trí chân,
  /// hướng di chuyển, lớp ảnh đã chọn (biến thể + lật), quãng đường
  /// đã đi (để tính khung bước chân).
  _RouteState _routeState(_RouteActor actor, double t) {
    final progress = (t * actor.speed + actor.phase) % 1.0;
    final distance = pingPongProgress(progress) * actor.route.totalLength;
    final forward = pingPongForward(progress);
    final sample = actor.route.sample(distance, forward);
    var point = sample.point;
    if (actor.sidewalk) {
      point = sidewalkPoint(point, sample.legUnit);
    }
    final choice = actor.isCar
        ? carSpriteFor(actor.model, sample.direction)
        : personSpriteFor(actor.model, sample.direction, walkFrameB(distance));
    return _RouteState(
      point: point,
      direction: sample.direction,
      choice: choice,
      distance: distance,
    );
  }

  /// Một xe/người ở vị trí hiện tại: hộp vuông neo chân tại [state],
  /// bóng đổ mềm dưới chân, ảnh lật ngang nếu cần; người đi bộ nhún
  /// nhẹ theo nhịp bước (chỉ ảnh nhún, bóng ở yên dưới chân).
  Widget _routeWidget(
    _RouteActor actor,
    _RouteState state,
    double w,
    double h,
  ) {
    final size = w * actor.width;
    final anchorX = state.point.dx / townFrameWidth * w;
    final anchorY = state.point.dy / townFrameHeight * h;
    // Mép đáy (chân/bánh xe) nằm ở anchorRow/512 chiều cao hộp.
    final bottom = size * actor.anchorRow / 512;
    final shadowHeight = size * 0.10;
    Widget sprite = Image.asset(state.choice.asset, fit: BoxFit.contain);
    if (state.choice.flipHorizontal) {
      sprite = Transform.flip(flipX: true, child: sprite);
    }
    if (!actor.isCar) {
      // Nhún nhẹ theo nhịp bước: lên xuống ~0,6% chiều cao bản đồ,
      // về 0 đúng lúc đổi khung bước chân (mỗi 30 px đường đã đi).
      final bob = 0.006 * h * math.sin(math.pi * state.distance / 30).abs();
      sprite = Transform.translate(offset: Offset(0, -bob), child: sprite);
    }
    return Positioned(
      key: Key('town-layer-${_keyOf(state.choice.asset)}'),
      left: anchorX - size / 2,
      top: anchorY - bottom,
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: size * 0.075,
            top: bottom - shadowHeight * 0.3,
            width: size * 0.85,
            height: shadowHeight,
            child: const _SoftShadow(),
          ),
          Positioned.fill(child: sprite),
        ],
      ),
    );
  }

  /// Một cây ở vị trí chân cây: hộp vuông neo gốc thân tại [tree.feet],
  /// đung đưa ±2° quanh gốc, bóng đổ mềm neo đúng chân (mẫu xe/người
  /// — cây cũ không có bóng nên nhìn như nổi).
  Widget _treeLayer(_TreeSpec tree, double w, double h) {
    final size = w * tree.width;
    final feetX = tree.feet.dx / townFrameWidth * w;
    final feetY = tree.feet.dy / townFrameHeight * h;
    // Mép đáy (gốc thân) nằm ở anchorRow/512 chiều cao hộp.
    final bottom = size * tree.anchorRow / 512;
    final shadowHeight = size * 0.10;
    return Positioned(
      key: Key('town-layer-${_keyOf(tree.asset)}'),
      left: feetX - size / 2,
      top: feetY - bottom,
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: size * 0.075,
            top: bottom - shadowHeight * 0.3,
            width: size * 0.85,
            height: shadowHeight,
            child: const _SoftShadow(),
          ),
          Positioned.fill(
            child: Transform.rotate(
              alignment: Alignment.bottomCenter,
              angle: 0.035 * math.sin(2 * math.pi * (_treeT + tree.phase)),
              child: Image.asset(tree.asset, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }

  /// Vùng bấm 5 khu + nhà hồng, vẽ trên cùng để nhãn đọc được và
  /// vùng bấm không bị lớp động che (lớp động không nhận chạm nên
  /// dù vẽ dưới, bấm vẫn xuyên qua được).
  List<Widget> _tapZones(double w, double h) {
    // Nhãn co theo bề rộng bản đồ (bản đồ 400 dp trở lên giữ cỡ
    // chữ đầy đủ; bản đồ nhỏ hơn co tối đa còn 60% để vừa 608x248
    // mà không tràn — chữ nhỏ ở cỡ này chỉ để test, máy thật dùng
    // cỡ đầy đủ).
    final labelScale = (w / 400).clamp(0.6, 1.0);
    return [
      for (var i = 0; i < townAreas.length; i++)
        Positioned(
          left: w * townAreas[i].building.left,
          top: h * townAreas[i].building.top,
          width: w * townAreas[i].building.width,
          height: h * townAreas[i].building.height,
          child: PressBounce(
            child: GestureDetector(
              key: Key('town-stage-$i-button'),
              onTap: () => widget.onAreaTap(i),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: Colors.transparent),
                  ),
                  Positioned(
                    left: 2,
                    right: 2,
                    bottom: 2,
                    child: _AreaLabel(
                      area: townAreas[i],
                      status: widget.statuses[i],
                      scale: labelScale,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      Positioned(
        left: w * roomBuildingRect.left,
        top: h * roomBuildingRect.top,
        width: w * roomBuildingRect.width,
        height: h * roomBuildingRect.height,
        child: PressBounce(
          child: GestureDetector(
            key: const Key('town-room-house-button'),
            onTap: widget.onRoomTap,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Colors.transparent),
                ),
                Positioned(
                  left: 2,
                  right: 2,
                  bottom: 2,
                  child: _RoomLabel(scale: labelScale),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  /// Tên file không đuôi (vd `car_01_dr`) để đặt khóa widget cho test.
  static String _keyOf(String asset) => asset.split('/').last.split('.').first;
}

/// Một lớp mặt đất + y chân của nó (để sắp theo chiều sâu).
class _GroundLayer {
  const _GroundLayer(this.feetY, this.widget);

  /// y chân (tọa độ khung nền 1600x900): càng lớn càng gần người
  /// xem, vẽ sau (che lớp có y chân nhỏ hơn).
  final double feetY;

  final Widget widget;
}

/// Trạng thái hiện tại của một xe/người trên tuyến.
class _RouteState {
  const _RouteState({
    required this.point,
    required this.direction,
    required this.choice,
    required this.distance,
  });

  /// Vị trí chân (đã lệch vỉa hè nếu là người), tọa độ khung nền.
  final Offset point;

  /// Hướng di chuyển tại điểm đó.
  final TownTravelDirection direction;

  /// Lớp ảnh đã chọn (biến thể + lật ngang).
  final TownSpriteChoice choice;

  /// Quãng đường đã đi từ đầu tuyến (px khung nền).
  final double distance;
}

/// Bóng đổ mềm dưới chân xe/người (mẫu màn Phòng): ellipse đen
/// 20%, viền mờ dần (làm mờ bằng MaskFilter để bóng loang đều theo
/// ellipse, không bị viền cứng). PNG lớp động không có bóng sẵn.
class _SoftShadow extends StatelessWidget {
  const _SoftShadow();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SoftShadowPainter());
  }
}

class _SoftShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Nhãn dán trên công trình: tên khu + nhãn trạng thái chặng hôm nay.
class _AreaLabel extends StatelessWidget {
  const _AreaLabel({
    required this.area,
    required this.status,
    required this.scale,
  });

  final TownArea area;
  final String status;

  /// Hệ số co chữ theo bề rộng bản đồ (1.0 ở bản đồ ≥ 400 dp).
  final double scale;

  @override
  Widget build(BuildContext context) {
    final (label, chipColor) = switch (status) {
      StageStatus.done => ('Xong ✓', Colors.green.shade600),
      StageStatus.inProgress => ('Đang làm', Colors.amber.shade700),
      _ => ('Chưa làm', Colors.grey.shade600),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(area.color)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            area.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 2 * scale),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 1),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(fontSize: 10 * scale, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhãn dán trên nhà hồng: tên + gợi ý vào phòng (không có trạng
/// thái chặng như 5 khu toán).
class _RoomLabel extends StatelessWidget {
  const _RoomLabel({required this.scale});

  /// Hệ số co chữ theo bề rộng bản đồ (1.0 ở bản đồ ≥ 400 dp).
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF2A7C3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Phòng của bé',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 2 * scale),
          // Thu nhỏ cả hàng khi hẹp (font test Ahem rộng hơn Nunito
          // thật nên ở local hàng này vượt chiều rộng nhãn — giống
          // cách nhãn trạng thái dùng FittedBox ở _AreaLabel).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home_outlined, size: 12 * scale),
                const SizedBox(width: 2),
                Text('Vào phòng', style: TextStyle(fontSize: 10 * scale)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
