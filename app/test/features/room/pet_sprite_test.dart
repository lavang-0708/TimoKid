/// Test động tác pet trong Phòng ([PetSprite]): đi nước kiệu, thở +
/// vẫy đuôi, động tác ngẫu nhiên khi đứng yên, nhảy vui + tim, cờ hình
/// thật của Muse.
///
/// Hiệu ứng chỉ chạy khi cổng [AnimationGate] bật nên các test bật lại
/// cổng và bơm từng khung bằng `pump(Duration)` (mẫu
/// `room_screen_test.dart`).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/animation/animation_gate.dart';
import 'package:timokid/features/room/pet_art.dart';
import 'package:timokid/features/room/pet_growth.dart';
import 'package:timokid/features/room/pet_sprite.dart';

Widget _host({
  bool walking = false,
  bool facingLeft = false,
  int happyTick = 0,
}) => MaterialApp(
  home: Center(
    child: SizedBox(
      width: 200,
      height: 200,
      child: PetSprite(
        species: 'dog',
        stage: PetStage.newborn,
        walking: walking,
        facingLeft: facingLeft,
        happyTick: happyTick,
      ),
    ),
  ),
);

Matrix4 _matrix(WidgetTester tester) =>
    tester.widget<Transform>(find.byKey(const Key('pet-sprite'))).transform;

double _dy(WidgetTester tester) => tester
    .widget<FractionalTranslation>(
      find
          .ancestor(
            of: find.byKey(const Key('pet-sprite')),
            matching: find.byType(FractionalTranslation),
          )
          .first,
    )
    .translation
    .dy;

void main() {
  setUp(() => AnimationGate.enabled = true);
  tearDown(() => AnimationGate.enabled = false);

  testWidgets('cổng tắt: pet tĩnh, không có hiệu ứng', (tester) async {
    AnimationGate.enabled = false;
    await tester.pumpWidget(_host(walking: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pet-sprite')), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('đứng yên: thở + lắc ngang nhỏ (ma trận đổi theo thời gian)', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 100));
    final seen = <double>{};
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      seen.add(double.parse(_matrix(tester).storage[5].toStringAsFixed(3)));
      // Đứng yên thì không nảy lên.
      if (find.byKey(const Key('pet-action-jump')).evaluate().isEmpty) {
        expect(_dy(tester).abs(), lessThan(0.01));
      }
    }
    expect(seen.length, greaterThan(3), reason: 'co giãn dọc phải đổi (thở)');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('đi: nảy lên xuống + nén lúc tiếp đất, nghiêng luân phiên', (
    tester,
  ) async {
    await tester.pumpWidget(_host(walking: true));
    await tester.pump(const Duration(milliseconds: 50));
    var minDy = 0.0;
    var minSy = 9.0;
    var maxSy = 0.0;
    var minRot = 9.0;
    var maxRot = -9.0;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      final m = _matrix(tester);
      minDy = _dy(tester) < minDy ? _dy(tester) : minDy;
      minSy = m.storage[5] < minSy ? m.storage[5] : minSy;
      maxSy = m.storage[5] > maxSy ? m.storage[5] : maxSy;
      // storage[1] = sin(rot) * sx: dấu cho biết nghiêng bên nào.
      minRot = m.storage[1] < minRot ? m.storage[1] : minRot;
      maxRot = m.storage[1] > maxRot ? m.storage[1] : maxRot;
    }
    expect(minDy, lessThan(-0.07), reason: 'nảy lên khoảng 9% chiều cao');
    expect(minSy, lessThan(0.95), reason: 'nén lúc tiếp đất');
    expect(maxSy, greaterThan(1.0), reason: 'giãn giữa nhịp nảy');
    expect(minRot, lessThan(-0.03));
    expect(maxRot, greaterThan(0.03));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('đi sang trái: nghiêng đảo chiều so với đi sang phải', (
    tester,
  ) async {
    Future<double> tiltAtQuarter(bool left) async {
      await tester.pumpWidget(_host(walking: true, facingLeft: left));
      await tester.pump();
      // 1/4 chu kỳ 600 ms: sin = 1 (nghiêng cực đại về trước).
      await tester.pump(const Duration(milliseconds: 150));
      final v = _matrix(tester).storage[1];
      await tester.pumpWidget(const SizedBox());
      return v;
    }

    final right = await tiltAtQuarter(false);
    final left = await tiltAtQuarter(true);
    expect(right, greaterThan(0.03));
    expect(left, lessThan(-0.03));
  });

  testWidgets('đứng yên 6–12 giây thì tự làm động tác (nhảy/quay/ngồi)', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    bool anyAction() => [
      'pet-action-jump',
      'pet-action-spin',
      'pet-action-sit',
    ].any((k) => find.byKey(Key(k)).evaluate().isNotEmpty);
    // Chưa tới 6 giây thì chưa có.
    for (var i = 0; i < 55; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(anyAction(), isFalse, reason: 'sớm hơn 6 giây');
    }
    var seen = false;
    for (var i = 0; i < 80 && !seen; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      seen = anyAction();
    }
    expect(seen, isTrue, reason: 'trong 13,5 giây phải có động tác');
    // Động tác xong thì trở lại bình thường.
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(anyAction(), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bắt đầu đi thì bỏ động tác đang làm', (tester) async {
    await tester.pumpWidget(_host());
    for (var i = 0; i < 135; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(const Key('pet-action-sit')).evaluate().isNotEmpty ||
          find.byKey(const Key('pet-action-spin')).evaluate().isNotEmpty ||
          find.byKey(const Key('pet-action-jump')).evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pumpWidget(_host(walking: true));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('pet-action-sit')), findsNothing);
    expect(find.byKey(const Key('pet-action-spin')), findsNothing);
    expect(find.byKey(const Key('pet-action-jump')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('chạm (happyTick tăng): nhảy vui + tim bay lên rồi tắt', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('pet-hearts')), findsNothing);

    await tester.pumpWidget(_host(happyTick: 1));
    await tester.pump();
    var minDy = 0.0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      minDy = _dy(tester) < minDy ? _dy(tester) : minDy;
    }
    expect(find.byKey(const Key('pet-hearts')), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNWidgets(3));
    expect(minDy, lessThan(-0.2), reason: 'nhảy cao ~30% chiều cao');

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('pet-hearts')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('khung pet Muse (lô 8B) đã bật, tên file đúng quy ước', () {
    expect(petMotionArtReady, isTrue);
    expect(petHasMotionArt('cat', PetStage.newborn), isTrue);
    // Chó mới nở: khung lô 8B còn trong vỏ, chờ vẽ lại.
    expect(petHasMotionArt('dog', PetStage.newborn), isFalse);
    expect(petHasMotionArt('dog', PetStage.teen), isTrue);
    expect(petWalkAssets('cat', PetStage.teen), [
      'assets/images/pets/cat_teen_walk_a.png',
      'assets/images/pets/cat_teen_walk_b.png',
      'assets/images/pets/cat_teen_walk_c.png',
      'assets/images/pets/cat_teen_walk_d.png',
    ]);
    expect(
      petHappyAsset('rabbit', PetStage.adult),
      'assets/images/pets/rabbit_adult_happy.png',
    );
    expect(
      petSitAsset('dog', PetStage.newborn),
      'assets/images/pets/dog_newborn_sit.png',
    );
  });
}
