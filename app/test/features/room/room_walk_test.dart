/// Logic đi lại trong Phòng (G) và pet lớn (F): kiểm bằng tọa độ khung
/// 1600x900 đã đo trên nền thật (`docs/ASSETS.md` mục "Phòng v3b").
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/features/room/pet_growth.dart';
import 'package:timokid/features/room/room_assets.dart';
import 'package:timokid/features/room/room_walk.dart';

void main() {
  group('vùng đi được', () {
    test('chỗ đứng mặc định của nhân vật và pet đứng được', () {
      expect(roomWalkable(roomCharacterFeet), isTrue);
      expect(roomWalkable(roomPetFeet), isTrue);
    });

    test('không đứng lên đồ đạc, tường, hay ngoài khung', () {
      for (final r in roomObstacleFootprints.values) {
        expect(roomWalkable(r.center), isFalse, reason: '$r');
      }
      expect(roomWalkable(const Offset(800, 400)), isFalse); // tường
      expect(roomWalkable(const Offset(800, 899)), isFalse); // mép dưới
      expect(roomWalkable(const Offset(5, 850)), isFalse); // mép trái
    });

    test('chạm vào tường/giường thì đi tới sàn ngay phía trước', () {
      final onWall = roomWalkTarget(const Offset(820, 300));
      expect(roomWalkable(onWall), isTrue);
      expect((onWall.dx - 820).abs(), lessThan(1));
      final onBed = roomWalkTarget(const Offset(450, 600));
      expect(roomWalkable(onBed), isTrue);
      expect(onBed.dy, greaterThan(700)); // trước mặt giường
    });

    test('mọi điểm đích đều đứng được (lưới chạm khắp khung)', () {
      for (var x = 0.0; x <= 1600; x += 80) {
        for (var y = 0.0; y <= 900; y += 60) {
          final t = roomWalkTarget(Offset(x, y));
          expect(roomWalkable(t), isTrue, reason: '($x,$y) → $t');
        }
      }
    });
  });

  group('đường đi', () {
    bool pathClear(Offset from, List<Offset> path) {
      var a = from;
      for (final b in path) {
        for (var i = 1; i <= 50; i++) {
          if (!roomWalkable(Offset.lerp(a, b, i / 50)!)) return false;
        }
        a = b;
      }
      return true;
    }

    test('đi vòng trước bàn học thay vì xuyên qua', () {
      const from = Offset(1000, 720);
      const to = Offset(1420, 840);
      final path = roomWalkPath(from, to);
      expect(path.last, to);
      expect(pathClear(from, path), isTrue);
    });

    test('mọi cặp điểm đứng được đều có đường không xuyên đồ', () {
      final spots = <Offset>[
        for (var x = 40.0; x <= 1560; x += 140)
          for (var y = 680.0; y <= 880; y += 50)
            if (roomWalkable(Offset(x, y))) Offset(x, y),
      ];
      for (final a in spots) {
        for (final b in spots) {
          final path = roomWalkPath(a, b);
          expect(path.last, b);
          expect(pathClear(a, path), isTrue, reason: '$a → $b: $path');
        }
      }
    });

    test('pet đứng sau lưng bé, đứng được', () {
      final spot = roomPetFollowSpot(
        const Offset(800, 820),
        kidFacingLeft: false,
      );
      expect(roomWalkable(spot), isTrue);
      expect(spot.dx, lessThan(800));
    });

    test('xa thì nhỏ, gần thì to; chỗ đứng mặc định đúng cỡ gốc', () {
      expect(roomDepthScale(810), 1.0);
      expect(roomDepthScale(700), lessThan(1.0));
      expect(roomDepthScale(870), greaterThan(1.0));
    });
  });

  group('pet lớn', () {
    test('giai đoạn theo số ngày xong đề', () {
      expect(petStageForDays(0), PetStage.newborn);
      expect(petStageForDays(2), PetStage.newborn);
      expect(petStageForDays(3), PetStage.teen);
      expect(petStageForDays(7), PetStage.teen);
      expect(petStageForDays(8), PetStage.adult);
      expect(petDaysToNextStage(1), 2);
      expect(petDaysToNextStage(5), 3);
      expect(petDaysToNextStage(9), isNull);
    });

    test('cỡ pet tăng dần, nhỡ = 58% chiều cao bé (209 px)', () {
      final sizes = PetStage.values.map(petBoxSize).toList();
      for (var i = 1; i < sizes.length; i++) {
        expect(sizes[i], greaterThan(sizes[i - 1]));
      }
      // Thân pet cao 400/512 hộp.
      expect(petBoxSize(PetStage.teen) * 400 / 512, closeTo(208.8, 0.1));
    });
  });
}
