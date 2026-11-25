/// Biến thể của một phòng duy nhất: quyền sở hữu (bộ / món lẻ / quà tặng
/// nền), "Thay cả bộ" và lưu trữ + chuyển dữ liệu từ bản cũ.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/features/room/room_assets.dart';
import 'package:timokid/features/room/room_themes.dart';
import 'package:timokid/features/room/room_variants.dart';

void main() {
  const ready = {'tet': true, 'ngan_ha': true, 'rong': true};

  /// Món có biến thể ở chủ đề: 7 món lớn/vừa; Rồng thêm 8 món cửa hàng.
  List<RoomPlaceable> variantsIn(String theme) => [
    for (final p in roomPlaceables)
      if (p.hasVariant(theme)) p,
  ];

  Set<String> allItems(String theme) => {
    for (final p in variantsIn(theme)) roomThemeVariantItemId(theme, p.id),
  };

  group('sở hữu', () {
    test('chủ đề chưa có hình: không có gì dù đã mua', () {
      final own = RoomOwnership({roomThemeItemId('tet'), ...allItems('tet')});
      expect(own.hasBackground('tet'), isFalse);
      expect(own.hasItemVariant('tet', 'gau-bong'), isFalse);
      expect(own.variantsOf('gau-bong'), [roomThemeClassic]);
      expect(own.hasAnyTheme, isFalse);
    });

    test('có bộ => có nền và MỌI món của chủ đề đó (không chủ đề khác)', () {
      final own = RoomOwnership({roomThemeItemId('tet')}, ready: ready);
      expect(own.hasBackground('tet'), isTrue);
      for (final p in variantsIn('tet')) {
        expect(own.hasItemVariant('tet', p.id), isTrue, reason: p.id);
        expect(own.hasItemVariant('ngan_ha', p.id), isFalse, reason: p.id);
      }
      // Món nhỏ không có biến thể: không "có" dù có bộ.
      expect(own.hasItemVariant('tet', 'gau-bong'), isFalse);
      expect(own.setComplete('tet'), isTrue);
      expect(own.setComplete('ngan_ha'), isFalse);
      expect(own.backgroundThemes.map((t) => t.id), ['tet']);
    });

    test('mua lẻ vài món: có biến thể món đó, chưa có nền', () {
      final own = RoomOwnership({
        roomThemeVariantItemId('tet', 'noi_giuong'),
      }, ready: ready);
      expect(own.hasItemVariant('tet', 'noi_giuong'), isTrue);
      expect(own.hasItemVariant('tet', 'noi_ghe'), isFalse);
      expect(own.hasBackground('tet'), isFalse);
      expect(own.setComplete('tet'), isFalse);
      expect(own.variantsOf('noi_giuong'), [roomThemeClassic, 'tet']);
      expect(own.variantsOf('noi_ghe'), [roomThemeClassic]);
      expect(own.hasAnyTheme, isTrue);
    });

    test('thiếu đúng một món lẻ: chưa tặng nền; đủ món: tặng nền', () {
      final items = allItems('ngan_ha');
      final missing = items.first;
      final almost = RoomOwnership({...items}..remove(missing), ready: ready);
      expect(almost.hasBackground('ngan_ha'), isFalse);
      final full = RoomOwnership(items, ready: ready);
      expect(full.hasBackground('ngan_ha'), isTrue);
      // Đủ món lẻ => bộ coi như đã có (nền + món).
      expect(full.setComplete('ngan_ha'), isTrue);
      // Quà tặng chỉ theo chủ đề đó.
      expect(full.hasBackground('tet'), isFalse);
    });

    test('món lẻ chủ đề này không mở món chủ đề khác', () {
      final own = RoomOwnership({
        roomThemeVariantItemId('tet', 'noi_giuong'),
      }, ready: ready);
      expect(own.hasItemVariant('ngan_ha', 'noi_giuong'), isFalse);
    });
  });

  group('Thay cả bộ (roomApplySet)', () {
    test('món có biến thể đổi sang bộ, món chưa có giữ nguyên', () {
      final partial = RoomOwnership({
        roomThemeVariantItemId('tet', 'noi_giuong'),
      }, ready: ready);
      final out = roomApplySet(partial, {
        'noi_ghe': 'ngan_ha',
        'noi_leu': 'tet',
      }, 'tet');
      expect(out, {
        'noi_giuong': 'tet',
        'noi_ghe': 'ngan_ha',
        'noi_leu': 'tet',
      });
    });

    test('có bộ: mọi món đổi sang bộ; về gốc: rỗng', () {
      final own = RoomOwnership({roomThemeItemId('rong')}, ready: ready);
      final out = roomApplySet(own, {'noi_tranh': 'tet'}, 'rong');
      expect(out.length, variantsIn('rong').length); // 7 lớn/vừa + 8 cửa hàng
      expect(out.values.toSet(), {'rong'});
      expect(roomApplySet(own, out, roomThemeClassic), isEmpty);
    });
  });

  group('JSON biến thể', () {
    test('mã hóa bỏ classic; giải mã bỏ mục sai', () {
      expect(encodeRoomVariants({'a': 'tet', 'b': 'classic'}), '{"a":"tet"}');
      expect(decodeRoomVariants('{"a":"tet","b":3,"c":""}'), {'a': 'tet'});
      expect(decodeRoomVariants('hỏng'), isEmpty);
      expect(decodeRoomVariants(null), isEmpty);
      expect(decodeRoomVariants('[1]'), isEmpty);
    });
  });

  group('lưu trữ + chuyển dữ liệu', () {
    late AppDatabase db;
    late String childId;
    late RoomLookStore store;

    setUp(() async {
      db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      childId = await db.ensureSeeded();
      store = RoomLookStore(db);
    });

    Future<void> put(String key, String value) =>
        db.settingsDao.setValue(childId: childId, key: key, value: value);
    Future<String?> get(String key) =>
        db.settingsDao.getValue(childId: childId, key: key);

    test('máy mới: mặc định gốc, chưa ghi gì', () async {
      final look = await store.load(childId);
      expect(look.background, roomThemeClassic);
      expect(look.variants, isEmpty);
      expect(look.layout, isEmpty);
      expect(await get(roomBackgroundSettingsKey), isNull);
      expect(await get(roomLayoutSettingsKey), isNull);
    });

    test('ghi rồi đọc lại đúng nền, biến thể, bố cục', () async {
      await store.saveBackground(childId, 'rong');
      await store.saveVariants(childId, {'noi_leu': 'rong', 'a': 'classic'});
      await store.saveLayout(childId, {'noi_leu': const Offset(1, 2)});
      final look = await store.load(childId);
      expect(look.background, 'rong');
      expect(look.variants, {'noi_leu': 'rong'});
      expect(look.variantOf('noi_leu'), 'rong');
      expect(look.variantOf('khac'), roomThemeClassic);
      expect(look.layout, {'noi_leu': const Offset(1, 2)});
    });

    test('chuyển từ bản cũ: room_theme + room_layout_<chủ đề>', () async {
      await put(roomThemeSettingsKey, 'rong');
      await put(
        'room_layout_rong',
        encodeRoomLayout({'a': const Offset(5, 6)}),
      );
      await put(
        'room_layout_classic',
        encodeRoomLayout({'a': const Offset(9, 9)}),
      );
      final look = await store.load(childId);
      expect(look.background, 'rong');
      expect(look.layout, {'a': const Offset(5, 6)});
      // 8 món Cửa hàng đang vẽ bản Rồng như bản cũ; món nhỏ (không có biến
      // thể) và 7 món lớn vẫn gốc.
      final shopIds = {
        for (final p in roomPlaceables)
          if (p.shopId != null && p.hasVariant('rong')) p.id,
      };
      expect(shopIds, hasLength(8));
      expect(look.variants.keys.toSet(), shopIds);
      expect(look.variants.values.toSet(), {'rong'});
      // Đã ghi khóa mới, khóa cũ để nguyên.
      expect(await get(roomBackgroundSettingsKey), 'rong');
      expect(await get(roomLayoutSettingsKey), isNotNull);
      expect(await get(roomThemeSettingsKey), 'rong');
      expect(await get('room_layout_rong'), isNotNull);
    });

    test(
      'chuyển từ bản cũ: chủ đề chưa có bố cục riêng -> lấy của phòng gốc',
      () async {
        await put(roomThemeSettingsKey, 'rong');
        await put(
          'room_layout_classic',
          encodeRoomLayout({'a': const Offset(9, 9)}),
        );
        final look = await store.load(childId);
        expect(look.background, 'rong');
        expect(look.layout, {'a': const Offset(9, 9)});
      },
    );

    test('chuyển từ bản cũ: chỉ có room_layout_classic', () async {
      await put(
        'room_layout_classic',
        encodeRoomLayout({'a': const Offset(3, 4)}),
      );
      final look = await store.load(childId);
      expect(look.background, roomThemeClassic);
      expect(look.variants, isEmpty);
      expect(look.layout, {'a': const Offset(3, 4)});
    });

    test('khóa mới đã có thì không bị khóa cũ đè', () async {
      await put(roomThemeSettingsKey, 'tet');
      await put('room_layout_tet', encodeRoomLayout({'a': const Offset(5, 6)}));
      await put(roomBackgroundSettingsKey, 'classic');
      await put(roomVariantsSettingsKey, '{}');
      await put(
        roomLayoutSettingsKey,
        encodeRoomLayout({'a': const Offset(1, 1)}),
      );
      final look = await store.load(childId);
      expect(look.background, 'classic');
      expect(look.variants, isEmpty);
      expect(look.layout, {'a': const Offset(1, 1)});
    });

    test('Xếp lại như cũ: bố cục rỗng, không chuyển lại từ khóa cũ', () async {
      await put(
        'room_layout_classic',
        encodeRoomLayout({'a': const Offset(3, 4)}),
      );
      expect((await store.load(childId)).layout, isNotEmpty);
      await store.resetLayout(childId);
      expect((await store.load(childId)).layout, isEmpty);
    });
  });
}
