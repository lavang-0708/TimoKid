/// Logic thuần của kéo thả đồ trong Phòng: vùng sàn/tường, kẹp vị trí,
/// mã hóa JSON, và bố cục mặc định không đè món vẽ sẵn trong nền sạch.
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/features/room/room_assets.dart';

/// Hộp nhìn thấy (alpha > 40) của từng ảnh 512x512, đo bằng PIL.
const Map<String, Rect> _visible512 = {
  'gau-bong': Rect.fromLTRB(125, 95, 389, 445),
  'den-sao': Rect.fromLTRB(96, 91, 419, 450),
  'binh-hoa': Rect.fromLTRB(156, 106, 361, 430),
  'coc-sao': Rect.fromLTRB(100, 83, 355, 434),
  'noi_be_ca': Rect.fromLTRB(110, 121, 404, 441),
  'noi_cay_cao': Rect.fromLTRB(124, 61, 390, 441),
  'noi_den_trang': Rect.fromLTRB(138, 141, 375, 441),
  'noi_ghe_luoi': Rect.fromLTRB(121, 212, 393, 441),
  'noi_ke_sach': Rect.fromLTRB(85, 81, 428, 441),
  'noi_leu': Rect.fromLTRB(82, 102, 432, 441),
  'noi_nha_pet': Rect.fromLTRB(98, 141, 416, 441),
  'noi_tranh': Rect.fromLTRB(116, 141, 397, 441),
};

/// Đồ vẽ sẵn trong `room_v3_clean.webp` (khung 1600x900), đo bằng mắt.
const Map<String, Rect> _painted = {
  'giường': Rect.fromLTRB(155, 380, 745, 725),
  'tủ đầu giường': Rect.fromLTRB(45, 590, 265, 782),
  'cuội': Rect.fromLTRB(270, 705, 395, 782),
  'mặt bàn + chân bàn': Rect.fromLTRB(1040, 495, 1370, 700),
  'tủ dưới bàn': Rect.fromLTRB(1180, 590, 1370, 780),
  'ghế': Rect.fromLTRB(965, 515, 1155, 755),
  'kệ lớn': Rect.fromLTRB(1130, 30, 1455, 390),
  'tủ áo': Rect.fromLTRB(1365, 65, 1600, 880),
  'chậu cây': Rect.fromLTRB(785, 540, 880, 685),
  'cửa sổ + rèm': Rect.fromLTRB(450, 55, 1075, 640),
  'kệ mây + tranh nhỏ': Rect.fromLTRB(55, 185, 320, 330),
};

Rect _visibleBox(RoomPlaceable p, Offset pos) {
  final v = _visible512[p.id]!;
  final k = p.size / 512;
  return Rect.fromLTRB(
    pos.dx + v.left * k,
    pos.dy + v.top * k,
    pos.dx + v.right * k,
    pos.dy + v.bottom * k,
  );
}

void main() {
  group('danh sách món kéo thả', () {
    test('4 món nhỏ vẽ rời + 8 món Cửa hàng, mã duy nhất', () {
      expect(roomPlaceables, hasLength(12));
      expect({for (final p in roomPlaceables) p.id}, hasLength(12));
      // Chậu cây vẽ sẵn trong nền: không kéo được.
      expect(roomPlaceables.any((p) => p.id == 'chau-cay'), isFalse);
      expect(
        roomPlaceables.where((p) => p.kind == RoomPlaceKind.surface),
        hasLength(4),
      );
      expect(roomPlaceables.where((p) => p.wall), hasLength(2));
      expect(
        roomPlaceables.where((p) => p.kind == RoomPlaceKind.floor),
        hasLength(6),
      );
    });

    test('ảnh theo biến thể: món Cửa hàng và món nhỏ đều đổi tiền tố', () {
      final leu = roomPlaceables.firstWhere((p) => p.id == 'noi_leu');
      expect(leu.assetFor('classic'), 'assets/images/furniture/noi_leu.webp');
      expect(leu.assetFor('tet'), 'assets/images/furniture/tet_leu.webp');
      final gau = roomPlaceables.firstWhere((p) => p.id == 'gau-bong');
      expect(gau.assetFor('classic'), gau.item.asset);
      expect(gau.assetFor('tet'), 'assets/images/furniture/tet_gau_bong.webp');
    });
  });

  group('vùng sàn / tường', () {
    test('roomFloorTopAt khớp đa giác sàn', () {
      expect(roomFloorTopAt(0), 795);
      expect(roomFloorTopAt(400), 645);
      expect(roomFloorTopAt(800), 645);
      expect(roomFloorTopAt(1200), 645);
      expect(roomFloorTopAt(1600), 795);
      expect(roomFloorTopAt(200), closeTo(720, 0.01));
    });

    test('chân bị kẹp vào sàn (cách chân tường, trên đáy khung)', () {
      expect(roomClampFloorFeet(const Offset(800, 2000)).dy, 895);
      expect(
        roomClampFloorFeet(const Offset(800, 0)).dy,
        645 + roomFloorFeetInset,
      );
      // Sát mép trái, chân tường dốc xuống: giới hạn trên thấp hơn.
      final left = roomClampFloorFeet(const Offset(-50, 0));
      expect(left.dx, roomPlaceMinX);
      expect(left.dy, roomFloorTopAt(roomPlaceMinX) + roomFloorFeetInset);
      expect(roomClampFloorFeet(const Offset(5000, 700)).dx, roomPlaceMaxX);
      // Điểm hợp lệ giữ nguyên, và luôn nằm trong đa giác sàn.
      expect(
        roomClampFloorFeet(const Offset(700, 800)),
        const Offset(700, 800),
      );
      for (final p in const [
        Offset(0, 0),
        Offset(1600, 0),
        Offset(1600, 900),
        Offset(30, 700),
        Offset(1590, 700),
      ]) {
        expect(roomPointInFloor(roomClampFloorFeet(p)), isTrue, reason: '$p');
      }
    });

    test('món tường nằm dưới trần, trên chân tường', () {
      final up = roomClampWallAnchor(const Offset(800, -500));
      expect(up.dy, roomWallRegion.top);
      final down = roomClampWallAnchor(const Offset(800, 5000));
      expect(down.dy, 645 - 4);
      // Mép trái: chân tường thấp hơn nên được phép thấp hơn.
      final edge = roomClampWallAnchor(const Offset(roomPlaceMinX, 5000));
      expect(edge.dy, roomFloorTopAt(roomPlaceMinX) - 4);
      // Chừa chiều cao món để đỉnh không chạm trần.
      final tall = roomClampWallAnchor(
        const Offset(800, 0),
        visibleHeight: 100,
      );
      expect(tall.dy, roomWallRegion.top + 100);
    });

    test('món nhỏ: đặt trên mặt phẳng hoặc sàn, không lơ lửng trên tường', () {
      final onBed = roomClampSurfaceAnchor(const Offset(400, 545));
      expect(onBed, const Offset(400, 545));
      // Giữa không trung gần giường: hút về mặt giường.
      final air = roomClampSurfaceAnchor(const Offset(400, 300));
      expect(roomBedSurface.contains(air), isTrue);
      // Dưới sàn: ở sàn.
      expect(roomClampSurfaceAnchor(const Offset(800, 800)).dy, 800);
    });

    test('roomClampPlaceable giữ neo trong vùng của từng loại', () {
      for (final p in roomPlaceables) {
        for (final tl in const [
          Offset(-900, -900),
          Offset(3000, -900),
          Offset(-900, 3000),
          Offset(3000, 3000),
          Offset(700, 400),
        ]) {
          final c = roomClampPlaceable(p, tl);
          final anchor = c + p.anchorOffset;
          switch (p.kind) {
            case RoomPlaceKind.floor:
              expect(roomPointInFloor(anchor), isTrue, reason: '${p.id} $tl');
              expect(anchor.dy, lessThanOrEqualTo(roomFloorFeetBottom));
            case RoomPlaceKind.wall:
              expect(
                anchor.dy,
                lessThanOrEqualTo(roomFloorTopAt(anchor.dx) - 4 + 0.001),
              );
              expect(anchor.dy, greaterThanOrEqualTo(roomWallRegion.top));
            case RoomPlaceKind.surface:
              final ok =
                  roomPointInFloor(anchor) ||
                  roomSurfaces.any((r) => r.inflate(0.001).contains(anchor));
              expect(ok, isTrue, reason: '${p.id} $tl');
          }
        }
      }
    });
  });

  group('lưu bố cục', () {
    test('một khóa chung; khóa cũ theo chủ đề chỉ để chuyển dữ liệu', () {
      expect(roomLayoutSettingsKey, 'room_layout');
      expect(roomLegacyLayoutSettingsKey('rong'), 'room_layout_rong');
    });

    test('mã hóa rồi giải mã giữ nguyên', () {
      const layout = {'noi_leu': Offset(10.5, 20), 'gau-bong': Offset(0, 99)};
      expect(decodeRoomLayout(encodeRoomLayout(layout)), layout);
    });

    test('JSON hỏng/thiếu: dùng mặc định, bỏ mục sai', () {
      expect(decodeRoomLayout(null), isEmpty);
      expect(decodeRoomLayout(''), isEmpty);
      expect(decodeRoomLayout('không phải json'), isEmpty);
      expect(decodeRoomLayout('[1,2]'), isEmpty);
      expect(decodeRoomLayout('{"a":{"x":1,"y":2},"b":{"x":"1"},"c":5}'), {
        'a': const Offset(1, 2),
      });
    });
  });

  group('bố cục mặc định', () {
    test('mọi món mặc định nằm đúng vùng (kẹp không đổi vị trí)', () {
      for (final p in roomPlaceables) {
        final c = roomClampPlaceable(p, p.defaultPos);
        expect((c - p.defaultPos).distance, lessThan(0.001), reason: p.id);
      }
    });

    test('ảnh nằm trong khung 1600x900', () {
      for (final p in roomPlaceables) {
        final b = _visibleBox(p, p.defaultPos);
        expect(b.left, greaterThanOrEqualTo(0), reason: p.id);
        expect(b.top, greaterThanOrEqualTo(0), reason: p.id);
        expect(b.right, lessThanOrEqualTo(roomFrameWidth), reason: p.id);
        expect(b.bottom, lessThanOrEqualTo(roomFrameHeight), reason: p.id);
      }
    });

    test('món không đè nhau và không đè đồ vẽ sẵn trong nền', () {
      for (final p in roomPlaceables) {
        final b = _visibleBox(p, p.defaultPos);
        // Món nhỏ đặt trên giường/tủ/bàn nên chỉ kiểm với món khác.
        if (p.kind != RoomPlaceKind.surface) {
          for (final e in _painted.entries) {
            expect(b.overlaps(e.value), isFalse, reason: '${p.id} đè ${e.key}');
          }
        }
        for (final q in roomPlaceables) {
          if (q.id.compareTo(p.id) <= 0) continue;
          expect(
            b.overlaps(_visibleBox(q, q.defaultPos)),
            isFalse,
            reason: '${p.id} đè ${q.id}',
          );
        }
      }
    });
  });
}
