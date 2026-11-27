/// Hộp thư trong Phòng (T3-06): chấm đỏ khi có thư chưa mở, danh sách thư,
/// mở quà có hiệu ứng và chỉ nhận một lần, biểu tượng đồng bộ, cài đặt
/// bố/mẹ sau cổng; không tràn ở màn nhỏ.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/sync/sync_providers.dart';
import 'package:timokid/features/auth/login_screen.dart';
import 'package:timokid/features/auth/parent_settings_screen.dart';
import 'package:timokid/features/profile/profile_picker_screen.dart';
import 'package:timokid/features/room/room_screen.dart';
import 'package:timokid/features/town/town_screen.dart';

import '../../helpers/sync_harness.dart';

void main() {
  late SyncHarness h;
  late String childId;

  setUp(() async {
    h = SyncHarness();
    childId = await h.db.ensureSeeded();
  });

  GoRouter router([String start = RoomScreen.route]) => GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: RoomScreen.route,
        builder: (context, state) => const RoomScreen(),
      ),
      GoRoute(
        path: TownScreen.route,
        builder: (context, state) => const TownScreen(),
      ),
      GoRoute(
        path: ParentSettingsScreen.route,
        builder: (context, state) => const ParentSettingsScreen(),
      ),
      GoRoute(
        path: LoginScreen.route,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: ProfilePickerScreen.route,
        builder: (context, state) => const ProfilePickerScreen(),
      ),
    ],
  );

  Map<String, Object?> msg(
    String id, {
    int xu = 0,
    int gem = 0,
    String body = 'Bố thưởng con',
  }) => {
    'id': id,
    'child_id': childId,
    'body': body,
    'gift_xu': xu,
    'gift_gem': gem,
    'gift_item_id': null,
    'opened_at': null,
    'claimed_at': null,
    'created_at': '2026-11-28T08:00:00+00:00',
    'updated_at': '2026-11-28T08:00:00+00:00',
  };

  Future<void> syncInto(WidgetTester tester, c) async {
    await c.read(syncControllerProvider.notifier).syncNow();
    await tester.pumpAndSettle();
  }

  testWidgets('chưa có thư: có nút hộp thư, không có chấm đỏ; hộp thư trống', (
    tester,
  ) async {
    await h.pump(tester, router());
    expect(find.byKey(const Key('room-mail-button')), findsOneWidget);
    expect(find.byKey(const Key('mail-red-dot')), findsNothing);
    expect(find.byKey(const Key('sync-status-icon')), findsOneWidget);
    await tester.tap(find.byKey(const Key('room-mail-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mailbox-empty')), findsOneWidget);
  });

  testWidgets('thư mới về qua đồng bộ: hiện chấm đỏ; mở thư rồi chấm đỏ tắt', (
    tester,
  ) async {
    h.signIn();
    h.neon.table('messages')['m1'] = msg('m1', body: 'Con giỏi lắm!');
    final c = await h.pump(tester, router());
    await c.read(authProvider.notifier).refresh();
    await syncInto(tester, c);
    expect(find.byKey(const Key('mail-red-dot')), findsOneWidget);

    await tester.tap(find.byKey(const Key('room-mail-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mail-tile-m1')));
    await tester.pumpAndSettle();
    expect(find.text('Con giỏi lắm!'), findsWidgets);
    expect(find.byKey(const Key('mail-gift-open-button')), findsNothing);
    await tester.tap(find.byKey(const Key('mail-letter-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mailbox-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mail-red-dot')), findsNothing);
    // Trạng thái "đã mở" được gửi lên server.
    await syncInto(tester, c);
    expect(h.neon.table('messages')['m1']!['opened_at'], isNotNull);
  });

  testWidgets('mở quà: hiệu ứng, xu vào ví, chỉ nhận một lần', (tester) async {
    h.signIn();
    h.neon.table('messages')['m1'] = msg('m1', xu: 50, gem: 2);
    final c = await h.pump(tester, router());
    await c.read(authProvider.notifier).refresh();
    await syncInto(tester, c);
    expect(find.byKey(const Key('room-xu-balance')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('room-xu-balance'))).data,
      '0',
    );

    await tester.tap(find.byKey(const Key('room-mail-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mail-tile-m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mail-gift-open-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // giữa hiệu ứng
    expect(find.byKey(const Key('mail-gift-reveal')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('+50 xu'), findsOneWidget);
    expect(find.text('+2 kim cương'), findsOneWidget);
    expect(find.byKey(const Key('mail-gift-open-button')), findsNothing);
    expect(
      await h.db.walletDao.balance(childId: childId, currency: Currency.xu),
      50,
    );
    expect(
      await h.db.walletDao.balance(childId: childId, currency: Currency.gem),
      2,
    );

    // Đóng, mở lại thư: quà đã nhận, không có nút mở.
    await tester.tap(find.byKey(const Key('mail-letter-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mail-tile-m1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mail-gift-claimed')), findsOneWidget);
    expect(find.byKey(const Key('mail-gift-open-button')), findsNothing);
    await tester.tap(find.byKey(const Key('mail-letter-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mailbox-close')));
    await tester.pumpAndSettle();

    // HUD cập nhật số dư; đồng bộ lại không cộng thêm.
    expect(
      tester.widget<Text>(find.byKey(const Key('room-xu-balance'))).data,
      '50',
    );
    await syncInto(tester, c);
    await syncInto(tester, c);
    expect(
      await h.db.walletDao.balance(childId: childId, currency: Currency.xu),
      50,
    );
    expect(
      h.neon.log.where((l) => l.table == 'rpc/claim_message'),
      hasLength(1),
    );
  });

  testWidgets('mở quà khi mất mạng: báo lỗi, chưa cộng, thử lại được', (
    tester,
  ) async {
    h.signIn();
    h.neon.table('messages')['m1'] = msg('m1', xu: 50);
    final c = await h.pump(tester, router());
    await c.read(authProvider.notifier).refresh();
    await syncInto(tester, c);
    await tester.tap(find.byKey(const Key('room-mail-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mail-tile-m1')));
    await tester.pumpAndSettle();
    h.neon.dropRequest = (r) => r.url.path.endsWith('claim_message');
    await tester.tap(find.byKey(const Key('mail-gift-open-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mail-gift-error')), findsOneWidget);
    expect(
      await h.db.walletDao.balance(childId: childId, currency: Currency.xu),
      0,
    );
    h.neon.dropRequest = null;
    await tester.tap(find.byKey(const Key('mail-gift-open-button')));
    await tester.pumpAndSettle();
    expect(find.text('+50 xu'), findsOneWidget);
  });

  testWidgets(
    'biểu tượng đồng bộ: chưa đăng nhập → đã đồng bộ → mất mạng → lỗi',
    (tester) async {
      h.signIn();
      final c = await h.pump(tester, router());
      Finder icon(String s) => find.byKey(ValueKey('sync-icon-$s'));
      expect(icon('signedOut'), findsOneWidget);
      await c.read(authProvider.notifier).refresh();
      await syncInto(tester, c);
      expect(icon('synced'), findsOneWidget);
      h.neon.dropRequest = (_) => true;
      await syncInto(tester, c);
      expect(icon('offline'), findsOneWidget);
      // Mất mạng không chặn việc chơi: Phòng vẫn hiện.
      expect(find.byKey(const Key('room-screen')), findsOneWidget);
      h.neon.dropRequest = null;
      h.neon.forceStatus = (_) => 500; // Neon lỗi hoặc đang ngủ
      await syncInto(tester, c);
      expect(icon('error'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chạm biểu tượng → cổng phụ huynh → Cài đặt; đăng xuất xóa phiên',
    (tester) async {
      h.signIn();
      final c = await h.pump(tester, router());
      await c.read(authProvider.notifier).refresh();
      await tester.tap(find.byKey(const Key('sync-status-icon')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('parent-gate')), findsOneWidget);
      // Sai thì không vào.
      await tester.enterText(find.byKey(const Key('parent-gate-input')), '1');
      await tester.tap(find.byKey(const Key('parent-gate-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('parent-settings-screen')), findsNothing);
      final q = tester
          .widget<Text>(find.byKey(const Key('parent-gate-question')))
          .data!;
      final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
      await tester.enterText(
        find.byKey(const Key('parent-gate-input')),
        '${int.parse(m.group(1)!) * int.parse(m.group(2)!)}',
      );
      await tester.tap(find.byKey(const Key('parent-gate-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('parent-settings-screen')), findsOneWidget);
      expect(find.textContaining('bo@example.com'), findsOneWidget);

      await tester.tap(find.byKey(const Key('parent-logout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('parent-logout-confirm')));
      await tester.pumpAndSettle();
      expect(h.store.data, isEmpty);
      expect(c.read(authProvider).signedIn, isFalse);
      expect(find.byKey(const Key('parent-login')), findsOneWidget);
      // Dữ liệu của bé vẫn còn.
      expect(await h.db.childrenDao.getFirstChild(), isNotNull);
    },
  );

  for (final size in const [Size(608, 248), Size(640, 320), Size(800, 360)]) {
    testWidgets(
      'HUD Phòng + Thị trấn có chấm đỏ thư không tràn ở ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        h.signIn();
        h.neon.table('messages')['m1'] = msg('m1', xu: 5);
        final c = await h.pump(tester, router(), size: size);
        await c.read(authProvider.notifier).refresh();
        await syncInto(tester, c);
        expect(find.byKey(const Key('mail-red-dot')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('room-mail-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mail-tile-m1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mail-gift-open-button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('mail-letter-close')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mailbox-close')));
        await tester.pumpAndSettle();
        c.read(neonClientProvider);
        // Thị trấn.
        await tester.tap(find.byKey(const Key('room-town-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('town-screen')), findsOneWidget);
        expect(find.byKey(const Key('sync-status-icon')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
