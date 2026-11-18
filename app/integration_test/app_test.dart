import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/features/math/math_session.dart';
import 'package:timokid/main.dart' as app;

/// Integration test: mở app thật trên máy ảo, vào thẳng màn Thị trấn,
/// chụp màn hình, rồi đi hết chặng 1 của đề ngày (T1-09): câu đúng
/// ngay, câu đúng sau gợi ý, câu sai hai lần, câu điền số; chụp màn
/// hình mỗi trạng thái. Chạy bằng `flutter drive` (xem workflow
/// integration-test.yml và test_driver/integration_test.dart).
///
/// Đáp án đúng tính lại từ đề ngày đã lưu trong DB của app: test đọc
/// DB qua [databaseProvider], sinh lại từng câu từ seed bằng
/// [ResolvedQuestion.resolve] — cùng code màn hình dùng.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mở app vào thẳng màn Thị trấn, làm hết chặng 1', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('town-screen')), findsOneWidget);
    expect(find.text('Thị trấn Diệu Kỳ'), findsOneWidget);

    // Trên Android phải convert surface trước rồi mới chụp được.
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    final bytes = await binding.takeScreenshot('town');
    expect(bytes.isNotEmpty, isTrue);

    // --- T1-09: đi hết chặng 1 (mảng logic, bậc 1) ---
    // Nút khu 0 của màn Thị trấn T1-12 (tên key cũ `town-math-button`
    // đã bỏ khi viết lại màn Thị trấn).
    await tester.tap(find.byKey(const Key('town-stage-0-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('math-screen')), findsOneWidget);

    // Đọc đề ngày đã lưu từ DB của app để tính đáp án đúng.
    final element = tester.element(find.byKey(const Key('math-screen')));
    final db = ProviderScope.containerOf(element).read(databaseProvider);
    final childId = await db.ensureSeeded();
    // Thử nghiệm: tắt âm thanh để khoanh vùng lỗi pumpAndSettle treo
    // sau khi trả lời đúng (PR #13).
    await db.settingsDao.setValue(key: 'sound_enabled', value: 'false');
    final set = await db.dailySetsDao.getDailySet(childId, db.clock.today());
    final resolved = db.dailySetsDao
        .readQuestions(set!)
        .sublist(0, 5)
        .map(ResolvedQuestion.resolve)
        .toList();

    // Surface đã convert ở trên (chỉ được gọi một lần cho cả test).
    Future<void> takeShot(String name) async {
      await tester.pumpAndSettle();
      final shot = await binding.takeScreenshot(name);
      expect(shot.isNotEmpty, isTrue);
    }

    Future<void> tapCorrect(int qi) async {
      await tester.tap(
        find.byKey(Key('choice-${resolved[qi].correctDisplayIndex}')),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapWrong(int qi) async {
      final correct = resolved[qi].correctDisplayIndex;
      await tester.tap(find.byKey(Key('choice-${correct == 0 ? 1 : 0}')));
      await tester.pumpAndSettle();
    }

    Future<void> tapNext() async {
      await tester.tap(find.byKey(const Key('math-next-button')));
      await tester.pumpAndSettle();
    }

    // Câu 1 đúng ngay lần đầu.
    await tapCorrect(0);
    expect(find.byKey(const Key('math-correct')), findsOneWidget);
    await takeShot('math-correct');
    await tapNext();

    // Câu 2 sai lần đầu (hiện gợi ý) rồi đúng lần hai.
    await tapWrong(1);
    expect(find.byKey(const Key('math-hint')), findsOneWidget);
    await takeShot('math-hint');
    await tapCorrect(1);
    await tapNext();

    // Câu 3 sai hai lần (hiện lời giải).
    await tapWrong(2);
    await tapWrong(2);
    expect(find.byKey(const Key('math-solution')), findsOneWidget);
    await takeShot('math-solution');
    await tapNext();

    // Câu 4 đúng ngay lần đầu.
    await tapCorrect(3);
    await tapNext();

    // Câu 5 điền số đúng ngay lần đầu.
    final answer = '${resolved[4].question.answer}';
    for (final ch in answer.split('')) {
      await tester.tap(find.byKey(Key('keypad-$ch')));
    }
    await tester.pumpAndSettle();
    await takeShot('math-number');
    await tester.tap(find.byKey(const Key('keypad-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('math-correct')), findsOneWidget);
    await tapNext();

    // Cuối chặng: màn kết quả — đúng 4/5 câu.
    expect(find.byKey(const Key('stage-result-screen')), findsOneWidget);
    expect(find.text('Đúng 4/5 câu'), findsOneWidget);
    await takeShot('math-result');
  });
}
