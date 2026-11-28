/// Ảnh giao diện lô 6 (`assets/images/ui/`) cho golden: nạp sẵn trong
/// async thật (`runAsync`) để ảnh chụp golden không thiếu nút/biển.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const List<String> uiImagePaths = <String>[
  'assets/images/ui/ui_btn_back.webp',
  'assets/images/ui/ui_icon_wardrobe.webp',
  'assets/images/ui/ui_icon_shop.webp',
  'assets/images/ui/ui_icon_town.webp',
  'assets/images/ui/ui_icon_room.webp',
  'assets/images/ui/ui_coin.webp',
  'assets/images/ui/ui_gem.webp',
  'assets/images/ui/ui_star.webp',
  'assets/images/ui/ui_sign_board.webp',
  'assets/images/ui/ui_logo.webp',
  'assets/images/ui/ui_splash_bg.webp',
  'assets/images/ui/ui_onboarding_bg.webp',
  'assets/images/ui/ui_pedestal.webp',
  'assets/images/ui/ui_card.webp',
  'assets/images/ui/ui_card_selected.webp',
  'assets/images/ui/ui_icon_clothes.webp',
  'assets/images/ui/ui_icon_pet_items.webp',
  'assets/images/backgrounds/shop_bg.webp',
  'assets/images/town/arena_building.webp',
  'assets/images/backgrounds/arena_bg.webp',
  'assets/images/ui/medal_gold.webp',
  'assets/images/ui/medal_silver.webp',
  'assets/images/ui/medal_bronze.webp',
  'assets/images/ui/medal_participant.webp',
  'assets/images/items/gem_chest.webp',
];

/// Ảnh lô 17 (cư dân, sổ sticker, mở khóa): lấy theo thư mục để thêm ảnh
/// mới không phải sửa danh sách.
List<String> lot17ImagePaths() => <String>[
  for (final dir in const ['residents', 'stickers', 'unlocks'])
    for (final f in Directory('assets/images/$dir').listSync())
      if (f.path.endsWith('.webp')) f.path,
];

/// Nạp sẵn mọi ảnh giao diện rồi vẽ lại một khung.
Future<void> precacheUiImages(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold).first);
  await tester.runAsync(() async {
    for (final path in [...uiImagePaths, ...lot17ImagePaths()]) {
      await precacheImage(AssetImage(path), context);
    }
  });
  await tester.pump();
}
