/// Hai công tắc "Âm thanh" và "Nhạc nền" (PLAN T2-08): nút loa ở HUD Phòng
/// và Thị trấn mở bảng, bật tắt được và lưu vào settings (không cần cổng
/// phụ huynh).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/features/room/room_screen.dart';
import 'package:timokid/features/town/town_screen.dart';

import '../../helpers/sync_harness.dart';

void main() {
  late SyncHarness h;

  setUp(() async {
    h = SyncHarness();
    await h.db.ensureSeeded();
  });

  GoRouter router(String start) => GoRouter(
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
    ],
  );

  for (final start in [RoomScreen.route, TownScreen.route]) {
    testWidgets('$start: công tắc lưu vào settings', (tester) async {
      await h.pump(tester, router(start));
      final button = find.byKey(const Key('sound-settings-button'));
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();

      Switch sw(String key) => tester.widget<Switch>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(Switch),
        ),
      );
      // Mặc định cả hai bật.
      expect(sw('toggle-sfx').value, isTrue);
      expect(sw('toggle-music').value, isTrue);

      await tester.tap(find.byKey(const Key('toggle-sfx')));
      await tester.pumpAndSettle();
      expect(await h.db.settingsDao.getValue(key: 'sound_enabled'), 'false');
      // Nhạc không đổi theo.
      expect(await h.db.settingsDao.getValue(key: 'music_enabled'), 'true');

      await tester.tap(find.byKey(const Key('toggle-music')));
      await tester.pumpAndSettle();
      expect(await h.db.settingsDao.getValue(key: 'music_enabled'), 'false');
      expect(sw('toggle-sfx').value, isFalse);
      expect(sw('toggle-music').value, isFalse);

      // Mở lại bảng: giữ nguyên trạng thái đã lưu.
      await tester.tapAt(const Offset(10, 10)); // đóng bảng
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(sw('toggle-sfx').value, isFalse);
      expect(sw('toggle-music').value, isFalse);

      await tester.tap(find.byKey(const Key('toggle-music')));
      await tester.pumpAndSettle();
      expect(await h.db.settingsDao.getValue(key: 'music_enabled'), 'true');
    });
  }
}
