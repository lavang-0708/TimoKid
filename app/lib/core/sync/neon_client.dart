/// Máy khách HTTP cho Neon Auth và Neon Data API (T3-03/T3-04), dịch từ
/// `admin/src/lib/http.ts` sang Dart:
///
/// - Đăng nhập: `POST {auth}/sign-in/email` (hoặc `/sign-up/email`) trả
///   cookie phiên. App không có trình duyệt nên tự giữ cookie (lưu trong
///   [SessionStore], không log).
/// - JWT ngắn hạn (khoảng 15 phút): `GET {auth}/token` kèm cookie, giữ
///   trong bộ nhớ, tự làm mới khi sắp hết hạn hoặc khi Data API trả 401.
/// - Data API (PostgREST): `Authorization: Bearer <jwt>`.
///
/// Nhận `http.Client` từ ngoài để test thay bằng `MockClient`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'session_store.dart';
import 'sync_config.dart';

enum NeonErrorKind { network, auth, server, client }

class NeonException implements Exception {
  NeonException(this.kind, this.status, this.message, {this.code});

  final NeonErrorKind kind;
  final int status;
  final String message;
  final String? code;

  @override
  String toString() => 'NeonException($kind, $status, $message)';
}

class NeonResponse {
  NeonResponse(this.status, this.body);
  final int status;

  /// JSON đã giải mã (List/Map), hoặc null nếu thân rỗng.
  final Object? body;
}

/// Thời điểm hết hạn (giây epoch) của JWT, null nếu không đọc được.
int? jwtExp(String jwt) {
  try {
    final parts = jwt.split('.');
    if (parts.length < 2) return null;
    final json = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final exp = (json as Map)['exp'];
    return exp is num ? exp.toInt() : null;
  } on Object {
    return null;
  }
}

class NeonClient {
  NeonClient({
    required http.Client client,
    required SessionStore store,
    this.authUrl = SyncConfig.authUrl,
    this.apiUrl = SyncConfig.apiUrl,
    this.origin = SyncConfig.origin,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 25),
  }) : _http = client,
       // ignore: prefer_initializing_formals
       _store = store,
       _now = now ?? DateTime.now;

  static const cookieKey = 'auth_cookie';
  static const emailKey = 'auth_email';

  final http.Client _http;
  final SessionStore _store;
  final String authUrl;
  final String apiUrl;
  final String origin;
  final DateTime Function() _now;
  final Duration timeout;

  String? _jwt;
  Map<String, String>? _jar;

  // ------------------------------------------------------------- phiên

  Future<Map<String, String>> _cookies() async {
    final cached = _jar;
    if (cached != null) return cached;
    final raw = await _store.read(cookieKey);
    final jar = <String, String>{};
    if (raw != null && raw.isNotEmpty) {
      for (final part in raw.split('; ')) {
        final i = part.indexOf('=');
        if (i > 0) jar[part.substring(0, i)] = part.substring(i + 1);
      }
    }
    return _jar = jar;
  }

  /// Đã có phiên đăng nhập (cookie) chưa. Chưa kiểm tra còn hạn không.
  Future<bool> hasSession() async => (await _cookies()).isNotEmpty;

  Future<String?> savedEmail() => _store.read(emailKey);

  Future<void> _absorbCookies(http.BaseResponse res) async {
    final header = res.headers['set-cookie'];
    if (header == null || header.isEmpty) return;
    final jar = await _cookies();
    // Nhiều Set-Cookie bị http gộp bằng dấu phẩy; dấu phẩy trong
    // `Expires=Wed, 21 Oct` không đứng trước `tên=`, nên tách an toàn.
    for (final c in header.split(RegExp(r',(?=\s*[\w.\-]+=)'))) {
      final pair = c.split(';').first.trim();
      final i = pair.indexOf('=');
      if (i <= 0) continue;
      final name = pair.substring(0, i);
      final value = pair.substring(i + 1);
      if (value.isEmpty) {
        jar.remove(name);
      } else {
        jar[name] = value;
      }
    }
    await _store.write(
      cookieKey,
      jar.entries.map((e) => '${e.key}=${e.value}').join('; '),
    );
  }

  // ------------------------------------------------------------- gọi

  Future<http.Response> _send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    final req = http.Request(method, url);
    req.headers.addAll(headers);
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    try {
      final streamed = await _http.send(req).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on Object {
      throw NeonException(NeonErrorKind.network, 0, 'Không kết nối được mạng.');
    }
  }

  Object? _decode(http.Response res) {
    if (res.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      return res.body;
    }
  }

  NeonException _toError(int status, Object? body) {
    final b = body is Map ? body : const {};
    final message =
        '${b['message'] ?? b['error'] ?? b['hint'] ?? 'Lỗi $status'}';
    final code = b['code'] is String ? b['code'] as String : null;
    // `not authenticated` do ensure_family ném ra khi Data API chưa nhận
    // ra JWT: coi là lỗi xác thực để lấy JWT mới và thử lại một lần.
    final authish =
        status == 401 ||
        RegExp('not authenticated', caseSensitive: false).hasMatch(message) ||
        (status == 403 &&
            RegExp('jwt|token', caseSensitive: false).hasMatch(message));
    if (authish) {
      return NeonException(NeonErrorKind.auth, status, message, code: code);
    }
    return NeonException(
      status >= 500 ? NeonErrorKind.server : NeonErrorKind.client,
      status,
      message,
      code: code,
    );
  }

  // ------------------------------------------------------------- auth

  Map<String, String> _authHeaders() => {
    'Origin': origin,
    'Accept': 'application/json',
  };

  Future<Map<String, String>> _authHeadersWithCookie() async {
    final jar = await _cookies();
    return {
      'Origin': origin,
      'Accept': 'application/json',
      if (jar.isNotEmpty)
        'Cookie': jar.entries.map((e) => '${e.key}=${e.value}').join('; '),
    };
  }

  Future<void> signIn(String email, String password) => _authenticate(
    'sign-in/email',
    email,
    {'email': email, 'password': password},
  );

  Future<void> signUp(String email, String password, {String name = ''}) =>
      _authenticate('sign-up/email', email, {
        'email': email,
        'password': password,
        'name': name.isEmpty ? email.split('@').first : name,
      });

  Future<void> _authenticate(
    String path,
    String email,
    Map<String, String> body,
  ) async {
    _jar = {};
    _jwt = null;
    final res = await _send(
      'POST',
      Uri.parse('$authUrl/$path'),
      headers: _authHeaders(),
      body: body,
    );
    final decoded = _decode(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final e = _toError(res.statusCode, decoded);
      throw NeonException(
        res.statusCode >= 500 ? NeonErrorKind.server : NeonErrorKind.auth,
        res.statusCode,
        authMessageVi(e.code, e.message, status: res.statusCode),
        code: e.code,
      );
    }
    await _absorbCookies(res);
    await _store.write(emailKey, email);
  }

  /// Xin email đặt lại mật khẩu (Better Auth `request-password-reset`, bản
  /// cũ tên `forget-password`). Server luôn trả thành công dù email có tài
  /// khoản hay không (không lộ email nào đã đăng ký). [redirectTo] là trang
  /// web admin hoàn tất việc đặt lại (phải thuộc domain được phép của Neon
  /// Auth). Ném [NeonException] khi mất mạng hoặc server từ chối.
  Future<void> requestPasswordReset(
    String email, {
    String redirectTo = SyncConfig.resetRedirect,
  }) async {
    for (final path in const ['request-password-reset', 'forget-password']) {
      final res = await _send(
        'POST',
        Uri.parse('$authUrl/$path'),
        headers: _authHeaders(),
        body: {'email': email, 'redirectTo': redirectTo},
      );
      if (res.statusCode >= 200 && res.statusCode < 300) return;
      // Bản Better Auth cũ chưa có đường dẫn mới: thử tên cũ.
      if (res.statusCode == 404 && path == 'request-password-reset') continue;
      final e = _toError(res.statusCode, _decode(res));
      throw NeonException(
        res.statusCode >= 500 ? NeonErrorKind.server : NeonErrorKind.client,
        res.statusCode,
        authMessageVi(e.code, e.message, status: res.statusCode),
        code: e.code,
      );
    }
  }

  /// Đổi mật khẩu khi đang đăng nhập (Better Auth `change-password`).
  /// Sai mật khẩu hiện tại thì ném [NeonException] có `code` `INVALID_PASSWORD`.
  Future<void> changePassword(String current, String next) async {
    final res = await _send(
      'POST',
      Uri.parse('$authUrl/change-password'),
      headers: await _authHeadersWithCookie(),
      body: {
        'currentPassword': current,
        'newPassword': next,
        'revokeOtherSessions': false,
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final e = _toError(res.statusCode, _decode(res));
      throw NeonException(
        res.statusCode >= 500
            ? NeonErrorKind.server
            : res.statusCode == 401
            ? NeonErrorKind.auth
            : NeonErrorKind.client,
        res.statusCode,
        authMessageVi(e.code, e.message, status: res.statusCode),
        code: e.code,
      );
    }
    await _absorbCookies(res);
  }

  /// Đăng xuất: xóa phiên trên máy (kể cả khi gọi server lỗi).
  Future<void> signOut() async {
    try {
      await _send(
        'POST',
        Uri.parse('$authUrl/sign-out'),
        headers: await _authHeadersWithCookie(),
        body: <String, Object>{},
      );
    } on Object {
      // vẫn đăng xuất cục bộ
    }
    _jwt = null;
    _jar = {};
    await _store.delete(cookieKey);
    await _store.delete(emailKey);
  }

  Future<String> refreshJwt() async {
    final res = await _send(
      'GET',
      Uri.parse('$authUrl/token'),
      headers: await _authHeadersWithCookie(),
    );
    final body = _decode(res);
    final token = body is Map ? body['token'] : null;
    if (res.statusCode < 200 ||
        res.statusCode >= 300 ||
        token is! String ||
        token.isEmpty) {
      _jwt = null;
      if (res.statusCode >= 500) {
        throw NeonException(
          NeonErrorKind.server,
          res.statusCode,
          'Máy chủ lỗi.',
        );
      }
      throw NeonException(
        NeonErrorKind.auth,
        res.statusCode,
        'Phiên đăng nhập đã hết hạn, hãy đăng nhập lại.',
      );
    }
    await _absorbCookies(res);
    return _jwt = token;
  }

  Future<String> _token() async {
    final jwt = _jwt;
    if (jwt != null) {
      final exp = jwtExp(jwt);
      if (exp != null && exp * 1000 - _now().millisecondsSinceEpoch > 60000) {
        return jwt;
      }
    }
    return refreshJwt();
  }

  // ------------------------------------------------------------- data

  /// Gọi Data API. [path] vd `attempts` hoặc `rpc/ensure_family`; [query]
  /// được mã hóa đúng (dấu `+` của múi giờ...). Lỗi 401 thì làm mới JWT
  /// và thử lại một lần. Ném [NeonException] khi lỗi.
  Future<NeonResponse> api(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? prefer,
  }) async {
    var refreshed = false;
    for (;;) {
      final jwt = await _token();
      final res = await _send(
        method,
        Uri.parse('$apiUrl/$path').replace(queryParameters: query),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Accept': 'application/json',
          'Prefer': ?prefer,
        },
        body: body,
      );
      final decoded = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return NeonResponse(res.statusCode, decoded);
      }
      final err = _toError(res.statusCode, decoded);
      if (err.kind == NeonErrorKind.auth && !refreshed) {
        refreshed = true;
        _jwt = null;
        continue;
      }
      throw err;
    }
  }

  /// Lấy hoặc tạo gia đình của tài khoản (gọi ngay sau đăng nhập).
  Future<void> ensureFamily() =>
      api('POST', 'rpc/ensure_family', body: {'p_display_name': ''});
}

String authMessageVi(String? code, String fallback, {int? status}) {
  switch (code) {
    case 'INVALID_EMAIL_OR_PASSWORD':
      return 'Email hoặc mật khẩu không đúng.';
    case 'USER_ALREADY_EXISTS':
    case 'USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL':
      return 'Email này đã có tài khoản. Hãy đăng nhập.';
    case 'INVALID_EMAIL':
      return 'Email không hợp lệ.';
    case 'PASSWORD_TOO_SHORT':
      return 'Mật khẩu quá ngắn (cần ít nhất 8 ký tự).';
    case 'PASSWORD_TOO_LONG':
      return 'Mật khẩu quá dài.';
    case 'INVALID_PASSWORD':
      return 'Mật khẩu hiện tại chưa đúng.';
    case 'EMAIL_NOT_VERIFIED':
      return 'Email chưa được xác nhận.';
    case 'RESET_PASSWORD_DISABLED':
      return 'Máy chủ chưa bật tính năng quên mật khẩu.';
  }
  if (status == 429) return 'Thử quá nhiều lần. Hãy đợi một lúc rồi thử lại.';
  final f = fallback.toLowerCase();
  if (f.contains('password') && f.contains('short')) {
    return 'Mật khẩu quá ngắn (cần ít nhất 8 ký tự).';
  }
  return 'Không thực hiện được: $fallback';
}
