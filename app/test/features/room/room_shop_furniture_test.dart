/// Test nội thất mua ở Cửa hàng trong Phòng (T2-06b): ô đặt tạm hợp lệ
/// (trong khung, dấu chân trên sàn, không chặn chỗ đứng mặc định), dấu
/// chân thêm chặn đường đi, Phòng chỉ vẽ món đã mua khi cờ hình bật,
/// xếp theo chân y, chạm ra bong bóng.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/room/room_assets.dart';
import 'package:timokid/features/room/room_screen.dart';
import 'package:timokid/features/room/room_walk.dart';
import 'package:timokid/features/shop/shop_catalog.dart';
import 'package:timokid/features/shop/shop_service.dart';

void main() {
  group('ô đặt tạm roomShopFurniture', () {
    test('đủ 8 món, mã khớp danh mục Cửa hàng, hình đúng đường dẫn', () {
      expect(roomShopFurniture, hasLength(8));
      expect({
        for (final f in roomShopFurniture) roomShopFurnitureId(f),
      }, shopFurniture.keys.toSet());
      for (final f in roomShopFurniture) {
        expect(f.asset, shopFurnitureAsset(roomShopFurnitureId(f)));
        expect(f.reaction, isNotEmpty);
      }
    });

    test('ảnh nằm trong khung 1600x900 (sàn chạm đáy được)', () {
      for (final f in roomShopFurniture) {
        expect(f.placeX, greaterThanOrEqualTo(0), reason: f.key);
        expect(f.placeY, greaterThanOrEqualTo(0), reason: f.key);
        expect(f.placeX + f.placeSize, lessThanOrEqualTo(roomFrameWidth));
        // Đáy ảnh 512 có phần trong suốt: cho phép lố tối đa 10% cỡ.
        expect(
          f.placeY + f.placeSize,
          lessThanOrEqualTo(roomFrameHeight + 0.1 * f.placeSize),
        );
      }
    });

    test('món sàn có dấu chân nằm trên sàn; món tường không chặn đường', () {
      for (final f in roomShopFurniture) {
        if (f.wall) {
          expect(f.footprint, isNull, reason: f.key);
          continue;
        }
        final fp = f.footprint!;
        expect(fp.bottom, lessThanOrEqualTo(f.anchor.dy), reason: f.key);
        for (final corner in [fp.topLeft, fp.topRight, fp.bottomCenter]) {
          expect(
            roomPointInFloor(corner.translate(0, 0.5)),
            isTrue,
            reason: '${f.key} $corner',
          );
        }
      }
      // Đèn (bậu cửa sổ), tranh (tường): không chặn đường.
      expect(roomShopFurniture.where((f) => f.wall), hasLength(2));
    });

    test('mua đủ cả 8 món vẫn đứng được ở chỗ mặc định và đi lại được', () {
      final extra = [
        for (final f in roomShopFurniture)
          if (f.footprint != null) f.footprint!,
      ];
      expect(roomWalkable(roomCharacterFeet, extra: extra), isTrue);
      expect(roomWalkable(roomPetFeet, extra: extra), isTrue);
      // Từ chỗ mặc định tới chỗ khác của sàn vẫn có đường.
      final path = roomWalkPath(
        roomCharacterFeet,
        const Offset(760, 740),
        extra: extra,
      );
      var at = roomCharacterFeet;
      for (final p in path) {
        expect(roomWalkable(p, extra: extra), isTrue, reason: '$p');
        at = p;
      }
      expect(at, const Offset(760, 740));
    });
  });

  group('dấu chân thêm trong room_walk', () {
    const block = Rect.fromLTRB(560, 740, 700, 780);

    test('không truyền extra: hành vi cũ không đổi', () {
      expect(roomWalkable(block.center), isTrue);
      expect(roomWalkTarget(block.center), block.center);
    });

    test('đứng trong dấu chân (kể cả lề) là không hợp lệ', () {
      expect(roomWalkable(block.center, extra: const [block]), isFalse);
      expect(
        roomWalkable(block.center.translate(0, 20), extra: const [block]),
        isFalse,
      );
      expect(
        roomWalkable(
          Offset(block.left - roomWalkMargin - 2, block.center.dy),
          extra: const [block],
        ),
        isTrue,
      );
    });

    test('chạm vào dấu chân thì dò ra chỗ đứng được; đường đi vòng', () {
      final t = roomWalkTarget(block.center, extra: const [block]);
      expect(roomWalkable(t, extra: const [block]), isTrue);
      final path = roomWalkPath(
        const Offset(400, 760),
        const Offset(860, 760),
        extra: const [block],
      );
      expect(path.length, greaterThan(1));
      var a = const Offset(400, 760);
      for (final p in path) {
        expect(roomWalkable(p, extra: const [block]), isTrue);
        a = p;
      }
      expect(a, const Offset(860, 760));
    });

    test('pet theo bé không đứng trong dấu chân', () {
      final spot = roomPetFollowSpot(
        const Offset(850, 760),
        kidFacingLeft: false,
        extra: const [Rect.fromLTRB(660, 730, 740, 790)],
      );
      expect(
        roomWalkable(spot, extra: const [Rect.fromLTRB(660, 730, 740, 790)]),
        isTrue,
      );
    });
  });

  group('Phòng vẽ nội thất mua', () {
    late AppDatabase db;
    late String childId;

    setUp(() async {
      db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      childId = await db.ensureSeeded();
      await OnboardingService(db: db).completeOnboarding(
        childId: childId,
        profile: CharacterProfile.defaults().copyWith(
          dress: 'girl_top_02',
          name: 'An',
        ),
        eggSpecies: 'dog',
      );
      // Cho thẳng vào kho (nguồn shop) 3 món: sàn, sàn, tường.
      for (final id in ['noi_nha_pet', 'noi_be_ca', 'noi_tranh']) {
        await db.inventoryDao.grant(
          childId: childId,
          itemId: id,
          source: InventorySource.shop,
        );
      }
    });

    Future<void> pumpRoom(WidgetTester tester, {required bool ready}) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: RoomScreen.route,
        routes: [
          GoRoute(
            path: RoomScreen.route,
            builder: (context, state) =>
                RoomScreen(cleanBackground: true, furnitureArtReady: ready),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('cờ hình tắt: không vẽ dù đã mua', (tester) async {
      await pumpRoom(tester, ready: false);
      expect(find.byKey(const Key('room-furniture-noi_nha_pet')), findsNothing);
      expect(find.byKey(const Key('room-furniture-noi_tranh')), findsNothing);
      // Đồ có sẵn vẫn còn.
      expect(find.byKey(const Key('room-furniture-chau-cay')), findsOneWidget);
    });

    testWidgets('cờ hình bật: chỉ vẽ món đã mua, đúng ô, chạm ra bong bóng', (
      tester,
    ) async {
      await pumpRoom(tester, ready: true);
      expect(
        find.byKey(const Key('room-furniture-noi_nha_pet')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('room-furniture-noi_be_ca')), findsOneWidget);
      expect(find.byKey(const Key('room-furniture-noi_tranh')), findsOneWidget);
      expect(find.byKey(const Key('room-furniture-noi_leu')), findsNothing);
      expect(
        find.byKey(const Key('room-furniture-noi_den_trang')),
        findsNothing,
      );

      // Ô đặt: tỉ lệ khung nền (ảnh phủ vừa khung cảnh).
      final floor = tester.getRect(find.byKey(const Key('room-floor')));
      final house = roomShopFurniture.firstWhere(
        (f) => f.key == 'room-furniture-noi_nha_pet',
      );
      final r = tester.getRect(
        find.byKey(const Key('room-furniture-noi_nha_pet')),
      );
      expect(
        r.width,
        closeTo(house.placeSize / roomFrameWidth * floor.width, 0.5),
      );
      expect(
        r.left,
        closeTo(floor.left + house.placeX / roomFrameWidth * floor.width, 0.5),
      );

      await tester.tap(find.byKey(const Key('room-furniture-noi_nha_pet')));
      await tester.pump();
      expect(find.text('Nhà của pet ấm áp quá!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('room-reaction-bubble')), findsNothing);
    });

    testWidgets('chạm vào dấu chân nội thất: nhân vật không đứng đè lên', (
      tester,
    ) async {
      await pumpRoom(tester, ready: true);
      final floor = tester.getRect(find.byKey(const Key('room-floor')));
      final fp = roomShopFurniture
          .firstWhere((f) => f.key == 'room-furniture-noi_nha_pet')
          .footprint!;
      Offset toScreen(Offset f) => Offset(
        floor.left + f.dx / roomFrameWidth * floor.width,
        floor.top + f.dy / roomFrameHeight * floor.height,
      );
      await tester.tapAt(toScreen(fp.center));
      await tester.pumpAndSettle();
      // Chân nhân vật = đáy hộp nhân vật theo tỉ lệ chân; đủ kiểm gần
      // đúng: tâm ngang nhân vật không nằm trong dải dấu chân đã phình.
      final kid = tester.getRect(find.byKey(const Key('room-character')));
      final feetFrame = Offset(
        (kid.center.dx - floor.left) / floor.width * roomFrameWidth,
        (kid.bottom - floor.top) / floor.height * roomFrameHeight,
      );
      expect(fp.inflate(roomWalkMargin).contains(feetFrame), isFalse);
    });
  });
}
