/// Biểu tượng đám mây nhỏ trên HUD Thị trấn/Phòng (T3-04): đã đồng bộ /
/// đang đồng bộ / mất mạng / lỗi / chưa đăng nhập. Chạm vào (qua cổng phụ
/// huynh) mở Cài đặt của bố/mẹ. Lỗi đồng bộ không bao giờ chặn việc chơi.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/parent_gate.dart';
import '../../features/auth/parent_settings_screen.dart';
import 'sync_providers.dart';

class SyncStatusIcon extends ConsumerWidget {
  const SyncStatusIcon({super.key = const Key('sync-status-icon')});

  static (IconData, Color, String) look(SyncStatus s) => switch (s) {
    SyncStatus.synced => (
      Icons.cloud_done_rounded,
      const Color(0xFFB8F0C8),
      'Đã đồng bộ',
    ),
    SyncStatus.syncing => (
      Icons.cloud_sync_rounded,
      Colors.white,
      'Đang đồng bộ',
    ),
    SyncStatus.offline => (
      Icons.cloud_off_rounded,
      const Color(0xFFFFE08A),
      'Chưa có mạng',
    ),
    SyncStatus.error => (
      Icons.error_outline_rounded,
      const Color(0xFFFFA8A0),
      'Đồng bộ lỗi',
    ),
    SyncStatus.needsLogin => (
      Icons.lock_reset_rounded,
      const Color(0xFFFFA8A0),
      'Cần đăng nhập lại',
    ),
    SyncStatus.signedOut => (
      Icons.cloud_queue_rounded,
      const Color(0x99FFFFFF),
      'Chưa đăng nhập',
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncControllerProvider.select((s) => s.status));
    final (icon, color, text) = look(status);
    return Tooltip(
      message: text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          if (await showParentGate(context) && context.mounted) {
            await context.push(ParentSettingsScreen.route);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Icon(
            icon,
            key: ValueKey('sync-icon-${status.name}'),
            size: 20,
            color: color,
          ),
        ),
      ),
    );
  }
}
