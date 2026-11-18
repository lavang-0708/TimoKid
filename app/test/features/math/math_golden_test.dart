/// Golden test cho màn làm toán (T1-09): câu trắc nghiệm, gợi ý sau
/// sai lần 1, lời giải sau sai lần 2, đúng (hiện xu), bàn phím số,
/// màn kết quả chặng.
///
/// Làm theo mẫu `figure_golden_test.dart` của T1-06: nạp font DejaVu
/// Sans của máy làm font 'Nunito' (fontFamily của AppTheme, PLAN điểm
/// (m)) để chữ đọc được — DejaVu là phông đứng chỗ cho Nunito để ảnh
/// golden khớp nhau giữa máy local và CI; Nunito thật kiểm bằng mắt
/// trên máy thật. Ảnh kỳ vọng nhúng base64 trong
/// `goldens/math_golden_data.dart` và được giải mã ra file PNG trước
/// khi so sánh. Nạp thêm MaterialIcons để phím Xóa
/// (Icons.backspace_outlined) hiện đúng trong ảnh.
///
/// Bố cục 2 cột (sửa sau review PR #11): 6 trạng thái chụp ở 800x360
/// (mặt phẳng ngang nhỏ, gần máy ảo 640x320 nhất trong các cỡ chuẩn),
/// thêm trắc nghiệm và bàn phím ở 1280x800 (màn lớn). Ảnh cũ ở
/// 1280x720 đã lỗi thời vì đổi bố cục nên sinh lại toàn bộ.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/theme/app_theme.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/math/math_screen.dart';
import 'package:timokid/features/math/math_session.dart';
import 'package:timokid/features/stage_result/stage_result_screen.dart';

import '../../goldens/math_golden_data.dart';

AppDatabase openMemoryDb({Clock? clock}) => AppDatabase(
  executor: NativeDatabase.memory(),
  clock: clock ?? const SystemClock(),
);

void _restoreGoldens() {
  const goldens = {
    'test/goldens/math_choice.png': mathChoiceBase64,
    'test/goldens/math_choice_bilingual.png': mathChoiceBilingualBase64,
    'test/goldens/math_hint.png': mathHintBase64,
    'test/goldens/math_solution.png': mathSolutionBase64,
    'test/goldens/math_correct.png': mathCorrectBase64,
    'test/goldens/math_number.png': mathNumberBase64,
    'test/goldens/math_result.png': mathResultBase64,
    'test/goldens/math_choice_1280x800.png': mathChoice1280x800Base64,
    'test/goldens/math_number_1280x800.png': mathNumber1280x800Base64,
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
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late StageSession session;

  setUpAll(() async {
    await _loadTestFonts();
    _restoreGoldens();
  });

  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 18, 8, 0));
    db = openMemoryDb(clock: clock);
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
    final set = await service.getOrCreateTodaySet(childId: childId);
    final questions = db.dailySetsDao.readQuestions(set).sublist(0, 5);
    session = StageSession(
      db: db,
      childId: childId,
      dailySetId: set.id,
      stageIndex: 0,
      questions: questions,
    );
  });

  /// Bơm màn làm toán ở một cỡ mặt phẳng cho trước (mặc định 800x360
  /// cho 6 trạng thái chính).
  Future<void> pumpMath(
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
        // Dùng đúng theme của app (fontFamily Nunito, màu pastel):
        // không có theme thì chữ dùng phông mặc định của engine
        // (Roboto — không nạp ở đây) nên ảnh golden toàn ô vuông.
        child: MaterialApp(
          theme: AppTheme.light,
          home: MathScreen(session: session),
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
    await tester.tap(find.byKey(Key('choice-${correct == 0 ? 1 : 0}')));
    await tester.pumpAndSettle();
  }

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('math-next-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('màn câu trắc nghiệm', (tester) async {
    await pumpMath(tester);
    await expectLater(
      find.byKey(const Key('math-screen')),
      matchesGoldenFile('../../goldens/math_choice.png'),
    );
  });

  testWidgets('màn trắc nghiệm song ngữ (thứ trong tuần)', (tester) async {
    // Đáp án có chữ (logic.weekday) hiện VI to trên, EN nhỏ nhạt
    // dưới trong cùng nút — chụp riêng để kiểm bằng mắt.
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
    await expectLater(
      find.byKey(const Key('math-screen')),
      matchesGoldenFile('../../goldens/math_choice_bilingual.png'),
    );
  });

  testWidgets('màn gợi ý sau sai lần đầu', (tester) async {
    await pumpMath(tester);
    await tapWrongChoice(tester);
    await expectLater(
      find.byKey(const Key('math-screen')),
      matchesGoldenFile('../../goldens/math_hint.png'),
    );
  });

  testWidgets('màn lời giải sau sai hai lần', (tester) async {
    await pumpMath(tester);
    await tapWrongChoice(tester);
    await tapWrongChoice(tester);
    await expectLater(
      find.byKey(const Key('math-screen')),
      matchesGoldenFile('../../goldens/math_solution.png'),
    );
  });

  testWidgets('màn đúng, hiện xu', (tester) async {
    await pumpMath(tester);
    await tapCorrectChoice(tester);
    await expectLater(
      find.byKey(const Key('math-screen')),
      matchesGoldenFile('../../goldens/math_correct.png'),
    );
  });

  testWidgets('màn bàn phím số', (tester) async {
    await pumpMath(tester);
    for (var i = 0; i < 4; i++) {
      await tapCorrectChoice(tester);
      await tapNext(tester);
    }
    await expectLater(
      find.byKey(const Key('math-screen')),
      matchesGoldenFile('../../goldens/math_number.png'),
    );
  });

  testWidgets('màn trắc nghiệm ở 1280x800', (tester) async {
    await pumpMath(tester, size: const Size(1280, 800));
    await expectLater(
      find.byKey(const Key('math-screen')),
      matchesGoldenFile('../../goldens/math_choice_1280x800.png'),
    );
  });

  testWidgets('màn bàn phím số ở 1280x800', (tester) async {
    await pumpMath(tester, size: const Size(1280, 800));
    for (var i = 0; i < 4; i++) {
      await tapCorrectChoice(tester);
      await tapNext(tester);
    }
    await expectLater(
      find.byKey(const Key('math-screen')),
      matchesGoldenFile('../../goldens/math_number_1280x800.png'),
    );
  });

  testWidgets('màn kết quả chặng', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const StageResultScreen(
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
    await expectLater(
      find.byKey(const Key('stage-result-screen')),
      matchesGoldenFile('../../goldens/math_result.png'),
    );
  });
}
