/// Đường dẫn mọi ảnh nhân vật toàn thân (E) + pet theo giai đoạn (F),
/// để golden test nạp trước vào ImageCache (codec chỉ chạy trong
/// `runAsync`, thiếu bước này thì ảnh chụp trắng trơn).
library;

import 'package:material_ui/material_ui.dart';

import 'ui_images.dart';

import 'package:timokid/features/character/kid_assets.dart';

List<String> kidImagePaths() => <String>[
  for (final g in ['girl', 'boy'])
    for (var n = 1; n <= 3; n++) ...[
      kidFullAsset(g, n),
      kidFullAsset(g, n, wave: true),
      kidFullAsset(g, n, backpack: true),
      kidFullAsset(g, n, wave: true, backpack: true),
      kidEyePatch(g, n).asset,
      kidEyePatch(g, n, wave: true).asset,
    ],
  for (final g in ['girl', 'boy']) ...[
    for (final a in ['hat', 'bow']) kidHeadAccessoryAsset(g, a)!,
    kidGlassesAsset(g),
    kidWhiteShoesAsset(g),
    for (var n = 1; n <= 3; n++)
      for (final up in [false, true]) ...?kidWalkFrames(g, n, up: up),
  ],
  for (final s in ['dog', 'cat', 'rabbit'])
    for (final st in ['egg', 'newborn', 'teen', 'adult'])
      'assets/images/pets/${s}_$st.webp',
  for (final id in [
    'pet_food_bone',
    'pet_food_fish',
    'pet_food_carrot',
    'pet_toy_ball',
    'pet_toy_yarn',
    'pet_toy_plush',
  ])
    'assets/images/items/$id.webp',
  ...uiImagePaths,
];

/// Tên file ảnh của [provider] (ảnh nhân vật được bọc [ResizeImage]).
String assetNameOf(ImageProvider<Object> provider) => switch (provider) {
  ResizeImage(:final imageProvider) => assetNameOf(imageProvider),
  AssetImage(:final assetName) => assetName,
  _ => '$provider',
};
