/// Test hình học thuần cho màn Phòng v3b (D): mọi điểm neo/đa giác/
/// dấu chân trong `docs/D_IMAGES.md` đã kiểm chứng bằng code trên
/// ảnh `room_v3.png` thật (xem mục 8 trong `docs/D_IMAGES.md` —
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
      expect(item.asset, endsWith('_v3.png'));
      expect(item.asset, startsWith('assets/images/furniture/'));
    }
    expect(roomBackgroundAsset, 'assets/images/backgrounds/room_v3.png');
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

  test('rect hiển thị phủ khít rect món vẽ sẵn trong nền', () {
    // Content bbox của PNG riêng (khung 512, đo bằng code) +
    // rect món vẽ sẵn trong nền (docs/D_IMAGES.md mục 2). Lớp rời
    // phải phủ khít món trong nền để không lộ ra gây hình đôi;
    // dung sai 2 px vì rect trong nền đo có sai số, và đèn/cốc
    // thiếu ~1 px ở một mép (đèn mép phải, cốc mép đáy).
    const contentBbox512 = <String, Rect>{
      'room-furniture-gau-bong': Rect.fromLTRB(125, 95, 388, 444),
      'room-furniture-den-sao': Rect.fromLTRB(96, 91, 418, 449),
      'room-furniture-chau-cay': Rect.fromLTRB(99, 119, 373, 440),
      'room-furniture-binh-hoa': Rect.fromLTRB(156, 106, 360, 429),
      'room-furniture-coc-sao': Rect.fromLTRB(100, 83, 354, 433),
    };
    const bakedInBackground = <String, Rect>{
      'room-furniture-gau-bong': Rect.fromLTRB(355, 425, 475, 550),
      'room-furniture-den-sao': Rect.fromLTRB(90, 455, 210, 580),
      'room-furniture-chau-cay': Rect.fromLTRB(785, 530, 900, 670),
      'room-furniture-binh-hoa': Rect.fromLTRB(1250, 365, 1360, 510),
      'room-furniture-coc-sao': Rect.fromLTRB(1071, 432, 1127, 515),
    };
    for (final item in roomFurniture) {
      final content = contentBbox512[item.key]!;
      final display = Rect.fromLTRB(
        item.placeX + content.left / 512 * item.placeSize,
        item.placeY + content.top / 512 * item.placeSize,
        item.placeX + content.right / 512 * item.placeSize,
        item.placeY + content.bottom / 512 * item.placeSize,
      );
      final baked = bakedInBackground[item.key]!;
      expect(
        display.left <= baked.left + 2 &&
            display.top <= baked.top + 2 &&
            display.right >= baked.right - 2 &&
            display.bottom >= baked.bottom - 2,
        isTrue,
        reason:
            '${item.key}: rect hiển thị $display phải phủ khít '
            'món trong nền $baked (không hở, không hình đôi)',
      );
      // Điểm neo đáy là đáy món (giữa rect hiển thị theo x,
      // dung sai 3 px vì đế món hẹp hơn thân).
      expect(item.anchor.dx, closeTo(display.center.dx, 3));
      expect(item.anchor.dy, closeTo(display.bottom, 2));
    }
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
