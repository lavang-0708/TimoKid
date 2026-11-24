/// Lỗi 24/11: mua bộ cao cấp (vd bé trai "Vest dạ hội" 05, "Hiệp sĩ
/// hoàng gia" 07), mặc vào thì nhân vật trong Phòng lại hiện bộ 3 (áo
/// đỏ) vì KidSprite ép số bộ về 1–3. Bộ 04–07 phải hiện đúng ảnh.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/features/character/kid_sprite.dart';

void main() {
  for (final n in [4, 5, 6, 7]) {
    testWidgets('bé trai mặc bộ 0$n: hiện đúng ảnh bộ 0$n', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 300,
              child: KidSprite(
                gender: 'boy',
                outfit: n,
                animationsEnabled: false,
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(Key('kid-full-boy-$n')), findsOneWidget);
      expect(find.byKey(const Key('kid-full-boy-3')), findsNothing);
    });
  }
}
