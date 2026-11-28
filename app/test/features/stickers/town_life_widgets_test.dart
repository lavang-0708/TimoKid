/// Widget test bản 0.4 "thị trấn sống" (T4-02, T4-03, T4-04): bong bóng
/// cư dân ở màn Tòa nhà, lời cảm ơn ở màn Kết quả chặng, Sổ sticker (khóa /
/// mở / tiến độ), cửa sổ "Sticker mới!" đúng một lần, nút Sổ sticker ở HUD,
/// phần thưởng mở khóa ở Thị trấn/Phòng; và không tràn ở 4 cỡ màn.
library;

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/router/app_router.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/building/building_screen.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_config.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/questions/question_registry.dart';
import 'package:timokid/features/residents/resident_content.dart';
import 'package:timokid/features/residents/resident_service.dart';
import 'package:timokid/features/stage_result/stage_result_screen.dart';
import 'package:timokid/features/stickers/sticker_service.dart';
import 'package:timokid/features/unlocks/unlock_config.dart';
import 'package:timokid/main.dart';

import '../building/play_stage_helper.dart';

const _sizes = [
  Size(608, 248),
  Size(640, 320),
  Size(800, 360),
  Size(1280, 800),
];

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late String setId;
  late ResidentBook book;

  DailySetService dailySetService() => DailySetService(
    dailySetsDao: db.dailySetsDao,
    reviewQueueDao: db.reviewQueueDao,
    ladderService: LadderService(
      attemptsDao: db.attemptsDao,
      skillProgressDao: db.skillProgressDao,
    ),
    clock: clock,
    random: Random(5),
  );

  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 18, 8, 0));
    db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
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
    final service = dailySetService();
    setId = (await service.getOrCreateTodaySet(childId: childId)).id;
    book = await ResidentBook.load();
  });

  Future<void> master(int n) async {
    for (final f in allFormIds.take(n)) {
      await db.skillProgressDao.setFormMastered(
        childId: childId,
        formId: f,
        mastered: true,
      );
    }
  }

  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    Size size = const Size(800, 360),
    String? location,
    Object? extra,
  }) async {
    tester.view.physicalSize = size;
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
    if (location != null) {
      router.go(location, extra: extra);
      await tester.pumpAndSettle();
    }
    return router;
  }

  String bubbleText(WidgetTester tester, Key key) => tester
      .widget<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .data!;

  void noError(WidgetTester tester, String step) {
    expect(tester.takeException(), isNull, reason: 'tràn/lỗi ở $step');
  }

  StageResultArgs resultArgs({int firstTry = 5}) => StageResultArgs(
    stageIndex: 0,
    strand: 'logic',
    correctCount: 5,
    firstTryCorrectCount: firstTry,
    totalQuestions: 5,
    xuEarned: 20,
    nextStageIndex: 1,
  );

  // ------------------------------------------------------------- Sổ sticker

  group('Sổ sticker', () {
    testWidgets(
      'chưa có sticker: toàn hình bóng "?", 0/90, tiến độ từng mảng',
      (tester) async {
        await pumpApp(tester, location: '/stickers');
        expect(find.byKey(const Key('sticker-book-screen')), findsOneWidget);
        expect(
          tester
              .widget<Text>(
                find.descendant(
                  of: find.byKey(const Key('sticker-total-progress')),
                  matching: find.byType(Text),
                ),
              )
              .data,
          '0/90',
        );
        expect(find.text('Lôgic 0/19'), findsOneWidget);
        expect(find.text('Hình học 0/19'), findsOneWidget);
        expect(find.text('Lôgic: 0/19 sticker'), findsOneWidget);
        expect(
          find.byKey(const Key('sticker-locked-logic.age')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('sticker-logic.age')), findsNothing);
        expect(find.text('?'), findsWidgets);
        expect(find.text('???'), findsWidgets);
        expect(
          find.text('Còn 5 dạng nữa để mở khung vàng cho sổ sticker'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('sticker-gold-frame-logic')), findsNothing);
        expect(find.byKey(const Key('title-chip')), findsNothing);
      },
    );

    testWidgets('có dạng thành thạo: sticker mở, +2 kim cương mỗi cái, '
        'nhãn Mới chỉ lần xem đầu, trang theo mảng', (tester) async {
      for (final f in ['logic.age', 'logic.queue', 'geo.perim']) {
        await db.skillProgressDao.setFormMastered(
          childId: childId,
          formId: f,
          mastered: true,
        );
      }
      final router = await pumpApp(tester, location: '/stickers');
      expect(find.text('3/90'), findsOneWidget);
      expect(find.text('Lôgic 2/19'), findsOneWidget);
      expect(find.text('Lôgic: 2/19 sticker'), findsOneWidget);
      expect(find.byKey(const Key('sticker-logic.age')), findsOneWidget);
      expect(find.byKey(const Key('sticker-locked-logic.age')), findsNothing);
      expect(find.text('Tính tuổi'), findsOneWidget);
      expect(find.text('Xếp hàng'), findsOneWidget);
      expect(find.byKey(const Key('sticker-new-logic.age')), findsOneWidget);
      // Chưa mở: vẫn là hình bóng.
      expect(
        find.byKey(const Key('sticker-locked-logic.balance')),
        findsOneWidget,
      );
      expect(
        await db.walletDao.balance(childId: childId, currency: Currency.gem),
        6,
      );

      // Sang trang Hình học.
      await tester.tap(find.byKey(const Key('sticker-tab-geo')));
      await tester.pumpAndSettle();
      expect(find.text('Hình học: 1/19 sticker'), findsOneWidget);
      expect(find.byKey(const Key('sticker-geo.perim')), findsOneWidget);
      expect(find.text('Chu vi'), findsOneWidget);

      // Vào lại: không còn nhãn Mới, kim cương không cộng thêm.
      router.go('/');
      await tester.pumpAndSettle();
      router.go('/stickers');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sticker-new-logic.age')), findsNothing);
      expect(find.byKey(const Key('sticker-logic.age')), findsOneWidget);
      expect(
        await db.walletDao.balance(childId: childId, currency: Currency.gem),
        6,
      );
    });

    testWidgets('đủ 5 dạng: khung vàng + dòng tiến độ sang mốc kế', (
      tester,
    ) async {
      await master(5);
      await pumpApp(tester, location: '/stickers');
      expect(find.byKey(const Key('sticker-gold-frame-logic')), findsOneWidget);
      expect(
        find.text('Còn 7 dạng nữa để mở đài phun nước ở Thị trấn'),
        findsOneWidget,
      );
    });

    testWidgets('đủ 30 dạng: danh hiệu Nhà toán học nhí + đã mở hết', (
      tester,
    ) async {
      await master(30);
      await pumpApp(tester, location: '/stickers');
      expect(find.byKey(const Key('title-chip')), findsOneWidget);
      expect(find.text(UnlockConfig.titleText), findsOneWidget);
      expect(find.textContaining('mở hết'), findsOneWidget);
      expect(find.text('30/90'), findsOneWidget);
    });

    testWidgets('mở khóa quà Phòng khi vào Sổ (20 dạng): kho có món', (
      tester,
    ) async {
      await master(20);
      await pumpApp(tester, location: '/stickers');
      expect(
        await db.inventoryDao.has(childId, UnlockConfig.roomGiftItemId),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------- HUD

  group('nút Sổ sticker ở HUD', () {
    testWidgets('Phòng: bấm mở sổ, bấm Quay lại về Phòng', (tester) async {
      await pumpApp(tester);
      expect(find.byKey(const Key('room-screen')), findsOneWidget);
      await tester.tap(find.byKey(const Key('sticker-book-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sticker-book-screen')), findsOneWidget);
      await tester.tap(find.byKey(const Key('sticker-back-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('room-screen')), findsOneWidget);
    });

    testWidgets('Thị trấn: bấm mở sổ, bấm Quay lại về Thị trấn', (
      tester,
    ) async {
      await pumpApp(tester, location: '/');
      expect(find.byKey(const Key('town-screen')), findsOneWidget);
      await tester.tap(find.byKey(const Key('sticker-book-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sticker-book-screen')), findsOneWidget);
      await tester.tap(find.byKey(const Key('sticker-back-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('town-screen')), findsOneWidget);
    });
  });

  // ------------------------------------------------------ mở khóa ở Thị trấn

  group('phần thưởng mở khóa', () {
    testWidgets('đài phun nước ở Thị trấn chỉ hiện từ 12 dạng', (tester) async {
      await master(11);
      await pumpApp(tester, location: '/');
      expect(find.byKey(const Key('town-fountain')), findsNothing);
    });

    testWidgets(
      '12 dạng: có đài phun nước; 30 dạng: danh hiệu ở Thị trấn và Phòng',
      (tester) async {
        await master(12);
        final router = await pumpApp(tester, location: '/');
        expect(find.byKey(const Key('town-fountain')), findsOneWidget);
        expect(find.byKey(const Key('title-chip')), findsNothing);
        await master(30);
        router.go('/stickers');
        await tester.pumpAndSettle();
        router.go('/');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('title-chip')), findsOneWidget);
        router.go('/room');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('title-chip')), findsOneWidget);
      },
    );
  });

  // ------------------------------------------------ cư dân ở màn Tòa nhà

  group('bong bóng cư dân ở màn Tòa nhà', () {
    final bubble = const Key('building-resident-bubble');

    testWidgets(
      'chưa xong chặng: câu "nhờ giúp" có tên bé, đúng cư dân của khu',
      (tester) async {
        await pumpApp(
          tester,
          location: BuildingScreen.route,
          extra: const BuildingScreenArgs(stageIndex: 0),
        );
        final knight = book.forStrand('logic')!;
        expect(knight.name, 'Hiệp sĩ Bình minh');
        expect(
          find.byKey(const Key('resident-portrait-hiep_si_sang')),
          findsOneWidget,
        );
        expect(
          bubbleText(tester, bubble),
          pickResidentLine(
            knight,
            LineKind.ask,
            date: '2026-11-18',
            childName: 'Mai',
          ),
        );
        expect(bubbleText(tester, bubble), contains('Mai'));
        // Số liệu chặng vẫn còn.
        expect(find.byKey(const Key('building-status')), findsOneWidget);
      },
    );

    testWidgets('mỗi khu một cư dân riêng', (tester) async {
      final router = await pumpApp(
        tester,
        location: BuildingScreen.route,
        extra: const BuildingScreenArgs(stageIndex: 1),
      );
      expect(
        find.byKey(const Key('resident-portrait-co_bong')),
        findsOneWidget,
      );
      router.go(
        BuildingScreen.route,
        extra: const BuildingScreenArgs(stageIndex: 4),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('resident-portrait-chu_xoay')),
        findsOneWidget,
      );
    });

    testWidgets('cùng ngày thì cùng câu khi mở lại màn', (tester) async {
      final router = await pumpApp(
        tester,
        location: BuildingScreen.route,
        extra: const BuildingScreenArgs(stageIndex: 2),
      );
      final first = bubbleText(tester, bubble);
      router.go('/');
      await tester.pumpAndSettle();
      router.go(
        BuildingScreen.route,
        extra: const BuildingScreenArgs(stageIndex: 2),
      );
      await tester.pumpAndSettle();
      expect(bubbleText(tester, bubble), first);
    });

    testWidgets('xong chặng: câu chào; chạm cư dân nghe câu chào khác', (
      tester,
    ) async {
      await db.dailySetsDao.updateStageStatus(
        id: setId,
        stageIndex: 0,
        status: StageStatus.done,
      );
      await pumpApp(
        tester,
        location: BuildingScreen.route,
        extra: const BuildingScreenArgs(stageIndex: 0),
      );
      final knight = book.forStrand('logic')!;
      String greet(int v) => pickResidentLine(
        knight,
        LineKind.greeting,
        date: '2026-11-18',
        childName: 'Mai',
        variant: v,
      );
      expect(bubbleText(tester, bubble), greet(0));
      await tester.tap(find.byKey(const Key('resident-tap-hiep_si_sang')));
      await tester.pumpAndSettle();
      expect(bubbleText(tester, bubble), greet(1));
    });

    testWidgets(
      'đủ 5 dạng thành thạo: xong chặng thì cư dân nói lời đặc biệt',
      (tester) async {
        await master(5);
        await db.dailySetsDao.updateStageStatus(
          id: setId,
          stageIndex: 0,
          status: StageStatus.done,
        );
        await pumpApp(
          tester,
          location: BuildingScreen.route,
          extra: const BuildingScreenArgs(stageIndex: 0),
        );
        expect(
          bubbleText(tester, bubble),
          pickResidentLine(
            book.forStrand('logic')!,
            LineKind.special,
            date: '2026-11-18',
            childName: 'Mai',
          ),
        );
      },
    );
  });

  // -------------------------------------------- lời cảm ơn ở màn Kết quả chặng

  group('lời cảm ơn của cư dân ở màn Kết quả chặng', () {
    final thanks = const Key('resident-thanks-bubble');

    testWidgets('làm tốt: lời cảm ơn của đúng cư dân, có tên bé', (
      tester,
    ) async {
      await pumpApp(
        tester,
        location: StageResultScreen.route,
        extra: resultArgs(firstTry: 4),
      );
      expect(
        bubbleText(tester, thanks),
        pickResidentLine(
          book.forStrand('logic')!,
          LineKind.thanks,
          date: '2026-11-18',
          childName: 'Mai',
          extra: 'stage:0',
        ),
      );
      expect(
        find.byKey(const Key('resident-portrait-hiep_si_sang')),
        findsOneWidget,
      );
      expect(find.text('Cảm ơn bé nhé, làm tốt lắm!'), findsNothing);
    });

    testWidgets('làm còn vất vả (đúng ngay ≤ 2/5): câu động viên', (
      tester,
    ) async {
      await pumpApp(
        tester,
        location: StageResultScreen.route,
        extra: resultArgs(firstTry: 2),
      );
      expect(
        bubbleText(tester, thanks),
        pickResidentLine(
          book.forStrand('logic')!,
          LineKind.encourage,
          date: '2026-11-18',
          childName: 'Mai',
          extra: 'stage:0',
        ),
      );
    });

    testWidgets('không có ProviderScope: giữ lời cảm ơn chung như cũ', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: StageResultScreen(result: resultArgs())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cảm ơn bé nhé, làm tốt lắm!'), findsOneWidget);
      expect(find.byKey(thanks), findsNothing);
    });
  });

  // ---------------------------------------------- cửa sổ "Sticker mới!"

  group('cửa sổ Sticker mới!', () {
    testWidgets(
      'hiện sau màn kết quả khi vừa thành thạo dạng mới, đúng MỘT lần',
      (tester) async {
        await db.skillProgressDao.setFormMastered(
          childId: childId,
          formId: 'logic.balance',
          mastered: true,
        );
        final router = await pumpApp(
          tester,
          location: StageResultScreen.route,
          extra: resultArgs(),
        );
        expect(find.byKey(const Key('new-sticker-dialog')), findsOneWidget);
        expect(find.text('Sticker mới!'), findsOneWidget);
        expect(find.byKey(const Key('sticker-logic.balance')), findsOneWidget);
        expect(find.text('Cân thăng bằng'), findsOneWidget);
        expect(find.text('+2 kim cương'), findsOneWidget);
        expect(
          await db.walletDao.balance(childId: childId, currency: Currency.gem),
          2,
        );
        // Màn kết quả vẫn ở dưới.
        expect(find.byKey(const Key('stage-result-screen')), findsOneWidget);

        await tester.tap(find.byKey(const Key('new-sticker-dismiss')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('new-sticker-dialog')), findsNothing);

        // Vào lại màn kết quả: không hiện nữa, kim cương không cộng thêm.
        router.go('/');
        await tester.pumpAndSettle();
        router.go(StageResultScreen.route, extra: resultArgs());
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('new-sticker-dialog')), findsNothing);
        expect(
          await db.walletDao.balance(childId: childId, currency: Currency.gem),
          2,
        );
      },
    );

    testWidgets('không có sticker mới thì không hiện cửa sổ', (tester) async {
      await pumpApp(
        tester,
        location: StageResultScreen.route,
        extra: resultArgs(),
      );
      expect(find.byKey(const Key('new-sticker-dialog')), findsNothing);
    });

    testWidgets('cùng lúc chạm mốc mở khóa: cửa sổ báo cả phần thưởng', (
      tester,
    ) async {
      await master(5);
      await pumpApp(
        tester,
        location: StageResultScreen.route,
        extra: resultArgs(),
      );
      expect(find.byKey(const Key('new-unlock-gold_frame')), findsOneWidget);
      expect(find.textContaining('khung vàng'), findsWidgets);
      expect(find.text('+10 kim cương'), findsOneWidget);
      expect(find.text('Sticker mới!'), findsOneWidget);
      // Nhiều hơn số tối đa thì gộp "và N sticker khác".
      await tester.tap(find.byKey(const Key('new-sticker-dismiss')));
      await tester.pumpAndSettle();
    });

    testWidgets('nút "Xem sổ sticker" mở Sổ', (tester) async {
      await db.skillProgressDao.setFormMastered(
        childId: childId,
        formId: 'arith.quick',
        mastered: true,
      );
      await pumpApp(
        tester,
        location: StageResultScreen.route,
        extra: resultArgs(),
      );
      await tester.tap(find.byKey(const Key('new-sticker-open-book')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sticker-book-screen')), findsOneWidget);
      expect(find.byKey(const Key('sticker-arith.quick')), findsNothing);
      await tester.tap(find.byKey(const Key('sticker-tab-arith')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sticker-arith.quick')), findsOneWidget);
    });
  });

  // ----------------------------- thành thạo qua làm bài thật -> sticker

  testWidgets('làm hết một chặng khi đã đủ 5 câu đúng ngay của một dạng: '
      'sticker + 2 kim cương được cấp', (tester) async {
    const form = 'logic.age';
    final level = LadderConfig.masteryLevelForForm(
      questionGeneratorFor(form)!.supportedLevels,
    );
    for (var i = 0; i < 5; i++) {
      await db.attemptsDao.recordAttempt(
        childId: childId,
        formId: form,
        strand: Strand.logic,
        level: level,
        rung: 5,
        answerType: AnswerType.choice,
        correctFirstTry: true,
        attemptsCount: 1,
        durationMs: 1000,
      );
    }
    final ladder = LadderService(
      attemptsDao: db.attemptsDao,
      skillProgressDao: db.skillProgressDao,
    );
    expect(
      await ladder.evaluateFormMastery(childId: childId, formId: form),
      isTrue,
    );
    final stickers = StickerService(db: db);
    expect(await stickers.earned(childId), isEmpty);

    final extra = await dailySetService().buildExtraStage(
      childId: childId,
      strand: Strand.comb,
    );
    await playStageCorrectly(db: db, childId: childId, questions: extra);

    expect(await stickers.earned(childId), contains(form));
    final entries = (await db.walletDao.getEntries(childId))
        .where((e) => e.refId == 'sticker:$form');
    expect(entries, hasLength(1));
    expect(entries.single.amount, 2);
    expect(entries.single.currency, Currency.gem);
  });

  // ---------------------------------------------------- không tràn 4 cỡ màn

  group('không tràn ở 608x248, 640x320, 800x360, 1280x800', () {
    for (final size in _sizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('Sổ sticker (12 dạng, khung vàng, đổi trang) $label', (
        tester,
      ) async {
        await master(12);
        await pumpApp(tester, size: size, location: '/stickers');
        noError(tester, 'Sổ sticker $label');
        for (final s in Strand.all) {
          await tester.tap(find.byKey(Key('sticker-tab-$s')));
          await tester.pumpAndSettle();
          noError(tester, 'trang $s $label');
        }
      });

      testWidgets('Sổ sticker (30 dạng, danh hiệu) $label', (tester) async {
        await master(30);
        await pumpApp(tester, size: size, location: '/stickers');
        noError(tester, 'Sổ sticker 30 $label');
      });

      testWidgets('Tòa nhà có cư dân $label', (tester) async {
        for (var i = 0; i < 5; i++) {
          final router = await pumpApp(
            tester,
            size: size,
            location: BuildingScreen.route,
            extra: BuildingScreenArgs(stageIndex: i),
          );
          noError(tester, 'Tòa nhà $i $label');
          expect(
            find.byKey(const Key('building-resident-bubble')),
            findsOneWidget,
          );
          router.go('/');
          await tester.pumpAndSettle();
        }
      });

      testWidgets('Kết quả chặng có cư dân + cửa sổ Sticker mới $label', (
        tester,
      ) async {
        await master(6);
        await pumpApp(
          tester,
          size: size,
          location: StageResultScreen.route,
          extra: resultArgs(),
        );
        noError(tester, 'cửa sổ Sticker mới $label');
        expect(find.byKey(const Key('new-sticker-dialog')), findsOneWidget);
        await tester.tap(find.byKey(const Key('new-sticker-dismiss')));
        await tester.pumpAndSettle();
        noError(tester, 'Kết quả chặng $label');
        expect(find.byKey(const Key('resident-thanks-bubble')), findsOneWidget);
      });

      testWidgets('Kết quả chặng động viên $label', (tester) async {
        await pumpApp(
          tester,
          size: size,
          location: StageResultScreen.route,
          extra: resultArgs(firstTry: 1),
        );
        noError(tester, 'Kết quả chặng động viên $label');
      });

      testWidgets(
        'Thị trấn + Phòng có đài phun nước, danh hiệu, nút sổ $label',
        (tester) async {
          await master(30);
          final router = await pumpApp(tester, size: size, location: '/');
          noError(tester, 'Thị trấn $label');
          expect(find.byKey(const Key('sticker-book-button')), findsOneWidget);
          router.go('/room');
          await tester.pumpAndSettle();
          noError(tester, 'Phòng $label');
          expect(find.byKey(const Key('sticker-book-button')), findsOneWidget);
        },
      );
    }
  });
}
