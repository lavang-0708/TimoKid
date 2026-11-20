/// Widget test màn mở đầu (T2-03): đi các bước, quay lại, kiểm tên,
/// chọn trứng, lưu xong vào Thị trấn.
///
/// Dáng nữ (bộ nhân vật nữ 1, PR #18) chỉ có 5 bước: giới tính, màu
/// tóc, váy, tên, trứng — không có bước màu da/kiểu mắt/kiểu miệng.
/// Dáng nam (chưa có hình thật) giữ 7 bước cũ với xem trước tạm.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/router/app_router.dart';
import 'package:timokid/features/character/placeholder_layers.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/main.dart';

void main() {
  late AppDatabase db;
  late String childId;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    childId = await db.ensureSeeded();
  });

  Future<void> pumpOnboarding(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        // Xem trước dùng lớp tạm (không có file hình thật ở local);
        // khi chạy app thì router mặc định dùng hình thật.
        child: TimoKidApp(
          router: AppRouter.create(
            showOnboarding: true,
            previewLoader: placeholderLayerLoader,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
  }

  /// Đi từ bước giới tính nữ tới bước đặt tên (3 lần Tiếp): chọn màu
  /// tóc nâu, chọn váy tím.
  Future<void> goToNameStepGirl(WidgetTester tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.byKey(const Key('onboarding-gender-girl')));
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-hair-color-1')));
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-dress-girl_top_02')));
    await tapNext(tester);
    expect(find.text('Đặt tên cho nhân vật'), findsOneWidget);
  }

  /// Đi từ bước giới tính nam tới bước đặt tên (5 lần Tiếp).
  Future<void> goToNameStepBoy(WidgetTester tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.byKey(const Key('onboarding-gender-boy')));
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-skin-0')));
    await tapNext(tester);
    await tester.tap(
      find.byKey(const Key('onboarding-hair-style-girl_hair_02')),
    );
    await tapNext(tester);
    await tester.tap(
      find.byKey(const Key('onboarding-eye-style-girl_eyes_03')),
    );
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-mouth-girl_mouth_02')));
    await tapNext(tester);
    expect(find.text('Đặt tên cho nhân vật'), findsOneWidget);
  }

  testWidgets('mở đầu hiện bước giới tính nữ (5 bước) + xem trước', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    expect(find.byKey(const Key('onboarding-screen')), findsOneWidget);
    expect(find.text('Bước 1/5'), findsOneWidget);
    expect(find.text('Bé là bé gái hay bé trai?'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-preview')), findsOneWidget);
    expect(find.text('Hình tạm'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-back-button')), findsNothing);
  });

  testWidgets('nữ không có bước màu da/kiểu mắt/kiểu miệng, có bước váy', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    await tester.tap(find.byKey(const Key('onboarding-gender-girl')));
    await tapNext(tester);
    // Bước 2/5: chỉ chọn màu tóc.
    expect(find.text('Bước 2/5'), findsOneWidget);
    expect(find.text('Chọn màu tóc'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-skin-0')), findsNothing);
    expect(
      find.byKey(const Key('onboarding-hair-style-girl_hair_01')),
      findsNothing,
    );
    await tapNext(tester);
    // Bước 3/5: chọn váy (đồ gốc / váy hồng / váy tím).
    expect(find.text('Bước 3/5'), findsOneWidget);
    expect(find.text('Chọn váy'), findsOneWidget);
    expect(find.text('Bộ đồ gốc'), findsOneWidget);
    expect(find.text('Váy hồng'), findsOneWidget);
    expect(find.text('Váy tím'), findsOneWidget);
    expect(
      find.byKey(const Key('onboarding-eye-style-girl_eyes_01')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('onboarding-mouth-girl_mouth_01')),
      findsNothing,
    );
  });

  testWidgets('nam vẫn đủ 7 bước (màu da/kiểu mắt/kiểu miệng)', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.byKey(const Key('onboarding-gender-boy')));
    await tapNext(tester);
    expect(find.text('Bước 2/7'), findsOneWidget);
    expect(find.text('Chọn màu da'), findsOneWidget);
    await tapNext(tester);
    expect(find.text('Bước 3/7'), findsOneWidget);
    expect(find.text('Chọn kiểu tóc và màu tóc'), findsOneWidget);
    await tapNext(tester);
    expect(find.text('Bước 4/7'), findsOneWidget);
    expect(find.text('Chọn kiểu mắt và màu mắt'), findsOneWidget);
    await tapNext(tester);
    expect(find.text('Bước 5/7'), findsOneWidget);
    expect(find.text('Chọn kiểu miệng'), findsOneWidget);
  });

  testWidgets('quay lại được ở mọi bước (nữ)', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.byKey(const Key('onboarding-gender-girl')));
    await tapNext(tester);
    await tapNext(tester);
    expect(find.text('Bước 3/5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-back-button')));
    await tester.pumpAndSettle();
    expect(find.text('Bước 2/5'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-back-button')));
    await tester.pumpAndSettle();
    expect(find.text('Bước 1/5'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-back-button')), findsNothing);
  });

  /// Nhập tên vào ô tên (enterText không tự pump nên phải pump để
  /// onChanged chạy và nút Tiếp mở khóa).
  Future<void> enterName(WidgetTester tester, String name) async {
    await tester.enterText(
      find.byKey(const Key('onboarding-name-field')),
      name,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tên rỗng thì nút Tiếp bị khóa; nhập tên thì mở', (tester) async {
    await goToNameStepGirl(tester);

    final next = find.byKey(const Key('onboarding-next-button'));
    expect(tester.widget<ElevatedButton>(next).onPressed, isNull);
    await enterName(tester, 'An');
    expect(tester.widget<ElevatedButton>(next).onPressed, isNotNull);
  });

  testWidgets('chưa chọn trứng thì nút Xong bị khóa; chọn rồi thì mở', (
    tester,
  ) async {
    await goToNameStepGirl(tester);
    await enterName(tester, 'An');
    await tapNext(tester);
    expect(find.text('Chọn một quả trứng'), findsOneWidget);

    final finish = find.byKey(const Key('onboarding-finish-button'));
    expect(tester.widget<ElevatedButton>(finish).onPressed, isNull);
    await tester.tap(find.byKey(const Key('onboarding-egg-cat')));
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(finish).onPressed, isNotNull);
  });

  testWidgets('bước chọn trứng: hình PNG thật, không còn SVG tạm', (
    tester,
  ) async {
    await goToNameStepGirl(tester);
    await enterName(tester, 'An');
    await tapNext(tester);
    expect(find.text('Chọn một quả trứng'), findsOneWidget);

    for (final species in ['dog', 'cat', 'rabbit']) {
      final card = find.byKey(Key('onboarding-egg-$species'));
      final image = find.descendant(of: card, matching: find.byType(Image));
      expect(image, findsOneWidget);
      final provider = tester.widget<Image>(image).image;
      expect(provider, isA<AssetImage>());
      expect(
        (provider as AssetImage).assetName,
        'assets/images/pets/${species}_egg.png',
      );
    }
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('đi hết 5 bước nữ: lưu hồ sơ + trứng rồi vào Thị trấn', (
    tester,
  ) async {
    await goToNameStepGirl(tester);
    await enterName(tester, 'An');
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-egg-cat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-finish-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('town-screen')), findsOneWidget);
    expect(find.text('Thị trấn Diệu Kỳ'), findsOneWidget);

    final service = OnboardingService(db: db);
    expect(await service.isCompleted(), isTrue);
    final profile = await service.loadProfile(childId);
    expect(profile, isNotNull);
    expect(profile!.name, 'An');
    expect(profile.gender, 'girl');
    // Nữ bộ 1: kiểu tóc cố định, màu tóc nâu đã chọn, váy tím.
    expect(profile.hairStyle, 'girl_hair_01');
    expect(profile.hairColor, 0xFFA9715C);
    expect(profile.dress, 'girl_top_02');
    expect(
      await db.settingsDao.getValue(childId: childId, key: 'selected_egg'),
      'cat',
    );
    final child = await db.childrenDao.getChild(childId);
    expect(child!.name, 'An');
  });

  testWidgets('đi hết 7 bước nam: lưu hồ sơ rồi vào Thị trấn', (tester) async {
    await goToNameStepBoy(tester);
    await enterName(tester, 'Bình');
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-egg-dog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-finish-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('town-screen')), findsOneWidget);

    final service = OnboardingService(db: db);
    final profile = await service.loadProfile(childId);
    expect(profile, isNotNull);
    expect(profile!.gender, 'boy');
    expect(profile.name, 'Bình');
    expect(profile.hairStyle, 'girl_hair_02');
    expect(profile.eyeStyle, 'girl_eyes_03');
    expect(profile.mouthStyle, 'girl_mouth_02');
    expect(profile.dress, isNull);
    expect(
      await db.settingsDao.getValue(childId: childId, key: 'selected_egg'),
      'dog',
    );
  });
}
