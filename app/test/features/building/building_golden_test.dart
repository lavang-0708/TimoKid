/// Golden test cho màn Tòa nhà (PR (B)): chặng 0 (Lâu đài Lôgic,
/// chưa làm) ở 800x360.
///
/// Mẫu `room_golden_test.dart`: nạp font DejaVu thành 'Nunito',
/// giải mã ảnh golden từ base64 trước khi so.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/ui_images.dart';

import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/building/building_screen.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';

import '../../goldens/building_golden_data.dart';

void _restoreGoldens() {
  const goldens = {'test/goldens/building_800x360.png': building800x360Base64};
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
}

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;

  setUpAll(() async {
    await _loadTestFonts();
    _restoreGoldens();
  });

  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 18, 8, 0));
    db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
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
    await service.getOrCreateTodaySet(childId: childId);
  });

  testWidgets('màn tòa nhà chặng 0 ở 800x360', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        // Dùng đúng theme của app (fontFamily Nunito): không có
        // theme thì chữ dùng phông mặc định của engine nên ảnh
        // golden toàn ô vuông (xem `room_golden_test.dart`).
        child: MaterialApp(
          theme: AppTheme.light,
          home: const BuildingScreen(args: BuildingScreenArgs(stageIndex: 0)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('building-screen')), findsOneWidget);
    await precacheUiImages(tester);
    await expectLater(
      find.byKey(const Key('building-screen')),
      matchesGoldenFile('../../goldens/building_800x360.png'),
    );
  });
}
