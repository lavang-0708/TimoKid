/// Test cấu hình Tháp: tầng → bậc, ngưỡng qua tầng, thưởng.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/features/tower/tower_config.dart';

void main() {
  test('tầng → bậc: 1–5 bậc 1, 6–10 bậc 2, tầng thường', () {
    expect(TowerConfig.rungForFloor(1), 1);
    expect(TowerConfig.rungForFloor(4), 1);
    expect(TowerConfig.rungForFloor(6), 2);
    expect(TowerConfig.rungForFloor(9), 2);
    expect(TowerConfig.rungForFloor(11), 3);
    expect(TowerConfig.rungForFloor(26), 6);
    expect(TowerConfig.rungForFloor(29), 6);
  });

  test('tầng boss: bậc +1, kẹp tối đa 6', () {
    expect(TowerConfig.rungForFloor(5), 2);
    expect(TowerConfig.rungForFloor(10), 3);
    expect(TowerConfig.rungForFloor(25), 6);
    expect(TowerConfig.rungForFloor(30), 6);
  });

  test('chỉ tầng chia hết cho 5 là boss', () {
    final bosses = [
      for (var f = 1; f <= 30; f++)
        if (TowerConfig.isBoss(f)) f,
    ];
    expect(bosses, [5, 10, 15, 20, 25, 30]);
  });

  test('ngưỡng qua tầng: thường 3/5, boss 4/5', () {
    expect(TowerConfig.passNeeded(1), 3);
    expect(TowerConfig.passNeeded(5), 4);
    expect(TowerConfig.passNeeded(29), 3);
    expect(TowerConfig.passNeeded(30), 4);
  });

  test('thưởng lần đầu: thường 10 xu, boss 1 kc + 20 xu, đỉnh 3 kc', () {
    expect(TowerConfig.firstClearXu(1), 10);
    expect(TowerConfig.firstClearGems(1), 0);
    expect(TowerConfig.firstClearXu(10), 20);
    expect(TowerConfig.firstClearGems(10), 1);
    expect(TowerConfig.firstClearXu(30), 20);
    expect(TowerConfig.firstClearGems(30), 3);
  });
}
