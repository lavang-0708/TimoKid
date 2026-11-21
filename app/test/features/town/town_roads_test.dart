/// Test logic thuần cho bản đồ thị trấn v3b (C): đường đi D1–D6,
/// hướng/lật xe-người, khung bước chân, và vùng bấm 6 công trình.
///
/// Không cần widget: mọi hàm đều ở `town_roads.dart` +
/// `town_assets.dart` nên test chạy nhanh, không phụ thuộc ảnh.
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/features/town/town_assets.dart';
import 'package:timokid/features/town/town_roads.dart';

/// 6 vùng bấm (5 khu + nhà hồng) theo tỉ lệ 0..1 → đổi sang px
/// khung nền 1600x900.
List<Rect> _townFrameRects() {
  final areas = townAreas.map((a) {
    final b = a.building;
    return Rect.fromLTWH(
      b.left * townFrameWidth,
      b.top * townFrameHeight,
      b.width * townFrameWidth,
      b.height * townFrameHeight,
    );
  }).toList();
  final room = roomBuildingRect;
  areas.add(
    Rect.fromLTWH(
      room.left * townFrameWidth,
      room.top * townFrameHeight,
      room.width * townFrameWidth,
      room.height * townFrameHeight,
    ),
  );
  return areas;
}

void main() {
  group('đường đi: mọi điểm trên tuyến nằm trong vùng đường đã khai báo', () {
    // 4 tuyến: 2 xe chạy giữa làn, 2 người đi trên vỉa hè (lệch
    // tâm 25 px — vẫn phải trong nửa rộng 50 px của đường).
    final routes = <(TownRoute route, bool sidewalk)>[
      (car1Route, false),
      (car2Route, false),
      (walker1Route, true),
      (walker2Route, true),
    ];

    for (final (route, sidewalk) in routes) {
      test('tuyến ${route.waypoints.first} → ${route.waypoints.last}', () {
        // Lấy mẫu mỗi 5 px dọc tuyến (cả chiều xuôi và ngược).
        for (var d = 0.0; d <= route.totalLength; d += 5) {
          for (final forward in [true, false]) {
            final sample = route.sample(d, forward);
            var point = sample.point;
            if (sidewalk) {
              point = sidewalkPoint(point, sample.legUnit);
            }
            expect(
              isOnRoad(point),
              isTrue,
              reason:
                  'điểm $point (d=$d, xuôi=$forward) lệch khỏi vùng đường '
                  '(cách tâm ${distanceToRoads(point).toStringAsFixed(1)} px > 50)',
            );
          }
        }
      });
    }

    test('điểm đầu/cuối tuyến đúng điểm mốc', () {
      // So sánh có dung sai: điểm nội suy bằng số thực nên có thể
      // lệch ~1e-13 so với điểm mốc (in ra giống hệt nhau nhưng
      // `==` vẫn đỏ).
      void expectPoint(Offset actual, Offset expected) {
        expect(
          (actual - expected).distance,
          lessThan(0.001),
          reason: 'điểm $actual lệch điểm mốc $expected',
        );
      }

      expectPoint(car1Route.sample(0, true).point, const Offset(774, 511));
      expectPoint(
        car1Route.sample(car1Route.totalLength, true).point,
        const Offset(1524, 882),
      );
      expectPoint(car2Route.sample(0, true).point, const Offset(856, 783));
      expectPoint(
        car2Route.sample(car2Route.totalLength, true).point,
        const Offset(1536, 443),
      );
      expectPoint(walker1Route.sample(0, true).point, const Offset(820, 785));
      expectPoint(
        walker1Route.sample(walker1Route.totalLength, true).point,
        const Offset(1250, 570),
      );
      expectPoint(walker2Route.sample(0, true).point, const Offset(1150, 681));
      expectPoint(
        walker2Route.sample(walker2Route.totalLength, true).point,
        const Offset(1540, 874),
      );
    });

    test('hướng di chuyển đúng theo đoạn đường đang đi', () {
      // Xe 1 chạy trên C1 (đường chéo xuống-phải): xuôi thì ↘,
      // ngược thì ↖. Xe 2 chạy trên C2: xuôi ↗, ngược ↙.
      expect(
        car1Route.sample(0, true).direction,
        TownTravelDirection.downRight,
      );
      expect(
        car1Route.sample(400, true).direction,
        TownTravelDirection.downRight,
      );
      expect(
        car1Route.sample(400, false).direction,
        TownTravelDirection.upLeft,
      );
      expect(car2Route.sample(0, true).direction, TownTravelDirection.upRight);
      expect(
        car2Route.sample(300, false).direction,
        TownTravelDirection.downLeft,
      );
    });

    test('điểm vỉa hè lệch townSidewalkOffset px sang phía nam đường', () {
      for (final direction in TownTravelDirection.values) {
        final unit = directionUnit(direction);
        final point = const Offset(800, 450);
        final sidewalk = sidewalkPoint(point, unit);
        expect((sidewalk - point).distance, closeTo(townSidewalkOffset, 0.001));
        // Phía nam = y tăng (xuống dưới màn hình).
        expect(sidewalk.dy, greaterThan(point.dy));
      }
    });
  });

  group('hướng và lật: biến thể lớp + lật ngang khớp hướng di chuyển', () {
    test('bảng hướng mặt đo bằng mắt (khóa lại, đừng sửa theo tên file)', () {
      // Xe dr: đầu xe ↘; xe ur: NHÌN TỪ SAU nên đầu xe ↖ (tên "ur"
      // dễ gây nhầm thành ↗ — đây là điểm Claude dặn riêng khi
      // review decode lần 2).
      expect(carVariantFacing['dr'], TownTravelDirection.downRight);
      expect(carVariantFacing['ur'], TownTravelDirection.upLeft);
      // Người dr: mặt ↘; người ur: NHÌN TỪ SAU nên mặt ↗.
      expect(personVariantFacing['dr'], TownTravelDirection.downRight);
      expect(personVariantFacing['ur'], TownTravelDirection.upRight);
    });

    test('xe: mỗi hướng đường chọn đúng biến thể + đúng lật hay không', () {
      for (final model in ['car_01', 'car_02']) {
        for (final direction in TownTravelDirection.values) {
          final choice = carSpriteFor(model, direction);
          final variant = choice.asset.split('_').last.split('.').first;
          final facing = carVariantFacing[variant]!;
          expect(
            effectiveFacing(facing, choice.flipHorizontal),
            direction,
            reason:
                'xe $model đi $direction: chọn ${choice.asset} '
                '(lật=${choice.flipHorizontal}) thì mặt xe quay '
                '${effectiveFacing(facing, choice.flipHorizontal)}',
          );
        }
      }
    });

    test('người: mỗi hướng đường chọn đúng biến thể + đúng lật hay không', () {
      for (final model in ['person_01', 'person_02']) {
        for (final direction in TownTravelDirection.values) {
          for (final frameB in [false, true]) {
            final choice = personSpriteFor(model, direction, frameB);
            final parts = choice.asset
                .split('/')
                .last
                .split('.')
                .first
                .split('_');
            // person_01_dr_a → biến thể là phần thứ 3 (dr/ur).
            final variant = parts[2];
            final facing = personVariantFacing[variant]!;
            expect(
              effectiveFacing(facing, choice.flipHorizontal),
              direction,
              reason:
                  'người $model đi $direction (khung ${frameB ? 'b' : 'a'}): '
                  'chọn ${choice.asset} (lật=${choice.flipHorizontal}) thì '
                  'mặt quay ${effectiveFacing(facing, choice.flipHorizontal)}',
            );
            // Khung bước chân đúng a/b theo frameB.
            expect(parts[3], frameB ? 'b' : 'a');
          }
        }
      }
    });
  });

  group('khung bước chân và sóng tới-lui', () {
    test('walkFrameB đổi khung mỗi 30 px đường đã đi', () {
      expect(walkFrameB(0), isFalse);
      expect(walkFrameB(29), isFalse);
      expect(walkFrameB(30), isTrue);
      expect(walkFrameB(59), isTrue);
      expect(walkFrameB(60), isFalse);
    });

    test('pingPongProgress đi 0..1..0 trong một chu kỳ', () {
      expect(pingPongProgress(0), 0);
      expect(pingPongProgress(0.25), 0.5);
      expect(pingPongProgress(0.5), 1);
      expect(pingPongProgress(0.75), 0.5);
      expect(pingPongProgress(1.0), 0);
      expect(pingPongForward(0.25), isTrue);
      expect(pingPongForward(0.75), isFalse);
    });
  });

  group('tuyến đường không cắt qua công trình (vòng sửa PR #31)', () {
    // Kiểm tra ĐỘC LẬP với vùng đường đã khai báo: test "điểm trên
    // tuyến nằm trong vùng đường" không bắt được lỗi khai báo sai —
    // D2 cũ (880, 70) → (1120, 220) nằm gọn trong vùng đường khai
    // báo cũ nhưng cắt qua khối lều Hội chợ, xe hồng ở t = 0 nằm
    // trên cỏ (990, 90). Test này bắt lỗi đó bằng rect chân công
    // trình đo từ nền thật (`townBuildingFootprints`).
    final routes = <(TownRoute route, bool sidewalk)>[
      (car1Route, false),
      (car2Route, false),
      (walker1Route, true),
      (walker2Route, true),
    ];

    for (final (route, sidewalk) in routes) {
      test('tuyến ${route.waypoints.first} → ${route.waypoints.last}', () {
        expect(
          routeHitsBuilding(route, sidewalk: sidewalk),
          isFalse,
          reason:
              'tuyến cắt qua chân một công trình (xem '
              'townBuildingFootprints)',
        );
      });
    }

    test('hồi quy: D2 cũ cắt qua lều Hội chợ (lỗi PR #31)', () {
      // Tuyến xe 1 với đoạn D2 cũ (880, 70) → (1120, 220) →
      // (1420, 380) → (1600, 470): phải CHẠM lều thì test mới có
      // giá trị — nếu ai đó "sửa" D2 về đoạn thẳng cũ, test này đỏ.
      final oldCar1 = TownRoute(const [
        Offset(0, 480),
        Offset(300, 360),
        Offset(600, 210),
        Offset(880, 70),
        Offset(1120, 220),
        Offset(1420, 380),
        Offset(1600, 470),
      ]);
      expect(routeHitsBuilding(oldCar1, sidewalk: false), isTrue);
    });
  });

  group('vùng bấm 6 công trình (rect mới đo từ nền v3b)', () {
    test('tâm mỗi vùng chỉ nằm trong đúng vùng đó', () {
      final all = _townFrameRects();
      for (var i = 0; i < all.length; i++) {
        final center = all[i].center;
        final hits = <int>[];
        for (var j = 0; j < all.length; j++) {
          if (all[j].contains(center)) hits.add(j);
        }
        expect(hits, [i], reason: 'tâm vùng $i nằm trong các vùng $hits');
      }
    });

    test('không vùng bấm nào che nhãn của vùng khác', () {
      // Nhãn dán ở dải cuối vùng bấm (cao ~140 px theo khung nền,
      // tính cả nhãn phình ở màn nhỏ); vùng vẽ sau đè vùng vẽ trước
      // (thứ tự: 5 khu theo townAreas, rồi nhà hồng cuối cùng).
      final all = _townFrameRects();
      for (var i = 0; i < all.length; i++) {
        final label = Rect.fromLTWH(
          all[i].left + 2,
          all[i].bottom - 140,
          all[i].width - 4,
          140,
        );
        for (var j = i + 1; j < all.length; j++) {
          final overlap = label.intersect(all[j]);
          expect(
            overlap.isEmpty,
            isTrue,
            reason:
                'nhãn vùng $i bị vùng $j che ${overlap.width}x${overlap.height} px',
          );
        }
      }
    });

    test('công trình nằm trong đúng vùng bấm của nó', () {
      final all = _townFrameRects();
      // Thứ tự: 0 Lôgic, 1 Số học, 2 Con số, 3 Hình học, 4 Tổ hợp,
      // 5 Nhà của bé.
      expect(
        all[2].contains(const Offset(725, 165)),
        isTrue,
      ); // thân tháp + đồng hồ
      expect(all[4].contains(const Offset(1200, 100)), isTrue); // lều hội chợ
      expect(all[3].contains(const Offset(620, 600)), isTrue); // khối hình học
      expect(all[3].contains(const Offset(700, 580)), isTrue);
      expect(all[3].contains(const Offset(820, 620)), isTrue);
      expect(all[5].contains(const Offset(192, 667)), isTrue); // thân nhà hồng
    });
  });
}
