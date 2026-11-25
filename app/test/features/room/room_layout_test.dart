/// Logic thuần của kéo thả đồ trong Phòng: vùng sàn/tường, kẹp vị trí,
/// mã hóa JSON, và bố cục mặc định không đè món vẽ sẵn trong nền sạch.
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/features/room/room_assets.dart';
import 'package:timokid/features/room/room_themes.dart';

/// Hộp nhìn thấy (alpha > 40) của từng ảnh 512x512, đo bằng PIL.
const Map<String, Rect> _visible512 = {
  'gau-bong': Rect.fromLTRB(125, 95, 389, 445),
  'den-sao': Rect.fromLTRB(96, 91, 419, 450),
  'chau-cay': Rect.fromLTRB(99, 119, 374, 441),
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

/// Hộp nhìn thấy của món [p] ở biến thể [variant] khi lưu vị trí [pos]:
/// món lớn cắt theo hộp bao thì là cả hộp, ô 512x512 thì theo hộp đo.
Rect _visibleBox(
  RoomPlaceable p,
  Offset pos, {
  String variant = roomThemeClassic,
}) {
  final art = p.artFor(variant);
  final box = p.boxAt(variant, pos);
  if (art.cropped) return box;
  final v = _visible512[p.id]!;
  final k = art.width / 512;
  return Rect.fromLTRB(
    box.left + v.left * k,
    box.top + v.top * k,
    box.left + v.right * k,
    box.top + v.bottom * k,
  );
}

RoomPlaceable _p(String id) => roomPlaceables.firstWhere((p) => p.id == id);

/// Hai hình chữ nhật có phần chung có diện tích dương không.
bool _overlap(Rect a, Rect b) => a.overlaps(b);

void main() {
  group('danh sách món kéo thả', () {
    test('7 món lớn + 5 món nhỏ + 8 món Cửa hàng, mã duy nhất', () {
      expect(roomV4Ready, isTrue);
      expect(roomPlaceables, hasLength(20));
      expect({for (final p in roomPlaceables) p.id}, hasLength(20));
      // Chậu cây nay là món kéo thả bình thường (đứng sàn).
      expect(_p('chau-cay').kind, RoomPlaceKind.floor);
      expect(_p('chau-cay').item.inCleanBackground, isFalse);
      expect(
        roomPlaceables.where((p) => p.kind == RoomPlaceKind.surface),
        hasLength(4),
      );
      // Kệ lớn, đèn mặt trăng, tranh: gắn tường.
      expect(roomPlaceables.where((p) => p.wall).map((p) => p.id).toSet(), {
        'noi_ke_lon',
        'noi_den_trang',
        'noi_tranh',
      });
      // Thảm: duy nhất món phẳng.
      expect(roomPlaceables.where((p) => p.flat).map((p) => p.id), [
        'noi_tham',
      ]);
    });

    test('7 món lớn: cỡ hộp, điểm neo và ảnh đúng doc lô 15', () {
      const expected = {
        // id: (rộng, cao, neo x, neo y)
        'noi_giuong': (500.0, 340.0, 455.0, 715.0),
        'noi_tu_dau_giuong': (194.0, 190.0, 138.0, 780.0),
        'noi_tu_ao': (320.0, 820.0, 1440.0, 885.0),
        'noi_ban_hoc': (320.0, 269.0, 1140.0, 775.0),
        'noi_ghe': (160.0, 240.0, 1000.0, 745.0),
        'noi_ke_lon': (270.0, 360.0, 1125.0, 390.0),
        'noi_tham': (590.0, 160.0, 705.0, 855.0),
      };
      for (final e in expected.entries) {
        final p = _p(e.key);
        final art = p.classicArt;
        expect(art.width, e.value.$1, reason: e.key);
        expect(art.height, e.value.$2, reason: e.key);
        expect(art.cropped, isTrue, reason: e.key);
        expect(p.defaultPos + p.anchorOffset, Offset(e.value.$3, e.value.$4));
        expect(p.item.asset, 'assets/images/furniture/${e.key}.webp');
      }
    });

    test(
      'ảnh theo biến thể: món Cửa hàng, món lớn đổi tiền tố; món nhỏ dùng lại',
      () {
        final leu = _p('noi_leu');
        expect(leu.assetFor('classic'), 'assets/images/furniture/noi_leu.webp');
        expect(leu.assetFor('rong'), 'assets/images/furniture/rong_leu.webp');
        // Tết/Ngân hà chưa có hình món cửa hàng: dùng ảnh gốc.
        expect(leu.hasVariant('tet'), isFalse);
        expect(leu.assetFor('tet'), leu.item.asset);
        final bed = _p('noi_giuong');
        expect(
          bed.assetFor('rong'),
          'assets/images/furniture/rong_giuong.webp',
        );
        expect(
          _p('noi_tu_dau_giuong').assetFor('rong'),
          'assets/images/furniture/rong_tu_dau_giuong.webp',
        );
        // 5 món nhỏ không có biến thể chủ đề: luôn ảnh gốc.
        final gau = _p('gau-bong');
        expect(gau.hasVariant('rong'), isFalse);
        expect(gau.assetFor('rong'), gau.item.asset);
        expect(bed.hasVariant('rong'), isTrue);
      },
    );

    test('biến thể Rồng: cỡ hộp đúng doc, kệ lớn đứng sàn', () {
      const expected = {
        'noi_giuong': (560.0, 380.0),
        'noi_tu_dau_giuong': (195.0, 199.0),
        'noi_tu_ao': (320.0, 820.0),
        'noi_ban_hoc': (320.0, 262.0),
        'noi_ghe': (160.0, 240.0),
        'noi_ke_lon': (240.0, 712.0),
        'noi_tham': (590.0, 160.0),
      };
      for (final e in expected.entries) {
        final art = _p(e.key).artFor('rong');
        expect(art.width, e.value.$1, reason: e.key);
        expect(art.height, e.value.$2, reason: e.key);
        // Điểm neo = đáy-giữa hộp.
        expect(art.anchor, Offset(art.width / 2, art.height), reason: e.key);
      }
      final shelf = _p('noi_ke_lon');
      expect(shelf.kindFor('classic'), RoomPlaceKind.wall);
      expect(shelf.kindFor('rong'), RoomPlaceKind.floor);
      // Biến thể chưa vẽ (Tết/Ngân hà): như phòng gốc.
      expect(shelf.kindFor('tet'), RoomPlaceKind.wall);
      expect(shelf.artFor('tet').width, 270);
    });

    test('đổi biến thể giữ điểm neo (món không nhảy chỗ)', () {
      final bed = _p('noi_giuong');
      const pos = Offset(200, 380);
      final classicBox = bed.boxAt('classic', pos);
      final dragonBox = bed.boxAt('rong', pos);
      expect(dragonBox.bottomCenter, classicBox.bottomCenter);
      expect(dragonBox.width, 560);
    });
  });

  group('vùng sàn / tường', () {
    test('roomFloorTopAt khớp đa giác sàn đo trên room_v4 + room_rong', () {
      // Giữa phòng: chân tường phòng Rồng y 660 (phòng gốc 598).
      expect(roomFloorTopAt(300), 660);
      expect(roomFloorTopAt(800), 660);
      expect(roomFloorTopAt(1070), 660);
      // Hai mép dốc cong xuống.
      expect(roomFloorTopAt(0), 838);
      expect(roomFloorTopAt(1600), 862);
      expect(roomFloorTopAt(100), 787);
      expect(roomFloorTopAt(1300), 775);
      // Nội suy tuyến tính giữa hai đỉnh.
      expect(roomFloorTopAt(75), closeTo((815 + 787) / 2, 0.01));
      expect(roomFloorTopAt(-10), 838);
      expect(roomFloorTopAt(2000), 862);
      // Điểm trên đường chân tường trong sàn, ngay trên nó thì không.
      expect(roomPointInFloor(const Offset(800, 661)), isTrue);
      expect(roomPointInFloor(const Offset(800, 640)), isFalse);
      expect(roomPointInFloor(const Offset(100, 800)), isTrue);
      expect(roomPointInFloor(const Offset(100, 770)), isFalse);
      expect(roomPointInFloor(const Offset(1500, 840)), isTrue);
      expect(roomPointInFloor(const Offset(1500, 815)), isFalse);
    });

    test('chân bị kẹp vào sàn (cách chân tường, trên đáy khung)', () {
      expect(roomClampFloorFeet(const Offset(800, 2000)).dy, 895);
      expect(
        roomClampFloorFeet(const Offset(800, 0)).dy,
        660 + roomFloorFeetInset,
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

    test('món cao/rộng: đỉnh không thò quá khung, hộp không ra mép', () {
      // Tủ áo cao 820: chân phải đủ thấp để đỉnh cách mép trên >= 20.
      final up = roomClampFloorFeet(
        const Offset(800, 0),
        visibleHeight: 820,
        halfWidth: 160,
      );
      expect(up.dy, roomPlaceTopMargin + 820);
      // Nửa bề rộng 160: x trong [160, 1440].
      expect(roomClampFloorFeet(const Offset(0, 880), halfWidth: 160).dx, 160);
      expect(
        roomClampFloorFeet(const Offset(1600, 880), halfWidth: 160).dx,
        1440,
      );
    });

    test('món tường nằm dưới trần, trên chân tường', () {
      final up = roomClampWallAnchor(const Offset(800, -500));
      expect(up.dy, roomWallRegion.top);
      final down = roomClampWallAnchor(const Offset(800, 5000));
      expect(down.dy, 660 - roomWallFloorGap);
      expect(down.dy, roomWallRegion.bottom);
      // Mép trái: chân tường thấp hơn nên được phép thấp hơn.
      final edge = roomClampWallAnchor(const Offset(roomPlaceMinX, 5000));
      expect(edge.dy, roomFloorTopAt(roomPlaceMinX) - roomWallFloorGap);
      // Chừa chiều cao món để đỉnh không chạm trần.
      final tall = roomClampWallAnchor(
        const Offset(800, 0),
        visibleHeight: 100,
      );
      expect(tall.dy, roomWallRegion.top + 100);
    });

    test('món nhỏ: đặt trên mặt phẳng hoặc sàn, không lơ lửng trên tường', () {
      final bed = roomDefaultSurfaces[0];
      final onBed = bed.center;
      expect(roomClampSurfaceAnchor(onBed), onBed);
      // Giữa không trung gần giường: hút về mặt giường.
      final air = roomClampSurfaceAnchor(Offset(onBed.dx, 300));
      expect(bed.inflate(0.001).contains(air), isTrue);
      // Dưới sàn: ở sàn.
      expect(roomClampSurfaceAnchor(const Offset(800, 800)).dy, 800);
    });

    test('roomClampPlaceable giữ neo trong vùng của từng loại', () {
      for (final p in roomPlaceables) {
        for (final variant in ['classic', 'rong']) {
          for (final tl in const [
            Offset(-900, -900),
            Offset(3000, -900),
            Offset(-900, 3000),
            Offset(3000, 3000),
            Offset(700, 400),
          ]) {
            final c = roomClampPlaceable(p, tl, variant: variant);
            final anchor = c + p.anchorOffset;
            final art = p.artFor(variant);
            switch (p.kindFor(variant)) {
              case RoomPlaceKind.floor:
                expect(roomPointInFloor(anchor), isTrue, reason: '${p.id} $tl');
                expect(anchor.dy, lessThanOrEqualTo(roomFloorFeetBottom));
                if (art.cropped) {
                  final box = p.boxAt(variant, c);
                  expect(box.left, greaterThanOrEqualTo(-0.001));
                  expect(box.right, lessThanOrEqualTo(roomFrameWidth + 0.001));
                  expect(
                    box.top,
                    greaterThanOrEqualTo(roomPlaceTopMargin - 0.001),
                  );
                }
              case RoomPlaceKind.wall:
                expect(
                  anchor.dy,
                  lessThanOrEqualTo(
                    roomFloorTopAt(anchor.dx) - roomWallFloorGap + 0.001,
                  ),
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
        for (final variant in ['classic', 'rong']) {
          final pos = p.defaultPosFor(variant);
          final c = roomClampPlaceable(p, pos, variant: variant);
          expect(
            (c - pos).distance,
            lessThan(0.001),
            reason: '${p.id} $variant',
          );
        }
      }
    });

    test('ảnh nằm trong khung 1600x900 (cả phòng gốc và phòng Rồng)', () {
      for (final p in roomPlaceables) {
        for (final variant in ['classic', 'rong']) {
          final b = _visibleBox(p, p.defaultPosFor(variant), variant: variant);
          expect(b.left, greaterThanOrEqualTo(0), reason: '${p.id} $variant');
          expect(b.top, greaterThanOrEqualTo(0), reason: '${p.id} $variant');
          expect(b.right, lessThanOrEqualTo(roomFrameWidth), reason: p.id);
          expect(b.bottom, lessThanOrEqualTo(roomFrameHeight), reason: p.id);
        }
      }
    });

    test('dấu chân trên sàn không đè nhau, nằm trong sàn', () {
      for (final variant in ['classic', 'rong']) {
        final feet = <String, Rect>{
          for (final p in roomPlaceables)
            p.id: ?p.footprintAt(p.defaultPosFor(variant), variant: variant),
        };
        // Thảm phẳng và món gắn tường không có dấu chân.
        expect(feet.containsKey('noi_tham'), isFalse);
        expect(feet.containsKey('noi_tranh'), isFalse);
        final ids = feet.keys.toList();
        for (var i = 0; i < ids.length; i++) {
          final f = feet[ids[i]]!;
          // Cạnh dưới (đáy món) nằm trong sàn.
          expect(roomPointInFloor(f.bottomCenter.translate(0, -1)), isTrue);
          for (var j = i + 1; j < ids.length; j++) {
            // Kệ lớn Rồng đứng sát tường sau, ngay sau bàn học: dấu chân hai
            // món chạm nhau (kệ vẽ trước, bàn che phần chân kệ).
            final shelfBehindDesk =
                variant == 'rong' &&
                {ids[i], ids[j]}.containsAll(['noi_ke_lon', 'noi_ban_hoc']);
            if (shelfBehindDesk) continue;
            expect(
              _overlap(f, feet[ids[j]]!),
              isFalse,
              reason: '$variant: ${ids[i]} đè ${ids[j]}',
            );
          }
        }
      }
    });

    test('lối đi trên thảm trống: chỗ bé và pet đứng không bị chặn', () {
      for (final variant in ['classic', 'rong']) {
        final extra = [
          for (final p in roomPlaceables)
            ?p.footprintAt(p.defaultPosFor(variant), variant: variant),
        ];
        for (final feet in [roomCharacterFeet, roomPetFeet]) {
          for (final f in extra) {
            expect(f.inflate(14).contains(feet), isFalse, reason: variant);
          }
        }
      }
      // Dải lối đi x 450–850, y 750–860 không có chân đồ nào.
      const aisle = Rect.fromLTRB(450, 750, 850, 860);
      for (final p in roomPlaceables) {
        final f = p.footprintAt(p.defaultPos);
        if (f != null) expect(_overlap(f, aisle), isFalse, reason: p.id);
      }
    });

    test('hộp nhìn thấy các món đứng cạnh nhau (cùng độ sâu) chỉ chạm nhẹ', () {
      // Cặp đè do thiết kế: món nhỏ đặt trên món lớn, ghế kê ở bàn, đèn
      // mặt trăng trên kệ treo.
      final stacked = <(String, String)>{
        ('gau-bong', 'noi_giuong'),
        ('den-sao', 'noi_tu_dau_giuong'),
        ('den-sao', 'noi_giuong'),
        ('binh-hoa', 'noi_ban_hoc'),
        ('noi_ghe', 'noi_ban_hoc'),
        ('noi_den_trang', 'noi_ke_lon'),
      };
      bool allowed(String a, String b) =>
          stacked.contains((a, b)) || stacked.contains((b, a));
      // Hai món đứng cạnh nhau cùng độ sâu (chân y cách < 40 px): phần
      // hộp chung không quá 25% hộp nhỏ hơn (hộp chữ nhật rộng hơn hình
      // thật; đã kiểm đè theo điểm ảnh khi dựng ảnh ghép xem trước).
      for (final a in roomPlaceables) {
        for (final b in roomPlaceables) {
          if (a.id.compareTo(b.id) >= 0) continue;
          if (a.flat || b.flat || a.wall || b.wall) continue;
          if (allowed(a.id, b.id)) continue;
          final fa = a.defaultPos + a.anchorOffset;
          final fb = b.defaultPos + b.anchorOffset;
          if ((fa.dy - fb.dy).abs() >= 40) continue;
          final ba = _visibleBox(a, a.defaultPos);
          final bb = _visibleBox(b, b.defaultPos);
          final common = ba.intersect(bb);
          if (common.width <= 0 || common.height <= 0) continue;
          final small = ba.width * ba.height < bb.width * bb.height ? ba : bb;
          expect(
            common.width * common.height / (small.width * small.height),
            lessThan(0.25),
            reason: '${a.id} đè ${b.id}',
          );
        }
      }
    });

    test('mặt phẳng mặc định chứa đúng chỗ món nhỏ', () {
      bool onSurface(String id) {
        final p = _p(id);
        final anchor = p.defaultPos + p.anchorOffset;
        return roomDefaultSurfaces.any((r) => r.inflate(2).contains(anchor));
      }

      expect(onSurface('gau-bong'), isTrue);
      expect(onSurface('den-sao'), isTrue);
      expect(onSurface('binh-hoa'), isTrue);
      expect(onSurface('coc-sao'), isTrue);
    });
  });

  group('mặt phẳng đi theo món chủ', () {
    Rect? boxOf(Map<String, Offset> layout, String variant, String id) {
      final p = roomPlaceableById(id);
      if (p == null) return null;
      return p.boxAt(variant, layout[id] ?? p.defaultPos);
    }

    test('dời giường / tủ đầu giường / bàn học thì mặt phẳng dời theo', () {
      final base = roomSurfacesFor((id) => boxOf(const {}, 'classic', id));
      expect(base, hasLength(4));
      for (var i = 0; i < 3; i++) {
        final host = const [
          'noi_giuong',
          'noi_tu_dau_giuong',
          'noi_ban_hoc',
        ][i];
        final p = _p(host);
        const delta = Offset(37, -12);
        final moved = roomSurfacesFor(
          (id) => boxOf({host: p.defaultPos + delta}, 'classic', id),
        );
        expect(moved[i], base[i].shift(delta), reason: host);
        // Các mặt khác đứng yên.
        for (var j = 0; j < 4; j++) {
          if (j != i) expect(moved[j], base[j], reason: '$host $j');
        }
      }
    });

    test(
      'đổi biến thể món chủ: mặt phẳng theo hộp mới, neo đáy giữ nguyên',
      () {
        final classic = roomSurfacesFor((id) => boxOf(const {}, 'classic', id));
        final dragon = roomSurfacesFor((id) => boxOf(const {}, 'rong', id));
        // Giường Rồng rộng 560 (gốc 500): mặt giường rộng hơn.
        expect(dragon[0].width, greaterThan(classic[0].width));
        expect(dragon[0].center.dx, closeTo(classic[0].center.dx, 0.001));
      },
    );

    test('món nhỏ bị kẹp vào mặt phẳng đã dời', () {
      final bed = _p('noi_giuong');
      const delta = Offset(100, 20);
      final surfaces = roomSurfacesFor(
        (id) => id == 'noi_giuong'
            ? bed.boxAt('classic', bed.defaultPos + delta)
            : boxOf(const {}, 'classic', id),
      );
      final bear = _p('gau-bong');
      // Đặt gấu ở chỗ cũ trên giường (chưa dời): vẫn ở mặt giường cũ nên
      // bị hút sang mặt giường mới.
      final c = roomClampPlaceable(bear, bear.defaultPos, surfaces: surfaces);
      final anchor = c + bear.anchorOffset;
      expect(surfaces[0].inflate(0.001).contains(anchor), isTrue);
    });

    test('kệ lớn đổi biến thể gốc -> Rồng: kẹp lại vị trí vào sàn', () {
      final shelf = _p('noi_ke_lon');
      // Vị trí lưu lúc treo tường (neo y 390) không hợp với sàn.
      final saved = shelf.defaultPos;
      expect(
        roomClampPlaceable(shelf, saved) - saved,
        Offset.zero,
        reason: 'treo tường: giữ nguyên',
      );
      final onFloor = roomClampPlaceable(shelf, saved, variant: 'rong');
      final feet = onFloor + shelf.anchorOffset;
      expect(roomPointInFloor(feet), isTrue);
      // Đỉnh kệ Rồng (cao 712) không thò quá mép trên.
      expect(shelf.boxAt('rong', onFloor).top, greaterThanOrEqualTo(19.999));
      // Ngược lại: kệ Rồng đứng sàn -> gốc treo tường: neo lên vùng tường.
      final floorPos = shelf.defaultPosFor('rong');
      final back = roomClampPlaceable(shelf, floorPos);
      expect(
        (back + shelf.anchorOffset).dy,
        lessThanOrEqualTo(roomFloorTopAt(1190) - roomWallFloorGap + 0.001),
      );
    });

    test('thảm: vị trí mặc định kẹp không đổi, luôn nằm trong khung', () {
      final rug = _p('noi_tham');
      for (final tl in const [Offset(-500, 0), Offset(5000, 5000)]) {
        final box = rug.boxAt('classic', roomClampPlaceable(rug, tl));
        expect(box.left, greaterThanOrEqualTo(-0.001));
        expect(box.right, lessThanOrEqualTo(roomFrameWidth + 0.001));
      }
    });
  });
}
