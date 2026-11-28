/// Neon giả cho test đồng bộ: Neon Auth + Data API trong bộ nhớ, dùng
/// `MockClient` nên không có cuộc gọi mạng thật nào. Mô phỏng đúng các
/// hành vi mà bộ đồng bộ dựa vào: upsert `ignore-duplicates` /
/// `merge-duplicates` theo `id`, trigger `keep_newest`, `claim_message`
/// chỉ trả quà một lần.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timokid/core/sync/neon_client.dart';
import 'package:timokid/core/sync/session_store.dart';

class Logged {
  Logged(this.method, this.table, this.query, this.prefer, this.body);
  final String method;
  final String table;
  final Map<String, String> query;
  final String? prefer;
  final Object? body;
}

class FakeNeon {
  FakeNeon() {
    client = MockClient(_handle);
  }

  late final MockClient client;

  /// table -> id -> dòng.
  final Map<String, Map<String, Map<String, Object?>>> tables = {};
  final List<Logged> log = [];

  /// Ném lỗi mạng TRƯỚC khi server xử lý.
  bool Function(http.Request req)? dropRequest;

  /// Trả mã lỗi HTTP (vd 500) cho các lệnh gọi Data API.
  int? Function(http.Request req)? forceStatus;

  /// Server xử lý xong nhưng phản hồi bị mất (lỗi mạng ở máy khách).
  bool Function(http.Request req)? loseResponse;

  String goodPassword = 'matkhau123';

  /// Email đã có tài khoản: đăng ký trùng thì server trả USER_ALREADY_EXISTS.
  final Set<String> existingEmails = {};

  /// Nội dung các lệnh gọi `request-password-reset` / `change-password`.
  final List<Map<String, Object?>> resetRequests = [];
  final List<Map<String, Object?>> passwordChanges = [];

  /// Tên đường dẫn đặt lại mật khẩu mà server giả hiểu (bản Better Auth cũ
  /// dùng `forget-password`).
  String resetPath = 'request-password-reset';

  /// Ép Neon Auth trả mã HTTP này cho đăng nhập/đăng ký (vd 503).
  int? authFailStatus;

  /// Phiên hết hạn: `/token` trả 401 dù có cookie.
  bool sessionExpired = false;
  int tokenCalls = 0;

  Map<String, Map<String, Object?>> table(String name) =>
      tables.putIfAbsent(name, () => {});

  List<Logged> posts([String? t]) => [
    for (final l in log)
      if (l.method == 'POST' &&
          !l.table.startsWith('rpc/') &&
          (t == null || l.table == t))
        l,
  ];

  static String jwt() {
    String enc(Object o) =>
        base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
    return '${enc({'alg': 'none'})}.${enc({'exp': 4102444800, 'sub': 'u1'})}.sig';
  }

  http.Response _json(
    Object? body, [
    int status = 200,
    Map<String, String>? h,
  ]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json', ...?h},
  );

  Future<http.Response> _handle(http.Request req) async {
    if (dropRequest?.call(req) ?? false) {
      throw http.ClientException('network down');
    }
    final res = _route(req);
    if (loseResponse?.call(req) ?? false) {
      throw http.ClientException('response lost');
    }
    return res;
  }

  http.Response _route(http.Request req) {
    final path = req.url.path;
    if (path.contains('/auth/')) {
      if (authFailStatus != null &&
          (path.endsWith('/sign-in/email') ||
              path.endsWith('/sign-up/email'))) {
        return _json({'message': 'unavailable'}, authFailStatus!);
      }
      if (path.endsWith('/$resetPath')) {
        resetRequests.add((jsonDecode(req.body) as Map).cast());
        return _json({'status': true});
      }
      if (path.endsWith('/request-password-reset') ||
          path.endsWith('/forget-password')) {
        return _json({'message': 'Not found'}, 404);
      }
      if (path.endsWith('/change-password')) {
        final b = (jsonDecode(req.body) as Map).cast<String, Object?>();
        if (!(req.headers['Cookie'] ?? '').contains('session_token')) {
          return _json({'message': 'Unauthorized'}, 401);
        }
        if (b['currentPassword'] != goodPassword) {
          return _json({
            'code': 'INVALID_PASSWORD',
            'message': 'Invalid password',
          }, 400);
        }
        passwordChanges.add(b);
        goodPassword = b['newPassword'] as String;
        return _json({'status': true});
      }
      if (path.endsWith('/sign-up/email') &&
          existingEmails.contains((jsonDecode(req.body) as Map)['email'])) {
        return _json({
          'code': 'USER_ALREADY_EXISTS',
          'message': 'User already exists',
        }, 422);
      }
      if (path.endsWith('/sign-in/email') || path.endsWith('/sign-up/email')) {
        final b = jsonDecode(req.body) as Map;
        if (b['password'] != goodPassword) {
          return _json({
            'code': 'INVALID_EMAIL_OR_PASSWORD',
            'message': 'Invalid email or password',
          }, 401);
        }
        return _json(
          {
            'user': {'id': 'u1', 'email': b['email']},
          },
          200,
          {
            'set-cookie': 'neon-auth.session_token=abc123; Path=/; Expires=Wed, 21 Oct 2026 07:28:00 GMT; HttpOnly, neon-auth.x=1; Path=/',
          },
        );
      }
      if (path.endsWith('/token')) {
        tokenCalls++;
        if (sessionExpired) return _json({'message': 'expired'}, 401);
        if (!(req.headers['Cookie'] ?? '').contains(
          'neon-auth.session_token=abc123',
        )) {
          return _json({'message': 'no session'}, 401);
        }
        return _json({'token': jwt()});
      }
      if (path.endsWith('/sign-out')) return _json({'success': true});
    }
    final i = path.indexOf('/rest/v1/');
    final name = path.substring(i + '/rest/v1/'.length);
    final body = req.body.isEmpty ? null : jsonDecode(req.body);
    log.add(
      Logged(
        req.method,
        name,
        req.url.queryParameters,
        req.headers['Prefer'],
        body,
      ),
    );
    final forced = forceStatus?.call(req);
    if (forced != null) return _json({'message': 'boom'}, forced);
    if (req.headers['Authorization'] != 'Bearer ${jwt()}') {
      return _json({'message': 'JWT invalid'}, 401);
    }
    if (name == 'rpc/ensure_family') return _json({'id': 'fam1'});
    if (name == 'rpc/claim_message') {
      final id = (body as Map)['p_message_id'] as String;
      final m = table('messages')[id];
      if (m == null) return _json({'message': 'message not found'}, 400);
      if (m['claimed_at'] != null) {
        return _json([
          {'claimed': false, 'gift_xu': 0, 'gift_gem': 0, 'gift_item_id': null},
        ]);
      }
      m['claimed_at'] = '2026-11-28T10:00:00+00:00';
      m['opened_at'] ??= '2026-11-28T10:00:00+00:00';
      m['updated_at'] = '2026-11-28T10:00:00.5+00:00';
      return _json([
        {
          'claimed': true,
          'gift_xu': m['gift_xu'],
          'gift_gem': m['gift_gem'],
          'gift_item_id': m['gift_item_id'],
        },
      ]);
    }
    final t = table(name);
    switch (req.method) {
      case 'POST':
        final prefer = req.headers['Prefer'] ?? '';
        final rows = [
          for (final r in body as List) (r as Map).cast<String, Object?>(),
        ];
        for (final r in rows) {
          final id = r['id'] as String;
          final old = t[id];
          if (old == null) {
            t[id] = {...r};
          } else if (prefer.contains('merge-duplicates')) {
            final nu = DateTime.parse(r['updated_at'] as String);
            final ou = DateTime.parse(old['updated_at'] as String);
            if (!nu.isBefore(ou)) old.addAll(r);
          } else if (!prefer.contains('ignore-duplicates')) {
            return _json({'code': '23505', 'message': 'duplicate key'}, 409);
          }
        }
        return http.Response('', 201);
      case 'PATCH':
        final id = req.url.queryParameters['id'] ?? '';
        final ids = id.startsWith('eq.')
            ? [id.substring(3)]
            : id.substring(4, id.length - 1).split(',');
        for (final x in ids) {
          t[x]?.addAll((body as Map).cast<String, Object?>());
        }
        return http.Response('', 204);
      case 'GET':
        var rows = t.values.toList();
        final f = req.url.queryParameters['updated_at'];
        if (f != null) {
          final mark = DateTime.parse(f.substring(3));
          rows = [
            for (final r in rows)
              if (DateTime.parse(r['updated_at'] as String).isAfter(mark)) r,
          ];
        }
        rows.sort(
          (a, b) =>
              DateTime.parse(a['updated_at'] as String)
                  .compareTo(DateTime.parse(b['updated_at'] as String)),
        );
        return _json(rows);
    }
    return http.Response('', 404);
  }

  /// Máy khách đã đăng nhập sẵn (cookie đã có trong kho).
  NeonClient signedInClient(MemorySessionStore store) {
    store.data[NeonClient.cookieKey] = 'neon-auth.session_token=abc123';
    return NeonClient(client: client, store: store);
  }
}
