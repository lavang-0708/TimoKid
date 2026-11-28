/// Cài đặt của bố/mẹ (T3-03), mở sau cổng phụ huynh từ biểu tượng đám
/// mây trên HUD: email đang đăng nhập, lần đồng bộ gần nhất và trạng thái,
/// đồng bộ ngay, đổi mật khẩu, đăng xuất (có xác nhận), đăng nhập lại khi
/// phiên hết hạn, đổi bé, thêm bé.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database_provider.dart';
import '../../core/sync/neon_client.dart';
import '../../core/sync/sync_providers.dart';
import '../../core/sync/sync_status_icon.dart';
import '../onboarding/onboarding_screen.dart';
import '../profile/profile_picker_screen.dart';
import '../profile/profile_service.dart';
import 'login_screen.dart';

/// "14:05 28/11/2026" (giờ máy).
String formatSyncTime(DateTime t) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(t.hour)}:${p(t.minute)} ${p(t.day)}/${p(t.month)}/${t.year}';
}

class ParentSettingsScreen extends ConsumerWidget {
  const ParentSettingsScreen({super.key});

  static const String route = '/parent';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final sync = ref.watch(syncControllerProvider);
    final (_, _, statusText) = SyncStatusIcon.look(sync.status);
    final needsLogin = auth.signedIn && sync.status == SyncStatus.needsLogin;
    final last = sync.lastSyncedAt;
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
            subtitle: Text(
              auth.signedIn
                  ? 'Đồng bộ: $statusText\nLần gần nhất: '
                        '${last == null ? 'chưa có' : formatSyncTime(last)}'
                  : 'Đồng bộ: $statusText',
              key: const Key('parent-sync-info'),
            ),
            isThreeLine: auth.signedIn,
          ),
          if (needsLogin)
            ListTile(
              key: const Key('parent-relogin'),
              leading: const Icon(Icons.lock_reset_rounded),
              title: const Text('Đăng nhập lại'),
              subtitle: const Text(
                'Phiên đã hết hạn nên chưa đồng bộ được. Bé vẫn chơi bình '
                'thường, dữ liệu được giữ trên máy.',
              ),
              onTap: () => context.push(LoginScreen.route),
            ),
          if (auth.signedIn) ...[
            ListTile(
              key: const Key('parent-sync-now'),
              leading: const Icon(Icons.sync_rounded),
              title: const Text('Đồng bộ ngay'),
              onTap: () => ref.read(syncControllerProvider.notifier).syncSoon(),
            ),
            ListTile(
              key: const Key('parent-change-password'),
              leading: const Icon(Icons.password_rounded),
              title: const Text('Đổi mật khẩu'),
              onTap: () async {
                final done = await showDialog<bool>(
                  context: context,
                  builder: (_) => const ChangePasswordDialog(),
                );
                if (done == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã đổi mật khẩu.')),
                  );
                }
              },
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
                      'Dữ liệu và tiến độ của bé vẫn còn nguyên trên máy này, '
                      'bé vẫn chơi bình thường. App chỉ ngừng đồng bộ lên '
                      'tài khoản cho tới khi bố/mẹ đăng nhập lại.',
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

/// Đổi mật khẩu: mật khẩu hiện tại + mật khẩu mới (+ nhập lại).
class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_current.text.isEmpty) {
      setState(() => _error = 'Hãy nhập mật khẩu hiện tại.');
      return;
    }
    if (_next.text.length < 8) {
      setState(() => _error = 'Mật khẩu mới cần ít nhất 8 ký tự.');
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = 'Hai mật khẩu mới chưa giống nhau.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .changePassword(_current.text, _next.text);
      if (mounted) Navigator.of(context).pop(true);
    } on NeonException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = switch (e.kind) {
            NeonErrorKind.network =>
              'Không có mạng. Kiểm tra kết nối rồi thử lại.',
            NeonErrorKind.server =>
              'Máy chủ đang bận. Thử lại sau ít giây nhé.',
            // 401 ở đây có thể là sai mật khẩu hoặc phiên hết hạn.
            NeonErrorKind.auth when e.code != 'INVALID_PASSWORD' =>
              'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại rồi đổi mật khẩu.',
            _ => e.message,
          };
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('change-password-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Đổi mật khẩu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              TextField(
                key: const Key('cp-current'),
                controller: _current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                  isDense: true,
                ),
              ),
              TextField(
                key: const Key('cp-new'),
                controller: _next,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu mới (ít nhất 8 ký tự)',
                  isDense: true,
                ),
              ),
              TextField(
                key: const Key('cp-confirm'),
                controller: _confirm,
                obscureText: true,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Nhập lại mật khẩu mới',
                  isDense: true,
                  errorText: _error,
                  errorMaxLines: 3,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('cp-cancel'),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Hủy'),
                  ),
                  ElevatedButton(
                    key: const Key('cp-submit'),
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Đang đổi...' : 'Đổi mật khẩu'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
