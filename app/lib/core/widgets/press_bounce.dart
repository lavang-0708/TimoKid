/// Nút nảy nhẹ khi bấm (PR ưu tiên sau v0.0.3 — góp ý "cần xu hướng
/// game hơn, linh động hơn").
///
/// Bọc ngoài nút có sẵn (mở đầu, Thị trấn, màn nở): lúc nhấn xuống
/// thì nút co lại 0.94 trong 140 ms, nhả ra thì về 1.0. Chỉ là hiệu
/// ứng một lần nên `pumpAndSettle` vẫn qua được; cổng [AnimationGate]
/// tắt hẳn khi chạy test để ảnh golden/widget chụp trạng thái tĩnh.
///
/// `Listener` không chặn cử chỉ: nút bên trong vẫn nhận bấm như
/// thường, bọc này chỉ thêm co giãn.
library;

import 'package:material_ui/material_ui.dart';

import '../animation/animation_gate.dart';

class PressBounce extends StatefulWidget {
  const PressBounce({
    super.key,
    required this.child,
    this.animationsEnabled = true,
  });

  /// Nút bên trong.
  final Widget child;

  /// Tắt riêng hiệu ứng của bọc này (mặc định bật; cổng chung
  /// [AnimationGate] vẫn có quyền tắt).
  final bool animationsEnabled;

  @override
  State<PressBounce> createState() => _PressBounceState();
}

class _PressBounceState extends State<PressBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  bool get _on => AnimationGate.enabled && widget.animationsEnabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_on) return widget.child;
    return Listener(
      onPointerDown: (_) => _controller.forward(),
      onPointerUp: (_) => _controller.reverse(),
      onPointerCancel: (_) => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          key: const Key('press-bounce-scale'),
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
