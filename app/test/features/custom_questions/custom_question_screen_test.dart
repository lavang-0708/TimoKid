/// Màn làm toán với câu tự soạn (T5-03): hiện đề tiếng Việt (không có tiếng
/// Anh thì không chừa chỗ trống), trắc nghiệm và điền số chấm đúng, lời
/// giải của bố/mẹ hiện khi sai, không tràn ở cỡ nhỏ.
library;

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/features/custom_questions/custom_question_service.dart';
import 'package:timokid/features/math/math_screen.dart';
import 'package:timokid/features/math/math_session.dart';

void main() {
  late AppDatabase db;
  late String childId;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    childId = await db.ensureSeeded();
  });

  DailySetQuestion choiceQ() =>
      CustomQuestionService(db: db, random: Random(5)).build(
        custom: const CustomQuestionSnapshot(
          id: 'c1',
          textVi: 'Con vật nào biết bay?',
          answer: 'Chim',
          choices: ['Cá', 'Chim', 'Mèo'],
          explanationVi: 'Chim có cánh nên bay được.',
        ),
        strand: Strand.logic,
        rung: 1,
      );

  Future<StageSession> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = StageSession(
      db: db,
      childId: childId,
      dailySetId: null,
      stageIndex: -1,
      questions: [choiceQ()],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: MathScreen(session: session)),
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  for (final size in const [Size(1280, 720), Size(608, 248)]) {
    testWidgets(
      'trắc nghiệm tự soạn ở ${size.width.toInt()}x${size.height.toInt()}: '
      'đề tiếng Việt, không dòng tiếng Anh, chọn đúng thì qua',
      (tester) async {
        final session = await pump(tester, size);
        expect(find.text('Con vật nào biết bay?'), findsOneWidget);
        expect(find.byKey(const Key('math-question-text-en')), findsNothing);
        final idx = session.current.correctDisplayIndex;
        await tester.ensureVisible(find.byKey(Key('choice-$idx')));
        await tester.tap(find.byKey(Key('choice-$idx')));
        await tester.pumpAndSettle();
        expect(session.state, QuestionState.correct);
        expect(find.byKey(const Key('math-correct')), findsOneWidget);
        expect(tester.takeException(), isNull);
        final a = (await db.attemptsDao.getAttemptsForChild(childId)).single;
        expect(a.formId, 'custom:c1');
      },
    );
  }

  testWidgets('chọn sai hai lần: hiện lời giải của bố/mẹ', (tester) async {
    final session = await pump(tester, const Size(1280, 720));
    final wrong = session.current.correctDisplayIndex == 0 ? 1 : 0;
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(Key('choice-$wrong')));
      await tester.pumpAndSettle();
    }
    expect(session.state, QuestionState.solution);
    expect(find.text('Chim có cánh nên bay được.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
