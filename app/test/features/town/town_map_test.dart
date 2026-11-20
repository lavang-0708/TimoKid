/// Widget test cho bản đồ thị trấn v2 (A2): nền + 10 lớp động +
/// 6 vùng bấm (5 khu + nhà hồng về Phòng), chuyển động tắt được
/// qua cổng [AnimationGate].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/animation/animation_gate.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/features/town/town_map.dart';

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

  testWidgets('cổng tắt: đủ 10 lớp động + 6 vùng bấm', (tester) async {
    await pumpMap(tester);

    for (final layer in [
      'cloud_01',
      'cloud_02',
      'cloud_03',
      'car_01',
      'car_02',
      'fountain',
      'tree_01',
      'tree_02',
      'person_01',
      'person_02',
    ]) {
      expect(
        find.byKey(Key('town-layer-$layer')),
        findsOneWidget,
        reason: 'thiếu lớp động $layer',
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

  testWidgets('cổng bật: xe chạy nên vị trí đổi sau 500 ms', (tester) async {
    AnimationGate.enabled = true;
    addTearDown(() => AnimationGate.enabled = false);
    await pumpMap(tester);

    final car = find.byKey(const Key('town-layer-car_01'));
    final before = tester.getTopLeft(car);
    await tester.pump(const Duration(milliseconds: 500));
    final after = tester.getTopLeft(car);
    // Xe hồng chạy dọc đường từ trái sang phải (30 giây một lượt):
    // sau 500 ms phải dịch sang phải vài dp.
    expect(after.dx, greaterThan(before.dx));
  });
}
