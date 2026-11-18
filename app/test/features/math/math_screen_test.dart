/// Widget test cho T1-09: màn làm toán.
///
/// Đề chặng lấy từ `DailySetService` thật (DB bộ nhớ, `FakeClock`,
/// `Random` gieo sẵn hạt giống) nên câu hỏi xác định: chặng 0 mảng
/// logic ở bậc 1 có 4 câu trắc nghiệm (bậc 1) và 1 câu điền số (bậc 2).
/// Đáp án đúng tính lại từ seed của từng câu qua
/// `ResolvedQuestion.resolve` — cùng code màn hình dùng.
library;

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/database/tables.dart' hide AnswerType;
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/math/math_screen.dart';
import 'package:timokid/features/math/math_session.dart';
import 'package:timokid/features/questions/question.dart';
import 'package:timokid/features/rewards/reward_config.dart';
import 'package:timokid/features/stage_result/stage_result_screen.dart';
import 'package:timokid/features/town/town_screen.dart';

AppDatabase openMemoryDb({Clock? clock}) => AppDatabase(
  executor: NativeDatabase.memory(),
  clock: clock ?? const SystemClock(),
);

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late StageSession session;

  Future<DailySet> buildTodaySet() async {
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
    return service.getOrCreateTodaySet(childId: childId);
  }

  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 18, 8, 0));
    db = openMemoryDb(clock: clock);
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    final set = await buildTodaySet();
    final questions = db.dailySetsDao.readQuestions(set).sublist(0, 5);
    session = StageSession(
      db: db,
      childId: childId,
      dailySetId: set.id,
      stageIndex: 0,
      questions: questions,
    );
  });

  /// Bơm màn làm toán với phiên có sẵn, mặt phẳng ngang 1280x720.
  Future<void> pumpMath(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: MathScreen(session: session)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapCorrectChoice(WidgetTester tester) async {
    await tester.tap(
      find.byKey(Key('choice-${session.current.correctDisplayIndex}')),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapWrongChoice(WidgetTester tester) async {
    final correct = session.current.correctDisplayIndex;
    final wrong = correct == 0 ? 1 : 0;
    await tester.tap(find.byKey(Key('choice-$wrong')));
    await tester.pumpAndSettle();
  }

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('math-next-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('hiện câu 1 trắc nghiệm, nút EN đổi đề VI/EN', (tester) async {
    await pumpMath(tester);

    expect(find.byKey(const Key('math-screen')), findsOneWidget);
    expect(find.text('Câu 1/5'), findsOneWidget);
    expect(find.text(session.current.question.questionVi), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(Key('choice-$i')), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('math-en-toggle')));
    await tester.pumpAndSettle();
    expect(find.text(session.current.question.questionEn), findsOneWidget);

    await tester.tap(find.byKey(const Key('math-en-toggle')));
    await tester.pumpAndSettle();
    expect(find.text(session.current.question.questionVi), findsOneWidget);
  });

  testWidgets('nút từ khóa mở bảng song ngữ', (tester) async {
    await pumpMath(tester);

    await tester.tap(find.byKey(const Key('math-keywords-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('keywords-dialog')), findsOneWidget);
    final keyword = session.current.question.keywords.first;
    expect(find.text('${keyword.en} — ${keyword.vi}'), findsOneWidget);

    await tester.tap(find.byKey(const Key('keywords-close-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('keywords-dialog')), findsNothing);
  });

  testWidgets('chọn đúng ngay hiện xu, ghi attempts và cộng xu vào ví', (
    tester,
  ) async {
    await pumpMath(tester);

    await tapCorrectChoice(tester);

    expect(find.byKey(const Key('math-correct')), findsOneWidget);
    expect(find.text('Đúng rồi! +2 xu'), findsOneWidget);
    final attempts = await db.attemptsDao.getAttemptsForChild(childId);
    expect(attempts, hasLength(1));
    expect(attempts.single.correctFirstTry, isTrue);
    expect(attempts.single.attemptsCount, 1);
    expect(
      await db.walletDao.balance(childId: childId, currency: Currency.xu),
      2,
    );
  });

  testWidgets('sai lần đầu hiện gợi ý, đúng lần hai được nửa xu làm tròn lên', (
    tester,
  ) async {
    await pumpMath(tester);

    await tapWrongChoice(tester);
    expect(find.byKey(const Key('math-hint')), findsOneWidget);
    expect(find.byKey(const Key('math-correct')), findsNothing);

    await tapCorrectChoice(tester);
    expect(find.byKey(const Key('math-correct')), findsOneWidget);
    // Xu cơ số bậc 1 là 2, đúng sau gợi ý còn 1.
    expect(find.text('Đúng rồi! +1 xu'), findsOneWidget);
    final attempts = await db.attemptsDao.getAttemptsForChild(childId);
    expect(attempts, hasLength(1));
    expect(attempts.single.correctFirstTry, isFalse);
    expect(attempts.single.attemptsCount, 2);
    expect(
      await db.walletDao.balance(childId: childId, currency: Currency.xu),
      1,
    );
  });

  testWidgets('sai hai lần hiện lời giải, bấm Tiếp sang câu 2', (tester) async {
    await pumpMath(tester);

    await tapWrongChoice(tester);
    await tapWrongChoice(tester);
    expect(find.byKey(const Key('math-solution')), findsOneWidget);
    expect(
      find.textContaining(session.current.question.explanationVi),
      findsOneWidget,
    );
    final attempts = await db.attemptsDao.getAttemptsForChild(childId);
    expect(attempts, hasLength(1));
    expect(attempts.single.correctFirstTry, isFalse);
    expect(attempts.single.attemptsCount, 2);

    await tapNext(tester);
    expect(find.text('Câu 2/5'), findsOneWidget);
  });

  testWidgets('câu thường sai thì vào sổ ôn tập, đúng ngay thì không', (
    tester,
  ) async {
    await pumpMath(tester);

    // Câu 1 sai hai lần → vào sổ (dạng + bậc của câu vừa làm).
    await tapWrongChoice(tester);
    await tapWrongChoice(tester);
    var entry = await db.reviewQueueDao.getEntry(
      childId,
      session.resolved[0].spec.formId,
    );
    expect(entry, isNotNull);
    expect(entry!.rung, session.resolved[0].spec.rung);
    expect(entry.correctStreak, 0);

    // Câu 2 đúng ngay lần đầu → không vào sổ.
    await tapNext(tester);
    await tapCorrectChoice(tester);
    entry = await db.reviewQueueDao.getEntry(
      childId,
      session.resolved[1].spec.formId,
    );
    expect(entry, isNull);
  });

  testWidgets('câu ôn tập: đúng ngay tăng chuỗi, sai quay về mốc 1 ngày', (
    tester,
  ) async {
    // Gieo một mục ôn tập đến hạn rồi làm câu ôn tập của dạng đó.
    await db.reviewQueueDao.upsertEntry(
      childId: childId,
      formId: 'logic.balance',
      rung: 3,
      dueDate: clock.now(),
    );
    // Một phiên hai câu ôn tập của cùng dạng (seed khác nhau): câu 1
    // đúng ngay, câu 2 sai hai lần. Dùng một phiên vì bơm lại một
    // phiên mới trong cùng test sẽ tái dùng State cũ của màn hình.
    final reviewQuestions = <DailySetQuestion>[
      DailySetQuestion(
        formId: 'logic.balance',
        strand: Strand.logic,
        level: 3,
        rung: 3,
        answerType: 'choice',
        seed: 1,
        isReview: true,
      ),
      DailySetQuestion(
        formId: 'logic.balance',
        strand: Strand.logic,
        level: 3,
        rung: 3,
        answerType: 'choice',
        seed: 2,
        isReview: true,
      ),
    ];
    session = StageSession(
      db: db,
      childId: childId,
      dailySetId: null,
      stageIndex: -1,
      questions: reviewQuestions,
    );
    await pumpMath(tester);

    // Câu 1 đúng ngay lần đầu → chuỗi 1, còn trong sổ.
    await tapCorrectChoice(tester);
    var entry = await db.reviewQueueDao.getEntry(childId, 'logic.balance');
    expect(entry, isNotNull);
    expect(entry!.correctStreak, 1);

    // Câu 2 sai hai lần → chuỗi về 0.
    await tapNext(tester);
    await tapWrongChoice(tester);
    await tapWrongChoice(tester);
    entry = await db.reviewQueueDao.getEntry(childId, 'logic.balance');
    expect(entry, isNotNull);
    expect(entry!.correctStreak, 0);
  });

  testWidgets('điền số: gõ số, xóa, gửi đúng', (tester) async {
    await pumpMath(tester);

    // Làm đúng 4 câu trắc nghiệm để sang câu điền số (câu 5, bậc 2).
    for (var i = 0; i < 4; i++) {
      await tapCorrectChoice(tester);
      await tapNext(tester);
    }
    expect(find.text('Câu 5/5'), findsOneWidget);
    expect(session.current.displayType, AnswerType.number);
    final answer = '${session.current.question.answer}';

    // Ô hiển thị số đã gõ (chứ không phải phím bấm trùng chữ số).
    Finder typedText(String value) => find.descendant(
      of: find.byKey(const Key('math-typed-answer')),
      matching: find.text(value),
    );

    for (final ch in answer.split('')) {
      await tester.tap(find.byKey(Key('keypad-$ch')));
    }
    await tester.pumpAndSettle();
    expect(typedText(answer), findsOneWidget);

    // Xóa một chữ số rồi gõ lại.
    await tester.tap(find.byKey(const Key('keypad-delete')));
    await tester.pumpAndSettle();
    expect(typedText(answer.substring(0, answer.length - 1)), findsOneWidget);
    await tester.tap(find.byKey(Key('keypad-${answer[answer.length - 1]}')));
    await tester.pumpAndSettle();
    expect(typedText(answer), findsOneWidget);

    await tester.tap(find.byKey(const Key('keypad-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('math-correct')), findsOneWidget);
    // Xu cơ số bậc 2 là 2, đúng ngay lần đầu.
    expect(find.text('Đúng rồi! +2 xu'), findsOneWidget);
  });

  testWidgets('nút bấm tối thiểu 56x56 dp', (tester) async {
    await pumpMath(tester);

    final choiceSize = tester.getSize(find.byKey(const Key('choice-0')));
    expect(choiceSize.height, greaterThanOrEqualTo(56));
    expect(choiceSize.width, greaterThanOrEqualTo(56));
    final backSize = tester.getSize(find.byKey(const Key('math-back-button')));
    expect(backSize.height, greaterThanOrEqualTo(56));
    expect(backSize.width, greaterThanOrEqualTo(56));
    final enSize = tester.getSize(find.byKey(const Key('math-en-toggle')));
    expect(enSize.height, greaterThanOrEqualTo(56));
    expect(enSize.width, greaterThanOrEqualTo(56));
    final keywordsSize = tester.getSize(
      find.byKey(const Key('math-keywords-button')),
    );
    expect(keywordsSize.height, greaterThanOrEqualTo(56));
    expect(keywordsSize.width, greaterThanOrEqualTo(56));

    await tapCorrectChoice(tester);
    final nextSize = tester.getSize(find.byKey(const Key('math-next-button')));
    expect(nextSize.height, greaterThanOrEqualTo(56));
    expect(nextSize.width, greaterThanOrEqualTo(56));
  });

  testWidgets('nút màn Kết quả chặng tối thiểu 56x56 dp', (tester) async {
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

    final backSize = tester.getSize(
      find.byKey(const Key('stage-result-back-button')),
    );
    expect(backSize.height, greaterThanOrEqualTo(56));
    expect(backSize.width, greaterThanOrEqualTo(56));
    final nextSize = tester.getSize(
      find.byKey(const Key('stage-result-next-button')),
    );
    expect(nextSize.height, greaterThanOrEqualTo(56));
    expect(nextSize.width, greaterThanOrEqualTo(56));
  });

  // Lỗi integration test máy ảo 640x320: nút choice-3 nằm ngoài màn
  // hình (y=357) vì bố cục cũ xếp dọc 1 cột. Bố cục 2 cột mới phải
  // vừa ở cả 3 cỡ: cột trái cuộn được, cột phải không cuộn, mọi nút
  // đều bấm được (bấm choice-3 sai thì hiện gợi ý).
  // Mỗi cỡ là một test riêng: pumpWidget với cùng loại widget sẽ tái
  // dùng State cũ (không chạy lại initState) nên không thể bơm lại
  // một phiên mới trong cùng một test.
  Future<void> walkStageAtSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: MathScreen(session: session)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Bấm nút choice-3 (nút từng nằm ngoài màn hình ở 640x320).
    final correct = session.current.correctDisplayIndex;
    await tester.tap(find.byKey(Key('choice-${correct == 3 ? 0 : 3}')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('math-hint')), findsOneWidget);

    // Sai lần hai → lời giải, bấm Tiếp sang câu 2.
    await tapWrongChoice(tester);
    expect(find.byKey(const Key('math-solution')), findsOneWidget);
    await tapNext(tester);
    expect(find.text('Câu 2/5'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Làm đúng 3 câu trắc nghiệm còn lại để sang câu điền số.
    for (var i = 0; i < 3; i++) {
      await tapCorrectChoice(tester);
      await tapNext(tester);
    }
    expect(find.text('Câu 5/5'), findsOneWidget);
    expect(find.byKey(const Key('keypad-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Bàn phím bấm được ở cỡ này: gõ đáp án rồi gửi.
    final answer = '${session.current.question.answer}';
    for (final ch in answer.split('')) {
      await tester.tap(find.byKey(Key('keypad-$ch')));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('keypad-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('math-correct')), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  for (final size in const [Size(640, 320), Size(800, 360), Size(1280, 800)]) {
    testWidgets(
      'bố cục vừa ở ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async => walkStageAtSize(tester, size),
    );
  }

  testWidgets('nút bàn phím số tối thiểu 56x56 dp', (tester) async {
    await pumpMath(tester);

    for (var i = 0; i < 4; i++) {
      await tapCorrectChoice(tester);
      await tapNext(tester);
    }
    final keySize = tester.getSize(find.byKey(const Key('keypad-1')));
    expect(keySize.height, greaterThanOrEqualTo(56));
    expect(keySize.width, greaterThanOrEqualTo(56));
  });

  testWidgets('hình vẽ hiện nếu câu có hình', (tester) async {
    final figureQuestions = <DailySetQuestion>[
      for (var i = 0; i < 5; i++)
        DailySetQuestion(
          formId: 'geo.countsq',
          strand: Strand.geo,
          level: 1,
          rung: 1,
          answerType: 'choice',
          seed: i + 1,
        ),
    ];
    session = StageSession(
      db: db,
      childId: childId,
      dailySetId: null,
      stageIndex: -1,
      questions: figureQuestions,
    );
    await pumpMath(tester);

    expect(find.byKey(const Key('math-figure')), findsOneWidget);
  });

  testWidgets('đi hết chặng thì sang màn kết quả chặng', (tester) async {
    // Bơm cả app qua router mới (không dùng router tĩnh của app để
    // trạng thái điều hướng không rò sang test khác), DB bộ nhớ ghi đè
    // qua provider. Đi từ Thị trấn bằng nút "Làm toán".
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
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

    await tester.tap(find.byKey(const Key('town-math-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('math-screen')), findsOneWidget);

    // Màn này tự dựng phiên riêng qua _load() nên đáp án tính từ đề
    // đã lưu trong DB (cùng đề mà setUp đã tạo), không dùng `session`
    // của setUp.
    final todaySet = await db.dailySetsDao.getDailySet(childId, clock.today());
    final resolved = db.dailySetsDao
        .readQuestions(todaySet!)
        .sublist(0, 5)
        .map(ResolvedQuestion.resolve)
        .toList();
    var qi = 0;
    Future<void> tapCorrect() async {
      await tester.tap(
        find.byKey(Key('choice-${resolved[qi].correctDisplayIndex}')),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapWrong() async {
      final correct = resolved[qi].correctDisplayIndex;
      await tester.tap(find.byKey(Key('choice-${correct == 0 ? 1 : 0}')));
      await tester.pumpAndSettle();
    }

    Future<void> tapNextHere() async {
      await tester.tap(find.byKey(const Key('math-next-button')));
      await tester.pumpAndSettle();
      qi++;
    }

    // Câu 1 đúng ngay, câu 2 đúng sau gợi ý, câu 3 sai hai lần,
    // câu 4 đúng ngay, câu 5 điền số đúng ngay.
    await tapCorrect();
    await tapNextHere();
    await tapWrong();
    await tapCorrect();
    await tapNextHere();
    await tapWrong();
    await tapWrong();
    await tapNextHere();
    await tapCorrect();
    await tapNextHere();
    final answer = '${resolved[4].question.answer}';
    for (final ch in answer.split('')) {
      await tester.tap(find.byKey(Key('keypad-$ch')));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('keypad-submit')));
    await tester.pumpAndSettle();
    await tapNextHere();

    expect(find.byKey(const Key('stage-result-screen')), findsOneWidget);
    expect(find.text('Đúng 4/5 câu'), findsOneWidget);
    // Xu: 2 + 1 + 0 + 2 + 2 = 7, cộng thưởng xong chặng 5 = 12.
    expect(find.text('Nhận được 12 xu'), findsOneWidget);

    final attempts = await db.attemptsDao.getAttemptsForChild(childId);
    expect(attempts, hasLength(5));
    expect(
      await db.walletDao.balance(childId: childId, currency: Currency.xu),
      12,
    );
    final set = await db.dailySetsDao.getDailySet(childId, clock.today());
    expect(db.dailySetsDao.readStageStatus(set!).first, StageStatus.done);
  });

  testWidgets('RewardConfig: bảng xu theo bậc, nửa xu, gấp đôi ôn tập', (
    tester,
  ) async {
    expect(RewardConfig.baseXuForRung(1), 2);
    expect(RewardConfig.baseXuForRung(2), 2);
    expect(RewardConfig.baseXuForRung(3), 3);
    expect(RewardConfig.baseXuForRung(4), 3);
    expect(RewardConfig.baseXuForRung(5), 5);
    expect(RewardConfig.baseXuForRung(6), 5);
    expect(
      RewardConfig.xuForQuestion(
        rung: 3,
        correctFirstTry: true,
        isReview: false,
      ),
      3,
    );
    // Đúng sau gợi ý: 3 → 2 (làm tròn lên).
    expect(
      RewardConfig.xuForQuestion(
        rung: 3,
        correctFirstTry: false,
        isReview: false,
      ),
      2,
    );
    // Câu ôn tập: gấp đôi.
    expect(
      RewardConfig.xuForQuestion(
        rung: 3,
        correctFirstTry: true,
        isReview: true,
      ),
      6,
    );
    // Ôn tập + sau gợi ý: chia đôi rồi nhân đôi.
    expect(
      RewardConfig.xuForQuestion(
        rung: 5,
        correctFirstTry: false,
        isReview: true,
      ),
      6,
    );
    expect(RewardConfig.stageCompleteBonusXu, 5);
  });
}
