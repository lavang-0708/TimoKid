/// Test hiệu ứng rồng: hàm thuần (bản đầy đủ/nhỏ, cờ hình, khung phun,
/// bay-đi), vầng sáng, [DragonPetView] chạy từng hành động tới khi xong.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/animation/animation_gate.dart';
import 'package:timokid/features/pet/dragon_fx.dart';
import 'package:timokid/features/pet/dragon_fx_config.dart';
import 'package:timokid/features/room/pet_growth.dart';

Widget _host(
  DragonFxController c, {
  PetStage stage = PetStage.adult,
  bool art = false,
  bool left = false,
}) => MaterialApp(
  home: Center(
    child: SizedBox(
      width: 240,
      height: 240,
      child: DragonPetView(
        controller: c,
        stage: stage,
        artReady: art,
        facingLeft: left,
      ),
    ),
  ),
);

Future<void> _advance(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  tearDown(() => AnimationGate.enabled = false);

  group('hàm thuần', () {
    test('bản đầy đủ chỉ cho rồng trưởng thành', () {
      expect(dragonFxModeFor(PetStage.adult), DragonFxMode.full);
      expect(dragonFxModeFor(PetStage.teen), DragonFxMode.small);
      expect(dragonFxModeFor(PetStage.newborn), DragonFxMode.small);
    });

    test('cờ hình quyết định dùng hình thật (chỉ trưởng thành)', () {
      // Lô 12B đã về (24/11): cờ bật.
      expect(dragonFxArtReady, isTrue);
      expect(dragonUsesArt(PetStage.adult), isTrue);
      expect(dragonUsesArt(PetStage.adult, artReady: false), isFalse);
      expect(dragonUsesArt(PetStage.adult, artReady: true), isTrue);
      expect(dragonUsesArt(PetStage.teen, artReady: true), isFalse);
      expect(
        dragonFxAssets(DragonAction.fire).first,
        endsWith('dragon_fire_1.png'),
      );
      expect(
        dragonFxAssets(DragonAction.water).last,
        endsWith('dragon_water_4.png'),
      );
      expect(dragonFxAssets(DragonAction.fly), hasLength(4));
      expect(
        dragonFxAssets(DragonAction.fly).first,
        endsWith('dragon_fly_a.png'),
      );
      expect(dragonAuraAsset, endsWith('dragon_aura.png'));
    });

    test('khung phun 120 ms, khung 3 giữ thêm', () {
      expect(dragonFxArtFrameAt(0), 0);
      expect(dragonFxArtFrameAt(119), 0);
      expect(dragonFxArtFrameAt(120), 1);
      expect(dragonFxArtFrameAt(240), 2);
      expect(dragonFxArtFrameAt(240 + 120 + dragonFxHoldExtraMs - 1), 2);
      expect(dragonFxArtFrameAt(240 + 120 + dragonFxHoldExtraMs), 3);
      expect(dragonFxArtFrameAt(99999), 3);
      expect(
        dragonActionMs(DragonAction.fire, PetStage.adult, artReady: true),
        dragonFxArtTotalMs,
      );
    });

    test('thời gian hành động theo giai đoạn', () {
      expect(
        dragonActionMs(DragonAction.fire, PetStage.adult, artReady: false),
        dragonFireMs,
      );
      expect(
        dragonActionMs(DragonAction.water, PetStage.adult, artReady: false),
        dragonWaterMs,
      );
      expect(dragonActionMs(DragonAction.fire, PetStage.teen), dragonSmallMs);
      expect(dragonActionMs(DragonAction.fly, PetStage.newborn), dragonHopMs);
      expect(
        dragonActionMs(DragonAction.fly, PetStage.adult),
        dragonFlyRiseMs + dragonFlyHoverMs + dragonFlyLandMs,
      );
    });

    test('độ nâng: lên, treo, xuống', () {
      expect(dragonFlyLiftAt(0), 0);
      expect(dragonFlyLiftAt(0.5), 1);
      expect(dragonFlyLiftAt(1), 0);
      expect(dragonFlyLiftAt(0.05), inExclusiveRange(0, 1));
      expect(dragonFlyLiftAt(0.95), inExclusiveRange(0, 1));
    });

    test('đi quãng dài chỉ bay với rồng trưởng thành', () {
      bool fly(String sp, PetStage st, double len) =>
          dragonShouldFlyWalk(species: sp, stage: st, length: len);
      expect(fly('dragon', PetStage.adult, dragonFlyWalkThreshold + 1), isTrue);
      expect(
        fly('dragon', PetStage.adult, dragonFlyWalkThreshold - 1),
        isFalse,
      );
      expect(fly('dragon', PetStage.teen, 1500), isFalse);
      expect(fly('dragon', PetStage.newborn, 1500), isFalse);
      expect(fly('dog', PetStage.adult, 1500), isFalse);
    });

    test('số hạt không vượt trần', () {
      for (final n in [
        dragonFireParticles,
        dragonWaterParticles,
        dragonSmallParticles,
      ]) {
        expect(n, lessThanOrEqualTo(dragonFxMaxParticles));
      }
    });
  });

  group('cổng hiệu ứng tắt', () {
    for (final a in DragonAction.values) {
      testWidgets('${a.name}: xong ngay, không treo pumpAndSettle', (
        tester,
      ) async {
        AnimationGate.enabled = false;
        final c = DragonFxController();
        addTearDown(c.dispose);
        await tester.pumpWidget(_host(c));
        c.play(a);
        await tester.pumpAndSettle();
        expect(c.lastAction, a);
        expect(c.playCount, 1);
        expect(c.busy, isFalse);
        expect(find.byKey(const Key('dragon-aura-code')), findsOneWidget);
      });
    }
  });

  group('cổng hiệu ứng bật', () {
    setUp(() => AnimationGate.enabled = true);

    for (final stage in PetStage.values.where((s) => s != PetStage.egg)) {
      for (final a in DragonAction.values) {
        testWidgets('${stage.name} ${a.name}: chạy rồi tự xong', (
          tester,
        ) async {
          final c = DragonFxController();
          addTearDown(c.dispose);
          await tester.pumpWidget(_host(c, stage: stage));
          c.play(a);
          await tester.pump();
          expect(c.busy, isTrue);
          expect(
            find.byKey(Key('dragon-fx-running-${a.name}')),
            findsOneWidget,
          );
          if (a == DragonAction.fly) {
            await _advance(
              tester,
              dragonActionMs(a, stage, artReady: false) ~/ 2,
            );
            expect(c.lift.value, greaterThan(0));
            expect(find.byKey(const Key('dragon-flutter')), findsOneWidget);
          } else {
            await _advance(tester, 300);
            expect(find.byKey(Key('dragon-breath-${a.name}')), findsOneWidget);
          }
          await _advance(
            tester,
            dragonActionMs(a, stage, artReady: false) + 200,
          );
          expect(c.busy, isFalse);
          expect(c.lift.value, 0);
          expect(find.byKey(Key('dragon-fx-running-${a.name}')), findsNothing);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }

    testWidgets('cờ hình bật + trưởng thành: phun lửa dùng khung hình thật', (
      tester,
    ) async {
      final c = DragonFxController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(c, art: true));
      expect(find.byKey(const Key('dragon-aura-art')), findsOneWidget);
      c.play(DragonAction.fire);
      await _advance(tester, 300);
      // Hình thật thay hạt vẽ code.
      expect(find.byKey(const Key('dragon-breath-fire')), findsNothing);
      final paths = tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => (i.image as AssetImage).assetName)
          .toList();
      expect(paths.any((p) => p.contains('dragon_fire_')), isTrue);
      await _advance(tester, dragonFxArtTotalMs + 100);
      expect(c.busy, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cờ hình bật nhưng rồng nhỏ: vẫn bản code', (tester) async {
      final c = DragonFxController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(c, stage: PetStage.teen, art: true));
      c.play(DragonAction.water);
      await _advance(tester, 300);
      expect(find.byKey(const Key('dragon-breath-water')), findsOneWidget);
      await _advance(tester, dragonSmallMs + 100);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('bay-đi: nâng lên khi cruising, hạ cánh khi hết', (
      tester,
    ) async {
      final c = DragonFxController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(c));
      c.setCruising(true);
      await _advance(tester, dragonCruiseLiftMs + 100);
      expect(c.lift.value, closeTo(dragonFlyLift, 0.05));
      expect(find.byKey(const Key('dragon-fx-cruising')), findsOneWidget);
      c.setCruising(false);
      await _advance(tester, dragonCruiseLiftMs + 100);
      expect(c.lift.value, 0);
      expect(find.byKey(const Key('dragon-fx-cruising')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cờ hình bật: bay-đi dùng khung fly', (tester) async {
      final c = DragonFxController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(c, art: true));
      c.setCruising(true);
      await _advance(tester, 600);
      final paths = tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => (i.image as AssetImage).assetName);
      expect(paths.any((p) => p.contains('dragon_fly_')), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('hủy giữa chừng thì dừng + hạ độ cao', (tester) async {
      final c = DragonFxController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(c));
      c.play(DragonAction.fly);
      await _advance(tester, 800);
      c.cancel();
      await tester.pump();
      expect(c.busy, isFalse);
      expect(c.lift.value, 0);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('vầng sáng + nút', () {
    testWidgets('chỉ bọc loài rồng', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: DragonAura.wrapIf('dragon', const SizedBox()),
              ),
              SizedBox(
                width: 80,
                height: 80,
                child: DragonAura.wrapIf('cat', const SizedBox()),
              ),
            ],
          ),
        ),
      );
      expect(find.byType(DragonAura), findsOneWidget);
    });

    testWidgets('vầng sáng code (golden-less): vẽ được ở cổng bật', (
      tester,
    ) async {
      AnimationGate.enabled = true;
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 200,
            height: 200,
            child: DragonAura(artReady: false, child: SizedBox()),
          ),
        ),
      );
      await _advance(tester, 1500);
      expect(find.byKey(const Key('dragon-aura-code')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('3 nút bấm được và vô hiệu khi bận', (tester) async {
      final got = <DragonAction>[];
      Future<void> pump(bool enabled) => tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: DragonActionMenu(enabled: enabled, onAction: got.add),
          ),
        ),
      );
      await pump(true);
      await tester.tap(find.byKey(const Key('dragon-fx-fire')));
      await tester.tap(find.byKey(const Key('dragon-fx-water')));
      await tester.tap(find.byKey(const Key('dragon-fx-fly')));
      expect(got, DragonAction.values);
      expect(find.text('Phun lửa'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      await pump(false);
      await tester.tap(find.byKey(const Key('dragon-fx-fire')));
      expect(got, hasLength(3));
    });
  });
}
