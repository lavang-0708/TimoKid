/// Màn đăng nhập cho bố/mẹ (T3-03): email + mật khẩu (đăng nhập, hoặc
/// đăng ký tài khoản mới) và nút "Dùng không cần tài khoản" để app vẫn
/// chạy đầy đủ không đồng bộ. Hiện một lần khi mở app lần đầu (và máy
/// cài đè bản cũ); sau đó mở lại từ Cài đặt của bố/mẹ.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database_provider.dart';
import '../../core/sync/neon_client.dart';
import '../../core/sync/sync_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.next});

  static const String route = '/login';

  /// Màn đi tiếp sau khi đăng nhập hoặc bỏ qua (lần đầu mở app).
  /// Null = mở từ Cài đặt: quay lại màn trước.
  final String? next;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _markPromptDone() => ref
      .read(databaseProvider)
      .settingsDao
      .setValue(key: loginPromptDoneKey, value: 'true');

  void _leave() {
    final next = widget.next;
    if (next != null) {
      context.go(next);
    } else if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Hãy nhập email và mật khẩu.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .signIn(email, password, signUp: _signUp);
      await _markPromptDone();
      if (mounted) _leave();
    } on NeonException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.kind == NeonErrorKind.network
              ? 'Không có mạng. Kiểm tra kết nối rồi thử lại.'
              : e.message;
        });
      }
    }
  }

  Future<void> _skip() async {
    await _markPromptDone();
    if (mounted) _leave();
  }

  Widget _title() => Text(
    _signUp ? 'Bố/mẹ tạo tài khoản' : 'Bố/mẹ đăng nhập',
    key: const Key('login-title'),
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
  );

  Widget _why() => const Text(
    'Để lưu tiến độ của bé và xem trên điện thoại của bố/mẹ.',
    textAlign: TextAlign.center,
  );

  Widget _skipButton() => OutlinedButton(
    key: const Key('login-skip'),
    onPressed: _busy ? null : _skip,
    child: const Text('Dùng không cần tài khoản'),
  );

  Widget _form() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextField(
        key: const Key('login-email'),
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        decoration: const InputDecoration(labelText: 'Email', isDense: true),
      ),
      const SizedBox(height: 6),
      TextField(
        key: const Key('login-password'),
        controller: _password,
        obscureText: true,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(labelText: 'Mật khẩu', isDense: true),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _error!,
            key: const Key('login-error'),
            style: const TextStyle(color: Color(0xFFC62828)),
          ),
        ),
      const SizedBox(height: 8),
      ElevatedButton(
        key: const Key('login-submit'),
        onPressed: _busy ? null : _submit,
        child: Text(
          _busy ? 'Đang xử lý...' : (_signUp ? 'Tạo tài khoản' : 'Đăng nhập'),
        ),
      ),
      TextButton(
        key: const Key('login-toggle-signup'),
        onPressed: _busy
            ? null
            : () => setState(() {
                _signUp = !_signUp;
                _error = null;
              }),
        child: Text(
          _signUp ? 'Đã có tài khoản? Đăng nhập' : 'Chưa có tài khoản? Đăng ký',
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('login-screen'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Màn ngang (app luôn ngang): hai cột, nút "Dùng không cần
            // tài khoản" luôn thấy ngay, không phải cuộn.
            final wide = constraints.maxWidth >= 560;
            final Widget body = wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _title(),
                            const SizedBox(height: 10),
                            _skipButton(),
                            const SizedBox(height: 10),
                            _why(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: _form()),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _title(),
                      const SizedBox(height: 4),
                      _why(),
                      const SizedBox(height: 8),
                      _form(),
                      _skipButton(),
                    ],
                  );
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 640 : 420),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: body,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
