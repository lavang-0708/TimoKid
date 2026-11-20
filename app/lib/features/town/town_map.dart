/// Bản đồ Thị trấn phong cách v2 (A2): nền + lớp động + vùng bấm.
///
/// Nền `town_v2.png` (1600x900, isometric) vẽ đủ 6 công trình; 5 khu
/// toán là vùng bấm đặt đúng hình chữ nhật công trình (xem
/// [townAreas] trong `town_assets.dart`), nhà hồng là nút về Phòng.
/// 10 lớp động (mây, xe, đài phun nước, cây, người đi bộ) là PNG
/// trong suốt 512x512 đặt theo tỉ lệ khung nền, chuyển động bằng
/// Flutter animation.
///
/// Tọa độ lớp động và vùng bấm đều tính theo tỉ lệ khung nền
/// 1600x900 (x theo chiều rộng, y theo chiều cao): bản đồ hiển thị
/// trong hộp đúng tỉ lệ 16:9 (`AspectRatio`) nên vị trí không lệch
/// dù màn to hay nhỏ. Ảnh nền vẽ bằng `BoxFit.fill` trong hộp đó
/// (không `cover` như màn Phòng — `cover` cắt nền sẽ làm lệch vùng
/// bấm).
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
}

const List<_CloudSpec> _clouds = [
  _CloudSpec(
    asset: 'assets/images/town/cloud_01.png',
    top: 0.00,
    width: 0.12,
    rightward: true,
    speed: 1.0,
    phase: 0.0,
  ),
  _CloudSpec(
    asset: 'assets/images/town/cloud_02.png',
    top: 0.04,
    width: 0.13,
    rightward: false,
    speed: 0.7,
    phase: 0.3,
  ),
  _CloudSpec(
    asset: 'assets/images/town/cloud_03.png',
    top: 0.08,
    width: 0.11,
    rightward: true,
    speed: 1.3,
    phase: 0.6,
  ),
];

/// Xe/người đi dọc đường/vỉa hè: từ điểm đầu tới điểm cuối (tọa độ
/// tỉ lệ so với khung bản đồ), rồi lặp lại từ đầu (hai đầu ngoài
/// khung nên lúc quay lại không thấy).
class _PathSpec {
  const _PathSpec({
    required this.asset,
    required this.start,
    required this.end,
    required this.width,
    required this.speed,
    required this.phase,
    this.bob = false,
  });

  /// Đường dẫn asset PNG.
  final String asset;

  /// Điểm đầu (x tỉ lệ rộng, y tỉ lệ cao) và điểm cuối của đường đi.
  final Offset start;
  final Offset end;

  /// Bề rộng hộp (hộp vuông), tỉ lệ chiều rộng bản đồ.
  final double width;

  /// Tốc độ: số vòng trên một chu kỳ bộ điều khiển.
  final double speed;

  /// Vị trí ban đầu 0..1 (cũng là vị trí khi cổng tắt).
  final double phase;

  /// true = người đi bộ: nhún nhẹ theo nhịp bước.
  final bool bob;
}

// Xe chạy theo đường trong nền (đường dưới từ trái sang phải, đường
// trên từ phải sang trái; mặt xe quay theo hướng chạy).
const List<_PathSpec> _vehicles = [
  _PathSpec(
    asset: 'assets/images/town/car_01.png',
    start: Offset(-0.10, 0.95),
    end: Offset(1.05, 0.63),
    width: 0.075,
    speed: 1.0,
    phase: 0.0,
  ),
  _PathSpec(
    asset: 'assets/images/town/car_02.png',
    start: Offset(1.10, 0.24),
    end: Offset(-0.08, 0.48),
    width: 0.075,
    speed: 1.2,
    phase: 0.45,
  ),
];

// Người đi bộ dọc vỉa hè (bé gái đường dưới, bé trai đường trên).
const List<_PathSpec> _walkers = [
  _PathSpec(
    asset: 'assets/images/town/person_01.png',
    start: Offset(-0.06, 0.98),
    end: Offset(1.04, 0.67),
    width: 0.04,
    speed: 1.0,
    phase: 0.0,
    bob: true,
  ),
  _PathSpec(
    asset: 'assets/images/town/person_02.png',
    start: Offset(1.04, 0.29),
    end: Offset(-0.06, 0.52),
    width: 0.04,
    speed: 0.85,
    phase: 0.55,
    bob: true,
  ),
];

/// Đài phun nước ở giữa công viên (hộp vuông, tỉ lệ chiều rộng bản
/// đồ): nước phun nhấp nhô (scale + opacity theo chu kỳ 1,8 giây).
const double _fountainLeft = 0.655;
const double _fountainTop = 0.33;
const double _fountainWidth = 0.13;

/// Cây đung đưa nhẹ: xoay ±2° quanh gốc thân.
class _TreeSpec {
  const _TreeSpec({
    required this.asset,
    required this.left,
    required this.top,
    required this.width,
    required this.phase,
  });

  /// Đường dẫn asset PNG của cây.
  final String asset;

  /// Góc trên-trái của hộp cây, tỉ lệ khung bản đồ.
  final double left;
  final double top;

  /// Bề rộng hộp cây (hộp vuông), tỉ lệ chiều rộng bản đồ.
  final double width;

  /// Pha đung đưa 0..1 (hai cây lệch pha nhau).
  final double phase;
}

const List<_TreeSpec> _trees = [
  _TreeSpec(
    asset: 'assets/images/town/tree_01.png',
    left: 0.75,
    top: 0.77,
    width: 0.10,
    phase: 0.0,
  ),
  _TreeSpec(
    asset: 'assets/images/town/tree_02.png',
    left: 0.83,
    top: 0.27,
    width: 0.10,
    phase: 0.5,
  ),
];

class _TownMapState extends State<TownMap> with TickerProviderStateMixin {
  AnimationController? _cloudsController;
  AnimationController? _carsController;
  AnimationController? _peopleController;
  AnimationController? _fountainController;
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
    _fountainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
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
    _fountainController?.dispose();
    _treesController?.dispose();
    super.dispose();
  }

  double get _cloudT => _cloudsController?.value ?? 0;
  double get _carT => _carsController?.value ?? 0;
  double get _peopleT => _peopleController?.value ?? 0;
  double get _fountainT => _fountainController?.value ?? 0;
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
      _fountainController,
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

  /// 10 lớp động, vẽ theo thứ tự dưới lên trên: cây + đài phun ở
  /// mặt đất, xe + người trên đường, mây trên trời.
  List<Widget> _dynamicLayers(double w, double h) {
    return [
      for (final tree in _trees)
        Positioned(
          key: Key('town-layer-${_keyOf(tree.asset)}'),
          left: w * tree.left,
          top: h * tree.top,
          width: w * tree.width,
          height: w * tree.width,
          child: Transform.rotate(
            alignment: Alignment.bottomCenter,
            angle: 0.035 * math.sin(2 * math.pi * (_treeT + tree.phase)),
            child: Image.asset(tree.asset, fit: BoxFit.contain),
          ),
        ),
      Positioned(
        key: const Key('town-layer-fountain'),
        left: w * _fountainLeft,
        top: h * _fountainTop,
        width: w * _fountainWidth,
        height: w * _fountainWidth,
        child: Opacity(
          opacity:
              0.94 + 0.06 * (0.5 + 0.5 * math.sin(2 * math.pi * _fountainT)),
          child: Transform.scale(
            scale: 1 + 0.04 * math.sin(2 * math.pi * _fountainT),
            child: Image.asset(
              'assets/images/town/fountain.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
      for (final car in _vehicles) _pathLayer(car, _carT, w, h),
      for (final person in _walkers) _pathLayer(person, _peopleT, w, h),
      for (final cloud in _clouds)
        Positioned(
          key: Key('town-layer-${_keyOf(cloud.asset)}'),
          left: w * _cloudX(cloud),
          top: h * cloud.top,
          width: w * cloud.width,
          height: w * cloud.width,
          child: Image.asset(cloud.asset, fit: BoxFit.contain),
        ),
    ];
  }

  /// Vị trí x hiện tại của một đám mây (tỉ lệ chiều rộng bản đồ).
  double _cloudX(_CloudSpec cloud) {
    final p = (_cloudT * cloud.speed + cloud.phase) % 1.0;
    return cloud.rightward ? -0.16 + p * 1.20 : 1.04 - p * 1.20;
  }

  /// Một lớp chạy dọc đường (xe/người) ở vị trí hiện tại.
  Widget _pathLayer(_PathSpec spec, double t, double w, double h) {
    final p = (t * spec.speed + spec.phase) % 1.0;
    final cx = spec.start.dx + (spec.end.dx - spec.start.dx) * p;
    var cy = spec.start.dy + (spec.end.dy - spec.start.dy) * p;
    if (spec.bob) {
      // Nhún nhẹ theo nhịp bước: lên xuống ~0,6% chiều cao bản đồ.
      cy -= 0.006 * (math.sin(2 * math.pi * t * 20).abs());
    }
    final size = w * spec.width;
    return Positioned(
      key: Key('town-layer-${_keyOf(spec.asset)}'),
      left: (cx - spec.width / 2) * w,
      top: cy * h - size / 2,
      width: size,
      height: size,
      child: Image.asset(spec.asset, fit: BoxFit.contain),
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

  /// Tên file không đuôi (vd `car_01`) để đặt khóa widget cho test.
  static String _keyOf(String asset) => asset.split('/').last.split('.').first;
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
