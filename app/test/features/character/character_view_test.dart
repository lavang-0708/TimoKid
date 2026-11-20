/// Test cho CharacterView (T2-02): xếp lớp theo z, nhân màu, bộ nạp
/// lớp chèn được, thở + chớp mắt, lớp thiếu file không vỡ widget.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/animation/animation_gate.dart';
import 'package:timokid/features/character/character_model.dart';
import 'package:timokid/features/character/character_view.dart';

import 'character_fixtures.dart';

/// Đọc kích thước PNG từ header IHDR (byte 16-24, big-endian).
({int width, int height}) pngSize(Uint8List bytes) {
  int u32(int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
  return (width: u32(16), height: u32(20));
}

const palette1 = CharacterPalette(
  skin: Color(0xFFFFD9B3),
  hair: Color(0xFF8A5A2B),
  eyes: Color(0xFF4A6FA5),
  mouth: Color(0xFFD96A6A),
  top: Color(0xFFF2A7C3),
  bottom: Color(0xFF7FB3D5),
  shoes: Color(0xFFE8B4B8),
  accessoryHead: Color(0xFFF5D76E),
);

CharacterOutfit outfitA() => CharacterOutfit.girl(
  palette: palette1,
  accessoryHead: 'girl_accessory_head_01',
);

Future<void> pumpCharacter(
  WidgetTester tester,
  CharacterOutfit outfit, {
  bool animationsEnabled = false,
  CharacterLayerLoader? loader,
}) async {
  tester.view.physicalSize = const Size(256, 384);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: CharacterView(
          outfit: outfit,
          loader: loader ?? characterFixtureLoader,
          animationsEnabled: animationsEnabled,
          width: 256,
        ),
      ),
    ),
  );
  if (animationsEnabled) {
    // pumpAndSettle không bao giờ xong với animation lặp vô hạn.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  // Bật cổng hiệu ứng cho file này (testExecutable đã tắt cho mọi
  // file test): test thở/chớp mắt bơm bằng pump(Duration) chứ không
  // dùng pumpAndSettle với animation lặp. Các test còn lại bơm với
  // animationsEnabled: false nên cổng bật cũng không ảnh hưởng.
  setUpAll(() => AnimationGate.enabled = true);
  tearDownAll(() => AnimationGate.enabled = false);

  group('CharacterOutfit.girl', () {
    test('xếp lớp theo z, _line ngay sau lớp gốc', () {
      final outfit = outfitA();
      final layers = outfit.layers;
      final zs = layers.map((l) => l.z).toList();
      final sortedZs = [...zs]..sort();
      expect(zs, sortedZs);
      expect(layers.map((l) => l.id).toList(), [
        'girl_hair_back_01',
        'girl_body_01',
        'girl_body_01_line',
        'girl_shoes_01',
        'girl_bottom_01',
        'girl_top_01',
        'girl_eyes_01',
        'girl_eyes_01_line',
        'girl_mouth_01',
        'girl_mouth_01_line',
        'girl_hair_front_01',
        'girl_accessory_head_01',
      ]);
    });

    test('bộ tóc lấy cả sau + trước; không phụ kiện thì không có lớp đó', () {
      final outfit = CharacterOutfit.girl(
        palette: palette1,
        hairSet: 'girl_hair_02',
      );
      final ids = outfit.layers.map((l) => l.id).toSet();
      expect(ids.contains('girl_hair_back_02'), isTrue);
      expect(ids.contains('girl_hair_front_02'), isTrue);
      expect(ids.any((id) => id.contains('accessory')), isFalse);
    });

    test('bottom null = váy đầm liền thân, không có lớp bottom', () {
      final outfit = CharacterOutfit.girl(palette: palette1, bottom: null);
      expect(outfit.layers.any((l) => l.layer == 'bottom'), isFalse);
    });

    test('đường dẫn asset suy ra từ mã manifest', () {
      final outfit = outfitA();
      final top = outfit.layers.firstWhere((l) => l.id == 'girl_top_01');
      expect(top.assetPath, 'assets/images/character/girl/girl_top_01.png');
    });
  });

  group('fixture tạm', () {
    test('đủ 29 lớp, đúng khung hợp đồng 1024x1536, có kênh alpha', () {
      expect(characterFixtureBase64.length, 29);
      for (final entry in characterFixtureBase64.entries) {
        final bytes = base64Decode(entry.value);
        expect(bytes.sublist(0, 8), [
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
        ]);
        final size = pngSize(bytes);
        expect(size.width, 1024, reason: entry.key);
        expect(size.height, 1536, reason: entry.key);
        // PNG loại 6 (RGBA) mới có nền trong suốt.
        expect(bytes[25], 6, reason: entry.key);
      }
    });
  });

  group('CharacterView', () {
    testWidgets('lớp đổi màu có ColorFiltered, lớp không đổi màu thì không', (
      tester,
    ) async {
      final outfit = CharacterOutfit.girl(
        palette: palette1,
        accessoryHand: 'girl_accessory_hand_01',
      );
      await pumpCharacter(tester, outfit);

      // Áo (đổi màu) nằm trong ColorFiltered nhân màu.
      expect(
        find.ancestor(
          of: find.byKey(const Key('character-layer-girl_top_01')),
          matching: find.byType(ColorFiltered),
        ),
        findsOneWidget,
      );
      // Phụ kiện tay (recolorable: false trong manifest) không có.
      expect(
        find.ancestor(
          of: find.byKey(const Key('character-layer-girl_accessory_hand_01')),
          matching: find.byType(ColorFiltered),
        ),
        findsNothing,
      );
      // File _line cũng không nhân màu.
      expect(
        find.ancestor(
          of: find.byKey(const Key('character-layer-girl_eyes_01_line')),
          matching: find.byType(ColorFiltered),
        ),
        findsNothing,
      );
    });

    testWidgets('bộ nạp lớp chèn được: gọi đúng đường dẫn từng lớp', (
      tester,
    ) async {
      final outfit = outfitA();
      final loaded = <String>[];
      ImageProvider countingLoader(String path) {
        loaded.add(path);
        return characterFixtureLoader(path);
      }

      await pumpCharacter(tester, outfit, loader: countingLoader);

      expect(loaded.toSet(), outfit.layers.map((l) => l.assetPath).toSet());
    });

    testWidgets('lớp thiếu file không vỡ widget', (tester) async {
      final outfit = outfitA();
      ImageProvider failingLoader(String path) {
        if (path.contains('girl_top_01')) {
          throw FlutterError('thiếu file tạm');
        }
        return characterFixtureLoader(path);
      }

      await pumpCharacter(tester, outfit, loader: failingLoader);

      expect(find.byKey(const Key('character-view')), findsOneWidget);
      expect(
        find.byKey(const Key('character-layer-girl_eyes_01')),
        findsOneWidget,
      );
    });

    testWidgets('thở squash/stretch: cao lên + hẹp lại rồi về', (tester) async {
      await pumpCharacter(tester, outfitA(), animationsEnabled: true);
      final breath = find.byKey(const Key('character-breath'));
      expect(breath, findsOneWidget);

      double scaleX() {
        final t = tester.widget<Transform>(breath);
        return t.transform.storage[0];
      }

      double scaleY() {
        final t = tester.widget<Transform>(breath);
        return t.transform.storage[5];
      }

      // Sau 2 lần pump khởi động (t = 100 ms): gần đầu chu kỳ thở
      // (X ≈ 1.01 bè ra, Y ≈ 0.99 thấp xuống).
      expect(scaleX(), closeTo(1.01, 0.002));
      expect(scaleY(), closeTo(0.99, 0.002));
      // t = 1200 ms: giữa chu kỳ thở (easeInOut(0.5) = 0.5).
      await tester.pump(const Duration(milliseconds: 1100));
      expect(scaleX(), closeTo(0.9975, 0.002));
      expect(scaleY(), closeTo(1.01, 0.002));
      // t = 2400 ms: cuối chu kỳ thuận, cao nhất + hẹp nhất.
      await tester.pump(const Duration(milliseconds: 1200));
      expect(scaleX(), closeTo(0.985, 0.001));
      expect(scaleY(), closeTo(1.03, 0.001));
      // t = 3600 ms: đang thở ra, giữa chu kỳ ngược.
      await tester.pump(const Duration(milliseconds: 1200));
      expect(scaleX(), closeTo(0.9975, 0.002));
      expect(scaleY(), closeTo(1.01, 0.002));
    });

    testWidgets('chớp mắt: mắt co dọc ở cuối chu kỳ rồi mở lại', (
      tester,
    ) async {
      await pumpCharacter(tester, outfitA(), animationsEnabled: true);
      final blink = find.byKey(const Key('character-blink'));
      expect(blink, findsOneWidget);

      double scaleY() {
        final t = tester.widget<Transform>(blink);
        return t.transform.storage[5];
      }

      expect(scaleY(), 1.0);
      // 3200 ms: đang trong nhịp khép (3060–3230 ms của chu kỳ 3400 ms).
      await tester.pump(const Duration(milliseconds: 3200));
      expect(scaleY(), lessThan(0.9));
      // Hết chu kỳ: mắt mở lại.
      await tester.pump(const Duration(milliseconds: 300));
      expect(scaleY(), closeTo(1.0, 0.02));
    });

    testWidgets('tắt animation: không có Transform thở/chớp', (tester) async {
      await pumpCharacter(tester, outfitA(), animationsEnabled: false);
      expect(find.byKey(const Key('character-breath')), findsNothing);
      expect(find.byKey(const Key('character-blink')), findsNothing);
      expect(find.byKey(const Key('character-view')), findsOneWidget);
    });
  });
}
