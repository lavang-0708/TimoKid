/// Vùng mở menu QA ẩn (T1-13).
///
/// Gắn một vùng vô hình ở góc trên-trái màn hình (PLAN mục (i)):
/// nhấn giữ liên tục 5 giây thì mở [QaMenuScreen]. Vùng này chỉ
/// được gắn khi [QaConfig.enabled] (bản debug hoặc bản có cờ QA);
/// bản release giao cho bé không có vùng này.
///
/// Kỹ thuật: [Listener] với [HitTestBehavior.translucent] — vùng
/// trong suốt vẫn nhận sự kiện nhấn, đồng thời sự kiện vẫn đi tiếp
/// tới widget bên dưới (nút Về, tiêu đề AppBar...) nên thao tác
/// thường của bé không bị chặn. Nhấn giữ dùng [Timer] 5 giây +
/// [AnimationController] vẽ vòng tiến độ nhỏ trong góc để người giữ
/// biết là đang giữ (buông tay trước 5 giây thì hủy).
///
/// Mở menu bằng [AppRouter.router.push] (không dùng `Navigator.of`):
/// vùng này nằm trong `builder` của `MaterialApp.router` nên context
/// của nó ở ngoài Navigator.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import 'qa_config.dart';
import 'qa_menu_screen.dart';

/// Bọc toàn app: gắn vùng mở menu QA lên trên mọi màn hình khi QA bật.
class QaMenuOpener extends StatelessWidget {
  const QaMenuOpener({
    super.key,
    required this.child,
    this.enabled = QaConfig.enabled,
  });

  /// Nội dung app (màn hình hiện tại của router).
  final Widget child;

  /// Có gắn vùng mở menu không. Mặc định theo [QaConfig.enabled];
  /// tham số này chỉ để test kiểm tra được cả hai trạng thái.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Stack(
      children: [
        child,
        const Positioned(top: 0, left: 0, child: _QaCornerZone()),
      ],
    );
  }
}

/// Vùng nhấn giữ 5 giây ở góc trên-trái để mở menu QA.
class _QaCornerZone extends StatefulWidget {
  const _QaCornerZone();

  @override
  State<_QaCornerZone> createState() => _QaCornerZoneState();
}

class _QaCornerZoneState extends State<_QaCornerZone>
    with SingleTickerProviderStateMixin {
  /// Phải giữ liên tục từng này thì menu mở (PLAN mục (i)).
  static const _holdDuration = Duration(seconds: 5);

  /// Kích thước vùng góc (dp): đủ lớn để nhấn giữ, đủ nhỏ để vẫn là "góc".
  static const _zoneSize = 72.0;

  Timer? _timer;
  late final AnimationController _progress;
  bool _pressing = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: _holdDuration);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progress.dispose();
    super.dispose();
  }

  void _startPress() {
    _timer?.cancel();
    _timer = Timer(_holdDuration, _openMenu);
    _progress.forward(from: 0);
    setState(() => _pressing = true);
  }

  void _cancelPress() {
    _timer?.cancel();
    _progress.reset();
    if (_pressing) setState(() => _pressing = false);
  }

  void _openMenu() {
    _cancelPress();
    if (!mounted) return;
    AppRouter.router.push(QaMenuScreen.route);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: const Key('qa-corner-zone'),
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _startPress(),
      onPointerUp: (_) => _cancelPress(),
      onPointerCancel: (_) => _cancelPress(),
      child: SizedBox(
        width: _zoneSize,
        height: _zoneSize,
        child: _pressing
            ? Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (context, _) => CircularProgressIndicator(
                      value: _progress.value,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
