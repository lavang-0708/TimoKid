/// Test hình học thuần cho màn Phòng v3b (D): mọi điểm neo/đa giác/
/// dấu chân trong `docs/D_IMAGES.md` đã kiểm chứng bằng code trên
/// ảnh `room_v3.webp` thật (xem mục 8 trong `docs/D_IMAGES.md` —
/// bài học từ PR #31: không tin vùng khai báo tay, kiểm bằng code).
///
/// Test này chạy KHÔNG cần widget: chỉ kiểm các hằng số hình học
/// trong `room_assets.dart` (điểm neo trên mặt phẳng đúng, rect
/// hiển thị phủ khít món vẽ sẵn trong nền, chân nhân vật/pet trên
/// sàn, dấu chân đồ chạm sàn). Mọi tọa độ theo khung nền 1600x900.
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/features/room/room_assets.dart';

/// Điểm có nằm trong [rect] không, tính cả mép (điểm neo ở mép
/// trước của mặt phẳng vẫn tính là "trên mặt phẳng").
bool _onRectInclusive(Rect rect, Offset p) =>
    p.dx >= rect.left &&
    p.dx <= rect.right &&
    p.dy >= rect.top &&
    p.dy <= rect.bottom;

void main() {
  test('5 món v3b, khóa widget giữ như v2', () {
    expect(roomFurniture.length, 5);
    expect(roomFurniture.map((f) => f.key), [
      'room-furniture-gau-bong',
      'room-furniture-den-sao',
      'room-furniture-chau-cay',
      'room-furniture-binh-hoa',
      'room-furniture-coc-sao',
    ]);
    for (final item in roomFurniture) {
      expect(item.asset, endsWith('_v3.webp'));
      expect(item.asset, startsWith('assets/images/furniture/'));
    }
    expect(roomBackgroundAsset, 'assets/images/backgrounds/room_v3.webp');
  });

  test('điểm neo gấu/đèn/bình/cốc trên mặt phẳng đúng', () {
    final byKey = {for (final f in roomFurniture) f.key: f};
    // Gấu ngồi trên mặt giường (neo y = 550).
    expect(
      _onRectInclusive(
        roomBedSurface,
        byKey['room-furniture-gau-bong']!.anchor,
      ),
      isTrue,
    );
    // Đèn đặt trên mặt tủ đầu giường (neo y = 580).
    expect(
      _onRectInclusive(
        roomNightstandSurface,
        byKey['room-furniture-den-sao']!.anchor,
      ),
      isTrue,
    );
    // Bình + cốc đặt trên mặt bàn học (neo y = 510/515).
    expect(
      _onRectInclusive(
        roomDeskSurface,
        byKey['room-furniture-binh-hoa']!.anchor,
      ),
      isTrue,
    );
    expect(
      _onRectInclusive(
        roomDeskSurface,
        byKey['room-furniture-coc-sao']!.anchor,
      ),
      isTrue,
    );
  });

  test('điểm neo chậu cây + chân nhân vật/pet trên sàn', () {
    final byKey = {for (final f in roomFurniture) f.key: f};
    // Chậu cây đặt trên sàn (neo y = 686), không phải trên bàn.
    expect(roomPointInFloor(byKey['room-furniture-chau-cay']!.anchor), isTrue);
    // Nhân vật + pet đứng trên sàn, trên thảm, trước giường.
    expect(roomPointInFloor(roomCharacterFeet), isTrue);
    expect(roomPointInFloor(roomPetFeet), isTrue);
  });

  test('vùng chạm = hộp món vẽ sẵn trong nền (đo bằng PIL 22/11)', () {
    // Nền room_v3.webp đã VẼ SẴN 5 món nên app không vẽ PNG rời đè
    // lên (đè → hình đôi) mà đặt vùng chạm vô hình đúng hộp món đo
    // trên ảnh thật. Rect đo bằng PIL (khung 1600x900).
    const measured = <String, Rect>{
      'room-furniture-gau-bong': Rect.fromLTRB(340, 440, 456, 548),
      'room-furniture-den-sao': Rect.fromLTRB(92, 486, 210, 604),
      'room-furniture-chau-cay': Rect.fromLTRB(783, 538, 902, 684),
      'room-furniture-binh-hoa': Rect.fromLTRB(1230, 396, 1357, 545),
      'room-furniture-coc-sao': Rect.fromLTRB(1076, 441, 1144, 523),
    };
    const frame = Rect.fromLTWH(0, 0, roomFrameWidth, roomFrameHeight);
    for (final item in roomFurniture) {
      expect(item.bakedRect, measured[item.key], reason: item.key);
      // Nằm trọn trong khung, đủ lớn để bé chạm (>= 60 px khung).
      expect(frame.contains(item.bakedRect.topLeft), isTrue);
      expect(frame.contains(item.bakedRect.bottomRight), isTrue);
      expect(item.bakedRect.width, greaterThanOrEqualTo(60));
      expect(item.bakedRect.height, greaterThanOrEqualTo(80));
      // Điểm neo bóng đổ (dùng khi có nền sạch) nằm giữa món theo x.
      expect(item.bakedRect.left <= item.anchor.dx, isTrue);
      expect(item.anchor.dx <= item.bakedRect.right, isTrue);
    }
    // Lô 8C: đã có nền sạch; chỉ chậu cây còn vẽ trong nền sạch.
    expect(roomCleanBackgroundReady, isTrue);
    expect(roomFurniture.where((f) => f.inCleanBackground).map((f) => f.key), [
      'room-furniture-chau-cay',
    ]);
    expect(
      roomCleanBackgroundAsset,
      'assets/images/backgrounds/room_v3_clean.webp',
    );
  });

  test('dấu chân đồ chạm sàn (cho PR (G))', () {
    // Mỗi dấu chân phải có ít nhất một góc hoặc tâm nằm trong đa
    // giác sàn — phần còn lại có thể chạm tường (giường/tủ sát
    // tường nên dấu chân vươn tới mép tường, ngoài đa giác sàn
    // là vùng sàn khuất sau đồ).
    for (final entry in roomObstacleFootprints.entries) {
      final r = entry.value;
      final corners = [
        r.topLeft,
        r.topRight,
        r.bottomLeft,
        r.bottomRight,
        r.center,
      ];
      expect(
        corners.any(roomPointInFloor),
        isTrue,
        reason: 'dấu chân ${entry.key} $r không chạm sàn',
      );
    }
  });

  test('ghế: mặt ghế trong rect ghế, chân ghế trên sàn', () {
    expect(_onRectInclusive(roomChairRect, roomChairSeatCenter), isTrue);
    expect(_onRectInclusive(roomChairRect, roomChairSeat.center), isTrue);
    expect(roomPointInFloor(roomChairRect.bottomLeft), isTrue);
    expect(roomPointInFloor(roomChairRect.bottomRight), isTrue);
  });

  test('hộp nhân vật/pet: chân đúng vị trí trong hộp', () {
    // Chân nhân vật ở giữa hộp theo x, ở 91,1% chiều cao hộp
    // (đường đất y = 1400/1536 trong khung nhân vật 1024x1536).
    expect(roomCharacterFeet.dx, roomCharacterBox.center.dx);
    expect(
      roomCharacterFeet.dy,
      closeTo(roomCharacterBox.top + roomCharacterBox.height * 1400 / 1536, 2),
    );
    // Chân pet ở giữa hộp theo x, ở 86% chiều cao hộp
    // (đường đất y = 440/512 trong khung pet 512x512).
    expect(roomPetFeet.dx, roomPetBox.center.dx);
    expect(
      roomPetFeet.dy,
      closeTo(roomPetBox.top + roomPetBox.height * 440 / 512, 2),
    );
  });

  test('roomPointInFloor: trong/ngoài đa giác sàn', () {
    expect(roomPointInFloor(const Offset(800, 800)), isTrue);
    expect(roomPointInFloor(const Offset(800, 700)), isTrue);
    expect(roomPointInFloor(const Offset(200, 700)), isFalse);
    expect(roomPointInFloor(const Offset(1500, 700)), isFalse);
    expect(roomPointInFloor(const Offset(800, 100)), isFalse);
    expect(roomPointInFloor(const Offset(800, 950)), isFalse);
  });
}
