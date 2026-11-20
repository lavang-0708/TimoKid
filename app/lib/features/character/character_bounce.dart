/// Bọc nhân vật để bấm vào thì nhảy lên + lấp lánh, đổi đồ thì nảy
/// 'pop' (PR ưu tiên sau v0.0.3 — góp ý "cần xu hướng game hơn,
/// linh động hơn").
///
/// Dùng ở Thị trấn và xem trước màn mở đầu, bọc ngoài `CharacterView`
/// (thở/chớp mắt vẫn do `CharacterView` lo). Cả hai hiệu ứng đều
/// một lần rồi dừng nên `pumpAndSettle` vẫn qua được; cổng
/// [AnimationGate] tắt hẳn khi chạy test để ảnh golden/widget chụp
/// trạng thái tĩnh xác định.
///
/// * Nhảy: bấm vào nhân vật thì nhảy lên ~22 dp rồi rơi xuống
///   (550 ms), 4 ngôi sao `✦` hiện quanh nhân vật lúc đang nhảy rồi
///   mờ dần khi rơi xuống.
/// * Pop: [popKey] đổi giá trị (vd đổi màu tóc/váy ở mở đầu) thì
///   nhân vật phồng lên 1.08 rồi về 1.0 trong 320 ms.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/animation/animation_gate.dart';

class CharacterBounce extends StatefulWidget {
  const CharacterBounce({
    super.key,
    required this.child,
    this.animationsEnabled = true,
    this.popKey,
  });

  /// Nhân vật bên trong (thường là `CharacterView`).
  final Widget child;

  /// Tắt riêng hiệu ứng của bọc này (mặc định bật; cổng chung
  /// [AnimationGate] vẫn có quyền tắt).
  final bool animationsEnabled;

  /// Đổi giá trị thì nhân vật nảy 'pop' một cái. Truyền chuỗi mô tả
  /// lựa chọn hiện tại (vd màu tóc + váy) để pop đúng lúc đổi đồ.
  final Object? popKey;

  @override
  State<CharacterBounce> createState() => _CharacterBounceState();
}

class _CharacterBounceState extends State<CharacterBounce>
    with TickerProviderStateMixin {
  late final AnimationController _jumpController;
  late final AnimationController _popController;
  late final Animation<double> _jumpY;
  late final Animation<double> _sparkle;
  late final Animation<double> _popScale;

  bool get _on => AnimationGate.enabled && widget.animationsEnabled;

  @override
  void initState() {
    super.initState();
    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    // Nhảy: lên nhanh (40%) rồi rơi xuống (60%).
    _jumpY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: -22), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: -22, end: 0), weight: 60),
    ]).animate(CurvedAnimation(parent: _jumpController, curve: Curves.easeOut));
    // Lấp lánh: hiện lúc đang nhảy, mờ dần khi rơi xuống.
    _sparkle = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 70),
    ]).animate(_jumpController);
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _popScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.08), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.08, end: 1), weight: 60),
    ]).animate(CurvedAnimation(parent: _popController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant CharacterBounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_on && widget.popKey != oldWidget.popKey) {
      _popController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _jumpController.dispose();
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cổng tắt (test) hoặc cờ riêng tắt: trả con nguyên vẹn, không
    // bọc GestureDetector để test bấm xuyên qua như bình thường.
    if (!_on) return widget.child;
    return GestureDetector(
      onTap: () => _jumpController.forward(from: 0),
      behavior: HitTestBehavior.translucent,
      child: AnimatedBuilder(
        animation: Listenable.merge([_jumpY, _sparkle, _popScale]),
        builder: (context, child) => Transform.translate(
          key: const Key('character-bounce-jump'),
          offset: Offset(0, _jumpY.value),
          child: Transform.scale(
            key: const Key('character-bounce-pop'),
            scale: _popScale.value,
            alignment: Alignment.bottomCenter,
            child: Stack(
              clipBehavior: Clip.none,
              children: [child!, ..._sparkles()],
            ),
          ),
        ),
        child: widget.child,
      ),
    );
  }

  /// 4 ngôi sao quanh nhân vật, chỉ hiện lúc đang nhảy. Dùng
  /// `Icons.star` (MaterialIcons) thay vì ký tự `✦`: Nunito (phông
  /// của app) không có ký tự dingbat nên chữ sẽ thành ô vuông trên
  /// máy thật (cùng bài học ở T1-09: chỉ dùng ký tự có trong phông).
  List<Widget> _sparkles() {
    if (_sparkle.value <= 0.01) return const [];
    const positions = <Alignment>[
      Alignment(-0.9, -0.9),
      Alignment(0.9, -0.7),
      Alignment(-0.7, -0.4),
      Alignment(0.8, -0.2),
    ];
    return [
      for (final position in positions)
        Align(
          alignment: position,
          child: Opacity(
            opacity: _sparkle.value,
            child: Transform.scale(
              scale: 0.6 + 0.6 * _sparkle.value,
              child: const Icon(Icons.star, size: 22, color: Color(0xFFFFC93C)),
            ),
          ),
        ),
    ];
  }
}
