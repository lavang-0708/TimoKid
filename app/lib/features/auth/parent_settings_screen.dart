/// Cài đặt của bố/mẹ (T3-03), mở sau cổng phụ huynh từ biểu tượng đám
/// mây trên HUD: đăng nhập / đăng xuất, đồng bộ ngay, đổi bé, thêm bé.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database_provider.dart';
import '../../core/sync/sync_providers.dart';
import '../../core/sync/sync_status_icon.dart';
import '../onboarding/onboarding_screen.dart';
import '../profile/profile_picker_screen.dart';
import '../profile/profile_service.dart';
import 'login_screen.dart';

class ParentSettingsScreen extends ConsumerWidget {
  const ParentSettingsScreen({super.key});

  static const String route = '/parent';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final sync = ref.watch(syncControllerProvider);
    final (_, _, statusText) = SyncStatusIcon.look(sync.status);
    return Scaffold(
      key: const Key('parent-settings-screen'),
      appBar: AppBar(title: const Text('Cài đặt cho bố/mẹ')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ListTile(
            key: const Key('parent-account'),
            leading: const Icon(Icons.account_circle_rounded),
            title: Text(
              auth.signedIn
                  ? 'Đã đăng nhập: ${auth.email ?? ''}'
                  : 'Chưa đăng nhập (dùng không cần tài khoản)',
            ),
            subtitle: Text('Đồng bộ: $statusText'),
          ),
          if (auth.signedIn) ...[
            ListTile(
              key: const Key('parent-sync-now'),
              leading: const Icon(Icons.sync_rounded),
              title: const Text('Đồng bộ ngay'),
              onTap: () => ref.read(syncControllerProvider.notifier).syncSoon(),
            ),
            ListTile(
              key: const Key('parent-logout'),
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Đăng xuất'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Đăng xuất?'),
                    content: const Text(
                      'Dữ liệu của bé vẫn còn trên máy, chỉ ngừng đồng bộ.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Hủy'),
                      ),
                      ElevatedButton(
                        key: const Key('parent-logout-confirm'),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Đăng xuất'),
                      ),
                    ],
                  ),
                );
                if (ok == true) await ref.read(authProvider.notifier).signOut();
              },
            ),
          ] else
            ListTile(
              key: const Key('parent-login'),
              leading: const Icon(Icons.login_rounded),
              title: const Text('Đăng nhập'),
              onTap: () => context.push(LoginScreen.route),
            ),
          const Divider(),
          ListTile(
            key: const Key('parent-switch-child'),
            leading: const Icon(Icons.switch_account_rounded),
            title: const Text('Đổi bé'),
            onTap: () => context.go(ProfilePickerScreen.route),
          ),
          ListTile(
            key: const Key('parent-add-child'),
            leading: const Icon(Icons.person_add_alt_1_rounded),
            title: const Text('Thêm bé'),
            onTap: () async {
              await ProfileService(db: ref.read(databaseProvider)).addChild();
              if (context.mounted) context.go(OnboardingScreen.route);
            },
          ),
        ],
      ),
    );
  }
}
