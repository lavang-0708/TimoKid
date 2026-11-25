/// Widget test màn mở đầu (T2-03): đi các bước, quay lại, kiểm tên,
/// chọn trứng, lưu xong vào Phòng (màn chính từ T2-04).
///
/// Từ (E) cả hai dáng có cùng 4 bước: giới tính, bộ đồ (3 bộ ảnh toàn
/// thân của dáng đã chọn), tên, trứng. Màu da/tóc/mắt cố định theo
/// hình đã duyệt nên không còn bước chọn màu.
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

  /// Đi từ bước giới tính tới bước đặt tên (2 lần Tiếp), chọn bộ
  /// [outfitKey].
  Future<void> goToNameStep(
    WidgetTester tester, {
    required String gender,
    required String outfitKey,
  }) async {
    await pumpOnboarding(tester);
    await tester.tap(find.byKey(Key('onboarding-gender-$gender')));
    await tapNext(tester);
    await tester.tap(find.byKey(Key('onboarding-dress-$outfitKey')));
    await tapNext(tester);
    expect(find.text('Đặt tên cho nhân vật'), findsOneWidget);
  }

  Future<void> goToNameStepGirl(WidgetTester tester) =>
      goToNameStep(tester, gender: 'girl', outfitKey: 'girl_top_02');

  Future<void> goToNameStepBoy(WidgetTester tester) =>
      goToNameStep(tester, gender: 'boy', outfitKey: 'boy_outfit_03');

  testWidgets('mở đầu hiện bước giới tính (4 bước) + xem trước ảnh thật', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    expect(find.byKey(const Key('onboarding-screen')), findsOneWidget);
    expect(find.text('Bước 1/4'), findsOneWidget);
    expect(find.text('Bé là bé gái hay bé trai?'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-preview')), findsOneWidget);
    expect(find.byKey(const Key('kid-full-girl-1')), findsOneWidget);
    expect(find.text('Hình tạm'), findsNothing);
    expect(find.byKey(const Key('onboarding-back-button')), findsNothing);
  });

  testWidgets('bước bộ đồ: 3 bộ theo dáng, xem trước đổi theo bộ chọn', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    await tester.tap(find.byKey(const Key('onboarding-gender-girl')));
    await tapNext(tester);
    expect(find.text('Bước 2/4'), findsOneWidget);
    expect(find.text('Chọn bộ đồ'), findsOneWidget);
    expect(find.text('Váy hồng'), findsOneWidget);
    expect(find.text('Váy tím'), findsOneWidget);
    expect(find.text('Váy hồng tạp dề'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-skin-0')), findsNothing);
    await tester.tap(find.byKey(const Key('onboarding-dress-girl_top_03')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kid-full-girl-3')), findsOneWidget);

    // Đổi sang bé trai: về bộ 1 của bé trai, đủ 3 bộ của bé trai.
    await tester.tap(find.byKey(const Key('onboarding-back-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-gender-boy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kid-full-boy-1')), findsOneWidget);
    await tapNext(tester);
    expect(find.text('Bước 2/4'), findsOneWidget);
    expect(find.text('Áo xanh, quần short'), findsOneWidget);
    expect(find.text('Áo hoodie xanh lá'), findsOneWidget);
    expect(find.text('Áo đỏ, quần jean'), findsOneWidget);
  });

  testWidgets('quay lại được ở mọi bước', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.byKey(const Key('onboarding-gender-girl')));
    await tapNext(tester);
    await tapNext(tester);
    expect(find.text('Bước 3/4'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-back-button')));
    await tester.pumpAndSettle();
    expect(find.text('Bước 2/4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-back-button')));
    await tester.pumpAndSettle();
    expect(find.text('Bước 1/4'), findsOneWidget);
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
        'assets/images/pets/${species}_egg.webp',
      );
    }
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('đi hết 4 bước nữ: lưu hồ sơ + trứng rồi vào Phòng', (
    tester,
  ) async {
    await goToNameStepGirl(tester);
    await enterName(tester, 'An');
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-egg-cat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-finish-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('room-screen')), findsOneWidget);

    final service = OnboardingService(db: db);
    expect(await service.isCompleted(), isTrue);
    final profile = await service.loadProfile(childId);
    expect(profile, isNotNull);
    expect(profile!.name, 'An');
    expect(profile.gender, 'girl');
    expect(profile.dress, 'girl_top_02');
    expect((await db.petsDao.getActive(childId))?.species, 'cat');
    final child = await db.childrenDao.getChild(childId);
    expect(child!.name, 'An');
  });

  testWidgets('đi hết 4 bước nam: lưu hồ sơ rồi vào Phòng', (tester) async {
    await goToNameStepBoy(tester);
    await enterName(tester, 'Bình');
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-egg-dog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-finish-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('room-screen')), findsOneWidget);

    final service = OnboardingService(db: db);
    final profile = await service.loadProfile(childId);
    expect(profile, isNotNull);
    expect(profile!.gender, 'boy');
    expect(profile.name, 'Bình');
    expect(profile.dress, 'boy_outfit_03');
    expect((await db.petsDao.getActive(childId))?.species, 'dog');
  });
}
