/// Test hồi quy tràn màn ở 608x248 (sửa sau review PR #19).
///
/// Máy ảo CI của integration test thấp hơn cỡ thiết kế 640x320 nên
/// 4 màn trên đường tới màn Kết quả chặng đều tràn `RenderFlex`
/// (màn toán tràn 39 px khi băng xanh hiện rồi không thấy
/// `stage-result-screen` ở `app_test.dart:168`): cột phải màn toán,
/// nút màn kết quả chặng, nút khu Thị trấn, hàng nút điều hướng mở
/// đầu. File này khóa cả 4 màn đều vừa ở đúng 608x248 — nhỏ hơn cả
/// máy ảo CI — và đi hết luồng toán tới màn kết quả (kịch bản
/// `app_test.dart:168`). Font test DejaVu rộng hơn Nunito thật nên
/// test này khắt khe hơn máy thật; qua được ở đây thì máy thật vừa.
///
/// Lưu ý: ở 608x248 vài nút nằm dưới nếp gấp cuộn (nút váy, thẻ
/// trứng, nút Tiếp lúc xem lời giải, nút gửi bàn phím) nên test dùng
/// `ensureVisible` trước khi bấm — đó là hành vi đúng của màn cuộn,
/// không phải lỗi; integration test trên máy ảo CI cao hơn không cần
/// cuộn tới các nút này.
library;

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/router/app_router.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/character/placeholder_layers.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/math/math_screen.dart';
import 'package:timokid/features/math/math_session.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';
import 'package:timokid/features/stage_result/stage_result_screen.dart';
import 'package:timokid/features/town/town_screen.dart';
import 'package:timokid/main.dart';

const _size = Size(608, 248);

void _setSize(WidgetTester tester) {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void _checkNoError(WidgetTester tester, String step) {
  final err = tester.takeException();
  expect(err, isNull, reason: 'tràn/lỗi ở $step: $err');
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('mở đầu nữ 608x248', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      await db.ensureSeeded();
    });

    testWidgets('đi hết 5 bước nữ rồi vào Thị trấn', (tester) async {
      _setSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          // Xem trước dùng lớp tạm (không có file hình thật ở local).
          child: TimoKidApp(
            router: AppRouter.create(
              showOnboarding: true,
              previewLoader: placeholderLayerLoader,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      _checkNoError(tester, 'bước 1 giới tính');

      Future<void> tapNext() async {
        await tester.tap(find.byKey(const Key('onboarding-next-button')));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const Key('onboarding-gender-girl')));
      await tapNext();
      _checkNoError(tester, 'bước 2 màu tóc');
      await tapNext();
      _checkNoError(tester, 'bước 3 váy');
      // Nút váy ở dưới nếp gấp cuộn ở màn thấp: cuộn tới rồi bấm.
      await _tapVisible(
        tester,
        find.byKey(const Key('onboarding-dress-girl_top_02')),
      );
      _checkNoError(tester, 'bước 3 chọn váy tím');
      await tapNext();
      _checkNoError(tester, 'bước 4 tên');
      await tester.enterText(
        find.byKey(const Key('onboarding-name-field')),
        'An',
      );
      await tester.pumpAndSettle();
      await tapNext();
      _checkNoError(tester, 'bước 5 trứng');
      // Thẻ trứng cao hơn vùng nhìn ở màn thấp (243 dp > 73 dp)
      // nên tâm thẻ nằm dưới nếp gấp — bấm vào hình trứng SVG ở
      // đỉnh thẻ (luôn thấy sau khi cuộn) thay vì tâm thẻ.
      final eggSvg = find.descendant(
        of: find.byKey(const Key('onboarding-egg-dog')),
        matching: find.byType(SvgPicture),
      );
      await tester.ensureVisible(eggSvg);
      await tester.pumpAndSettle();
      await tester.tap(eggSvg);
      await tester.pumpAndSettle();
      _checkNoError(tester, 'bước 5 chọn trứng chó');
      await tester.tap(find.byKey(const Key('onboarding-finish-button')));
      await tester.pumpAndSettle();
      _checkNoError(tester, 'vào Thị trấn');
      expect(find.byKey(const Key('town-screen')), findsOneWidget);
    });
  });

  group('thị trấn 608x248', () {
    late FakeClock clock;
    late AppDatabase db;
    late String childId;

    setUp(() async {
      clock = FakeClock(DateTime(2026, 11, 18, 8, 0));
      db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
      addTearDown(db.close);
      childId = await db.ensureSeeded();
      await OnboardingService(db: db).completeOnboarding(
        childId: childId,
        profile: CharacterProfile.defaults().copyWith(
          name: 'An',
          dress: 'girl_top_02',
        ),
        eggSpecies: 'dog',
      );
    });

    testWidgets('thị trấn có nhân vật nữ không tràn', (tester) async {
      _setSize(tester);
      final router = GoRouter(
        initialLocation: TownScreen.route,
        routes: [
          GoRoute(
            path: TownScreen.route,
            builder: (context, state) => const TownScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      _checkNoError(tester, 'thị trấn có nhân vật nữ');
      expect(find.byKey(const Key('town-character')), findsOneWidget);
    });
  });

  group('màn toán 608x248', () {
    late FakeClock clock;
    late AppDatabase db;
    late String childId;

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
        random: Random(42),
      );
      await service.getOrCreateTodaySet(childId: childId);
    });

    testWidgets('đi hết chặng 0 rồi sang màn kết quả chặng', (tester) async {
      // Kịch bản app_test.dart:168 trên máy ảo CI: đi từ Thị trấn
      // bằng nút khu 0, làm 5 câu rồi bấm Tiếp ở câu cuối phải thấy
      // màn kết quả chặng (trước sửa thì tràn 39 px rồi không thấy).
      _setSize(tester);
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
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      _checkNoError(tester, 'thị trấn');

      await tester.tap(find.byKey(const Key('town-stage-0-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('math-screen')), findsOneWidget);
      _checkNoError(tester, 'mở màn toán');

      // Đáp án tính lại từ đề đã lưu trong DB (cùng đề setUp tạo),
      // theo mẫu test 'đi hết chặng thì sang màn kết quả chặng'.
      final todaySet = await db.dailySetsDao.getDailySet(
        childId,
        clock.today(),
      );
      final resolved = db.dailySetsDao
          .readQuestions(todaySet!)
          .sublist(0, 5)
          .map(ResolvedQuestion.resolve)
          .toList();
      var qi = 0;

      Future<void> tapCorrect() async {
        await _tapVisible(
          tester,
          find.byKey(Key('choice-${resolved[qi].correctDisplayIndex}')),
        );
      }

      Future<void> tapWrong() async {
        final correct = resolved[qi].correctDisplayIndex;
        await _tapVisible(
          tester,
          find.byKey(Key('choice-${correct == 0 ? 1 : 0}')),
        );
      }

      Future<void> tapNextHere() async {
        // Nút Tiếp lúc đúng nằm ở băng xanh (luôn thấy); lúc xem
        // lời giải nằm trong cột phải (cuộn tới mới thấy ở màn thấp).
        await _tapVisible(tester, find.byKey(const Key('math-next-button')));
        qi++;
      }

      // Câu 1 đúng ngay.
      await tapCorrect();
      _checkNoError(tester, 'câu 1 đúng (băng xanh)');
      await tapNextHere();
      _checkNoError(tester, 'sau câu 1');

      // Câu 2 sai lần đầu -> gợi ý, rồi đúng.
      await tapWrong();
      _checkNoError(tester, 'câu 2 sai lần 1 (băng gợi ý)');
      await tapCorrect();
      _checkNoError(tester, 'câu 2 đúng (băng xanh)');
      await tapNextHere();
      _checkNoError(tester, 'sau câu 2');

      // Câu 3 sai hai lần -> lời giải.
      await tapWrong();
      await tapWrong();
      _checkNoError(tester, 'câu 3 sai lần 2 (băng lời giải)');
      await tapNextHere();
      _checkNoError(tester, 'sau câu 3');

      // Câu 4 đúng ngay.
      await tapCorrect();
      _checkNoError(tester, 'câu 4 đúng (băng xanh)');
      await tapNextHere();
      _checkNoError(tester, 'sau câu 4');

      // Câu 5 điền số đúng.
      final answer = '${resolved[4].question.answer}';
      for (final ch in answer.split('')) {
        await _tapVisible(tester, find.byKey(Key('keypad-$ch')));
      }
      _checkNoError(tester, 'câu 5 gõ số (bàn phím)');
      await _tapVisible(tester, find.byKey(const Key('keypad-submit')));
      _checkNoError(tester, 'câu 5 đúng (băng xanh)');
      await tapNextHere();
      _checkNoError(tester, 'sau câu 5 (sang kết quả)');

      expect(find.byKey(const Key('stage-result-screen')), findsOneWidget);
      expect(find.text('Đúng 4/5 câu'), findsOneWidget);
      expect(find.text('Nhận được 12 xu'), findsOneWidget);
    });
  });

  group('màn kết quả chặng 608x248', () {
    testWidgets('không tràn', (tester) async {
      _setSize(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: StageResultScreen(
            result: StageResultArgs(
              stageIndex: 0,
              strand: 'logic',
              correctCount: 4,
              firstTryCorrectCount: 3,
              totalQuestions: 5,
              xuEarned: 12,
              nextStageIndex: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      _checkNoError(tester, 'màn kết quả');
      expect(find.byKey(const Key('stage-result-screen')), findsOneWidget);
    });
  });
}
