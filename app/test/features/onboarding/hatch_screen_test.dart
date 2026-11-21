/// Widget test màn nở trứng (T2-03) + rẽ nhánh từ màn Kết quả chặng.
///
/// Màn nở chạy hoạt cảnh một lần rồi dừng (3,6 giây) nên
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
import 'package:timokid/features/room/pet_art.dart';
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

  testWidgets('có lần chờ nở: hiện pet mới nở, bấm Tiếp thì đã nở + về Phòng', (
    tester,
  ) async {
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
    // Sau khi nở: hai nửa vỏ là hình Muse vẽ (lô 8A) + pet mới nở.
    expect(paths, contains('assets/images/pets/dog_shell_bottom.png'));
    expect(paths, contains('assets/images/pets/dog_shell_top.png'));
    expect(paths, contains('assets/images/pets/dog_newborn.png'));
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.byKey(const Key('hatch-continue-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('hatch-continue-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('room-screen')), findsOneWidget);
    expect(await eggs.isHatched(childId), isTrue);
    expect(await eggs.isHatchPending(childId), isFalse);
  });

  testWidgets('hoạt cảnh nở từng bước: nứt dần, vỡ, pet nhảy ra', (
    tester,
  ) async {
    final eggs = EggService(db: db);
    await eggs.selectEgg(childId: childId, species: 'cat');
    await eggs.noteStageCompleted(childId);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: TimoKidApp(router: AppRouter.create(showHatch: true)),
      ),
    );
    // Nạp xong (DB) rồi mới chạy hoạt cảnh.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    // Đầu: trứng nguyên, chưa có nút Tiếp tục, chưa có vỏ vỡ.
    expect(find.byKey(const Key('hatch-hint')), findsOneWidget);
    expect(find.byKey(const Key('hatch-shell-top')), findsNothing);
    expect(find.byKey(const Key('hatch-continue-button')), findsNothing);

    // Giữa chừng (~2 giây): vẫn là trứng nguyên, chưa vỡ.
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.byKey(const Key('hatch-shell-top')), findsNothing);

    // Sau mốc vỡ (~2,9 giây): hai nửa vỏ, nút Tiếp tục chưa hiện.
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const Key('hatch-shell-top')), findsOneWidget);
    expect(find.byKey(const Key('hatch-shell-bottom')), findsOneWidget);
    expect(find.byKey(const Key('hatch-continue-button')), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hatch-continue-button')), findsOneWidget);
    expect(find.byKey(const Key('hatch-hint')), findsNothing);
  });

  testWidgets('bấm trứng: mỗi lần bấm nhảy tới bước nứt kế tiếp', (
    tester,
  ) async {
    final eggs = EggService(db: db);
    await eggs.selectEgg(childId: childId, species: 'dog');
    await eggs.noteStageCompleted(childId);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: TimoKidApp(router: AppRouter.create(showHatch: true)),
      ),
    );
    // Nạp xong (DB) rồi mới chạy hoạt cảnh.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    // Bấm 3 lần (mỗi lần chờ ~0,35 giây cho đoạn nhảy nhanh): xong
    // 3 vết nứt, mới tới 1 giây mà còn chưa vỡ.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('hatch-egg')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(const Key('hatch-shell-top')), findsNothing);
    }
    // Bấm lần 4: vỡ ngay (không phải đợi hết 3,6 giây).
    await tester.tap(find.byKey(const Key('hatch-egg')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const Key('hatch-shell-top')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hatch-continue-button')), findsOneWidget);
  });

  test('dòng thời gian: lắc mạnh dần, nứt đủ 3 bước, pet nhảy nén-giãn', () {
    double peak(double from, double to) {
      var m = 0.0;
      for (var t = from; t <= to; t += 5) {
        m = m < hatchWobbleAngle(t).abs() ? hatchWobbleAngle(t).abs() : m;
      }
      return m;
    }

    expect(peak(350, 850), lessThan(peak(1250, 1750)));
    expect(peak(1250, 1750), lessThan(peak(2000, 2600)));
    // Nghỉ giữa các đợt lắc và sau khi vỡ.
    expect(hatchWobbleAngle(1000), 0);
    expect(hatchWobbleAngle(2800), 0);

    expect(hatchCrackProgress(0).c1, 0);
    expect(hatchCrackProgress(1000).c1, 1);
    expect(hatchCrackProgress(1000).c2, 0);
    expect(hatchCrackProgress(1900).c2, 1);
    expect(hatchCrackProgress(1900).c3, 0);
    expect(hatchCrackProgress(2700).c3, 1);

    // Pet: chưa hiện trước vỡ; giãn dọc (>1) rồi nén (<1) lúc tiếp
    // đất; cuối về cỡ gốc.
    expect(hatchPetPose(2000), (0.0, 0.0, 0.0));
    final stretch = hatchPetPose(3000);
    expect(stretch.$2, greaterThan(1.0));
    expect(stretch.$1, lessThan(1.0));
    final land = hatchPetPose(3320);
    expect(land.$2, lessThan(1.0));
    expect(land.$1, greaterThan(1.0));
    expect(hatchPetPose(3600), (1.0, 1.0, 0.0));
  });

  test('hình trứng nứt Muse (lô 8A) đã bật, đường dẫn đúng quy ước', () {
    expect(eggCrackArtReady, isTrue);
    expect(eggCrackAsset('dog', 2), 'assets/images/pets/dog_egg_crack_2.png');
    expect(shellTopAsset('cat'), 'assets/images/pets/cat_shell_top.png');
    expect(
      shellBottomAsset('rabbit'),
      'assets/images/pets/rabbit_shell_bottom.png',
    );
  });

  testWidgets('không có lần chờ: hiện thông báo + nút về Phòng', (
    tester,
  ) async {
    await pumpHatch(tester);

    expect(find.text('Chưa có trứng nào nở.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('hatch-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-screen')), findsOneWidget);
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
