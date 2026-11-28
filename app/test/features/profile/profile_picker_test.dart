/// Nhiều bé (T3-03): màn chọn bé, "Thêm bé" (sau cổng phụ huynh) đi qua mở
/// đầu, dữ liệu bé đầu tiên giữ nguyên, router chọn đúng màn đầu.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/onboarding/onboarding_screen.dart';
import 'package:timokid/features/profile/profile_picker_screen.dart';
import 'package:timokid/features/profile/profile_service.dart';
import 'package:timokid/features/room/room_screen.dart';

import '../../helpers/sync_harness.dart';

void main() {
  late SyncHarness h;
  late String first;

  setUp(() async {
    h = SyncHarness();
    first = await h.db.ensureSeeded();
    // Bé tạo sau phải có giờ tạo muộn hơn (giờ lưu theo giây).
    (h.db.clock as FakeClock).advance(const Duration(minutes: 1));
    await h.db.walletDao.addEntry(
      childId: first,
      currency: Currency.xu,
      amount: 30,
      reason: 'answer_first_try',
    );
  });

  GoRouter router() => GoRouter(
    initialLocation: ProfilePickerScreen.route,
    routes: [
      GoRoute(
        path: ProfilePickerScreen.route,
        builder: (context, state) => const ProfilePickerScreen(),
      ),
      stubRoute(RoomScreen.route, 'room'),
      stubRoute(OnboardingScreen.route, 'onb'),
    ],
  );

  Future<void> passGate(WidgetTester tester) async {
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
  }

  testWidgets('hiện từng bé; chạm tên thì chọn bé đó và vào Phòng', (
    tester,
  ) async {
    final second = (await h.db.childrenDao.createChild(name: 'Na')).id;
    await h.pump(tester, router());
    expect(find.byKey(const Key('profile-picker-screen')), findsOneWidget);
    expect(find.byKey(Key('profile-card-$first')), findsOneWidget);
    expect(find.byKey(Key('profile-card-$second')), findsOneWidget);
    expect(find.text('Na'), findsOneWidget);

    await tester.tap(find.byKey(Key('profile-card-$second')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room/room')), findsOneWidget);
    expect(await h.db.ensureSeeded(), second);
  });

  testWidgets(
    'Thêm bé: cổng phụ huynh, tạo bé mới, vào mở đầu; bé đầu giữ dữ liệu',
    (tester) async {
      await h.db.childrenDao.createChild(name: 'Na');
      await h.pump(tester, router());
      await tester.tap(find.byKey(const Key('profile-add-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('parent-gate')), findsOneWidget);
      await passGate(tester);

      expect(find.byKey(const Key('onb/onboarding')), findsOneWidget);
      final all = await h.db.childrenDao.getChildrenInOrder();
      expect(all, hasLength(3));
      final created = all.last;
      expect(await h.db.ensureSeeded(), created.id); // bé mới đang chơi
      expect(
        await h.db.settingsDao.getValue(key: 'onboarding_completed'),
        'false',
      );
      expect(
        await h.db.skillProgressDao.getAllStrandProgress(created.id),
        hasLength(5),
      );
      // Dữ liệu cũ vẫn thuộc bé đầu tiên.
      expect((await h.db.childrenDao.getFirstChild())!.id, first);
      expect(
        await h.db.walletDao.balance(childId: first, currency: Currency.xu),
        30,
      );
      expect(
        await h.db.walletDao.balance(
          childId: created.id,
          currency: Currency.xu,
        ),
        0,
      );
    },
  );

  testWidgets('Thêm bé: sai cổng thì không tạo bé', (tester) async {
    await h.pump(tester, router());
    await tester.tap(find.byKey(const Key('profile-add-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('parent-gate-cancel')));
    await tester.pumpAndSettle();
    expect(await ProfileService(db: h.db).count(), 1);
    expect(find.byKey(const Key('profile-picker-screen')), findsOneWidget);
  });

  for (final size in const [Size(608, 248), Size(640, 320), Size(800, 360)]) {
    testWidgets(
      '4 bé không tràn ở ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        for (final n in ['Na', 'Bảo Ngọc Khánh An', 'Tí']) {
          await h.db.childrenDao.createChild(name: n);
        }
        await h.pump(tester, router(), size: size);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('profile-add-button')), findsOneWidget);
      },
    );
  }
}
