import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/animation/animation_gate.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/features/math/math_session.dart';
import 'package:timokid/main.dart' as app;

/// Integration test: mở app thật trên máy ảo, đi hết màn mở đầu nữ
/// (T2-03: giới tính, màu tóc, váy, tên, trứng) rồi vào Thị trấn,
/// chụp màn hình, rồi đi hết chặng 1 của đề ngày (T1-09): câu đúng
/// ngay, câu đúng sau gợi ý, câu sai hai lần, câu điền số; chụp màn
/// hình mỗi trạng thái. Chạy bằng `flutter drive` (xem workflow
/// integration-test.yml và test_driver/integration_test.dart).
///
/// Đáp án đúng tính lại từ đề ngày đã lưu trong DB của app: test đọc
/// DB qua [databaseProvider], sinh lại từng câu từ seed bằng
/// [ResolvedQuestion.resolve] — cùng code màn hình dùng.
void main() {
  // Tắt hiệu ứng lặp vô hạn khi chạy integration test (cùng mẫu
  // sound_enabled = false bên dưới): thở/chớp mắt/lắc trứng dùng
  // AnimationController.repeat() nên pumpAndSettle không bao giờ
  // dừng khi Thị trấn/mở đầu đang hiện. Máy thật vẫn bật hiệu ứng.
  AnimationGate.enabled = false;

  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mở đầu nữ, vào Thị trấn, làm hết chặng 1', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    // Trên Android phải convert surface trước rồi mới chụp được
    // (chỉ được gọi một lần cho cả test).
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();

    Future<void> takeShot(String name) async {
      await tester.pumpAndSettle();
      final shot = await binding.takeScreenshot(name);
      expect(shot.isNotEmpty, isTrue);
    }

    Future<void> tapOnboardingNext() async {
      await tester.tap(find.byKey(const Key('onboarding-next-button')));
      await tester.pumpAndSettle();
    }

    // Bỏ focus (đóng bàn phím ảo thật) rồi chờ tới khi viewport hết bị bóp
    // (Claude, PR #19 vòng 4): `receiveAction(done)` chỉ tới
    // TestTextInput, không tới IME thật của máy ảo, và
    // pumpAndSettle không chờ hiệu ứng bàn phím trượt xuống (phía
    // nền tảng gửi kích thước viewport dần dần). Bấm khi bàn phím
    // còn đang trượt thì tọa độ lệch, chạm hụt thẻ trứng.
    Future<void> closeKeyboard() async {
      FocusManager.instance.primaryFocus?.unfocus();
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
        if (tester.view.viewInsets.bottom == 0) break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    }

    // Bấm nút sau khi cuộn nó vào tầm nhìn (vòng 3 review PR #19):
    // bàn phím ảo mở ở bước tên có thể KHÔNG đóng trên máy ảo CI
    // dù app đã unfocus (receiveAction(done) không tới được IME
    // thật) nên viewport màn toán bị bóp — nút đáp án nằm dưới nếp
    // gấp, bấm trực tiếp chạm hụt, không ra băng xanh (lỗi ở dòng
    // 148 trước sửa). Cuộn tới nút trước khi bấm là hành vi đúng
    // của màn cuộn, giống người dùng thật.
    Future<void> tapVisible(Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    // --- T2-03: màn mở đầu nữ (DB mới: chưa xong mở đầu) ---
    expect(find.byKey(const Key('onboarding-screen')), findsOneWidget);
    expect(find.text('Bước 1/5'), findsOneWidget);
    await takeShot('onboarding-gender');

    await tester.tap(find.byKey(const Key('onboarding-gender-girl')));
    await tapOnboardingNext();
    expect(find.text('Bước 2/5'), findsOneWidget);
    await takeShot('onboarding-hair');

    // Màu tóc giữ mặc định (hồng); sang bước chọn váy.
    await tapOnboardingNext();
    expect(find.text('Bước 3/5'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-dress-girl_top_02')));
    await tester.pumpAndSettle();
    await takeShot('onboarding-dress');
    await tapOnboardingNext();

    // Bước đặt tên.
    expect(find.text('Bước 4/5'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('onboarding-name-field')),
      'An',
    );
    await tester.pumpAndSettle();
    // Bấm Done trên bàn phím ảo để đóng bàn phím trước khi sang
    // bước sau (review PR #19 vòng 2): bàn phím mở mà sang màn
    // khác thì bóp cột, tapCorrect(1) chạm hụt rồi không có
    // math-next-button. App cũng tự unfocus trong _next/_back.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await closeKeyboard();
    await takeShot('onboarding-name');
    await tapOnboardingNext();
    await closeKeyboard();

    // Bước chọn trứng.
    expect(find.text('Bước 5/5'), findsOneWidget);
    await tapVisible(const Key('onboarding-egg-dog'));
    // Thẻ trứng đã chọn thì nút Xong phải bấm được.
    final finish = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('onboarding-finish-button')),
    );
    expect(finish.onPressed, isNotNull);
    await takeShot('onboarding-egg');
    await tester.tap(find.byKey(const Key('onboarding-finish-button')));
    await tester.pumpAndSettle();

    // Vào Thị trấn: nhân vật nữ đã tạo đứng ở cột trái.
    expect(find.byKey(const Key('town-screen')), findsOneWidget);
    expect(find.text('Thị trấn Diệu Kỳ'), findsOneWidget);
    expect(find.byKey(const Key('town-character')), findsOneWidget);
    expect(find.text('An'), findsOneWidget);
    await takeShot('town');

    // --- T1-09: đi hết chặng 1 (mảng logic, bậc 1) ---
    // Nút khu 0 của màn Thị trấn T1-12 (tên key cũ `town-math-button`
    // đã bỏ khi viết lại màn Thị trấn).
    await tapVisible(const Key('town-stage-0-button'));
    expect(find.byKey(const Key('math-screen')), findsOneWidget);

    // Đọc đề ngày đã lưu từ DB của app để tính đáp án đúng.
    final element = tester.element(find.byKey(const Key('math-screen')));
    final db = ProviderScope.containerOf(element).read(databaseProvider);
    final childId = await db.ensureSeeded();
    // Tắt âm thanh khi chạy trên máy ảo CI: phát WAV qua audioplayers
    // làm pumpAndSettle không bao giờ dừng (đã khoanh vùng ở PR #13).
    // T1-15 thử pool 4 player cố định tái dùng (xem SoundService)
    // rồi bật lại âm thanh để CI kiểm chứng, nhưng máy ảo vẫn treo
    // nên Claude quyết tắt lại ở đây; không thử gói khác ở PR này.
    // Âm thanh vẫn bật trong app; kiểm bằng widget test (SoundPlayer
    // giả) và trên máy thật.
    await db.settingsDao.setValue(key: 'sound_enabled', value: 'false');
    final set = await db.dailySetsDao.getDailySet(childId, db.clock.today());
    final resolved = db.dailySetsDao
        .readQuestions(set!)
        .sublist(0, 5)
        .map(ResolvedQuestion.resolve)
        .toList();

    // Surface đã convert ở trên (chỉ được gọi một lần cho cả test);
    // `takeShot` đã định nghĩa ở đầu test, dùng chung cho cả luồng.
    Future<void> tapCorrect(int qi) async {
      await tapVisible(Key('choice-${resolved[qi].correctDisplayIndex}'));
    }

    Future<void> tapWrong(int qi) async {
      final correct = resolved[qi].correctDisplayIndex;
      await tapVisible(Key('choice-${correct == 0 ? 1 : 0}'));
    }

    Future<void> tapNext() async {
      await tapVisible(const Key('math-next-button'));
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
      await tapVisible(Key('keypad-$ch'));
    }
    await tester.pumpAndSettle();
    await takeShot('math-number');
    await tapVisible(const Key('keypad-submit'));
    expect(find.byKey(const Key('math-correct')), findsOneWidget);
    await tapNext();

    // Cuối chặng: màn kết quả — đúng 4/5 câu.
    expect(find.byKey(const Key('stage-result-screen')), findsOneWidget);
    expect(find.text('Đúng 4/5 câu'), findsOneWidget);
    await takeShot('math-result');
  });
}
