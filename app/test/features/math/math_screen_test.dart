/// Widget test cho T1-09 + T1-15: màn làm toán.
///
/// Đề chặng lấy từ `DailySetService` thật (DB bộ nhớ, `FakeClock`,
/// `Random` gieo sẵn hạt giống) nên câu hỏi xác định: chặng 0 mảng
/// logic ở bậc 1 có 4 câu trắc nghiệm (bậc 1) và 1 câu điền số (bậc 2).
/// Đáp án đúng tính lại từ seed của từng câu qua
/// `ResolvedQuestion.resolve` — cùng code màn hình dùng.
///
/// T1-15 thay chữ "Câu N/5" bằng thanh tiến độ 5 ô (PLAN điểm (m))
/// nên các test cũ kiểm tra chữ đó nay kiểm tra màu từng ô qua
/// [expectProgressCells]; băng "Đúng rồi!" nay tách thành hai dòng
/// chữ ("Đúng rồi!" + "+N xu") trong ô vàng.
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
import 'package:timokid/features/math/math_decor.dart';
import 'package:timokid/features/math/math_screen.dart';
import 'package:timokid/features/math/math_session.dart';
import 'package:timokid/features/questions/question.dart';
import 'package:timokid/features/sound/sound_service.dart';
import 'package:timokid/features/stage_result/stage_result_screen.dart';
import 'package:timokid/features/town/town_screen.dart';

/// [SoundPlayer] giả ghi lại đường dẫn đã phát (PLAN điểm (m)).
class FakeSoundPlayer implements SoundPlayer {
  final played = <String>[];

  @override
  Future<void> play(String assetPath) async {
    played.add(assetPath);
  }

  @override
  Future<void> dispose() async {}
}

AppDatabase openMemoryDb({Clock? clock}) => AppDatabase(
  executor: NativeDatabase.memory(),
  clock: clock ?? const SystemClock(),
);

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late StageSession session;
  late FakeSoundPlayer fakePlayer;
  late SoundService soundService;

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
    fakePlayer = FakeSoundPlayer();
    // coinDelay bằng 0 để test không phải chờ 300 ms thật.
    soundService = SoundService(
      db: db,
      player: fakePlayer,
      coinDelay: Duration.zero,
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
        child: MaterialApp(
          home: MathScreen(session: session, soundService: soundService),
        ),
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

  /// Thanh tiến độ 5 ô (T1-15, PLAN điểm (m)): ô đã làm xanh lá,
  /// ô đang làm tím đậm, ô chưa làm trắng. `done` là số ô đã làm
  /// (cũng là chỉ số câu hiện tại sau khi bấm Tiếp).
  void expectProgressCells(
    WidgetTester tester, {
    required int current,
    required int done,
  }) {
    expect(find.byKey(const Key('math-progress')), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      final cell = tester.widget<Container>(
        find.byKey(Key('math-progress-cell-$i')),
      );
      final color = (cell.decoration as BoxDecoration?)?.color;
      if (i < done) {
        expect(color, MathColors.progressDone, reason: 'ô $i đã làm');
      } else if (i == current) {
        expect(color, MathColors.progressCurrent, reason: 'ô $i đang làm');
      } else {
        expect(color, Colors.white, reason: 'ô $i chưa làm');
      }
    }
  }

  testWidgets('đề luôn hiện song ngữ, không còn nút đổi EN', (tester) async {
    await pumpMath(tester);

    expect(find.byKey(const Key('math-screen')), findsOneWidget);
    // T1-15: chữ "Câu 1/5" thay bằng thanh tiến độ 5 ô.
    expectProgressCells(tester, current: 0, done: 0);
    // Nền theo mảng logic + chữ đề tím đậm, dòng EN xám tím (T1-15).
    expect(
      tester
          .widget<Scaffold>(find.byKey(const Key('math-screen')))
          .backgroundColor,
      MathColors.strandBackground(Strand.logic),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('math-question-text')))
          .style
          ?.color,
      MathColors.questionText,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('math-question-text-en')))
          .style
          ?.color,
      MathColors.englishText,
    );
    // Đề tiếng Việt và tiếng Anh hiện cùng lúc (PLAN điểm (l)):
    // VI chữ to (key math-question-text), EN nhỏ hơn nhạt hơn dưới
    // (key math-question-text-en). Nút đổi EN đã bỏ, nút từ khóa giữ.
    expect(find.text(session.current.question.questionVi), findsOneWidget);
    expect(find.text(session.current.question.questionEn), findsOneWidget);
    expect(find.byKey(const Key('math-question-text')), findsOneWidget);
    expect(find.byKey(const Key('math-question-text-en')), findsOneWidget);
    expect(find.byKey(const Key('math-en-toggle')), findsNothing);
    expect(find.byKey(const Key('math-keywords-button')), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(Key('choice-$i')), findsOneWidget);
    }
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

  testWidgets('đúng phát correct rồi coin, sai phát wrong', (tester) async {
    await pumpMath(tester);

    await tapCorrectChoice(tester);
    // Cho timer coin (coinDelay bằng 0) và lần đọc settings chạy xong.
    await tester.pump(const Duration(milliseconds: 50));
    expect(fakePlayer.played, ['sounds/correct.wav', 'sounds/coin.wav']);
  });

  testWidgets('sai lần đầu phát wrong', (tester) async {
    await pumpMath(tester);

    await tapWrongChoice(tester);
    await tester.pump(const Duration(milliseconds: 50));
    expect(fakePlayer.played, ['sounds/wrong.wav']);
  });

  testWidgets('tắt sound_enabled thì không phát gì', (tester) async {
    await db.settingsDao.setValue(key: 'sound_enabled', value: 'false');
    await pumpMath(tester);

    await tapCorrectChoice(tester);
    await tapWrongChoice(tester);
    await tester.pump(const Duration(milliseconds: 50));
    expect(fakePlayer.played, isEmpty);
  });

  testWidgets('phím Xóa là biểu tượng backspace, không phải ký tự ⌫', (
    tester,
  ) async {
    await pumpMath(tester);

    // Đi tới câu điền số (câu 5): trả lời đúng 4 câu trắc nghiệm.
    for (var i = 0; i < 4; i++) {
      await tapCorrectChoice(tester);
      await tapNext(tester);
    }
    expect(find.byKey(const Key('keypad-delete')), findsOneWidget);
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    expect(find.text('⌫'), findsNothing);
  });

  testWidgets('chọn đúng ngay hiện xu, ghi attempts và cộng xu vào ví', (
    tester,
  ) async {
    await pumpMath(tester);

    await tapCorrectChoice(tester);

    expect(find.byKey(const Key('math-correct')), findsOneWidget);
    // T1-15: băng xanh tách thành "Đúng rồi!" + ô vàng "+2 xu".
    expect(find.text('Đúng rồi!'), findsOneWidget);
    expect(find.text('+2 xu'), findsOneWidget);
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
    expect(find.text('Đúng rồi!'), findsOneWidget);
    expect(find.text('+1 xu'), findsOneWidget);
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
    expectProgressCells(tester, current: 1, done: 1);
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
    expectProgressCells(tester, current: 4, done: 4);
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
    if (answer.length > 1) {
      // Đáp án một chữ số thì xóa xong ô trống, không còn chữ để tìm.
      expect(typedText(answer.substring(0, answer.length - 1)), findsOneWidget);
    }
    await tester.tap(find.byKey(Key('keypad-${answer[answer.length - 1]}')));
    await tester.pumpAndSettle();
    expect(typedText(answer), findsOneWidget);

    await tester.tap(find.byKey(const Key('keypad-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('math-correct')), findsOneWidget);
    // Xu cơ số bậc 2 là 2, đúng ngay lần đầu.
    expect(find.text('Đúng rồi!'), findsOneWidget);
    expect(find.text('+2 xu'), findsOneWidget);
  });

  testWidgets('nút bấm tối thiểu 56x56 dp', (tester) async {
    await pumpMath(tester);

    final choiceSize = tester.getSize(find.byKey(const Key('choice-0')));
    expect(choiceSize.height, greaterThanOrEqualTo(56));
    expect(choiceSize.width, greaterThanOrEqualTo(56));
    final backSize = tester.getSize(find.byKey(const Key('math-back-button')));
    expect(backSize.height, greaterThanOrEqualTo(56));
    expect(backSize.width, greaterThanOrEqualTo(56));
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
    expectProgressCells(tester, current: 1, done: 1);
    expect(tester.takeException(), isNull);

    // Làm đúng 3 câu trắc nghiệm còn lại để sang câu điền số.
    for (var i = 0; i < 3; i++) {
      await tapCorrectChoice(tester);
      await tapNext(tester);
    }
    expectProgressCells(tester, current: 4, done: 4);
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

    // Đi từ Thị trấn bằng nút khu 0 (Lâu đài Lôgic) của T1-12;
    // key cũ `town-math-button` đã bỏ khi viết lại màn Thị trấn.
    await tester.tap(find.byKey(const Key('town-stage-0-button')));
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

  // ---------- Test mới cho T1-15 (PLAN điểm (m)) ----------

  testWidgets('thanh tiến độ đổi màu theo từng câu', (tester) async {
    await pumpMath(tester);

    expectProgressCells(tester, current: 0, done: 0);

    // Câu 1 đúng ngay → ô 0 xanh, ô 1 tím; sang câu 2 giữ nguyên.
    await tapCorrectChoice(tester);
    expectProgressCells(tester, current: 0, done: 1);
    await tapNext(tester);
    expectProgressCells(tester, current: 1, done: 1);

    // Câu 2 sai hai lần → lời giải, sang câu 3 thì ô 1 cũng xanh.
    await tapWrongChoice(tester);
    await tapWrongChoice(tester);
    await tapNext(tester);
    expectProgressCells(tester, current: 2, done: 2);
  });

  testWidgets('đúng liền 3 câu hiện "3 câu liền!"', (tester) async {
    await pumpMath(tester);

    // Đúng 2 câu liền thì chưa hiện.
    for (var i = 0; i < 2; i++) {
      await tapCorrectChoice(tester);
      await tapNext(tester);
    }
    expect(find.byKey(const Key('math-streak')), findsNothing);

    // Đúng câu thứ 3 liên tiếp → hiện "★ 3 câu liền!" trong băng xanh.
    await tapCorrectChoice(tester);
    expect(find.byKey(const Key('math-streak')), findsOneWidget);
    expect(find.text('★ 3 câu liền!'), findsOneWidget);

    // Đúng tiếp câu 4 → chuỗi lên 4.
    await tapNext(tester);
    await tapCorrectChoice(tester);
    expect(find.text('★ 4 câu liền!'), findsOneWidget);
  });

  testWidgets(
    'xu bay về góc ví rồi biến mất, nút Tiếp vẫn bấm được giữa lúc bay',
    (tester) async {
      await pumpMath(tester);

      // Bấm đáp án đúng rồi bơm 2 lần 400 ms: lần đầu để submit
      // async xong và băng xanh xuất hiện, lần hai để băng trượt vào
      // hết (350 ms) nên nút Tiếp đã bấm được; xu bay (600 ms) vẫn
      // đang bay — không chờ pumpAndSettle chạy hết hiệu ứng. Bơm
      // thêm một khung hình để lớp phủ xu kịp vẽ sau callback cuối
      // khung hình.
      await tester.tap(
        find.byKey(Key('choice-${session.current.correctDisplayIndex}')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byKey(const Key('math-coin-fly')), findsOneWidget);

      // Nút Tiếp trong băng xanh vẫn bấm được giữa lúc xu đang bay
      // (lớp phủ bay là IgnorePointer, không chặn thao tác).
      await tapNext(tester);
      expect(find.byKey(const Key('math-coin-fly')), findsNothing);
      expectProgressCells(tester, current: 1, done: 1);
    },
  );

  testWidgets('đáp án trắc nghiệm song ngữ khi VI khác EN', (tester) async {
    // Dạng choiceOnly "thứ trong tuần": đáp án là tên thứ, VI/EN
    // khác nhau nên nút phải hiện cả hai dòng.
    session = StageSession(
      db: db,
      childId: childId,
      dailySetId: null,
      stageIndex: -1,
      questions: [
        for (var i = 0; i < 5; i++)
          DailySetQuestion(
            formId: 'logic.weekday',
            strand: Strand.logic,
            level: 1,
            rung: 1,
            answerType: 'choice',
            seed: i + 1,
          ),
      ],
    );
    await pumpMath(tester);

    expect(find.text(session.current.choiceTextsVi[0]), findsOneWidget);
    expect(find.text(session.current.choiceTextsEn[0]), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('choice-0')),
        matching: find.byType(Text),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('đáp án song ngữ vẫn vừa ở 640x320', (tester) async {
    // Nút trắc nghiệm hai dòng dài hơn: ở màn nhỏ nhất (640x320,
    // cột phải không cuộn) 4 nút vẫn phải vừa, không tràn.
    session = StageSession(
      db: db,
      childId: childId,
      dailySetId: null,
      stageIndex: -1,
      questions: [
        for (var i = 0; i < 5; i++)
          DailySetQuestion(
            formId: 'logic.weekday',
            strand: Strand.logic,
            level: 1,
            rung: 1,
            answerType: 'choice',
            seed: i + 1,
          ),
      ],
    );
    tester.view.physicalSize = const Size(640, 320);
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
    for (var i = 0; i < 4; i++) {
      final center = tester.getCenter(find.byKey(Key('choice-$i')));
      expect(center.dy, lessThan(320));
    }
    // Dòng EN vẫn hiện trong nút ở màn nhỏ (không bị cắt mất).
    expect(find.text(session.current.choiceTextsEn[0]), findsOneWidget);
  });

  testWidgets('đáp án số chỉ hiện một dòng (VI giống EN)', (tester) async {
    // Dạng tính nhanh: đáp án là số nên VI/EN giống nhau, nút chỉ
    // hiện một dòng chữ (không có dòng EN thừa).
    session = StageSession(
      db: db,
      childId: childId,
      dailySetId: null,
      stageIndex: -1,
      questions: [
        for (var i = 0; i < 5; i++)
          DailySetQuestion(
            formId: 'arith.quick',
            strand: Strand.arith,
            level: 1,
            rung: 1,
            answerType: 'choice',
            seed: i + 1,
          ),
      ],
    );
    await pumpMath(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('choice-0')),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
  });

  testWidgets('pet vui khi đúng, động viên khi sai', (tester) async {
    await pumpMath(tester);

    expect(find.byKey(const ValueKey('pet-happy')), findsOneWidget);

    // Sai lần đầu → pet động viên (băng cam + gợi ý).
    await tapWrongChoice(tester);
    expect(find.byKey(const ValueKey('pet-encouraging')), findsOneWidget);
    expect(find.byKey(const Key('math-hint-banner')), findsOneWidget);
    expect(find.text('Gần đúng rồi, xem gợi ý nhé'), findsOneWidget);

    // Sai lần hai → lời giải, pet vẫn động viên.
    await tapWrongChoice(tester);
    expect(find.byKey(const ValueKey('pet-encouraging')), findsOneWidget);

    // Sang câu mới → pet lại vui.
    await tapNext(tester);
    expect(find.byKey(const ValueKey('pet-happy')), findsOneWidget);
  });

  // Review PR #14 (2)(3): pet từng đè dòng tiếng Anh, băng gợi ý /
  // lời giải từng đè nửa dưới thẻ đề. Nay pet nằm cạnh thanh tiến
  // độ và băng nằm trong luồng bố cục dưới thẻ đề nên không còn
  // chồng lấn — kiểm ở cả 640x320 (chật nhất) và 800x360, mỗi cỡ
  // một test riêng (pumpWidget tái dùng State cũ nên không bơm lại
  // phiên mới trong cùng một test).
  Future<void> checkNoOverlap(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MathScreen(session: session, soundService: soundService),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    Rect rect(Key key) => tester.getRect(find.byKey(key));
    // Vùng thẻ đề thực sự thấy được = giao của thẻ với khung cuộn
    // (thẻ có thể dài hơn khung; phần bị cuộn khuất không tính).
    Rect visibleCardRect() {
      final card = rect(const Key('math-question-card'));
      final scroll = tester.getRect(
        find.ancestor(
          of: find.byKey(const Key('math-question-card')),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      return card.intersect(scroll);
    }

    // Trạng thái đang làm: pet không che đề (cả hai dòng).
    expect(
      rect(const ValueKey('pet-happy'))
          .overlaps(rect(const Key('math-question-text'))),
      isFalse,
    );
    expect(
      rect(const ValueKey('pet-happy'))
          .overlaps(rect(const Key('math-question-text-en'))),
      isFalse,
    );

    // Sai lần đầu: băng gợi ý không chồng phần thẻ đề đang thấy,
    // pet không che băng.
    await tapWrongChoice(tester);
    final hintBanner = rect(const Key('math-hint-banner'));
    expect(hintBanner.overlaps(visibleCardRect()), isFalse);
    expect(
      rect(const ValueKey('pet-encouraging')).overlaps(hintBanner),
      isFalse,
    );

    // Sai lần hai: băng lời giải cũng không chồng thẻ đề.
    await tapWrongChoice(tester);
    expect(
      rect(const Key('math-solution-banner')).overlaps(visibleCardRect()),
      isFalse,
    );
  }

  testWidgets('pet không che chữ nào, băng không chồng thẻ đề ở 640x320', (
    tester,
  ) async {
    await checkNoOverlap(tester, const Size(640, 320));
  });

  testWidgets('pet không che chữ nào, băng không chồng thẻ đề ở 800x360', (
    tester,
  ) async {
    await checkNoOverlap(tester, const Size(800, 360));
  });

  testWidgets('nút bị vô hiệu dùng pastel nhạt, nút đúng giữ xanh', (
    tester,
  ) async {
    // Review PR #14 (4): nút vô hiệu từng thành nâu đất (màu mặc
    // định của theme) — nay nút thường vô hiệu dùng pastel rất nhạt,
    // nút đúng vẫn xanh lá, nút sai vẫn đỏ.
    await pumpMath(tester);
    await tapCorrectChoice(tester);

    Color disabledBg(int choiceIndex) {
      final button = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(Key('choice-$choiceIndex')),
          matching: find.byType(ElevatedButton),
        ),
      );
      // `styleFrom(disabledBackgroundColor: ...)` gộp màu vô hiệu
      // vào `backgroundColor` (phân giải theo trạng thái).
      final resolved = button.style?.backgroundColor?.resolve({
        WidgetState.disabled,
      });
      expect(
        resolved,
        isNotNull,
        reason: 'nút choice-$choiceIndex phải có màu nền khi vô hiệu',
      );
      return resolved!;
    }

    final correct = session.current.correctDisplayIndex;
    expect(disabledBg(correct), Colors.green.shade300);
    for (var i = 0; i < session.current.choiceCount; i++) {
      if (i == correct) continue;
      expect(disabledBg(i), MathColors.disabledButtonBg);
    }
  });

  testWidgets('gợi ý và lời giải luôn thấy ngay ở 640x320', (tester) async {
    // Review PR #13: gợi ý/lời giải cũ nằm dưới đề trong cột cuộn
    // nên ở màn thấp bị khuất; nay nằm trong băng ở đáy cột trái nên
    // phải thấy ngay không cần cuộn, và không che nút đáp án.
    tester.view.physicalSize = const Size(640, 320);
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

    // Sai lần đầu: băng cam với nội dung gợi ý nằm trọn trong màn.
    // (Phông test Ahem làm chữ rộng gấp ~1,8 lần Nunito thật nên
    // gợi ý dài có thể cuộn trong băng ở test; việc "thấy hết không
    // cần cuộn" kiểm bằng mắt trên ảnh golden phông DejaVu. Ở đây
    // kiểm phần chắc chắn: băng nằm trọn trong màn, đầu nội dung
    // gợi ý thấy ngay, nút đáp án vẫn bấm được.)
    await tapWrongChoice(tester);
    expect(find.byKey(const Key('math-hint-banner')), findsOneWidget);
    final hintTopLeft = tester.getTopLeft(
      find.byKey(const Key('math-hint-banner')),
    );
    final hintSize = tester.getSize(find.byKey(const Key('math-hint-banner')));
    expect(hintTopLeft.dy, greaterThanOrEqualTo(0));
    expect(hintTopLeft.dy + hintSize.height, lessThanOrEqualTo(320));
    expect(hintSize.height, lessThanOrEqualTo(146));
    expect(
      tester.getTopLeft(find.byKey(const Key('math-hint'))).dy,
      lessThan(320),
    );
    // Nút đáp án vẫn bấm được (băng chỉ chiếm cột trái).
    expect(find.byKey(const Key('choice-0')), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const Key('choice-0'))).dy,
      lessThan(320),
    );

    // Sai lần hai: băng lời giải xanh dương nằm trọn trong màn,
    // nút Tiếp ở cột phải vẫn thấy và bấm được.
    await tapWrongChoice(tester);
    expect(find.byKey(const Key('math-solution-banner')), findsOneWidget);
    final solutionTopLeft = tester.getTopLeft(
      find.byKey(const Key('math-solution-banner')),
    );
    final solutionSize = tester.getSize(
      find.byKey(const Key('math-solution-banner')),
    );
    expect(solutionTopLeft.dy, greaterThanOrEqualTo(0));
    expect(solutionTopLeft.dy + solutionSize.height, lessThanOrEqualTo(320));
    expect(solutionSize.height, lessThanOrEqualTo(146));
    expect(
      tester.getTopLeft(find.byKey(const Key('math-solution'))).dy,
      lessThan(320),
    );
    expect(
      tester.getCenter(find.byKey(const Key('math-next-button'))).dy,
      lessThan(320),
    );
    await tapNext(tester);
    expectProgressCells(tester, current: 1, done: 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nền đổi màu theo mảng', (tester) async {
    // Chặng 0 mặc định là mảng logic; một phiên mảng hình học phải
    // có nền xanh lá nhạt khác hẳn.
    session = StageSession(
      db: db,
      childId: childId,
      dailySetId: null,
      stageIndex: -1,
      questions: [
        for (var i = 0; i < 5; i++)
          DailySetQuestion(
            formId: 'geo.countsq',
            strand: Strand.geo,
            level: 1,
            rung: 1,
            answerType: 'choice',
            seed: i + 1,
          ),
      ],
    );
    await pumpMath(tester);

    expect(
      tester
          .widget<Scaffold>(find.byKey(const Key('math-screen')))
          .backgroundColor,
      MathColors.strandBackground(Strand.geo),
    );
    expect(
      tester
          .widget<Scaffold>(find.byKey(const Key('math-screen')))
          .backgroundColor,
      isNot(MathColors.strandBackground(Strand.logic)),
    );
  });
}
