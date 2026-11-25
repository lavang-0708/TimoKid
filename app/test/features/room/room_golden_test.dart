/// Golden test cho màn Phòng (T2-04): khóa (0/5 chặng, trứng chưa nở)
/// và mở (5/5 chặng, pet đã nở) ở 800x360.
///
/// Dùng hồ sơ NAM để lớp nhân vật là lớp tạm xám (ổn định tuyệt đối
/// khi chạy local lẫn CI); hồ sơ nữ dùng hình thật `girl_body_01.webp`
/// — máy local không có file PNG thật (chỉ có ảnh thay thế trong
/// suốt) nên ảnh sẽ lệch với CI. Xem chú thích ở
/// `test/goldens/room_golden_data.dart` để sinh lại ảnh.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/features/character/kid_assets.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/character/placeholder_layers.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/onboarding/egg_service.dart';
import 'package:timokid/features/onboarding/onboarding_config.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/room/coming_soon_screen.dart';
import 'package:timokid/features/room/room_assets.dart';
import 'package:timokid/features/room/room_screen.dart';
import 'package:timokid/features/town/town_screen.dart';

import '../../helpers/quest_pin.dart';
import '../../goldens/room_golden_data.dart';
import '../../helpers/kid_images.dart';

AppDatabase openMemoryDb({Clock? clock}) => AppDatabase(
  executor: NativeDatabase.memory(),
  clock: clock ?? const SystemClock(),
);

void _restoreGoldens() {
  const goldens = {
    'test/goldens/room_locked.png': roomLockedBase64,
    'test/goldens/room_unlocked.png': roomUnlockedBase64,
  };
  for (final entry in goldens.entries) {
    File(entry.key).writeAsBytesSync(base64Decode(entry.value));
  }
}

Future<void> _loadTestFonts() async {
  final bytes = File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')
      .readAsBytesSync();
  final loader = FontLoader('Nunito')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
  final testerExe = File(Platform.resolvedExecutable);
  final iconsFile = File(
    '${testerExe.parent.parent.parent.parent.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (await iconsFile.exists()) {
    final icons = FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.view(iconsFile.readAsBytesSync().buffer)));
    await icons.load();
  }
}

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late String setId;

  setUpAll(() async {
    await _loadTestFonts();
    _restoreGoldens();
  });

  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 18, 8, 0));
    db = openMemoryDb(clock: clock);
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    await pinQuestsForGolden(db, childId);
    final service = DailySetService(
      dailySetsDao: db.dailySetsDao,
      reviewQueueDao: db.reviewQueueDao,
      ladderService: LadderService(
        attemptsDao: db.attemptsDao,
        skillProgressDao: db.skillProgressDao,
      ),
      clock: clock,
    );
    final set = await service.getOrCreateTodaySet(childId: childId);
    setId = set.id;
    // Hồ sơ nam: nhân vật tạm xám, ổn định tuyệt đối khi chụp golden.
    await OnboardingService(db: db).completeOnboarding(
      childId: childId,
      profile: CharacterProfile.defaults().copyWith(
        gender: 'boy',
        name: 'Bình',
      ),
      eggSpecies: 'dog',
    );
  });

  Future<void> pumpRoom(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Router mới mỗi test (không dùng router tĩnh của app để trạng
    // thái điều hướng không rò sang test khác).
    final router = GoRouter(
      initialLocation: RoomScreen.route,
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
          path: ComingSoonScreen.route,
          builder: (context, state) =>
              ComingSoonScreen(args: state.extra as ComingSoonArgs),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        // Dùng đúng theme của app (fontFamily Nunito, màu pastel):
        // không có theme thì chữ dùng phông mặc định của engine
        // (Roboto — không nạp ở đây) nên ảnh golden toàn ô vuông.
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Nạp trước ảnh lớp tạm vào ImageCache (mẫu
  /// `character_golden_test.dart` / `onboarding_golden_test.dart`):
  /// codec giải mã chỉ chạy trong async thật (`runAsync`), fake async
  /// của `pump` không lái được nó — không có bước này thì nhân vật
  /// trong ảnh chụp golden trắng trơn.
  Future<void> precacheImages(WidgetTester tester) async {
    final context = tester.element(find.byKey(const Key('room-screen')));
    await tester.runAsync(() async {
      for (final path in placeholderLayerBase64.keys) {
        await precacheImage(placeholderLayerLoader(path), context);
      }
      // PNG trứng/pet thật (PR #21): nạp trước để ảnh chụp golden
      // không trắng trơn (cùng lý do như lớp tạm xám — mẫu
      // `onboarding_golden_test.dart`).
      for (final path in [
        ...eggSpeciesAssets.values,
        ...newbornSpeciesAssets.values,
        ...kidImagePaths(),
      ]) {
        await precacheImage(AssetImage(path), context);
        // Ảnh khung nhân vật hiển thị qua ResizeImage (khóa đệm riêng).
        if (path.startsWith('assets/images/character/')) {
          await precacheImage(kidImage(path), context);
        }
      }
      // Nền + nội thất PNG v3b (D): nạp trước để ảnh chụp golden
      // không trắng trơn (cùng lý do như trứng/pet).
      for (final path in [
        roomBackgroundAsset,
        roomCleanBackgroundAsset,
        ...roomFurniture.map((f) => f.asset),
      ]) {
        await precacheImage(AssetImage(path), context);
      }
    });
    await tester.pump();
  }

  Future<void> markAllDone() async {
    for (var i = 0; i < 5; i++) {
      await db.dailySetsDao.updateStageStatus(
        id: setId,
        stageIndex: i,
        status: StageStatus.done,
      );
    }
  }

  testWidgets('Phòng khi khóa (0/5 chặng, trứng chưa nở)', (tester) async {
    await pumpRoom(tester);
    await precacheImages(tester);
    await expectLater(
      find.byKey(const Key('room-screen')),
      matchesGoldenFile('../../goldens/room_locked.png'),
    );
  });

  testWidgets('Phòng khi mở (5/5 chặng, pet đã nở)', (tester) async {
    await markAllDone();
    await EggService(db: db).noteStageCompleted(childId);
    await EggService(db: db).consumeHatchCelebration(childId);
    await pumpRoom(tester);
    await precacheImages(tester);
    await expectLater(
      find.byKey(const Key('room-screen')),
      matchesGoldenFile('../../goldens/room_unlocked.png'),
    );
  });
}
