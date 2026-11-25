/// Mô hình nhân vật theo lớp (T2-02, khớp `assets/manifest.json` v1 và
/// `docs/ASSETS.md`).
///
/// Một nhân vật là một chồng lớp, mỗi lớp một file PNG đúng khung
/// 1024x1536, chỉ chứa phần của lớp đó ở đúng vị trí. App chồng các
/// lớp theo z, tô màu lớp xám bằng phép nhân màu (multiply), rồi đặt
/// lớp `_line` (nét không đổi màu) lên trên lớp gốc.
///
/// File hình thật thay thế fixture 1:1 tại đúng đường dẫn manifest,
/// không cần sửa code: đường dẫn asset của mỗi lớp suy ra từ mã
/// manifest (`assets/images/character/<dáng>/<mã>.webp`).
library;

import 'package:material_ui/material_ui.dart';

/// Thứ tự chồng z của 10 mã lớp — khớp bảng `layers` trong
/// `assets/manifest.json` (v1) và `docs/ASSETS.md`. Mắt và miệng cùng
/// z 6 (khác vị trí nên không che nhau); phụ kiện đầu và tay cùng z 8.
const Map<String, int> characterLayerZ = {
  'hair_back': 1,
  'body': 2,
  'shoes': 3,
  'bottom': 4,
  'top': 5,
  'eyes': 6,
  'mouth': 6,
  'hair_front': 7,
  'accessory_head': 8,
  'accessory_hand': 8,
};

/// Các lớp có file `_line` đi kèm trong manifest v1: chỉ thân, mắt,
/// miệng có nét không đổi màu riêng (viền thân, mi mắt, viền miệng).
/// Tóc, áo, quần, giày, phụ kiện chưa có `_line` — khi manifest thêm
/// thì thêm mã lớp vào đây.
const Set<String> _characterLineLayers = {'body', 'eyes', 'mouth'};

/// Một lớp của nhân vật: một file PNG + màu nhân (nếu đổi màu được).
class CharacterLayerSpec {
  const CharacterLayerSpec({
    required this.id,
    required this.layer,
    required this.assetPath,
    this.tint,
    this.isLine = false,
  });

  /// Mã manifest, cũng là tên file (không tính đuôi), vd `girl_eyes_01`.
  final String id;

  /// Mã lớp, vd `eyes`. Quyết định thứ tự chồng qua [characterLayerZ].
  final String layer;

  /// Đường dẫn asset Flutter, vd
  /// `assets/images/character/girl/girl_eyes_01.webp`.
  final String assetPath;

  /// Màu nhân (multiply) lên lớp xám; null = giữ nguyên màu file.
  /// Chỉ lớp đổi màu (`recolorable: true` trong manifest) mới có tint.
  final Color? tint;

  /// True với file `_line`: vẽ ngay sau lớp gốc, không tô màu.
  final bool isLine;

  /// Bậc chồng; lớp lạ (không có trong hợp đồng) xếp sau cùng.
  int get z => characterLayerZ[layer] ?? 99;
}

/// Bảng màu của một bộ phối đồ: mỗi màu nhân lên lớp xám tương ứng.
class CharacterPalette {
  const CharacterPalette({
    required this.skin,
    required this.hair,
    required this.eyes,
    required this.mouth,
    required this.top,
    required this.bottom,
    required this.shoes,
    required this.accessoryHead,
  });

  final Color skin;
  final Color hair;
  final Color eyes;
  final Color mouth;
  final Color top;
  final Color bottom;
  final Color shoes;
  final Color accessoryHead;
}

/// Một bộ phối đồ đầy đủ: danh sách lớp đã xếp theo z, `_line` ngay
/// sau lớp gốc của nó.
class CharacterOutfit {
  CharacterOutfit({
    required this.form,
    required List<CharacterLayerSpec> layers,
  }) : layers = _sorted(layers);

  /// Dáng nhân vật: `girl` (dáng `boy` vẽ sau, xem manifest).
  final String form;

  /// Các lớp đã xếp theo z (ổn định: `_line` giữ ngay sau lớp gốc).
  final List<CharacterLayerSpec> layers;

  static List<CharacterLayerSpec> _sorted(List<CharacterLayerSpec> input) {
    final indexed = input.asMap().entries.toList();
    indexed.sort((a, b) {
      final byZ = a.value.z.compareTo(b.value.z);
      if (byZ != 0) return byZ;
      return a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList(growable: false);
  }

  /// Bộ đồ dáng nữ từ các mã manifest. `hairSet` là mã bộ tóc, vd
  /// `girl_hair_01` (lấy cả tóc sau + tóc trước trong bộ). `bottom`
  /// null = không mặc quần/váy (vd váy đầm liền thân ở lớp `top`).
  /// `accessoryHead`/`accessoryHand` null = không đeo phụ kiện đó.
  factory CharacterOutfit.girl({
    required CharacterPalette palette,
    String hairSet = 'girl_hair_01',
    String eyes = 'girl_eyes_01',
    String mouth = 'girl_mouth_01',
    String top = 'girl_top_01',
    String? bottom = 'girl_bottom_01',
    String shoes = 'girl_shoes_01',
    String? accessoryHead,
    String? accessoryHand,
    bool includeLines = true,
  }) {
    final specs = <CharacterLayerSpec>[];

    void add(String id, String layer, Color? tint, {bool line = false}) {
      specs.add(
        CharacterLayerSpec(
          id: id,
          layer: layer,
          assetPath: 'assets/images/character/girl/$id.webp',
          tint: line ? null : tint,
          isLine: line,
        ),
      );
      // File `_line` (nếu có trong manifest) đi ngay sau lớp gốc.
      if (!line && includeLines && _characterLineLayers.contains(layer)) {
        specs.add(
          CharacterLayerSpec(
            id: '${id}_line',
            layer: layer,
            assetPath: 'assets/images/character/girl/${id}_line.webp',
            isLine: true,
          ),
        );
      }
    }

    // Tóc sau (z 1) và tóc trước (z 7) cùng một bộ.
    final hairNumber = hairSet.split('_').last;
    add('girl_hair_back_$hairNumber', 'hair_back', palette.hair);
    add('girl_body_01', 'body', palette.skin);
    add(shoes, 'shoes', palette.shoes);
    if (bottom != null) add(bottom, 'bottom', palette.bottom);
    add(top, 'top', palette.top);
    add(eyes, 'eyes', palette.eyes);
    add(mouth, 'mouth', palette.mouth);
    add('girl_hair_front_$hairNumber', 'hair_front', palette.hair);
    if (accessoryHead != null) {
      add(accessoryHead, 'accessory_head', palette.accessoryHead);
    }
    if (accessoryHand != null) {
      // Phụ kiện tay trong manifest v1 không đổi màu
      // (`recolorable: false`) nên không có tint.
      add(accessoryHand, 'accessory_hand', null);
    }

    return CharacterOutfit(form: 'girl', layers: specs);
  }

  /// Bộ nhân vật nữ 1 (PR #18, `docs/ASSETS.md` mục "Bộ nhân vật nữ
  /// 1"): thân đã có sẵn mắt, miệng, tất, giày và bộ đồ gốc nên
  /// KHÔNG chồng thêm lớp eyes/mouth/shoes/bottom; chỉ có tóc (xám,
  /// đổi màu được) + váy (màu thật). `top` null = mặc bộ đồ gốc.
  ///
  /// Đúng cờ `recolorable` của bộ này: thân và váy màu thật nên
  /// không có tint; chỉ hai lớp tóc nhân màu [hairColor]. Không có
  /// file `_line` đi kèm bộ này. Bộ tóc sau để trống (trong suốt)
  /// nhưng vẫn phải có mặt để đủ bộ `girl_hair_01`.
  factory CharacterOutfit.girlSet1({required Color hairColor, String? top}) {
    // Danh sách lớp đúng thứ tự z — tóc sau, thân, váy, tóc trước.
    return CharacterOutfit(
      form: 'girl',
      layers: <CharacterLayerSpec>[
        CharacterLayerSpec(
          id: 'girl_hair_back_01',
          layer: 'hair_back',
          assetPath: 'assets/images/character/girl/girl_hair_back_01.webp',
          tint: hairColor,
        ),
        const CharacterLayerSpec(
          id: 'girl_body_01',
          layer: 'body',
          assetPath: 'assets/images/character/girl/girl_body_01.webp',
        ),
        if (top != null)
          CharacterLayerSpec(
            id: top,
            layer: 'top',
            assetPath: 'assets/images/character/girl/$top.webp',
          ),
        CharacterLayerSpec(
          id: 'girl_hair_front_01',
          layer: 'hair_front',
          assetPath: 'assets/images/character/girl/girl_hair_front_01.webp',
          tint: hairColor,
        ),
      ],
    );
  }
}
