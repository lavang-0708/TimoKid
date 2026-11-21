/// Golden test cho màn Thị trấn (T1-12): trước, giữa và sau khi xong
/// đề ngày — đúng 3 ảnh nghiệm thu của T1-12, chụp ở 800x360.
///
/// Làm theo mẫu `golden_test.dart` của T1-02: nạp font DejaVu Sans của
/// máy làm font 'Nunito' (fontFamily của AppTheme, PLAN điểm (m)) để
/// chữ đọc được — DejaVu là phông đứng chỗ cho Nunito để ảnh golden
/// khớp nhau giữa máy local và CI; Nunito thật kiểm bằng mắt trên máy
/// thật. Ảnh kỳ vọng nhúng base64 trong `goldens/town_golden_data.dart`
/// và được giải mã ra file PNG trước khi so sánh. Chạy lại bằng
/// `flutter test --update-goldens` rồi sinh lại file dữ liệu base64
/// từ PNG (xem ghi chú trong file đó).
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/ui_images.dart';

import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/math/math_screen.dart';
import 'package:timokid/features/stage_result/stage_result_screen.dart';
import 'package:timokid/features/town/town_assets.dart';
import 'package:timokid/features/town/town_screen.dart';

import '../../goldens/town_golden_data.dart';

AppDatabase openMemoryDb({Clock? clock}) => AppDatabase(
  executor: NativeDatabase.memory(),
  clock: clock ?? const SystemClock(),
);

void _restoreGoldens() {
  const goldens = {
    'test/goldens/town_before.png': townBeforeBase64,
    'test/goldens/town_during.png': townDuringBase64,
    'test/goldens/town_after.png': townAfterBase64,
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
  });

  Future<void> pumpTown(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Router mới mỗi test (không dùng router tĩnh của app để trạng
    // thái điều hướng không rò sang test khác).
    final router = GoRouter(
      initialLocation: TownScreen.route,
      routes: [
        GoRoute(
          path: TownScreen.route,
          builder: (context, state) => const TownScreen(),
        ),
        GoRoute(
          path: MathScreen.route,
          builder: (context, state) =>
              MathScreen(args: state.extra as MathScreenArgs?),
        ),
        GoRoute(
          path: StageResultScreen.route,
          builder: (context, state) =>
              StageResultScreen(result: state.extra as StageResultArgs?),
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

  Future<void> setStatuses(List<String> statuses) async {
    for (var i = 0; i < statuses.length; i++) {
      await db.dailySetsDao.updateStageStatus(
        id: setId,
        stageIndex: i,
        status: statuses[i],
      );
    }
  }

  /// Nạp trước nền + 17 lớp động vào ImageCache (mẫu
  /// `room_golden_test.dart` / A1): codec giải mã chỉ chạy trong
  /// async thật (`runAsync`), fake async của `pump` không lái được
  /// nó — không có bước này thì ảnh chụp golden thiếu nền/lớp động
  /// (test đầu chạy khi ảnh chưa kịp về, test sau mới có vì đã
  /// cache — bắt bằng mắt ở golden `town_before` A2).
  Future<void> precacheImages(WidgetTester tester) async {
    final context = tester.element(find.byKey(const Key('town-screen')));
    await tester.runAsync(() async {
      await precacheImage(const AssetImage(townBackgroundAsset), context);
      for (final path in [...townLayerAssets, ...uiImagePaths]) {
        await precacheImage(AssetImage(path), context);
      }
    });
    await tester.pump();
  }

  testWidgets('Thị trấn trước khi làm đề ngày (0/5 chặng)', (tester) async {
    await pumpTown(tester);
    await precacheImages(tester);
    await expectLater(
      find.byKey(const Key('town-screen')),
      matchesGoldenFile('../../goldens/town_before.png'),
    );
  });

  testWidgets('Thị trấn giữa đề ngày (2/5 chặng, 45 xu)', (tester) async {
    await setStatuses([
      StageStatus.done,
      StageStatus.done,
      StageStatus.inProgress,
      StageStatus.notStarted,
      StageStatus.notStarted,
    ]);
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: 45,
      reason: 'test',
    );
    await pumpTown(tester);
    await precacheImages(tester);
    await expectLater(
      find.byKey(const Key('town-screen')),
      matchesGoldenFile('../../goldens/town_during.png'),
    );
  });

  testWidgets('Thị trấn sau khi xong đề ngày (5/5 chặng, 120 xu, 1 ◆)', (
    tester,
  ) async {
    await setStatuses(List.filled(5, StageStatus.done));
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: 120,
      reason: 'test',
    );
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.gem,
      amount: 1,
      reason: 'test',
    );
    await pumpTown(tester);
    await precacheImages(tester);
    await expectLater(
      find.byKey(const Key('town-screen')),
      matchesGoldenFile('../../goldens/town_after.png'),
    );
  });
}
