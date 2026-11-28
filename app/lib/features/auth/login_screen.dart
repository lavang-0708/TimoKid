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
  final _confirm = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Đăng nhập lại khi phiên hết hạn: điền sẵn email đang dùng.
    _email.text = ref.read(authProvider).email ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Độ dài mật khẩu tối thiểu của Neon Auth.
  static const int minPassword = 8;

  /// Kiểm tra trước khi gọi mạng; trả thông báo lỗi hoặc null nếu hợp lệ.
  String? _validate(String email, String password) {
    if (email.isEmpty || password.isEmpty) {
      return 'Hãy nhập email và mật khẩu.';
    }
    if (!_emailRe.hasMatch(email)) {
      return 'Email chưa đúng dạng (vd: ten@gmail.com).';
    }
    if (_signUp) {
      if (password.length < minPassword) {
        return 'Mật khẩu cần ít nhất $minPassword ký tự.';
      }
      if (password != _confirm.text) return 'Hai mật khẩu chưa giống nhau.';
    }
    return null;
  }

  static String errorText(NeonException e) => switch (e.kind) {
    NeonErrorKind.network => 'Không có mạng. Kiểm tra kết nối rồi thử lại.',
    NeonErrorKind.server =>
      'Máy chủ đang bận hoặc vừa thức dậy. Thử lại sau ít giây nhé.',
    _ => e.message,
  };

  Future<void> _forgot() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => ForgotPasswordDialog(initialEmail: _email.text.trim()),
    );
    if (sent == true && mounted) {
      setState(() => _error = null);
    }
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
    final invalid = _validate(email, password);
    if (invalid != null) {
      setState(() => _error = invalid);
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
          _error = errorText(e);
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
        onSubmitted: (_) => _signUp ? null : _submit(),
        decoration: InputDecoration(
          labelText: _signUp
              ? 'Mật khẩu (ít nhất $minPassword ký tự)'
              : 'Mật khẩu',
          isDense: true,
        ),
      ),
      if (_signUp) ...[
        const SizedBox(height: 6),
        TextField(
          key: const Key('login-confirm'),
          controller: _confirm,
          obscureText: true,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            labelText: 'Nhập lại mật khẩu',
            isDense: true,
          ),
        ),
      ],
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
      if (!_signUp)
        TextButton(
          key: const Key('login-forgot'),
          onPressed: _busy ? null : _forgot,
          child: const Text('Quên mật khẩu?'),
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

/// Hộp "Quên mật khẩu?": nhập email, app xin Neon Auth gửi email đặt lại
/// mật khẩu; bố/mẹ bấm liên kết trong email để đặt mật khẩu mới trên trang
/// web của TimoKid (trình duyệt), rồi quay lại app đăng nhập.
class ForgotPasswordDialog extends ConsumerStatefulWidget {
  const ForgotPasswordDialog({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<ForgotPasswordDialog> {
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!_LoginScreenState._emailRe.hasMatch(email)) {
      setState(() => _error = 'Email chưa đúng dạng (vd: ten@gmail.com).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).requestPasswordReset(email);
      if (mounted) {
        setState(() {
          _busy = false;
          _sent = true;
        });
      }
    } on NeonException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _LoginScreenState.errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('forgot-dialog'),
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
                'Quên mật khẩu?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              if (_sent)
                const Text(
                  'Nếu email này đã có tài khoản, TimoKid vừa gửi một thư kèm '
                  'liên kết đặt lại mật khẩu (xem cả mục Thư rác). Bấm liên kết '
                  'trong thư, đặt mật khẩu mới trên trang web rồi quay lại app '
                  'đăng nhập.',
                  key: Key('forgot-sent'),
                )
              else ...[
                const Text(
                  'Nhập email đã đăng ký. TimoKid sẽ gửi thư có liên kết để '
                  'đặt mật khẩu mới.',
                ),
                TextField(
                  key: const Key('forgot-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    isDense: true,
                    errorText: _error,
                    errorMaxLines: 3,
                  ),
                ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('forgot-close'),
                    onPressed: () => Navigator.of(context).pop(_sent),
                    child: Text(_sent ? 'Đóng' : 'Hủy'),
                  ),
                  if (!_sent)
                    ElevatedButton(
                      key: const Key('forgot-send'),
                      onPressed: _busy ? null : _send,
                      child: Text(_busy ? 'Đang gửi...' : 'Gửi thư'),
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
