/// Golden test màn mở đầu + màn nở trứng (T2-03).
///
/// Làm theo mẫu `math_golden_test.dart`: nạp font DejaVu Sans của máy
/// làm font 'Nunito' để chữ đọc được; ảnh kỳ vọng nhúng base64 trong
/// `goldens/onboarding_golden_data.dart` và được giải mã ra file PNG
/// trước khi so sánh. Chụp ở 800x360 (mặt phẳng ngang nhỏ, gần máy ảo
/// 640x320 nhất trong các cỡ chuẩn).
///
/// Màn mở đầu bơm trực tiếp (không qua router) để xác định: xem
/// trước nhân vật dùng lớp tạm xám, trứng dùng PNG thật (PR #21).
/// Màn nở bơm sau khi đặt cờ chờ nở, `pumpAndSettle` chạy hết hoạt
/// cảnh 2,4 giây nên ảnh chụp thấy pet mới nở + nút Tiếp tục.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/features/character/placeholder_layers.dart';
import 'package:timokid/features/onboarding/egg_service.dart';
import 'package:timokid/features/onboarding/hatch_screen.dart';
import 'package:timokid/features/onboarding/onboarding_config.dart';
import 'package:timokid/features/onboarding/onboarding_screen.dart';

import '../../goldens/onboarding_golden_data.dart';
import '../../helpers/kid_images.dart';

void _restoreGoldens() {
  const goldens = {
    'test/goldens/onboarding_gender.png': onboardingGenderBase64,
    'test/goldens/onboarding_hair.png': onboardingHairBase64,
    'test/goldens/onboarding_dress.png': onboardingDressBase64,
    'test/goldens/onboarding_name.png': onboardingNameBase64,
    'test/goldens/onboarding_egg.png': onboardingEggBase64,
    'test/goldens/onboarding_hatch.png': onboardingHatchBase64,
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
  late AppDatabase db;
  late String childId;

  setUpAll(() async {
    await _loadTestFonts();
    _restoreGoldens();
  });

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    childId = await db.ensureSeeded();
  });

  Future<void> pumpOnboarding(
    WidgetTester tester, {
    Size size = const Size(800, 360),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          // Golden giữ nguyên ảnh lớp tạm (không cần file hình thật
          // ở local); khi chạy app thì xem trước dùng hình thật.
          home: OnboardingScreen(previewLoader: placeholderLayerLoader),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
  }

  /// Nạp trước ảnh vào ImageCache (mẫu `character_golden_test.dart`):
  /// codec giải mã chỉ chạy trong async thật (`runAsync`), fake async
  /// của `pump` không lái được nó — không có bước này thì ảnh chụp
  /// golden trắng trơn (cả lớp xám MemoryImage lẫn PNG trứng/pet).
  Future<void> precacheImages(WidgetTester tester, Finder scope) async {
    final context = tester.element(scope);
    await tester.runAsync(() async {
      for (final path in placeholderLayerBase64.keys) {
        await precacheImage(placeholderLayerLoader(path), context);
      }
      // PNG trứng/pet thật (PR #21): nạp trước để ảnh chụp golden
      // không trắng trơn (cùng lý do như lớp tạm xám).
      for (final path in [
        ...eggSpeciesAssets.values,
        ...newbornSpeciesAssets.values,
        ...kidImagePaths(),
      ]) {
        await precacheImage(AssetImage(path), context);
      }
    });
    await tester.pump();
  }

  testWidgets('màn chọn giới tính', (tester) async {
    await pumpOnboarding(tester);
    await precacheImages(tester, find.byKey(const Key('onboarding-screen')));
    await expectLater(
      find.byKey(const Key('onboarding-screen')),
      matchesGoldenFile('../../goldens/onboarding_gender.png'),
    );
  });

  testWidgets('màn chọn bộ đồ (bé trai)', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.byKey(const Key('onboarding-gender-boy')));
    await tapNext(tester);
    await precacheImages(tester, find.byKey(const Key('onboarding-screen')));
    await expectLater(
      find.byKey(const Key('onboarding-screen')),
      matchesGoldenFile('../../goldens/onboarding_hair.png'),
    );
  });

  testWidgets('màn chọn bộ đồ (bé gái, bộ 3)', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.byKey(const Key('onboarding-gender-girl')));
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-dress-girl_top_03')));
    await tester.pumpAndSettle();
    await precacheImages(tester, find.byKey(const Key('onboarding-screen')));
    await expectLater(
      find.byKey(const Key('onboarding-screen')),
      matchesGoldenFile('../../goldens/onboarding_dress.png'),
    );
  });

  testWidgets('màn đặt tên', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.byKey(const Key('onboarding-gender-girl')));
    await tapNext(tester);
    await tapNext(tester);
    await precacheImages(tester, find.byKey(const Key('onboarding-screen')));
    await expectLater(
      find.byKey(const Key('onboarding-screen')),
      matchesGoldenFile('../../goldens/onboarding_name.png'),
    );
  });

  testWidgets('màn chọn trứng', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.byKey(const Key('onboarding-gender-girl')));
    await tapNext(tester);
    await tapNext(tester);
    await tester.enterText(
      find.byKey(const Key('onboarding-name-field')),
      'An',
    );
    await tester.pumpAndSettle();
    await tapNext(tester);
    await precacheImages(tester, find.byKey(const Key('onboarding-screen')));
    await expectLater(
      find.byKey(const Key('onboarding-screen')),
      matchesGoldenFile('../../goldens/onboarding_egg.png'),
    );
  });

  testWidgets('màn trứng nở xong', (tester) async {
    final eggs = EggService(db: db);
    await eggs.selectEgg(childId: childId, species: 'dog');
    await eggs.noteStageCompleted(childId);
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light, home: const HatchScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester, find.byKey(const Key('hatch-screen')));
    await expectLater(
      find.byKey(const Key('hatch-screen')),
      matchesGoldenFile('../../goldens/onboarding_hatch.png'),
    );
  });
}
