/// Ảnh giao diện lô 6 (`assets/images/ui/`) cho golden: nạp sẵn trong
/// async thật (`runAsync`) để ảnh chụp golden không thiếu nút/biển.
library;

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

/// Nạp sẵn mọi ảnh giao diện rồi vẽ lại một khung.
Future<void> precacheUiImages(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold).first);
  await tester.runAsync(() async {
    for (final path in uiImagePaths) {
      await precacheImage(AssetImage(path), context);
    }
  });
  await tester.pump();
}
