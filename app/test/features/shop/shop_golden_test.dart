/// Golden test màn Cửa hàng (T2-06) ở 800x360: nhóm Quần áo (100 xu: bộ
/// đang có + 2 bộ mua được) và nhóm Phụ kiện (50 xu: vài món mua được,
/// vài món báo còn thiếu). Bé gái, ảnh nhân vật thật.
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
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/features/character/kid_assets.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/shop/shop_screen.dart';

import '../../goldens/shop_golden_data.dart';
import '../../helpers/kid_images.dart';

void _restoreGoldens() {
  const goldens = {
    'test/goldens/shop_outfits_800x360.png': shopOutfitsBase64,
    'test/goldens/shop_accessories_800x360.png': shopAccessoriesBase64,
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
    await OnboardingService(db: db).completeOnboarding(
      childId: childId,
      profile: CharacterProfile.defaults().copyWith(
        dress: 'girl_top_01',
        name: 'An',
      ),
      eggSpecies: 'dog',
    );
  });

  Future<void> pumpShop(WidgetTester tester, int xu) async {
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: xu,
      reason: 'test',
    );
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: ShopScreen.route,
      routes: [
        GoRoute(
          path: ShopScreen.route,
          builder: (context, state) => const ShopScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Nạp trước ảnh vào ImageCache trong async thật (cùng lý do như
  /// `room_golden_test.dart`): thẻ món dùng `kidImage` (ResizeImage)
  /// nên phải nạp đúng provider đó, không thì ảnh chụp trắng trơn.
  Future<void> precacheImages(WidgetTester tester) async {
    final context = tester.element(find.byKey(const Key('shop-screen')));
    await tester.runAsync(() async {
      for (final path in kidImagePaths()) {
        await precacheImage(kidImage(path), context);
        await precacheImage(AssetImage(path), context);
      }
    });
    await tester.pump();
  }

  testWidgets('Cửa hàng 800x360: Quần áo (100 xu)', (tester) async {
    await pumpShop(tester, 100);
    await precacheImages(tester);
    await expectLater(
      find.byKey(const Key('shop-screen')),
      matchesGoldenFile('../../goldens/shop_outfits_800x360.png'),
    );
  });

  testWidgets('Cửa hàng 800x360: Phụ kiện (50 xu)', (tester) async {
    await pumpShop(tester, 50);
    await tester.tap(find.byKey(const Key('shop-tab-accessories')));
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await expectLater(
      find.byKey(const Key('shop-screen')),
      matchesGoldenFile('../../goldens/shop_accessories_800x360.png'),
    );
  });
}
