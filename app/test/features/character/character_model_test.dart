/// Unit test bộ nhân vật nữ 1 (T2-03, PR #18).
///
/// Khóa đúng hợp đồng `docs/ASSETS.md` mục "Bộ nhân vật nữ 1": chỉ
/// 4 lớp (tóc sau, thân, váy, tóc trước), đúng thứ tự z, đúng cờ
/// `recolorable` (thân/váy màu thật không tint, chỉ tóc nhân màu).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/features/character/character_model.dart';

void main() {
  test('girlSet1 có váy: đúng lớp, đúng thứ tự, đúng tint', () {
    const hairColor = Color(0xFFFFB9D7);
    final outfit = CharacterOutfit.girlSet1(
      hairColor: hairColor,
      top: 'girl_top_02',
    );

    expect(outfit.layers.map((layer) => layer.id).toList(), <String>[
      'girl_hair_back_01',
      'girl_body_01',
      'girl_top_02',
      'girl_hair_front_01',
    ]);
    // Tóc sau + tóc trước nhân màu tóc; thân + váy màu thật, không tint.
    expect(outfit.layers[0].tint, hairColor);
    expect(outfit.layers[1].tint, isNull);
    expect(outfit.layers[2].tint, isNull);
    expect(outfit.layers[3].tint, hairColor);
    // Không có lớp mắt/miệng/giày/quần hay file `_line` nào.
    expect(outfit.layers.map((layer) => layer.layer).toList(), <String>[
      'hair_back',
      'body',
      'top',
      'hair_front',
    ]);
    expect(outfit.layers.any((layer) => layer.isLine), isFalse);
  });

  test('girlSet1 không chọn váy: chỉ 3 lớp, mặc bộ đồ gốc', () {
    const hairColor = Color(0xFFA9715C);
    final outfit = CharacterOutfit.girlSet1(hairColor: hairColor);

    expect(outfit.layers.map((layer) => layer.id).toList(), <String>[
      'girl_hair_back_01',
      'girl_body_01',
      'girl_hair_front_01',
    ]);
    expect(outfit.layers[0].tint, hairColor);
    expect(outfit.layers[1].tint, isNull);
    expect(outfit.layers[2].tint, hairColor);
  });
}
