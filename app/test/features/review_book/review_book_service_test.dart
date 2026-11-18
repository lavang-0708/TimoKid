/// Unit test cho T1-10: sổ ôn tập.
///
/// Chạy trên DB trong bộ nhớ với [FakeClock]: ngày do test đặt nên kiểm
/// chứng được vòng mốc 1 → 3 → 7 ngày, quay về mốc 1 ngày khi sai, và
/// mục đến hạn / chưa đến hạn. Các kiểm tra bám theo PLAN mục T1-10 và
/// mục "Làm rõ" (f), (g).
///
/// "Đúng sau gợi ý" ở đây được thể hiện bằng `correctFirstTry: false`
/// (phía ghi `attempts` ở T1-09 chịu trách nhiệm đặt cờ này false cho
/// câu đúng sau gợi ý, theo mục (f)).
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/review_book/review_book_config.dart';
import 'package:timokid/features/review_book/review_book_service.dart';

AppDatabase openMemoryDb({Clock? clock}) => AppDatabase(
  executor: NativeDatabase.memory(),
  clock: clock ?? const SystemClock(),
);

void main() {
  group('ReviewBookConfig: hằng số mốc ngày', () {
    test('cần 3 lần đúng ngay liên tiếp thì ra khỏi sổ', () {
      expect(ReviewBookConfig.requiredStreak, 3);
    });

    test('mốc hỏi lại: chuỗi 0 → 1 ngày, 1 → 3 ngày, 2 → 7 ngày', () {
      expect(ReviewBookConfig.intervalDays, [1, 3, 7]);
      expect(ReviewBookConfig.dueDelayForStreak(0), const Duration(days: 1));
      expect(ReviewBookConfig.dueDelayForStreak(1), const Duration(days: 3));
      expect(ReviewBookConfig.dueDelayForStreak(2), const Duration(days: 7));
      expect(ReviewBookConfig.retryDays, 1);
    });
  });

  group('ReviewBookService', () {
    late FakeClock clock;
    late AppDatabase db;
    late ReviewBookService book;
    late String childId;

    setUp(() async {
      clock = FakeClock(DateTime(2026, 11, 18, 8, 0));
      db = openMemoryDb(clock: clock);
      addTearDown(db.close);
      book = ReviewBookService(reviewQueueDao: db.reviewQueueDao, clock: clock);
      childId = await db.ensureSeeded();
    });

    test(
      'câu thường sai thì vào sổ: bậc lưu, chuỗi 0, hỏi lại sau 1 ngày',
      () async {
        await book.recordAnswer(
          childId: childId,
          formId: 'logic.balance',
          rung: 2,
          correctFirstTry: false,
        );

        final entry = await db.reviewQueueDao.getEntry(
          childId,
          'logic.balance',
        );
        expect(entry, isNotNull);
        expect(entry!.rung, 2);
        expect(entry.correctStreak, 0);
        expect(entry.dueDate, DateTime(2026, 11, 19, 8, 0));

        // Chưa đến hạn: chưa có mục nào.
        expect(await book.dueEntries(childId: childId), isEmpty);
        // Qua 1 ngày 1 phút: đến hạn.
        clock.advance(const Duration(days: 1, minutes: 1));
        final due = await book.dueEntries(childId: childId);
        expect(due.map((e) => e.formId), ['logic.balance']);
      },
    );

    test('câu thường đúng ngay lần đầu thì không vào sổ', () async {
      await book.recordAnswer(
        childId: childId,
        formId: 'logic.balance',
        rung: 2,
        correctFirstTry: true,
      );

      expect(await book.allEntries(childId: childId), isEmpty);
    });

    test(
      'vòng đầy đủ 1 → 3 → 7 ngày rồi ra khỏi sổ sau lần đúng thứ 3',
      () async {
        await book.recordAnswer(
          childId: childId,
          formId: 'logic.balance',
          rung: 2,
          correctFirstTry: false,
        );

        // Mốc 1 ngày: đúng lần 1 → chuỗi 1, hỏi lại sau 3 ngày.
        clock.advance(const Duration(days: 1, minutes: 1));
        expect(
          await book.recordReviewAnswer(
            childId: childId,
            formId: 'logic.balance',
            rung: 2,
            correctFirstTry: true,
          ),
          ReviewAnswerOutcome.streakAdvanced,
        );
        var entry = await db.reviewQueueDao.getEntry(childId, 'logic.balance');
        expect(entry!.correctStreak, 1);
        expect(entry.dueDate, DateTime(2026, 11, 22, 8, 1));

        // Chưa đủ 3 ngày: chưa đến hạn.
        clock.advance(const Duration(days: 2));
        expect(await book.dueEntries(childId: childId), isEmpty);
        // Đủ 3 ngày: đến hạn. Đúng lần 2 → chuỗi 2, hỏi lại sau 7 ngày.
        clock.advance(const Duration(days: 1, minutes: 1));
        expect(
          await book.recordReviewAnswer(
            childId: childId,
            formId: 'logic.balance',
            rung: 2,
            correctFirstTry: true,
          ),
          ReviewAnswerOutcome.streakAdvanced,
        );
        entry = await db.reviewQueueDao.getEntry(childId, 'logic.balance');
        expect(entry!.correctStreak, 2);
        expect(entry.dueDate, DateTime(2026, 11, 29, 8, 2));

        // Chưa đủ 7 ngày: chưa đến hạn.
        clock.advance(const Duration(days: 6));
        expect(await book.dueEntries(childId: childId), isEmpty);
        // Đủ 7 ngày: đến hạn. Đúng lần 3 → ra khỏi sổ.
        clock.advance(const Duration(days: 1, minutes: 1));
        expect(
          await book.recordReviewAnswer(
            childId: childId,
            formId: 'logic.balance',
            rung: 2,
            correctFirstTry: true,
          ),
          ReviewAnswerOutcome.graduated,
        );
        expect(
          await db.reviewQueueDao.getEntry(childId, 'logic.balance'),
          isNull,
        );
        expect(await book.allEntries(childId: childId), isEmpty);
      },
    );

    test('sai ở mốc chuỗi 1 thì quay về mốc 1 ngày', () async {
      await book.recordAnswer(
        childId: childId,
        formId: 'logic.balance',
        rung: 2,
        correctFirstTry: false,
      );
      clock.advance(const Duration(days: 1, minutes: 1));
      await book.recordReviewAnswer(
        childId: childId,
        formId: 'logic.balance',
        rung: 2,
        correctFirstTry: true,
      );

      // Sai ở lần hỏi lại thứ hai: chuỗi về 0, hỏi lại sau 1 ngày.
      clock.advance(const Duration(days: 3, minutes: 1));
      expect(
        await book.recordReviewAnswer(
          childId: childId,
          formId: 'logic.balance',
          rung: 2,
          correctFirstTry: false,
        ),
        ReviewAnswerOutcome.reset,
      );
      final entry = await db.reviewQueueDao.getEntry(childId, 'logic.balance');
      expect(entry!.correctStreak, 0);
      expect(entry.dueDate, DateTime(2026, 11, 23, 8, 2));

      // Lại đúng ngay 3 lần liên tiếp thì vẫn ra khỏi sổ (vòng làm lại).
      clock.advance(const Duration(days: 1, minutes: 1));
      await book.recordReviewAnswer(
        childId: childId,
        formId: 'logic.balance',
        rung: 2,
        correctFirstTry: true,
      );
      clock.advance(const Duration(days: 3, minutes: 1));
      await book.recordReviewAnswer(
        childId: childId,
        formId: 'logic.balance',
        rung: 2,
        correctFirstTry: true,
      );
      clock.advance(const Duration(days: 7, minutes: 1));
      expect(
        await book.recordReviewAnswer(
          childId: childId,
          formId: 'logic.balance',
          rung: 2,
          correctFirstTry: true,
        ),
        ReviewAnswerOutcome.graduated,
      );
      expect(
        await db.reviewQueueDao.getEntry(childId, 'logic.balance'),
        isNull,
      );
    });

    test('sai ở mốc chuỗi 2 thì quay về mốc 1 ngày', () async {
      await book.recordAnswer(
        childId: childId,
        formId: 'logic.balance',
        rung: 2,
        correctFirstTry: false,
      );
      clock.advance(const Duration(days: 1, minutes: 1));
      await book.recordReviewAnswer(
        childId: childId,
        formId: 'logic.balance',
        rung: 2,
        correctFirstTry: true,
      );
      clock.advance(const Duration(days: 3, minutes: 1));
      await book.recordReviewAnswer(
        childId: childId,
        formId: 'logic.balance',
        rung: 2,
        correctFirstTry: true,
      );

      // Sai ở lần hỏi lại thứ ba: chuỗi về 0, hỏi lại sau 1 ngày.
      clock.advance(const Duration(days: 7, minutes: 1));
      expect(
        await book.recordReviewAnswer(
          childId: childId,
          formId: 'logic.balance',
          rung: 2,
          correctFirstTry: false,
        ),
        ReviewAnswerOutcome.reset,
      );
      final entry = await db.reviewQueueDao.getEntry(childId, 'logic.balance');
      expect(entry!.correctStreak, 0);
      expect(entry.dueDate, DateTime(2026, 11, 30, 8, 3));
    });

    test('đúng sau gợi ý tính như sai: vào sổ và quay về mốc 1 ngày', () async {
      // Câu thường đúng sau gợi ý (correctFirstTry false) thì vào sổ.
      await book.recordAnswer(
        childId: childId,
        formId: 'logic.balance',
        rung: 2,
        correctFirstTry: false,
      );
      expect((await book.allEntries(childId: childId)).length, 1);

      // Câu ôn tập đúng sau gợi ý thì chuỗi về 0, hỏi lại sau 1 ngày.
      clock.advance(const Duration(days: 1, minutes: 1));
      await book.recordReviewAnswer(
        childId: childId,
        formId: 'logic.balance',
        rung: 2,
        correctFirstTry: true,
      );
      clock.advance(const Duration(days: 3, minutes: 1));
      expect(
        await book.recordReviewAnswer(
          childId: childId,
          formId: 'logic.balance',
          rung: 2,
          correctFirstTry: false,
        ),
        ReviewAnswerOutcome.reset,
      );
      final entry = await db.reviewQueueDao.getEntry(childId, 'logic.balance');
      expect(entry!.correctStreak, 0);
      expect(entry.dueDate, DateTime(2026, 11, 23, 8, 2));
    });

    test(
      'một dạng chỉ có một mục: gặp lại thì cập nhật bậc, đặt lại mốc',
      () async {
        await book.recordAnswer(
          childId: childId,
          formId: 'logic.balance',
          rung: 2,
          correctFirstTry: false,
        );
        clock.advance(const Duration(hours: 2));
        await book.recordAnswer(
          childId: childId,
          formId: 'logic.balance',
          rung: 4,
          correctFirstTry: false,
        );

        final entries = await book.allEntries(childId: childId);
        expect(entries.length, 1);
        expect(entries.single.formId, 'logic.balance');
        expect(entries.single.rung, 4);
        expect(entries.single.correctStreak, 0);
        expect(entries.single.dueDate, DateTime(2026, 11, 19, 10, 0));
      },
    );

    test('câu thường đúng ngay không động vào sổ (chuỗi không tăng)', () async {
      await book.recordAnswer(
        childId: childId,
        formId: 'logic.balance',
        rung: 2,
        correctFirstTry: false,
      );
      clock.advance(const Duration(days: 1, minutes: 1));
      await book.recordReviewAnswer(
        childId: childId,
        formId: 'logic.balance',
        rung: 2,
        correctFirstTry: true,
      );
      final before = await db.reviewQueueDao.getEntry(childId, 'logic.balance');

      // Đúng ngay ở câu thường: sổ không đổi (chuỗi vẫn 1, mốc vẫn cũ).
      await book.recordAnswer(
        childId: childId,
        formId: 'logic.balance',
        rung: 2,
        correctFirstTry: true,
      );
      final after = await db.reviewQueueDao.getEntry(childId, 'logic.balance');
      expect(after!.correctStreak, before!.correctStreak);
      expect(after.dueDate, before.dueDate);
      expect(after.rung, before.rung);
    });

    test('câu ôn tập của dạng chưa vào sổ thì không làm gì', () async {
      expect(
        await book.recordReviewAnswer(
          childId: childId,
          formId: 'logic.balance',
          rung: 2,
          correctFirstTry: true,
        ),
        ReviewAnswerOutcome.noEntry,
      );
      expect(await book.allEntries(childId: childId), isEmpty);
    });

    test('mục đến hạn xếp theo ngày hỏi lại, sớm nhất trước', () async {
      await book.recordAnswer(
        childId: childId,
        formId: 'logic.balance',
        rung: 2,
        correctFirstTry: false,
      );
      clock.advance(const Duration(hours: 2));
      await book.recordAnswer(
        childId: childId,
        formId: 'geo.sides',
        rung: 1,
        correctFirstTry: false,
      );

      // 22 tiếng 1 phút sau (11-19 08:01): chỉ dạng đầu đến hạn
      // (đến 08:00), dạng sau đến 10:00 nên chưa đến hạn.
      clock.advance(const Duration(hours: 22, minutes: 1));
      expect((await book.dueEntries(childId: childId)).map((e) => e.formId), [
        'logic.balance',
      ]);
      // Thêm 2 tiếng: cả hai đến hạn, sớm nhất trước.
      clock.advance(const Duration(hours: 2));
      expect((await book.dueEntries(childId: childId)).map((e) => e.formId), [
        'logic.balance',
        'geo.sides',
      ]);
      // Toàn bộ sổ cũng xếp cùng thứ tự.
      expect((await book.allEntries(childId: childId)).map((e) => e.formId), [
        'logic.balance',
        'geo.sides',
      ]);
    });
  });
}
