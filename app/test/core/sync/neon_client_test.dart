/// Máy khách Neon (T3-03): cookie phiên (kể cả `Expires` có dấu phẩy),
/// JWT lấy từ /token và làm mới khi 401, đăng xuất xóa phiên, không có
/// token trong kho lưu.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/sync/neon_client.dart';
import 'package:timokid/core/sync/session_store.dart';

import 'fake_neon.dart';

void main() {
  late FakeNeon neon;
  late MemorySessionStore store;
  late NeonClient client;

  setUp(() {
    neon = FakeNeon();
    store = MemorySessionStore();
    client = NeonClient(client: neon.client, store: store);
  });

  test(
    'đăng nhập: tách đúng nhiều Set-Cookie, chỉ lưu cookie + email',
    () async {
      await client.signIn('bo@example.com', 'matkhau123');
      expect(
        store.data[NeonClient.cookieKey],
        'neon-auth.session_token=abc123; neon-auth.x=1',
      );
      expect(store.data.keys.toSet(), {
        NeonClient.cookieKey,
        NeonClient.emailKey,
      });
      expect(await client.hasSession(), isTrue);
    },
  );

  test(
    'gọi Data API: lấy JWT một lần rồi dùng lại; ensure_family gửi đúng body',
    () async {
      await client.signIn('bo@example.com', 'matkhau123');
      await client.ensureFamily();
      await client.api('GET', 'children');
      expect(neon.tokenCalls, 1);
      final rpc = neon.log.firstWhere((l) => l.table == 'rpc/ensure_family');
      expect(rpc.body, {'p_display_name': ''});
    },
  );

  test('401 từ Data API thì làm mới JWT một lần rồi thử lại', () async {
    await client.signIn('bo@example.com', 'matkhau123');
    var n = 0;
    neon.forceStatus = (r) =>
        (r.url.path.endsWith('/children') && n++ == 0) ? 401 : null;
    await client.api('GET', 'children');
    expect(neon.tokenCalls, 2);
  });

  test(
    'phiên hết hạn: lỗi auth; sai mật khẩu: thông điệp tiếng Việt',
    () async {
      store.data[NeonClient.cookieKey] = 'neon-auth.session_token=het-han';
      await expectLater(
        client.api('GET', 'children'),
        throwsA(
          isA<NeonException>().having(
            (e) => e.kind,
            'kind',
            NeonErrorKind.auth,
          ),
        ),
      );
      await expectLater(
        client.signIn('a@b.c', 'sai'),
        throwsA(
          isA<NeonException>().having(
            (e) => e.message,
            'message',
            'Email hoặc mật khẩu không đúng.',
          ),
        ),
      );
    },
  );

  test('mất mạng: lỗi network', () async {
    await client.signIn('bo@example.com', 'matkhau123');
    neon.dropRequest = (_) => true;
    await expectLater(
      client.api('GET', 'children'),
      throwsA(
        isA<NeonException>().having(
          (e) => e.kind,
          'kind',
          NeonErrorKind.network,
        ),
      ),
    );
  });

  test('đăng xuất xóa phiên trên máy', () async {
    await client.signIn('bo@example.com', 'matkhau123');
    await client.signOut();
    expect(store.data, isEmpty);
    expect(await client.hasSession(), isFalse);
  });
}
