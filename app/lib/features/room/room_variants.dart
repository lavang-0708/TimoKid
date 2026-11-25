/// Biến thể của nền và từng món trong MỘT phòng (bộ phòng chủ đề): quyền
/// sở hữu (bộ / món lẻ / quà tặng nền) và lưu trữ (settings theo bé) kèm
/// chuyển dữ liệu từ bản cũ "mỗi chủ đề một phòng".
///
/// Quy tắc sở hữu (chỉ tính chủ đề ĐÃ có hình, cờ [roomThemeArtReady]):
/// - Có bộ `room_theme_<id>` => có nền + MỌI món của chủ đề đó.
/// - Có món lẻ `room_item_<id>_<món>` => có biến thể của món đó.
/// - Có đủ MỌI món lẻ của chủ đề => tặng luôn nền (không cần mua bộ).
/// - Bộ coi là đã có khi có bộ HOẶC đủ mọi món lẻ (nền + món đều có).
/// Tất cả suy ra từ kho đồ (`inventory`), không ghi thêm dòng nào.
library;

import 'dart:convert';
import 'dart:ui' show Offset;

import '../../core/database/app_database.dart';
import 'room_assets.dart';
import 'room_themes.dart';

/// Mã món lẻ (kho đồ / Cửa hàng) của biến thể [themeId] của món [placeableId].
String roomThemeVariantItemId(String themeId, String placeableId) =>
    'room_item_${themeId}_$placeableId';

/// Quyền sở hữu biến thể, tính từ mã món bé đang có ([inventory]).
class RoomOwnership {
  const RoomOwnership(
    this.inventory, {
    this.ready = roomThemeArtReady,
    this.placeables,
  });

  final Set<String> inventory;

  /// Cờ hình từng chủ đề (mặc định theo const; chỉ test đổi).
  final Map<String, bool> ready;

  /// Danh sách món tính (mặc định [roomPlaceables]).
  final List<RoomPlaceable>? placeables;

  List<RoomPlaceable> get _items => placeables ?? roomPlaceables;

  bool _ready(String themeId) => isRoomThemeReady(themeId, ready: ready);

  /// Đã mua đúng bộ [themeId] (dòng `room_theme_<id>` trong kho).
  bool ownsSet(String themeId) => inventory.contains(roomThemeItemId(themeId));

  /// Đã mua RIÊNG món lẻ biến thể [themeId] của [placeableId].
  bool boughtItem(String themeId, String placeableId) =>
      inventory.contains(roomThemeVariantItemId(themeId, placeableId));

  /// Món [placeableId] có hình biến thể [themeId] không (món Muse dùng lại
  /// nguyên bản ở chủ đề đó thì không; món lạ coi như có).
  bool _drawnIn(String themeId, String placeableId) {
    for (final p in _items) {
      if (p.id == placeableId) return p.hasVariant(themeId);
    }
    return true;
  }

  /// Có biến thể [themeId] của món [placeableId] (bộ hoặc mua lẻ).
  bool hasItemVariant(String themeId, String placeableId) =>
      _ready(themeId) &&
      _drawnIn(themeId, placeableId) &&
      (ownsSet(themeId) || boughtItem(themeId, placeableId));

  /// Có đủ biến thể [themeId] của MỌI món có hình ở chủ đề đó.
  bool hasAllItems(String themeId) =>
      _ready(themeId) &&
      _items
          .where((p) => p.hasVariant(themeId))
          .every((p) => hasItemVariant(themeId, p.id));

  /// Có nền [themeId]: mua bộ, hoặc quà tặng khi đủ mọi món lẻ.
  bool hasBackground(String themeId) =>
      _ready(themeId) && (ownsSet(themeId) || hasAllItems(themeId));

  /// Bộ [themeId] coi như đã có (nền + mọi món): hiện "Đã có", không mua bộ.
  bool setComplete(String themeId) =>
      hasBackground(themeId) && hasAllItems(themeId);

  /// Các chủ đề bé dùng được làm nền (theo thứ tự [roomThemes]).
  List<RoomTheme> get backgroundThemes => [
    for (final t in roomThemes)
      if (hasBackground(t.id)) t,
  ];

  /// Biến thể bé có của món [placeableId], gồm `classic` đứng đầu.
  List<String> variantsOf(String placeableId) => [
    roomThemeClassic,
    for (final t in roomThemes)
      if (hasItemVariant(t.id, placeableId)) t.id,
  ];

  /// Bé có biến thể chủ đề nào (nền hoặc món) không.
  bool get hasAnyTheme => roomThemes.any(
    (t) => hasBackground(t.id) || _items.any((p) => hasItemVariant(t.id, p.id)),
  );
}

/// "Thay cả bộ": biến thể từng món sau khi chọn bộ [themeId]. Món bé có
/// biến thể của bộ thì đổi sang bộ; món chưa có giữ biến thể hiện tại
/// ([current]). [roomThemeClassic] đưa mọi món về gốc.
Map<String, String> roomApplySet(
  RoomOwnership own,
  Map<String, String> current,
  String themeId,
) {
  if (themeId == roomThemeClassic) return const {};
  return {
    for (final p in own.placeables ?? roomPlaceables)
      if (own.hasItemVariant(themeId, p.id))
        p.id: themeId
      else if (current[p.id] != null && current[p.id] != roomThemeClassic)
        p.id: current[p.id]!,
  };
}

/// Diện mạo đã lưu của phòng: biến thể nền + từng món, và vị trí đồ.
class RoomLook {
  const RoomLook({
    this.background = roomThemeClassic,
    this.variants = const {},
    this.layout = const {},
  });

  /// Biến thể của nền (`classic` hoặc mã chủ đề).
  final String background;

  /// Mã món -> biến thể (chỉ ghi món KHÁC `classic`).
  final Map<String, String> variants;

  /// Mã món -> góc trên-trái (khung 1600x900).
  final Map<String, Offset> layout;

  String variantOf(String placeableId) =>
      variants[placeableId] ?? roomThemeClassic;
}

/// Mã hóa biến thể từng món thành JSON (bỏ món `classic`).
String encodeRoomVariants(Map<String, String> variants) => jsonEncode({
  for (final e in variants.entries)
    if (e.value != roomThemeClassic) e.key: e.value,
});

/// Giải mã JSON biến thể; hỏng thì bỏ qua (tất cả về gốc).
Map<String, String> decodeRoomVariants(String? json) {
  if (json == null || json.isEmpty) return const {};
  try {
    final raw = jsonDecode(json);
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.key is String && e.value is String && e.value != '')
          e.key as String: e.value as String,
    };
  } catch (_) {
    return const {};
  }
}

/// Đọc/ghi diện mạo phòng của một bé.
class RoomLookStore {
  RoomLookStore(this.db);

  final AppDatabase db;

  Future<String?> _get(String childId, String key) =>
      db.settingsDao.getValue(childId: childId, key: key);

  Future<void> _set(String childId, String key, String value) =>
      db.settingsDao.setValue(childId: childId, key: key, value: value);

  /// Đọc diện mạo; thiếu khóa mới thì chuyển từ khóa cũ (ghi luôn khóa mới):
  /// - `room_background` <- `room_theme` (mặc định `classic`);
  /// - `room_variants` <- nếu phòng cũ là chủ đề T thì MỌI món Cửa hàng
  ///   đang vẽ bản T (đúng như bản cũ), còn lại gốc;
  /// - `room_layout` <- `room_layout_<room_theme cũ>`, không có thì
  ///   `room_layout_classic`.
  /// Khóa cũ để nguyên (không xóa). Chưa kiểm tra bé có sở hữu hay không:
  /// nơi dùng tự lọc bằng [RoomOwnership].
  Future<RoomLook> load(String childId) async {
    final legacyTheme = await _get(childId, roomThemeSettingsKey);

    var background = await _get(childId, roomBackgroundSettingsKey);
    if (background == null) {
      background = legacyTheme ?? roomThemeClassic;
      if (legacyTheme != null) {
        await _set(childId, roomBackgroundSettingsKey, background);
      }
    }

    final variantsJson = await _get(childId, roomVariantsSettingsKey);
    Map<String, String> variants;
    if (variantsJson == null) {
      variants = {
        if (legacyTheme != null && legacyTheme != roomThemeClassic)
          for (final p in roomPlaceables)
            if (p.shopId != null && p.hasVariant(legacyTheme))
              p.id: legacyTheme,
      };
      if (variants.isNotEmpty) {
        await _set(
          childId,
          roomVariantsSettingsKey,
          encodeRoomVariants(variants),
        );
      }
    } else {
      variants = decodeRoomVariants(variantsJson);
    }

    var layoutJson = await _get(childId, roomLayoutSettingsKey);
    if (layoutJson == null) {
      final legacyKeys = [
        if (legacyTheme != null) roomLegacyLayoutSettingsKey(legacyTheme),
        roomLegacyLayoutSettingsKey(roomThemeClassic),
      ];
      for (final k in legacyKeys) {
        layoutJson = await _get(childId, k);
        if (layoutJson != null) {
          await _set(childId, roomLayoutSettingsKey, layoutJson);
          break;
        }
      }
    }
    return RoomLook(
      background: background,
      variants: variants,
      layout: decodeRoomLayout(layoutJson),
    );
  }

  Future<void> saveBackground(String childId, String background) =>
      _set(childId, roomBackgroundSettingsKey, background);

  Future<void> saveVariants(String childId, Map<String, String> variants) =>
      _set(childId, roomVariantsSettingsKey, encodeRoomVariants(variants));

  Future<void> saveLayout(String childId, Map<String, Offset> layout) =>
      _set(childId, roomLayoutSettingsKey, encodeRoomLayout(layout));

  /// Xóa vị trí đã lưu. Ghi bố cục RỖNG (không xóa khóa) để lần đọc sau
  /// không chuyển lại từ khóa cũ.
  Future<void> resetLayout(String childId) =>
      saveLayout(childId, const <String, Offset>{});
}
