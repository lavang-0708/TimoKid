import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
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
        child: const TimoKidApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mở app vào thẳng màn Thị trấn', (tester) async {
    await pumpApp(tester);

    expect(find.byKey(const Key('town-screen')), findsOneWidget);
    expect(find.text('Thị trấn Diệu Kỳ'), findsOneWidget);
    expect(find.byKey(const Key('town-math-button')), findsOneWidget);
    expect(find.byKey(const Key('town-result-button')), findsOneWidget);
  });

  testWidgets('bấm Làm toán thì sang màn Làm toán, bấm về thì quay lại', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('town-math-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('math-screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('math-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('town-screen')), findsOneWidget);
  });

  testWidgets('bấm Kết quả chặng thì sang màn Kết quả chặng', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('town-result-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stage-result-screen')), findsOneWidget);
  });
}
