/// Màn đăng nhập của bố/mẹ (T3-03): đăng nhập thành công, sai mật khẩu,
/// bỏ qua ("Dùng không cần tài khoản"), đăng ký, và không tràn ở màn nhỏ.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timokid/core/router/app_router.dart';
import 'package:timokid/core/sync/sync_providers.dart';
import 'package:timokid/features/auth/login_screen.dart';

import '../../helpers/sync_harness.dart';

void main() {
  routerFirstScreenTests();
  late SyncHarness h;

  setUp(() async {
    h = SyncHarness();
    await h.db.ensureSeeded();
  });

  GoRouter router() => GoRouter(
    initialLocation: '${LoginScreen.route}?first=1',
    routes: [
      GoRoute(
        path: LoginScreen.route,
        builder: (context, state) => const LoginScreen(next: '/next'),
      ),
      stubRoute('/next'),
    ],
  );

  Future<void> fill(WidgetTester tester, String email, String pw) async {
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), pw);
  }

  testWidgets('đăng nhập đúng: lưu phiên, gọi ensure_family, đi tiếp', (
    tester,
  ) async {
    final c = await h.pump(tester, router(), size: const Size(608, 248));
    // Nút bỏ qua thấy ngay, không cần cuộn, ở cả màn nhỏ nhất.
    expect(find.byKey(const Key('login-skip')), findsOneWidget);
    final skip = tester.getRect(find.byKey(const Key('login-skip')));
    expect(skip.bottom, lessThanOrEqualTo(248));
    await fill(tester, 'bo@example.com', 'matkhau123');
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stub/next')), findsOneWidget);
    expect(
      h.store.data['auth_cookie'],
      contains('neon-auth.session_token=abc123'),
    );
    expect(h.store.data['auth_email'], 'bo@example.com');
    expect(h.neon.log.where((l) => l.table == 'rpc/ensure_family'), isNotEmpty);
    expect(c.read(authProvider).signedIn, isTrue);
    expect(await h.db.settingsDao.getValue(key: loginPromptDoneKey), 'true');
    // Đồng bộ ngay sau đăng nhập: bé đã được gửi lên.
    expect(h.neon.table('children'), hasLength(1));
    // Không có token/mật khẩu trong kho ngoài cookie phiên và email.
    expect(h.store.data.keys.toSet(), {'auth_cookie', 'auth_email'});
  });

  testWidgets('sai mật khẩu: báo lỗi tiếng Việt, ở lại màn, chưa lưu phiên', (
    tester,
  ) async {
    final c = await h.pump(tester, router());
    await fill(tester, 'bo@example.com', 'sai-mat-khau');
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-error')), findsOneWidget);
    expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
    expect(find.byKey(const Key('login-screen')), findsOneWidget);
    expect(h.store.data, isEmpty);
    expect(c.read(authProvider).signedIn, isFalse);
    expect(await h.db.settingsDao.getValue(key: loginPromptDoneKey), isNull);
  });

  testWidgets('mất mạng khi đăng nhập: báo lỗi mạng, app không sập', (
    tester,
  ) async {
    h.neon.dropRequest = (_) => true;
    await h.pump(tester, router());
    await fill(tester, 'bo@example.com', 'matkhau123');
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không có mạng'), findsOneWidget);
    expect(find.byKey(const Key('login-screen')), findsOneWidget);
  });

  testWidgets(
    '"Dùng không cần tài khoản": đi tiếp, không gọi mạng, nhớ đã hỏi',
    (tester) async {
      await h.pump(tester, router());
      await tester.ensureVisible(find.byKey(const Key('login-skip')));
      await tester.tap(find.byKey(const Key('login-skip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stub/next')), findsOneWidget);
      expect(h.neon.log, isEmpty);
      expect(h.store.data, isEmpty);
      expect(await h.db.settingsDao.getValue(key: loginPromptDoneKey), 'true');
    },
  );

  testWidgets('chuyển sang đăng ký rồi tạo tài khoản', (tester) async {
    await h.pump(tester, router());
    await tester.tap(find.byKey(const Key('login-toggle-signup')));
    await tester.pumpAndSettle();
    expect(find.text('Bố/mẹ tạo tài khoản'), findsOneWidget);
    await fill(tester, 'moi@example.com', 'matkhau123');
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stub/next')), findsOneWidget);
  });

  for (final size in const [Size(608, 248), Size(640, 320), Size(800, 360)]) {
    testWidgets(
      'không tràn ở ${size.width.toInt()}x${size.height.toInt()} (cả khi có lỗi)',
      (tester) async {
        await h.pump(tester, router(), size: size);
        await fill(tester, 'bo@example.com', 'sai');
        await tester.ensureVisible(find.byKey(const Key('login-submit')));
        await tester.tap(find.byKey(const Key('login-submit')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('login-error')), findsOneWidget);
      },
    );
  }
}

/// Router thật của app: màn đầu theo trạng thái (T3-03).
void routerFirstScreenTests() {
  group('AppRouter màn đầu', () {
    testWidgets('lần đầu: đăng nhập → (bỏ qua) → chọn bé khi có từ 2 bé', (
      tester,
    ) async {
      final h = SyncHarness();
      await h.db.ensureSeeded();
      await h.db.childrenDao.createChild(name: 'Na');
      final router = AppRouter.create(showLogin: true, showProfilePicker: true);
      await h.pump(tester, router);
      expect(find.byKey(const Key('login-screen')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('login-skip')));
      await tester.tap(find.byKey(const Key('login-skip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-picker-screen')), findsOneWidget);
    });

    testWidgets('không cần đăng nhập, một bé: vào thẳng Phòng', (tester) async {
      final h = SyncHarness();
      await h.db.ensureSeeded();
      await h.pump(tester, AppRouter.create());
      expect(find.byKey(const Key('room-screen')), findsOneWidget);
    });
  });
}
