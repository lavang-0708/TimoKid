/// Cổng phụ huynh (T3-03): phép nhân ba chữ số; đúng mới qua.
library;

import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/features/auth/parent_gate.dart';

import '../../helpers/sync_harness.dart';

void main() {
  testWidgets(
    'trả lời đúng thì qua; sai thì báo và không qua; hủy thì không qua',
    (tester) async {
      final h = SyncHarness();
      bool? result;
      late BuildContext ctx;
      await h.pump(
        tester,
        goRouterFor((c) {
          ctx = c;
          return const SizedBox();
        }),
      );
      void open() =>
          showParentGate(ctx, random: Random(7)).then((v) => result = v);

      int answer() {
        final q = tester
            .widget<Text>(find.byKey(const Key('parent-gate-question')))
            .data!;
        final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
        final a = int.parse(m.group(1)!), b = int.parse(m.group(2)!);
        expect(a * b, inInclusiveRange(100, 999)); // tích ba chữ số
        return a * b;
      }

      // Sai.
      open();
      await tester.pumpAndSettle();
      final right = answer();
      await tester.enterText(
        find.byKey(const Key('parent-gate-input')),
        '${right + 1}',
      );
      await tester.tap(find.byKey(const Key('parent-gate-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Chưa đúng, thử lại nhé.'), findsOneWidget);
      expect(result, isNull); // vẫn mở

      // Đúng.
      await tester.enterText(
        find.byKey(const Key('parent-gate-input')),
        '$right',
      );
      await tester.tap(find.byKey(const Key('parent-gate-submit')));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.byKey(const Key('parent-gate')), findsNothing);

      // Hủy.
      result = null;
      open();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('parent-gate-cancel')));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    },
  );

  testWidgets('không tràn ở 608x248 kể cả khi bàn phím mở', (tester) async {
    final h = SyncHarness();
    late BuildContext ctx;
    await h.pump(
      tester,
      goRouterFor((c) {
        ctx = c;
        return const SizedBox();
      }),
      size: const Size(608, 248),
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 120);
    addTearDown(tester.view.resetViewInsets);
    showParentGate(ctx);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('parent-gate')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
