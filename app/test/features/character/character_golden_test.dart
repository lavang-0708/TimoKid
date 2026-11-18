/// Golden test cho CharacterView (T2-02): 3 bộ phối đồ x 3 bảng màu.
///
/// Ảnh chụp bằng fixture tạm (khối xám đúng khung hợp đồng, nhúng
/// base64 trong `character_fixtures.dart`) — code và golden test sẵn
/// sàng, khi hình thật về chỉ cần thay file tại đúng đường dẫn
/// manifest. Ảnh kỳ vọng nhúng base64 trong
/// `goldens/character_golden_data.dart` và được giải mã ra file PNG
/// trước khi so sánh (mẫu `math_golden_test.dart`).
///
/// Animation tắt để ảnh chụp xác định. Kích thước 256x384 dp, đúng
/// tỉ lệ khung 1024:1536.
library;

import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/features/character/character_model.dart';
import 'package:timokid/features/character/character_view.dart';

import '../../goldens/character_golden_data.dart';
import 'character_fixtures.dart';

const _palettes = <String, CharacterPalette>{
  'palette1': CharacterPalette(
    skin: Color(0xFFFFD9B3),
    hair: Color(0xFF8A5A2B),
    eyes: Color(0xFF4A6FA5),
    mouth: Color(0xFFD96A6A),
    top: Color(0xFFF2A7C3),
    bottom: Color(0xFF7FB3D5),
    shoes: Color(0xFFE8B4B8),
    accessoryHead: Color(0xFFF5D76E),
  ),
  'palette2': CharacterPalette(
    skin: Color(0xFFFFE0C2),
    hair: Color(0xFF3B2E5A),
    eyes: Color(0xFF2E7D6B),
    mouth: Color(0xFFC0392B),
    top: Color(0xFFA8D8A8),
    bottom: Color(0xFFF5A623),
    shoes: Color(0xFF8A7FA6),
    accessoryHead: Color(0xFF43A047),
  ),
  'palette3': CharacterPalette(
    skin: Color(0xFFF5CBA7),
    hair: Color(0xFFF06292),
    eyes: Color(0xFF7E57C2),
    mouth: Color(0xFFE57373),
    top: Color(0xFF81D4FA),
    bottom: Color(0xFFFFF176),
    shoes: Color(0xFFB39DDB),
    accessoryHead: Color(0xFFFF8A65),
  ),
};

CharacterOutfit _outfit(String name, CharacterPalette palette) {
  switch (name) {
    case 'outfitA':
      return CharacterOutfit.girl(
        palette: palette,
        accessoryHead: 'girl_accessory_head_01',
      );
    case 'outfitB':
      return CharacterOutfit.girl(
        palette: palette,
        hairSet: 'girl_hair_02',
        eyes: 'girl_eyes_02',
        mouth: 'girl_mouth_02',
        top: 'girl_top_02',
        bottom: 'girl_bottom_02',
        accessoryHead: 'girl_accessory_head_02',
      );
    case 'outfitC':
      return CharacterOutfit.girl(
        palette: palette,
        hairSet: 'girl_hair_03',
        eyes: 'girl_eyes_03',
        mouth: 'girl_mouth_03',
        top: 'girl_top_03',
        bottom: 'girl_bottom_01',
      );
    default:
      throw ArgumentError('Không có bộ đồ $name');
  }
}

void _restoreGoldens() {
  const goldens = {
    'test/goldens/character_outfitA_palette1.png':
        characterOutfitAPalette1Base64,
    'test/goldens/character_outfitA_palette2.png':
        characterOutfitAPalette2Base64,
    'test/goldens/character_outfitA_palette3.png':
        characterOutfitAPalette3Base64,
    'test/goldens/character_outfitB_palette1.png':
        characterOutfitBPalette1Base64,
    'test/goldens/character_outfitB_palette2.png':
        characterOutfitBPalette2Base64,
    'test/goldens/character_outfitB_palette3.png':
        characterOutfitBPalette3Base64,
    'test/goldens/character_outfitC_palette1.png':
        characterOutfitCPalette1Base64,
    'test/goldens/character_outfitC_palette2.png':
        characterOutfitCPalette2Base64,
    'test/goldens/character_outfitC_palette3.png':
        characterOutfitCPalette3Base64,
  };
  for (final entry in goldens.entries) {
    File(entry.key).writeAsBytesSync(base64Decode(entry.value));
  }
}

void main() {
  setUpAll(_restoreGoldens);

  for (final outfitName in ['outfitA', 'outfitB', 'outfitC']) {
    for (final paletteName in ['palette1', 'palette2', 'palette3']) {
      testWidgets('$outfitName + $paletteName', (tester) async {
        tester.view.physicalSize = const Size(256, 384);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final outfit = _outfit(outfitName, _palettes[paletteName]!);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: CharacterView(
                  outfit: outfit,
                  loader: characterFixtureLoader,
                  animationsEnabled: false,
                  width: 256,
                ),
              ),
            ),
          ),
        );
        // Nạp trước ảnh vào ImageCache: codec giải mã chỉ chạy trong
        // async thật (`runAsync`), fake async của `pump` không lái
        // được nó — không có bước này thì ảnh chụp golden trắng trơn
        // (layer 0x0 vì ảnh chưa về).
        final context = tester.element(find.byKey(const Key('character-view')));
        await tester.runAsync(() async {
          for (final layer in outfit.layers) {
            await precacheImage(
              characterFixtureLoader(layer.assetPath),
              context,
            );
          }
        });
        await tester.pump();

        await expectLater(
          find.byKey(const Key('character-view')),
          matchesGoldenFile(
            '../../goldens/character_${outfitName}_$paletteName.png',
          ),
        );
      });
    }
  }
}
