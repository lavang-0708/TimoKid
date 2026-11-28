/// Test màn Album và nút chụp ở Phòng (T5-05): lưới ảnh, xem to, xóa có
/// hỏi lại, trạng thái rỗng, nút chụp lưu ảnh (khung cảnh không gồm HUD),
/// không tràn ở cỡ nhỏ.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/album/album_screen.dart';
import 'package:timokid/features/album/photo_service.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/room/room_screen.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late Directory dir;

  setUp(() async {
    clock = FakeClock(DateTime(2027, 3, 1, 9));
    db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    dir = Directory.systemTemp.createTempSync('timokid_album_ui_');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  Future<Uint8List> tinyPng() async {
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawRect(
      const ui.Rect.fromLTWH(0, 0, 8, 5),
      ui.Paint()..color = const ui.Color(0xFFFFAA00),
    );
    final img = await rec.endRecording().toImage(8, 5);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> seedPhotos(WidgetTester tester, int n) async {
    await tester.runAsync(() async {
      final png = await tinyPng();
      final svc = PhotoAlbumService(db: db, directory: () async => dir);
      for (var i = 0; i < n; i++) {
        clock.advance(const Duration(minutes: 1));
        await svc.save(childId: childId, png: png, width: 8, height: 5);
      }
    });
  }

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(800, 360),
    String route = AlbumScreen.route,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: route,
      routes: [
        GoRoute(
          path: AlbumScreen.route,
          builder: (_, _) => const AlbumScreen(),
        ),
        GoRoute(path: RoomScreen.route, builder: (_, _) => const RoomScreen()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoDirectoryProvider.overrideWithValue(() async => dir),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  group('Album', () {
    testWidgets('rỗng: có lời nhắc chụp ảnh', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('album-empty')), findsOneWidget);
      expect(find.text('Album ảnh (0/60)'), findsOneWidget);
    });

    testWidgets('có ảnh: lưới hiện đủ ảnh, mới nhất đứng đầu', (tester) async {
      await seedPhotos(tester, 3);
      await pump(tester);
      expect(find.text('Album ảnh (3/60)'), findsOneWidget);
      final rows = await db.photosDao.listForChild(childId);
      expect(find.byKey(Key('album-photo-${rows.first.id}')), findsOneWidget);
      expect(find.byKey(const Key('album-grid')), findsOneWidget);
    });

    testWidgets('bấm ảnh mở xem to; Đóng thì không xóa', (tester) async {
      await seedPhotos(tester, 1);
      await pump(tester);
      final p = (await db.photosDao.listForChild(childId)).single;
      await tester.tap(find.byKey(Key('album-photo-${p.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('album-viewer')), findsOneWidget);
      await tester.tap(find.byKey(const Key('album-close-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('album-viewer')), findsNothing);
      expect(await db.photosDao.countForChild(childId), 1);
    });

    testWidgets('xóa có hỏi lại: Thôi giữ ảnh, Xóa mới xóa dòng và file', (
      tester,
    ) async {
      await seedPhotos(tester, 2);
      await pump(tester);
      final rows = await db.photosDao.listForChild(childId);
      final target = rows.first;
      await tester.tap(find.byKey(Key('album-photo-${target.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('album-delete-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('album-delete-confirm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('album-delete-cancel')));
      await tester.pumpAndSettle();
      expect(await db.photosDao.countForChild(childId), 2);

      await tester.tap(find.byKey(const Key('album-delete-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('album-delete-ok')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(await db.photosDao.countForChild(childId), 1);
      expect(File('${dir.path}/${target.fileName}').existsSync(), isFalse);
      expect(find.byKey(Key('album-photo-${target.id}')), findsNothing);
    });

    for (final size in const [Size(608, 248), Size(640, 320), Size(360, 640)]) {
      testWidgets('không tràn ở ${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        await seedPhotos(tester, 12);
        await pump(tester, size: size);
        final p = (await db.photosDao.listForChild(childId)).first;
        await tester.ensureVisible(find.byKey(Key('album-photo-${p.id}')));
        await tester.tap(find.byKey(Key('album-photo-${p.id}')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('album-delete-button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Nút chụp ở Phòng', () {
    Future<void> onboard() => OnboardingService(db: db).completeOnboarding(
      childId: childId,
      profile: CharacterProfile.defaults().copyWith(
        dress: 'girl_top_02',
        name: 'An',
      ),
      eggSpecies: 'dog',
    );

    testWidgets('bấm chụp: lưu một PNG đúng cỡ khung cảnh vào album', (
      tester,
    ) async {
      await onboard();
      await pump(tester, route: RoomScreen.route);
      expect(find.byKey(const Key('room-photo-button')), findsOneWidget);
      // Khung chụp chứa cảnh nhưng không chứa nút nào của HUD.
      final stage = find.byWidgetPredicate(
        (w) =>
            w is RepaintBoundary &&
            w.key is GlobalKey &&
            w.key.toString().contains('room-stage'),
      );
      expect(stage, findsOneWidget);
      expect(
        find.descendant(
          of: stage,
          matching: find.byKey(const Key('room-photo-button')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: stage,
          matching: find.byKey(const Key('room-shop-button')),
        ),
        findsNothing,
      );

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('room-photo-button')));
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pump(const Duration(milliseconds: 300));
      final rows = await db.photosDao.listForChild(childId);
      expect(rows, hasLength(1));
      // 800x360 x tỉ lệ 2 (cạnh dài 1600 < 2000).
      expect(rows.single.width, 1600);
      expect(rows.single.height, 720);
      final f = File('${dir.path}/${rows.single.fileName}');
      expect(f.existsSync(), isTrue);
      expect(f.readAsBytesSync().sublist(1, 4), [80, 78, 71]); // "PNG"
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    for (final size in const [Size(608, 248), Size(640, 320)]) {
      testWidgets(
        'hàng nút góc dưới không tràn ở ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          await onboard();
          await pump(tester, route: RoomScreen.route, size: size);
          expect(find.byKey(const Key('room-photo-button')), findsOneWidget);
          expect(find.byKey(const Key('room-album-button')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('nút Album mở màn album', (tester) async {
      await onboard();
      await pump(tester, route: RoomScreen.route);
      await tester.tap(find.byKey(const Key('room-album-button')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('album-screen')), findsOneWidget);
    });
  });
}
