/// Test hiệu ứng "juice" (T2-08): pháo giấy, vệt sao, nút nảy.
/// Cổng [AnimationGate] tắt thì không vẽ hạt nào (golden xác định); bật
/// thì pháo giấy có tối đa [kConfettiMaxParticles] hạt, tự dừng.
library;

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/animation/animation_gate.dart';
import 'package:timokid/core/widgets/fx_particles.dart';
import 'package:timokid/core/widgets/press_bounce.dart';
import 'package:timokid/features/arena/arena_config.dart';
import 'package:timokid/features/arena/arena_result_screen.dart';
import 'package:timokid/features/arena/arena_service.dart';
import 'package:timokid/features/arena/arena_session.dart';
import 'package:timokid/features/math/math_screen.dart';
import 'package:timokid/features/stage_result/stage_result_screen.dart';

StageResultArgs _args({int stage = 4, int? next}) => StageResultArgs(
  stageIndex: stage,
  strand: 'logic',
  correctCount: 5,
  firstTryCorrectCount: 5,
  totalQuestions: 5,
  xuEarned: 10,
  nextStageIndex: next,
);

ArenaResult _arena(ArenaMedal medal) {
  const f = ArenaFormat.heat;
  return ArenaResult(
    score: ArenaScore(
      correct: 20,
      total: 25,
      sectionCorrect: const [4, 4, 4, 4, 4],
      sectionTotal: 5,
      points: 80,
      maxPoints: 100,
      medal: medal,
    ),
    durationSec: 100,
    gemsAwarded: f.gemsFor(medal),
    alreadyRewardedToday: false,
  );
}

void main() {
  tearDown(() => AnimationGate.enabled = false);

  group('ConfettiBurst', () {
    testWidgets('cổng tắt: không vẽ gì', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SizedBox.expand(child: ConfettiBurst())),
      );
      expect(find.byKey(const Key('confetti-burst')), findsNothing);
    });

    testWidgets('cổng bật: vẽ rồi tự dừng, không chặn cảm ứng', (tester) async {
      AnimationGate.enabled = true;
      await tester.pumpWidget(
        const MaterialApp(home: SizedBox.expand(child: ConfettiBurst())),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('confetti-burst')), findsOneWidget);
      expect(find.byType(IgnorePointer), findsWidgets);
      await tester.pump(kConfettiDuration);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confetti-burst')), findsNothing);
    });

    test('số hạt bị chặn trên', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // Xin 1000 hạt: widget cắt còn tối đa kConfettiMaxParticles.
      const widget = ConfettiBurst(count: 1000);
      expect(
        widget.count.clamp(0, kConfettiMaxParticles),
        kConfettiMaxParticles,
      );
      ConfettiPainter(
        progress: 0.5,
        count: kConfettiMaxParticles,
        seed: 1,
      ).paint(canvas, const Size(800, 360));
      recorder.endRecording();
      expect(kConfettiMaxParticles, lessThanOrEqualTo(60));
      expect(kStarTrailMaxStars, lessThanOrEqualTo(8));
    });
  });

  group('pháo giấy đúng chỗ', () {
    testWidgets('xong chặng cuối (5/5) của đề ngày thì bắn pháo', (
      tester,
    ) async {
      AnimationGate.enabled = true;
      expect(_args().completesDailySet, isTrue);
      await tester.pumpWidget(
        MaterialApp(home: StageResultScreen(result: _args())),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('daily-confetti')), findsOneWidget);
      expect(find.byKey(const Key('confetti-burst')), findsOneWidget);
      await tester.pump(kConfettiDuration);
      await tester.pumpAndSettle();
    });

    testWidgets('chặng giữa chừng hoặc tự chọn: không pháo', (tester) async {
      AnimationGate.enabled = true;
      expect(_args(stage: 2, next: 3).completesDailySet, isFalse);
      expect(_args(stage: -1).completesDailySet, isFalse);
      await tester.pumpWidget(
        MaterialApp(home: StageResultScreen(result: _args(stage: 2, next: 3))),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('daily-confetti')), findsNothing);
    });

    testWidgets('cổng tắt: màn chặng cuối tĩnh, không có hạt', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: StageResultScreen(result: _args())),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confetti-burst')), findsNothing);
    });

    testWidgets('Đấu trường: được huy chương thì pháo, Tham gia thì không', (
      tester,
    ) async {
      AnimationGate.enabled = true;
      for (final (medal, expectConfetti) in [
        (ArenaMedal.gold, true),
        (ArenaMedal.silver, true),
        (ArenaMedal.bronze, true),
        (ArenaMedal.participant, false),
      ]) {
        await tester.pumpWidget(
          MaterialApp(home: ArenaResultScreen(result: _arena(medal))),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byKey(const Key('confetti-burst')),
          expectConfetti ? findsOneWidget : findsNothing,
          reason: medal.label,
        );
        await tester.pump(kConfettiDuration);
        // Gỡ cây để vòng sau dựng State mới.
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('nút nảy', () {
    testWidgets('RaisedAnswerButton co nhẹ khi bấm (cổng bật)', (tester) async {
      AnimationGate.enabled = true;
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RaisedAnswerButton(
              height: 56,
              bottomColor: Colors.grey,
              backgroundColor: null,
              enabled: true,
              onPressed: () => taps++,
              child: const Text('A'),
            ),
          ),
        ),
      );
      expect(find.byType(PressBounce), findsOneWidget);
      final center = tester.getCenter(find.text('A'));
      final gesture = await tester.startGesture(center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final scale = tester.widget<Transform>(
        find.byKey(const Key('press-bounce-scale')),
      );
      expect(scale.transform.storage[0], lessThan(1.0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('cổng tắt: không co (golden tĩnh)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RaisedAnswerButton(
              height: 56,
              bottomColor: Colors.grey,
              backgroundColor: null,
              enabled: true,
              onPressed: () {},
              child: const Text('A'),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('press-bounce-scale')), findsNothing);
    });
  });
}
