import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/qa/debug_clock.dart';

void main() {
  group('DebugClock', () {
    test('chưa lệch thì now()/today() đúng bằng đồng hồ gốc', () {
      final base = FakeClock(DateTime.utc(2026, 11, 19, 20, 0));
      final debug = DebugClock(base);

      expect(debug.now(), DateTime.utc(2026, 11, 19, 20, 0));
      expect(debug.today(), '2026-11-19');
      expect(debug.offset, Duration.zero);
      expect(debug.isAdvanced, isFalse);
    });

    test('advanceBy cộng vào now() và today()', () {
      final base = FakeClock(DateTime.utc(2026, 11, 19, 20, 0));
      final debug = DebugClock(base);

      debug.advanceBy(const Duration(days: 1));
      expect(debug.now(), DateTime.utc(2026, 11, 20, 20, 0));
      expect(debug.today(), '2026-11-20');
      expect(debug.offset, const Duration(days: 1));
      expect(debug.isAdvanced, isTrue);

      // Nhảy tiếp 1 ngày nữa thì cộng dồn.
      debug.advanceBy(const Duration(days: 1));
      expect(debug.today(), '2026-11-21');
      expect(debug.offset, const Duration(days: 2));
    });

    test('reset về lại ngày thật', () {
      final base = FakeClock(DateTime.utc(2026, 11, 19, 20, 0));
      final debug = DebugClock(base);

      debug.advanceBy(const Duration(days: 3));
      debug.reset();
      expect(debug.now(), DateTime.utc(2026, 11, 19, 20, 0));
      expect(debug.today(), '2026-11-19');
      expect(debug.offset, Duration.zero);
      expect(debug.isAdvanced, isFalse);
    });

    test('đồng hồ gốc trôi thì DebugClock trôi theo (cộng lệch)', () {
      final base = FakeClock(DateTime.utc(2026, 11, 19, 20, 0));
      final debug = DebugClock(base);
      debug.advanceBy(const Duration(days: 1));

      base.advance(const Duration(hours: 5));
      expect(debug.now(), DateTime.utc(2026, 11, 21, 1, 0));
      expect(debug.today(), '2026-11-21');
    });
  });
}
