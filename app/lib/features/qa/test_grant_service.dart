/// Tặng xu / kim cương cho bản thử (cờ `TEST_UNLOCKS`).
///
/// Ghi vào sổ ví bằng `refId` cố định nên chạy lại bao nhiêu lần cũng
/// chỉ tặng một lần: `test_grant_v1` cho lần đầu; sau đó nếu số dư một
/// loại tụt dưới [testTopUpBelow] thì nạp thêm [testGrantAmount] với
/// `test_topup_<n>` (n tăng dần, mỗi n một lần).
library;

import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import '../../core/test_build.dart';

class TestGrantService {
  TestGrantService({required this.db});

  final AppDatabase db;

  static const String grantRefId = 'test_grant_v1';
  static String topUpRefId(int n) => 'test_topup_$n';

  /// Tặng nếu cần. Trả true nếu vừa ghi thêm dòng nào vào sổ ví.
  Future<bool> grantIfNeeded(String childId) async {
    final wallet = db.walletDao;
    var wrote = false;
    if (!await wallet.hasEntryWithRefId(childId: childId, refId: grantRefId)) {
      for (final currency in [Currency.xu, Currency.gem]) {
        await wallet.addEntry(
          childId: childId,
          currency: currency,
          amount: testGrantAmount,
          reason: 'test_grant',
          refId: grantRefId,
        );
      }
      return true;
    }
    for (final currency in [Currency.xu, Currency.gem]) {
      final balance = await wallet.balance(
        childId: childId,
        currency: currency,
      );
      if (balance >= testTopUpBelow) continue;
      var n = 1;
      while (await wallet.hasEntryWithRefId(
        childId: childId,
        refId: topUpRefId(n),
      )) {
        n++;
      }
      await wallet.addEntry(
        childId: childId,
        currency: currency,
        amount: testGrantAmount,
        reason: 'test_topup',
        refId: topUpRefId(n),
      );
      wrote = true;
    }
    return wrote;
  }
}
