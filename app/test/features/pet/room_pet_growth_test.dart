/// Widget test Phòng (D): màn ăn mừng pet lớn lên, bong bóng tâm trạng,
/// "Pet của bé" đổi pet đi theo, "Nhận trứng mới" khi pet trưởng thành.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/onboarding/egg_service.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/pet/pet_care_service.dart';
import 'package:timokid/features/pet/pet_celebration.dart';
import 'package:timokid/features/pet/pet_service.dart';
import 'package:timokid/features/room/pet_growth.dart';
import 'package:timokid/features/room/room_screen.dart';

void main() {
  late AppDatabase db;
  late String childId;
  late PetService pets;

  setUp(() async {
    db = AppDatabase(
      executor: NativeDatabase.memory(),
      clock: FakeClock(DateTime(2026, 11, 23, 8, 0)),
    );
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    pets = PetService(db: db);
    await OnboardingService(db: db).completeOnboarding(
      childId: childId,
      profile: CharacterProfile.defaults().copyWith(
        dress: 'girl_top_02',
        name: 'An',
      ),
      eggSpecies: 'dog',
    );
    await EggService(db: db).noteStageCompleted(childId);
    await EggService(db: db).consumeHatchCelebration(childId);
  });

  Future<void> pumpRoom(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: RoomScreen.route,
      routes: [
        GoRoute(
          path: RoomScreen.route,
          builder: (context, state) => const RoomScreen(),
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

  group('màn ăn mừng lớn lên', () {
    testWidgets(
      'pet vượt giai đoạn đã thấy → lớp phủ, bấm Tuyệt vời ghi đã thấy',
      (tester) async {
        await pets.addXp(childId, amount: 80);
        await pumpRoom(tester);
        expect(find.byKey(const Key('pet-celebration')), findsOneWidget);
        expect(
          find.byKey(const Key('pet-celebration-confetti')),
          findsOneWidget,
        );
        expect(
          find.text('Chó Tinh Anh đã lớn thành tuổi nhỡ!'),
          findsOneWidget,
        );
        expect((await pets.active(childId))!.pet.stageSeen, 'newborn');
        await tester.tap(find.byKey(const Key('pet-celebration-ok')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('pet-celebration')), findsNothing);
        expect((await pets.active(childId))!.pet.stageSeen, 'teen');
        // Vào Phòng lần sau: không chiếu lại.
        await pumpRoom(tester);
        expect(find.byKey(const Key('pet-celebration')), findsNothing);
      },
    );

    testWidgets('chưa lớn thì không có lớp phủ', (tester) async {
      await pets.addXp(childId, amount: 79);
      await pumpRoom(tester);
      expect(find.byKey(const Key('pet-celebration')), findsNothing);
    });

    testWidgets(
      'nhảy hai giai đoạn một lần vẫn chỉ một màn, chữ theo giai đoạn mới',
      (tester) async {
        await pets.addXp(childId, amount: 250);
        await pumpRoom(tester);
        expect(
          find.text('Chó Tinh Anh đã lớn thành trưởng thành!'),
          findsOneWidget,
        );
      },
    );

    testWidgets('widget ăn mừng chạy riêng: gọi onDone', (tester) async {
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PetGrowCelebration(
            species: 'cat',
            from: PetStage.teen,
            to: PetStage.adult,
            onDone: () => done++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Mèo Mũm Mĩm đã lớn thành trưởng thành!'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('pet-celebration-ok')));
      expect(done, 1);
    });

    test('pháo giấy vẽ ổn định theo tiến độ', () {
      final a = PetConfettiPainter(progress: 0.2);
      expect(a.shouldRepaint(PetConfettiPainter(progress: 0.2)), isFalse);
      expect(a.shouldRepaint(PetConfettiPainter(progress: 0.3)), isTrue);
    });
  });

  group('bong bóng tâm trạng', () {
    testWidgets('đói → buồn → vui theo ăn và chơi trong ngày', (tester) async {
      await pumpRoom(tester);
      expect(find.byKey(const Key('room-pet-mood-hungry')), findsOneWidget);
      final care = PetCareService(db: db);
      await care.awardMeal(childId);
      await care.feed(childId, foodId: 'meal');
      await pumpRoom(tester);
      expect(find.byKey(const Key('room-pet-mood-sad')), findsOneWidget);
      await care.play(childId);
      await pumpRoom(tester);
      expect(find.byKey(const Key('room-pet-mood-happy')), findsOneWidget);
    });

    testWidgets('trứng chưa nở không có bong bóng', (tester) async {
      await pets.addXp(childId, amount: 250);
      await pets.claimStarterEgg(childId, 'cat');
      await pumpRoom(tester);
      expect(find.byKey(const Key('room-egg')), findsOneWidget);
      expect(find.byKey(const Key('room-pet-mood-hungry')), findsNothing);
    });
  });

  group('chọn pet', () {
    testWidgets('chỉ có một pet thì không có nút "Pet của bé"', (tester) async {
      await pumpRoom(tester);
      expect(find.byKey(const Key('room-pets-button')), findsNothing);
      expect(find.byKey(const Key('room-new-egg-button')), findsNothing);
    });

    testWidgets('đổi pet đi theo bằng "Pet của bé"', (tester) async {
      await pets.createEgg(childId: childId, species: 'cat', makeActive: false);
      await pumpRoom(tester);
      await tester.tap(find.byKey(const Key('room-pets-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('room-pet-pick-dog')), findsOneWidget);
      expect(find.byKey(const Key('room-pet-pick-cat')), findsOneWidget);
      await tester.tap(find.byKey(const Key('room-pet-pick-cat')));
      await tester.pumpAndSettle();
      expect((await pets.active(childId))!.species, 'cat');
      expect((await pets.pets(childId)).where((p) => p.active), hasLength(1));
      // Pet mới đi theo là trứng chưa nở.
      expect(find.byKey(const Key('room-egg')), findsOneWidget);
    });
  });

  group('nhận trứng mới khi pet trưởng thành', () {
    testWidgets('chưa trưởng thành thì không hiện nút', (tester) async {
      await pets.addXp(childId, amount: 249);
      await pumpRoom(tester);
      expect(find.byKey(const Key('room-new-egg-button')), findsNothing);
    });

    testWidgets('trưởng thành: chọn trứng chưa có, trứng mới đi theo', (
      tester,
    ) async {
      await pets.addXp(childId, amount: 250);
      await pumpRoom(tester);
      // Ăn mừng trước, rồi mới thấy nút.
      await tester.tap(find.byKey(const Key('pet-celebration-ok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('room-new-egg-button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('room-new-egg-button')));
      await tester.pumpAndSettle();
      // Chó đã có → chỉ mèo và thỏ.
      expect(find.byKey(const Key('room-new-egg-dog')), findsNothing);
      expect(find.byKey(const Key('room-new-egg-cat')), findsOneWidget);
      await tester.tap(find.byKey(const Key('room-new-egg-rabbit')));
      await tester.pumpAndSettle();
      final active = (await pets.active(childId))!;
      expect(active.species, 'rabbit');
      expect(active.hatched, isFalse);
      expect(find.byKey(const Key('room-new-egg-button')), findsNothing);
      expect(find.byKey(const Key('room-egg')), findsOneWidget);
    });
  });
}
