/// Danh mục món tặng của web admin (`admin/src/lib/items.ts`) phải khớp
/// danh mục Cửa hàng thật của app (trừ trứng pet): gửi quà bằng mã không có
/// trong app thì bé nhận được món "ma".
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/features/shop/shop_catalog.dart';

void main() {
  test('items.ts khớp mã món trong shop_catalog', () {
    final file = File('../admin/src/lib/items.ts');
    expect(file.existsSync(), isTrue, reason: 'chạy test từ thư mục app/');
    final adminIds = RegExp(r"\{ id: '([^']+)', name:")
        .allMatches(file.readAsStringSync())
        .map((m) => m.group(1)!)
        .toSet();
    final appIds = <String>{
      for (final g in ['girl', 'boy'])
        for (final i in shopItemsFor(g))
          if (i.kind != ShopItemKind.petEgg) i.id,
    };
    expect(adminIds.difference(appIds), isEmpty, reason: 'admin có mã lạ');
    expect(appIds.difference(adminIds), isEmpty, reason: 'admin thiếu món');
  });
}
