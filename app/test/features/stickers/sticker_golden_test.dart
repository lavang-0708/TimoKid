/// Golden test bản 0.4 ở 800x360: Sổ sticker (trang Lôgic có khung vàng,
/// trang Hình học), cửa sổ "Sticker mới!" và màn Kết quả chặng có lời cảm
/// ơn của cư dân. Hình sticker/cư dân là hình vẽ bằng code (cờ
/// `stickerArtReady`/`residentArtReady` đang tắt).
///
/// Mẫu `building_golden_test.dart`: nạp font DejaVu thành 'Nunito' (+ font
/// MaterialIcons nếu có), giải mã ảnh golden từ base64 trước khi so.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/router/app_router.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/stage_result/stage_result_screen.dart';
import 'package:timokid/main.dart';

import '../../goldens/sticker_golden_data.dart';
import '../../helpers/ui_images.dart';

const _goldens = {
  'test/goldens/sticker_book_logic_800x360.png': stickerBookLogic800x360Base64,
  'test/goldens/sticker_book_geo_800x360.png': stickerBookGeo800x360Base64,
  'test/goldens/sticker_new_popup_800x360.png': stickerNewPopup800x360Base64,
  'test/goldens/stage_result_resident_800x360.png':
      stageResultResident800x360Base64,
};

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

const _mastered = [
  'logic.age',
  'logic.queue',
  'logic.balance',
  'logic.backward',
  'arith.quick',
  'arith.money',
  'number.cards',
  'geo.perim',
  'geo.cubes',
  'comb.outfit',
  'comb.handshake',
  'comb.flag',
];

void main() {
  late AppDatabase db;
  late String childId;

  setUpAll(() async {
    await _loadTestFonts();
    for (final e in _goldens.entries) {
      File(e.key).writeAsBytesSync(base64Decode(e.value));
    }
  });

  setUp(() async {
    db = AppDatabase(
      executor: NativeDatabase.memory(),
      clock: FakeClock(DateTime(2026, 11, 18, 8, 0)),
    );
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    await OnboardingService(db: db).completeOnboarding(
      childId: childId,
      profile: CharacterProfile.defaults().copyWith(
        dress: 'girl_top_01',
        name: 'Mai',
      ),
      eggSpecies: 'dog',
    );
  });

  Future<GoRouter> pump(
    WidgetTester tester,
    String location, {
    Object? extra,
  }) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = AppRouter.create();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: TimoKidApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    router.go(location, extra: extra);
    await tester.pumpAndSettle();
    await precacheUiImages(tester);
    return router;
  }

  Future<void> master(Iterable<String> forms) async {
    for (final f in forms) {
      await db.skillProgressDao.setFormMastered(
        childId: childId,
        formId: f,
        mastered: true,
      );
    }
  }

  testWidgets('Sổ sticker trang Lôgic (12 dạng thành thạo, khung vàng)', (
    tester,
  ) async {
    await master(_mastered);
    await pump(tester, '/stickers');
    await expectLater(
      find.byKey(const Key('sticker-book-screen')),
      matchesGoldenFile('../../goldens/sticker_book_logic_800x360.png'),
    );
  });

  testWidgets('Sổ sticker trang Hình học', (tester) async {
    await master(_mastered);
    await pump(tester, '/stickers');
    await tester.tap(find.byKey(const Key('sticker-tab-geo')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('sticker-book-screen')),
      matchesGoldenFile('../../goldens/sticker_book_geo_800x360.png'),
    );
  });

  testWidgets(
    'cửa sổ Sticker mới! sau màn kết quả (2 sticker, mốc khung vàng)',
    (tester) async {
      await master(_mastered.take(5));
      await pump(
        tester,
        StageResultScreen.route,
        extra: const StageResultArgs(
          stageIndex: 0,
          strand: 'logic',
          correctCount: 5,
          firstTryCorrectCount: 4,
          totalQuestions: 5,
          xuEarned: 20,
          nextStageIndex: 1,
        ),
      );
      expect(find.byKey(const Key('new-sticker-dialog')), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/sticker_new_popup_800x360.png'),
      );
    },
  );

  testWidgets('Kết quả chặng có lời cảm ơn của cư dân', (tester) async {
    await pump(
      tester,
      StageResultScreen.route,
      extra: const StageResultArgs(
        stageIndex: 1,
        strand: 'arith',
        correctCount: 5,
        firstTryCorrectCount: 4,
        totalQuestions: 5,
        xuEarned: 20,
        nextStageIndex: 2,
      ),
    );
    await expectLater(
      find.byKey(const Key('stage-result-screen')),
      matchesGoldenFile('../../goldens/stage_result_resident_800x360.png'),
    );
  });
}
