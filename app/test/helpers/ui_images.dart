/// Ảnh giao diện lô 6 (`assets/images/ui/`) cho golden: nạp sẵn trong
/// async thật (`runAsync`) để ảnh chụp golden không thiếu nút/biển.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const List<String> uiImagePaths = <String>[
  'assets/images/ui/ui_btn_back.png',
  'assets/images/ui/ui_icon_wardrobe.png',
  'assets/images/ui/ui_icon_shop.png',
  'assets/images/ui/ui_icon_town.png',
  'assets/images/ui/ui_icon_room.png',
  'assets/images/ui/ui_coin.png',
  'assets/images/ui/ui_gem.png',
  'assets/images/ui/ui_star.png',
  'assets/images/ui/ui_sign_board.png',
  'assets/images/ui/ui_logo.png',
  'assets/images/ui/ui_splash_bg.png',
  'assets/images/ui/ui_onboarding_bg.png',
  'assets/images/ui/ui_pedestal.png',
  'assets/images/ui/ui_card.png',
  'assets/images/ui/ui_card_selected.png',
  'assets/images/ui/ui_icon_clothes.png',
  'assets/images/ui/ui_icon_pet_items.png',
  'assets/images/backgrounds/shop_bg.png',
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
