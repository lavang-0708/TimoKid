/// Widget test màn nở trứng (T2-03) + rẽ nhánh từ màn Kết quả chặng.
///
/// Màn nở chạy hoạt cảnh một lần rồi dừng (2,4 giây) nên
/// `pumpAndSettle` dừng được; nút Tiếp tục chỉ hiện khi hoạt cảnh xong.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/router/app_router.dart';
import 'package:timokid/features/onboarding/egg_service.dart';
import 'package:timokid/features/onboarding/hatch_screen.dart';
import 'package:timokid/features/stage_result/stage_result_screen.dart';
import 'package:timokid/features/town/town_screen.dart';
import 'package:timokid/main.dart';

void main() {
  late AppDatabase db;
  late String childId;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    childId = await db.ensureSeeded();
  });

  Future<void> pumpHatch(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: TimoKidApp(router: AppRouter.create(showHatch: true)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'có lần chờ nở: hiện pet mới nở, bấm Tiếp thì đã nở + về Thị trấn',
    (tester) async {
      final eggs = EggService(db: db);
      await eggs.selectEgg(childId: childId, species: 'dog');
      await eggs.noteStageCompleted(childId);
      await pumpHatch(tester);

      expect(find.byKey(const Key('hatch-screen')), findsOneWidget);
      expect(find.text('Chào bé cún Tinh Anh!'), findsOneWidget);
      // Trứng + pet mới nở là PNG thật (PR #21), không còn SVG tạm.
      final paths = tester
          .widgetList<Image>(find.byType(Image))
          .map((w) => w.image)
          .whereType<AssetImage>()
          .map((p) => p.assetName)
          .toList();
      expect(paths, contains('assets/images/pets/dog_egg.png'));
      expect(paths, contains('assets/images/pets/dog_newborn.png'));
      expect(find.byType(SvgPicture), findsNothing);
      expect(find.byKey(const Key('hatch-continue-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('hatch-continue-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('town-screen')), findsOneWidget);
      expect(await eggs.isHatched(childId), isTrue);
      expect(await eggs.isHatchPending(childId), isFalse);
    },
  );

  testWidgets('không có lần chờ: hiện thông báo + nút về Thị trấn', (
    tester,
  ) async {
    await pumpHatch(tester);

    expect(find.text('Chưa có trứng nào nở.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('hatch-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('town-screen')), findsOneWidget);
  });

  testWidgets('màn Kết quả chặng rẽ sang màn nở khi có lần chờ', (
    tester,
  ) async {
    final eggs = EggService(db: db);
    await eggs.selectEgg(childId: childId, species: 'rabbit');
    await eggs.noteStageCompleted(childId);

    final router = GoRouter(
      initialLocation: '/stage-result',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const TownScreen()),
        GoRoute(path: '/hatch', builder: (_, _) => const HatchScreen()),
        GoRoute(
          path: '/stage-result',
          builder: (_, _) => const StageResultScreen(
            result: StageResultArgs(
              stageIndex: 0,
              strand: 'logic',
              correctCount: 5,
              firstTryCorrectCount: 5,
              totalQuestions: 5,
              xuEarned: 15,
              nextStageIndex: 1,
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: TimoKidApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stage-result-screen')), findsOneWidget);
    await tester.tap(find.byKey(const Key('stage-result-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hatch-screen')), findsOneWidget);
    expect(find.text('Chào bé thỏ Bánh Bao!'), findsOneWidget);
  });

  testWidgets('màn Kết quả chặng về thẳng Thị trấn khi không có lần chờ', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/stage-result',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const TownScreen()),
        GoRoute(path: '/hatch', builder: (_, _) => const HatchScreen()),
        GoRoute(
          path: '/stage-result',
          builder: (_, _) => const StageResultScreen(
            result: StageResultArgs(
              stageIndex: 0,
              strand: 'logic',
              correctCount: 5,
              firstTryCorrectCount: 5,
              totalQuestions: 5,
              xuEarned: 15,
              nextStageIndex: 1,
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: TimoKidApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('stage-result-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('town-screen')), findsOneWidget);
  });
}
