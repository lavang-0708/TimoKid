/// Logic đi lại trong Phòng (G) và pet lớn (F): kiểm bằng tọa độ khung
/// 1600x900 đã đo trên nền thật (`docs/ASSETS.md` mục "Phòng v3b").
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/features/room/pet_growth.dart';
import 'package:timokid/features/room/room_assets.dart';
import 'package:timokid/features/room/room_walk.dart';

/// Dấu chân đồ rời ở bố cục mặc định phòng gốc v4 (phòng không còn đồ vẽ
/// sẵn nên [roomObstacleFootprints] rỗng): giường, tủ, bàn, ghế, thảm
/// phẳng (không chặn)...
final List<Rect> _extra = [
  for (final p in roomPlaceables) ?p.footprintAt(p.defaultPos),
];

void main() {
  group('vùng đi được', () {
    test('chỗ đứng mặc định của nhân vật và pet đứng được', () {
      expect(roomWalkable(roomCharacterFeet), isTrue);
      expect(roomWalkable(roomPetFeet), isTrue);
      expect(roomWalkable(roomCharacterFeet, extra: _extra), isTrue);
      expect(roomWalkable(roomPetFeet, extra: _extra), isTrue);
    });

    test('phòng v4 không có đồ vẽ sẵn trong nền: không dấu chân cố định', () {
      expect(roomObstacleFootprints, isEmpty);
    });

    test('không đứng lên đồ đạc, tường, hay ngoài khung', () {
      for (final r in _extra) {
        expect(roomWalkable(r.center, extra: _extra), isFalse, reason: '$r');
      }
      // Thảm phẳng không chặn: đứng được giữa thảm.
      expect(roomWalkable(const Offset(705, 840), extra: _extra), isTrue);
      expect(roomWalkable(const Offset(800, 400)), isFalse); // tường
      expect(roomWalkable(const Offset(800, 899)), isFalse); // mép dưới
      expect(roomWalkable(const Offset(5, 850)), isFalse); // mép trái
    });

    test('chạm vào tường/giường thì đi tới sàn ngay phía trước', () {
      final onWall = roomWalkTarget(const Offset(820, 300), extra: _extra);
      expect(roomWalkable(onWall, extra: _extra), isTrue);
      expect((onWall.dx - 820).abs(), lessThan(1));
      final onBed = roomWalkTarget(const Offset(450, 600), extra: _extra);
      expect(roomWalkable(onBed, extra: _extra), isTrue);
      expect(onBed.dy, greaterThan(700)); // trước mặt giường
    });

    test('mọi điểm đích đều đứng được (lưới chạm khắp khung)', () {
      for (var x = 0.0; x <= 1600; x += 80) {
        for (var y = 0.0; y <= 900; y += 60) {
          final t = roomWalkTarget(Offset(x, y), extra: _extra);
          expect(
            roomWalkable(t, extra: _extra),
            isTrue,
            reason: '($x,$y) → $t',
          );
        }
      }
    });
  });

  group('đường đi', () {
    final tolerant = [for (final r in _extra) r.deflate(0.5)];
    bool pathClear(Offset from, List<Offset> path) {
      var a = from;
      for (final b in path) {
        for (var i = 1; i <= 50; i++) {
          // Sượt đúng góc dấu chân (chạm mép) vẫn chấp nhận: co 0,5 px.
          if (!roomWalkable(Offset.lerp(a, b, i / 50)!, extra: tolerant)) {
            return false;
          }
        }
        a = b;
      }
      return true;
    }

    test('đi vòng trước bàn học thay vì xuyên qua', () {
      const from = Offset(900, 700);
      const to = Offset(1250, 830);
      final path = roomWalkPath(from, to, extra: _extra);
      expect(path.length, greaterThan(1)); // có vòng, không đi thẳng
      expect(path.last, to);
      expect(pathClear(from, path), isTrue);
    });

    test('mọi cặp điểm đứng được đều có đường không xuyên đồ', () {
      final spots = <Offset>[
        for (var x = 40.0; x <= 1560; x += 140)
          for (var y = 680.0; y <= 880; y += 50)
            if (roomWalkable(Offset(x, y), extra: _extra)) Offset(x, y),
      ];
      for (final a in spots) {
        for (final b in spots) {
          final path = roomWalkPath(a, b, extra: _extra);
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
    test('giai đoạn theo số câu đúng tích lũy (ngưỡng 80 / 250)', () {
      expect(petStageForXp(0), PetStage.newborn);
      expect(petStageForXp(79), PetStage.newborn);
      expect(petStageForXp(80), PetStage.teen);
      expect(petStageForXp(249), PetStage.teen);
      expect(petStageForXp(250), PetStage.adult);
      expect(petStageFor(xp: 999, hatched: false), PetStage.egg);
      expect(petXpToNextStage(10), 70);
      expect(petXpToNextStage(100), 150);
      expect(petXpToNextStage(250), isNull);
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

  group('hồ sơ tốc độ đi (góp ý v0.0.13: đi giật, nhanh)', () {
    test('quãng đi tăng dần, liền mạch, tới đích đúng lúc', () {
      for (final length in [40.0, 300.0, 900.0]) {
        final total = roomWalkDuration(length);
        var last = 0.0;
        for (var i = 0; i <= 200; i++) {
          final d = roomWalkDistanceAt(total * i / 200, length);
          expect(d, greaterThanOrEqualTo(last - 1e-9));
          // Không nhảy cóc: mỗi bước 1/200 không vượt 2 lần tốc độ đều.
          expect(d - last, lessThanOrEqualTo(2 * roomWalkSpeed * total / 200));
          last = d;
        }
        expect(last, closeTo(length, 1e-6));
      }
    });

    test('đi đều đúng tốc độ ở giữa quãng dài, chậm lúc đầu/cuối', () {
      const length = 900.0;
      final total = roomWalkDuration(length);
      const dt = 0.01;
      double v(double t) =>
          (roomWalkDistanceAt(t + dt, length) - roomWalkDistanceAt(t, length)) /
          dt;
      expect(v(total / 2), closeTo(roomWalkSpeed, 1));
      expect(v(0), lessThan(roomWalkSpeed * 0.1));
      expect(v(total - dt), lessThan(roomWalkSpeed * 0.1));
    });

    test('điểm trên đường gấp khúc theo quãng', () {
      const pts = [Offset(0, 0), Offset(100, 0), Offset(100, 50)];
      const cum = [0.0, 100.0, 150.0];
      expect(roomPointAlong(pts, cum, 50), (const Offset(50, 0), 0));
      expect(roomPointAlong(pts, cum, 125), (const Offset(100, 25), 1));
      expect(roomPointAlong(pts, cum, 999), (const Offset(100, 50), 1));
    });
  });
}
