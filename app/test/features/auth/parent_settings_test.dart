/// Cài đặt cho bố/mẹ: email, lần đồng bộ gần nhất, đồng bộ ngay, đăng xuất
/// có giải thích, đổi mật khẩu, phiên hết hạn (cần đăng nhập lại).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/sync/sync_providers.dart';
import 'package:timokid/core/sync/sync_status_icon.dart';
import 'package:timokid/features/auth/login_screen.dart';
import 'package:timokid/features/auth/parent_settings_screen.dart';

import '../../helpers/sync_harness.dart';

void main() {
  late SyncHarness h;

  setUp(() async {
    h = SyncHarness();
    await h.db.ensureSeeded();
  });

  GoRouter router() => GoRouter(
    initialLocation: ParentSettingsScreen.route,
    routes: [
      GoRoute(
        path: ParentSettingsScreen.route,
        builder: (context, state) => const ParentSettingsScreen(),
      ),
      GoRoute(
        path: LoginScreen.route,
        builder: (context, state) => const LoginScreen(),
      ),
    ],
  );

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  test('formatSyncTime dùng dạng HH:mm dd/MM/yyyy', () {
    expect(formatSyncTime(DateTime(2026, 11, 28, 9, 5)), '09:05 28/11/2026');
  });

  testWidgets('hiện email, mốc đồng bộ và trạng thái; Đồng bộ ngay chạy', (
    tester,
  ) async {
    h.signIn();
    final c = await h.pump(tester, router(), size: const Size(800, 900));
    await c.read(authProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.textContaining('bo@example.com'), findsOneWidget);
    expect(find.textContaining('chưa có'), findsOneWidget);
    await tapKey(tester, 'parent-sync-now');
    await tester.pumpAndSettle();
    expect(c.read(syncControllerProvider).status, SyncStatus.synced);
    final at = c.read(syncControllerProvider).lastSyncedAt!;
    expect(find.textContaining(formatSyncTime(at)), findsOneWidget);
    expect(find.textContaining('Đã đồng bộ'), findsOneWidget);
    // Mốc được lưu để lần mở app sau còn hiện.
    expect(await h.db.settingsDao.getValue(key: lastSyncedKey), isNotNull);
  });

  testWidgets('đăng xuất: hỏi xác nhận, nói rõ dữ liệu còn trên máy', (
    tester,
  ) async {
    h.signIn();
    final c = await h.pump(tester, router(), size: const Size(800, 900));
    await c.read(authProvider.notifier).refresh();
    await tester.pumpAndSettle();
    await tapKey(tester, 'parent-logout');
    expect(find.textContaining('vẫn còn nguyên trên máy'), findsOneWidget);
    // Hủy thì vẫn đăng nhập.
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(c.read(authProvider).signedIn, isTrue);
    await tapKey(tester, 'parent-logout');
    await tapKey(tester, 'parent-logout-confirm');
    expect(c.read(authProvider).signedIn, isFalse);
    expect(h.store.data, isEmpty);
    expect(await h.db.settingsDao.getValue(key: lastSyncedKey), isNull);
    expect(await h.db.childrenDao.getFirstChild(), isNotNull);
  });

  group('đổi mật khẩu', () {
    Future<void> open(WidgetTester tester) async {
      h.signIn();
      final c = await h.pump(tester, router(), size: const Size(800, 900));
      await c.read(authProvider.notifier).refresh();
      await tester.pumpAndSettle();
      await tapKey(tester, 'parent-change-password');
    }

    Future<void> fill(
      WidgetTester tester,
      String cur,
      String n,
      String c,
    ) async {
      await tester.enterText(find.byKey(const Key('cp-current')), cur);
      await tester.enterText(find.byKey(const Key('cp-new')), n);
      await tester.enterText(find.byKey(const Key('cp-confirm')), c);
      await tester.tap(find.byKey(const Key('cp-submit')));
      await tester.pumpAndSettle();
    }

    testWidgets('đổi thành công', (tester) async {
      await open(tester);
      await fill(tester, 'matkhau123', 'matkhaumoi1', 'matkhaumoi1');
      expect(h.neon.passwordChanges, hasLength(1));
      expect(h.neon.passwordChanges.single['newPassword'], 'matkhaumoi1');
      expect(find.byKey(const Key('change-password-dialog')), findsNothing);
      expect(find.text('Đã đổi mật khẩu.'), findsOneWidget);
    });

    testWidgets('sai mật khẩu hiện tại: báo rõ, hộp thoại còn mở', (
      tester,
    ) async {
      await open(tester);
      await fill(tester, 'sai-roi', 'matkhaumoi1', 'matkhaumoi1');
      expect(find.text('Mật khẩu hiện tại chưa đúng.'), findsOneWidget);
      expect(h.neon.passwordChanges, isEmpty);
    });

    testWidgets('mật khẩu mới ngắn hoặc lệch: chặn trước khi gọi mạng', (
      tester,
    ) async {
      await open(tester);
      await fill(tester, 'matkhau123', 'ngan', 'ngan');
      expect(find.text('Mật khẩu mới cần ít nhất 8 ký tự.'), findsOneWidget);
      await fill(tester, 'matkhau123', 'matkhaumoi1', 'matkhaumoi2');
      expect(find.text('Hai mật khẩu mới chưa giống nhau.'), findsOneWidget);
      expect(h.neon.passwordChanges, isEmpty);
    });

    testWidgets('mất mạng: báo lỗi mạng', (tester) async {
      await open(tester);
      h.neon.dropRequest = (_) => true;
      await fill(tester, 'matkhau123', 'matkhaumoi1', 'matkhaumoi1');
      expect(find.textContaining('Không có mạng'), findsOneWidget);
    });
  });

  group('phiên hết hạn', () {
    testWidgets(
      'đồng bộ báo "cần đăng nhập lại", chạm đăng nhập lại mở màn đăng nhập',
      (tester) async {
        h.signIn();
        h.neon.sessionExpired = true;
        final c = await h.pump(tester, router(), size: const Size(800, 900));
        await c.read(authProvider.notifier).refresh();
        await c.read(syncControllerProvider.notifier).syncNow();
        await tester.pumpAndSettle();
        expect(c.read(syncControllerProvider).status, SyncStatus.needsLogin);
        expect(find.byKey(const Key('parent-relogin')), findsOneWidget);
        expect(find.textContaining('Cần đăng nhập lại'), findsWidgets);
        // Dữ liệu và việc chơi không bị chặn.
        expect(await h.db.childrenDao.getFirstChild(), isNotNull);
        await tapKey(tester, 'parent-relogin');
        expect(find.byKey(const Key('login-screen')), findsOneWidget);
        // Email cũ được điền sẵn; đăng nhập lại xong thì đồng bộ được.
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('login-email')))
              .controller!
              .text,
          'bo@example.com',
        );
        h.neon.sessionExpired = false;
        await tester.enterText(
          find.byKey(const Key('login-password')),
          'matkhau123',
        );
        await tester.ensureVisible(find.byKey(const Key('login-submit')));
        await tester.tap(find.byKey(const Key('login-submit')));
        await tester.pumpAndSettle();
        expect(c.read(syncControllerProvider).status, SyncStatus.synced);
      },
    );

    test('biểu tượng đám mây có nhãn "Cần đăng nhập lại"', () {
      final (_, _, text) = SyncStatusIcon.look(SyncStatus.needsLogin);
      expect(text, 'Cần đăng nhập lại');
    });
  });
}
