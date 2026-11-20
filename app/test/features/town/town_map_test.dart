/// Widget test cho bản đồ thị trấn v3b (C): nền + 17 lớp động (9 lớp
/// hiện ở t = 0) + 6 vùng bấm (5 khu + nhà hồng về Phòng), chuyển
/// động tắt được qua cổng [AnimationGate].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/animation/animation_gate.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/features/town/town_assets.dart';
import 'package:timokid/features/town/town_map.dart';
import 'package:timokid/features/town/town_roads.dart';

void main() {
  const statuses = [
    StageStatus.notStarted,
    StageStatus.notStarted,
    StageStatus.notStarted,
    StageStatus.notStarted,
    StageStatus.notStarted,
  ];

  Future<void> pumpMap(
    WidgetTester tester, {
    void Function(int index)? onAreaTap,
    VoidCallback? onRoomTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 360,
            child: TownMap(
              statuses: statuses,
              onAreaTap: onAreaTap ?? (_) {},
              onRoomTap: onRoomTap ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('cổng tắt: đủ 9 lớp động hiện ở t=0 + 6 vùng bấm', (
    tester,
  ) async {
    await pumpMap(tester);

    // Ở t = 0: xe 1, xe 2 đang chạy ↘ (biến thể dr), người 1 đang
    // đi ↗ (biến thể ur, khung a), người 2 đang đi ↙ (biến thể dr
    // lật ngang, khung a) — xem `town_roads_test.dart`.
    for (final layer in [
      'cloud_01',
      'cloud_02',
      'cloud_03',
      'car_01_dr',
      'car_02_dr',
      'person_01_ur_a',
      'person_02_dr_a',
      'tree_01',
      'tree_02',
    ]) {
      expect(
        find.byKey(Key('town-layer-$layer')),
        findsOneWidget,
        reason: 'thiếu lớp động $layer',
      );
    }
    // Các biến thể khác không hiện ở t = 0 (chỉ 1 biến thể/xe/người
    // hiện ra tại một thời điểm).
    for (final layer in [
      'car_01_ur',
      'car_02_ur',
      'person_01_dr_a',
      'person_01_dr_b',
      'person_01_ur_b',
      'person_02_dr_b',
      'person_02_ur_a',
      'person_02_ur_b',
    ]) {
      expect(
        find.byKey(Key('town-layer-$layer')),
        findsNothing,
        reason: 'lớp $layer không được hiện ở t=0',
      );
    }
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(Key('town-stage-$i-button')), findsOneWidget);
    }
    expect(find.byKey(const Key('town-room-house-button')), findsOneWidget);
  });

  testWidgets('bấm chặng 0 gọi onAreaTap(0), bấm nhà hồng gọi onRoomTap', (
    tester,
  ) async {
    var tapped = -1;
    var roomTapped = false;
    await pumpMap(
      tester,
      onAreaTap: (i) => tapped = i,
      onRoomTap: () => roomTapped = true,
    );

    await tester.tap(find.byKey(const Key('town-stage-0-button')));
    await tester.pump();
    expect(tapped, 0);

    await tester.tap(find.byKey(const Key('town-room-house-button')));
    await tester.pump();
    expect(roomTapped, isTrue);
  });

  testWidgets('bấm đúng tâm từng rect thì gọi đúng khu / Phòng', (
    tester,
  ) async {
    // Bản đồ 800x360 trong SizedBox: AspectRatio 16:9 → bản đồ
    // 640x360, căn giữa (lệch trái 80 dp). Tâm rect (tọa độ khung
    // nền 1600x900) đổi sang tọa độ màn hình theo tỉ lệ đó.
    const mapLeft = 80.0;
    const mapWidth = 640.0;
    const mapHeight = 360.0;
    Offset toScreen(Offset framePoint) => Offset(
      mapLeft + framePoint.dx / townFrameWidth * mapWidth,
      framePoint.dy / townFrameHeight * mapHeight,
    );

    final tapped = <int>[];
    var roomTapped = false;
    await pumpMap(
      tester,
      onAreaTap: tapped.add,
      onRoomTap: () => roomTapped = true,
    );

    for (var i = 0; i < townAreas.length; i++) {
      final rect = townAreas[i].building;
      final center = Offset(
        rect.center.dx * townFrameWidth,
        rect.center.dy * townFrameHeight,
      );
      await tester.tapAt(toScreen(center));
      await tester.pump();
      expect(tapped, [i], reason: 'tâm rect khu $i phải gọi onAreaTap($i)');
      tapped.clear();
    }

    final roomCenter = Offset(
      roomBuildingRect.center.dx * townFrameWidth,
      roomBuildingRect.center.dy * townFrameHeight,
    );
    await tester.tapAt(toScreen(roomCenter));
    await tester.pump();
    expect(roomTapped, isTrue, reason: 'tâm rect nhà hồng phải gọi onRoomTap');
  });

  testWidgets('cổng bật: xe chạy ↘ nên vị trí đổi sau 500 ms', (tester) async {
    AnimationGate.enabled = true;
    addTearDown(() => AnimationGate.enabled = false);
    await pumpMap(tester);

    final car = find.byKey(const Key('town-layer-car_01_dr'));
    final before = tester.getTopLeft(car);
    await tester.pump(const Duration(milliseconds: 500));
    final after = tester.getTopLeft(car);
    // Xe hồng chạy ↘ dọc D2 (30 giây một lượt): sau 500 ms phải
    // dịch sang phải VÀ xuống dưới vài dp.
    expect(after.dx, greaterThan(before.dx));
    expect(after.dy, greaterThan(before.dy));
  });
}
