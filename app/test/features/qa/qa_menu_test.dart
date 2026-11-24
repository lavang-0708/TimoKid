import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/core/router/app_router.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/qa/qa_menu_opener.dart';
import 'package:timokid/features/review_book/review_book_service.dart';
import 'package:timokid/features/town/town_screen.dart';
import 'package:timokid/main.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // DB bộ nhớ (DB file của app không mở được trong widget test).
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    // Router là static nên giữ stack của test trước (vd: test trước
    // kết thúc khi menu QA còn mở thì router vẫn ở '/qa'). Về lại '/'
    // trước khi bơm để test nào cũng bắt đầu từ màn Thị trấn — nếu
    // không, test sau sẽ bơm cả Thị trấn lẫn menu cùng lúc và hai
    // `ensureSeeded` chạy chồng nhau gây trùng settings.
    AppRouter.router.go(TownScreen.route);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const TimoKidApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Nhấn giữ ở góc trên-trái (tâm vùng QA 72x72) trong [holdFor],
  /// rồi trả về gesture để test tự buông tay khi cần.
  Future<TestGesture> holdCorner(
    WidgetTester tester, {
    Duration holdFor = const Duration(seconds: 5),
  }) async {
    final gesture = await tester.startGesture(const Offset(36, 36));
    await tester.pump(holdFor);
    return gesture;
  }

  /// Mở menu QA bằng cách giữ góc 5 giây (để gesture mở cho test
  /// đóng sau khi xong).
  Future<TestGesture> openMenu(WidgetTester tester) async {
    final gesture = await holdCorner(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('qa-menu')), findsOneWidget);
    return gesture;
  }

  /// Ngày hôm nay / ngày mai theo giờ Việt Nam, dạng YYYY-MM-DD.
  String vnToday({int addDays = 0}) {
    final now = DateTime.now().toUtc().add(vietnamUtcOffset);
    final day = now.add(Duration(days: addDays));
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  group('mở menu bằng nhấn giữ góc', () {
    testWidgets('giữ góc 5 giây thì mở menu, nút đóng thì về Thị trấn', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.byKey(const Key('town-screen')), findsOneWidget);

      final gesture = await openMenu(tester);
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('qa-close-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('town-screen')), findsOneWidget);
      expect(find.byKey(const Key('qa-menu')), findsNothing);
    });

    testWidgets('buông tay trước 5 giây thì không mở menu', (tester) async {
      await pumpApp(tester);

      final gesture = await holdCorner(
        tester,
        holdFor: const Duration(seconds: 2),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('qa-menu')), findsNothing);
    });

    testWidgets('menu tắt thì không có vùng góc', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            home: QaMenuOpener(
              enabled: false,
              child: Scaffold(body: Text('x')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('qa-corner-zone')), findsNothing);
      expect(find.text('x'), findsOneWidget);
    });

    testWidgets('menu bật thì có vùng góc', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            home: QaMenuOpener(enabled: true, child: Scaffold(body: Text('x'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('qa-corner-zone')), findsOneWidget);
    });
  });

  group('chức năng trong menu', () {
    testWidgets('nhảy ngày đổi ngày hiển thị, về hôm nay thì về lại', (
      tester,
    ) async {
      await pumpApp(tester);
      final gesture = await openMenu(tester);

      expect(find.textContaining(vnToday()), findsOneWidget);
      expect(find.textContaining('đang ở ngày thật'), findsOneWidget);

      await tester.tap(find.byKey(const Key('qa-advance-day')));
      await tester.pumpAndSettle();
      expect(find.textContaining(vnToday(addDays: 1)), findsOneWidget);
      expect(find.textContaining('đang lệch +1 ngày'), findsOneWidget);

      await tester.tap(find.byKey(const Key('qa-reset-day')));
      await tester.pumpAndSettle();
      expect(find.textContaining(vnToday()), findsOneWidget);
      expect(find.textContaining('đang ở ngày thật'), findsOneWidget);

      await gesture.up();
    });

    testWidgets('đặt bậc từng mảng ghi vào skill_progress', (tester) async {
      await pumpApp(tester);
      final gesture = await openMenu(tester);
      final childId = await db.ensureSeeded();

      await tester.ensureVisible(find.byKey(const Key('qa-rung-logic')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('qa-rung-logic')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4').last);
      await tester.pumpAndSettle();

      final progress = await db.skillProgressDao.getStrandProgress(
        childId,
        Strand.logic,
      );
      expect(progress?.rung, 4);

      await gesture.up();
    });

    testWidgets('xem sổ ôn tập hiện mục đã vào sổ', (tester) async {
      final childId = await db.ensureSeeded();
      await ReviewBookService(
        reviewQueueDao: db.reviewQueueDao,
        clock: db.clock,
      ).recordAnswer(
        childId: childId,
        formId: 'logic.balance',
        rung: 2,
        correctFirstTry: false,
      );

      await pumpApp(tester);
      final gesture = await openMenu(tester);

      expect(find.byKey(const Key('qa-review-logic.balance')), findsOneWidget);
      expect(find.textContaining('Chuỗi đúng: 0/3'), findsOneWidget);

      await gesture.up();
    });

    testWidgets('xem 20 lượt trả lời gần nhất', (tester) async {
      final childId = await db.ensureSeeded();
      final id1 = await db.attemptsDao.recordAttempt(
        childId: childId,
        formId: 'logic.balance',
        strand: Strand.logic,
        level: 1,
        rung: 1,
        answerType: AnswerType.choice,
        correctFirstTry: true,
        attemptsCount: 1,
        durationMs: 1000,
      );
      final id2 = await db.attemptsDao.recordAttempt(
        childId: childId,
        formId: 'arith.quick',
        strand: Strand.arith,
        level: 2,
        rung: 3,
        answerType: AnswerType.number,
        correctFirstTry: false,
        attemptsCount: 2,
        durationMs: 2000,
      );

      await pumpApp(tester);
      final gesture = await openMenu(tester);

      expect(find.byKey(Key('qa-attempt-$id1')), findsOneWidget);
      expect(find.byKey(Key('qa-attempt-$id2')), findsOneWidget);
      expect(find.textContaining('Đúng ngay'), findsOneWidget);
      expect(find.textContaining('Chưa đúng ngay'), findsOneWidget);

      await gesture.up();
    });

    testWidgets('xem thử dạng bài sinh câu, không ghi lượt trả lời', (
      tester,
    ) async {
      await pumpApp(tester);
      final gesture = await openMenu(tester);
      final childId = await db.ensureSeeded();

      await tester.ensureVisible(find.byKey(const Key('qa-preview-generate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('qa-preview-generate')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('qa-preview-question')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('qa-preview-again')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('qa-preview-again')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('qa-preview-question')), findsOneWidget);

      expect(await db.attemptsDao.getAttemptsForChild(childId), isEmpty);

      await gesture.up();
    });

    testWidgets('xóa dữ liệu: hủy thì giữ nguyên, xác nhận thì về mới cài', (
      tester,
    ) async {
      final childId = await db.ensureSeeded();
      await db.skillProgressDao.setStrandRung(
        childId: childId,
        strand: Strand.logic,
        rung: 4,
      );
      await db.attemptsDao.recordAttempt(
        childId: childId,
        formId: 'logic.balance',
        strand: Strand.logic,
        level: 1,
        rung: 1,
        answerType: AnswerType.choice,
        correctFirstTry: true,
        attemptsCount: 1,
        durationMs: 1000,
      );

      await pumpApp(tester);
      final gesture = await openMenu(tester);

      // Hủy thì giữ nguyên.
      await tester.ensureVisible(find.byKey(const Key('qa-clear-data')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('qa-clear-data')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('qa-clear-confirm-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('qa-clear-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('qa-clear-confirm-dialog')), findsNothing);
      expect(
        (await db.skillProgressDao.getStrandProgress(
          childId,
          Strand.logic,
        ))?.rung,
        4,
      );

      // Xác nhận thì xóa hết và về màn Thị trấn.
      await tester.ensureVisible(find.byKey(const Key('qa-clear-data')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('qa-clear-data')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('qa-clear-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('town-screen')), findsOneWidget);

      final freshChildId = (await db.childrenDao.getAllChildren()).first.id;
      expect(await db.attemptsDao.getAttemptsForChild(freshChildId), isEmpty);
      expect(
        (await db.skillProgressDao.getStrandProgress(
          freshChildId,
          Strand.logic,
        ))?.rung,
        1,
      );

      await gesture.up();
    });

    testWidgets('nút "Xem thử hiệu ứng rồng" mở màn xem thử, chạy được', (
      tester,
    ) async {
      await pumpApp(tester);
      final gesture = await openMenu(tester);
      await tester.ensureVisible(find.byKey(const Key('qa-dragon-fx')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('qa-dragon-fx')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dragon-fx-preview')), findsOneWidget);
      await tester.tap(find.byKey(const Key('dragon-fx-fire')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dragon-preview-stage-newborn')));
      await tester.pumpAndSettle();
      expect(find.text('Lớn lên rồng sẽ phun lửa thật!'), findsOneWidget);
      await gesture.up();
    });
  });
}
