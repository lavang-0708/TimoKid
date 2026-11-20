import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/router/app_router.dart';
import 'package:timokid/main.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // Màn làm toán tải đề ngày từ DB nên test điều hướng phải có DB
    // thật (bộ nhớ); DB file của app không mở được trong widget test.
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        // Router mới mỗi test: router tĩnh của app giữ stack của
        // test trước (test trước kết thúc ở Thị trấn thì test sau
        // bơm vào đã ở Thị trấn, không còn ở Phòng).
        child: TimoKidApp(router: AppRouter.create(showOnboarding: false)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mở app vào thẳng màn Phòng, bấm Thị trấn thì sang Thị trấn', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byKey(const Key('room-screen')), findsOneWidget);
    expect(find.text('Phòng của bé'), findsOneWidget);

    await tester.tap(find.byKey(const Key('room-town-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('town-screen')), findsOneWidget);
    expect(find.text('Thị trấn Diệu Kỳ'), findsOneWidget);
    // 5 nút khu của T1-12 (nút "Làm toán"/"Kết quả chặng" tạm của
    // T1-02 đã bỏ); đề mới nên cả 5 chặng đều chưa làm.
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(Key('town-stage-$i-button')), findsOneWidget);
    }
    expect(find.text('Đề ngày: 0/5 chặng'), findsOneWidget);
  });

  testWidgets('bấm nút khu thì sang màn Làm toán, bấm về thì quay lại', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('room-town-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('town-screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('town-stage-0-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('math-screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('math-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('town-screen')), findsOneWidget);
  });
}
