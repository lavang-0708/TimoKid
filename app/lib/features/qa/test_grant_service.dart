/// Tặng xu / kim cương cho bản thử (cờ `TEST_UNLOCKS`).
///
/// Ghi vào sổ ví bằng `refId` cố định nên chạy lại bao nhiêu lần cũng
/// chỉ tặng một lần: `test_grant_v1` cho lần đầu; sau đó nếu số dư một
/// loại tụt dưới [testTopUpBelow] thì nạp thêm [testGrantAmount] với
/// `test_topup_<n>` (n tăng dần, mỗi n một lần).
library;

import 'package:drift/drift.dart' show Variable;

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

/// Dọn dấu vết bản thử khỏi máy khi chạy BẢN CHÍNH THỨC (cờ `TEST_UNLOCKS`
/// tắt) trên máy từng cài bản thử. Chạy đúng một lần (khóa
/// [doneKey], chỉ trên máy, tiền tố `sync_` nên không đồng bộ):
///
/// 1. Xóa mọi dòng ví có lý do trong `testWalletReasons` (tặng 10.000 xu và
///    kim cương, nạp lại). Sổ ví là append-only (trigger SQLite), nên
///    KHÔNG ghi dòng bù ("ngược") lên sổ: dòng bù sẽ được gửi lên server và
///    hiện thành giao dịch thật trong thống kê. Thay vào đó xóa cục bộ có
///    kiểm soát qua `AppDatabase.purgeWalletRowsByReason` (tạm bỏ trigger
///    xóa trong một giao dịch rồi tạo lại).
/// 2. Số dư của bé có thể âm (bé đã tiêu xu của bản thử). Bù về 0 bằng một
///    dòng `test_cleanup` chỉ nằm trên máy: đánh dấu `synced = 1` ngay và
///    bộ đồng bộ cũng bỏ qua mọi dòng thuộc `testWalletReasons`.
///
/// Đồ bé đã mua hay mở khóa bằng xu của bản thử vẫn giữ nguyên.
class TestGrantCleanup {
  TestGrantCleanup({required this.db});

  final AppDatabase db;

  static const String doneKey = 'sync_test_grants_cleaned_v1';

  /// Dọn nếu chưa dọn. Trả số dòng đã xóa (0 nếu đã dọn trước đó).
  Future<int> runIfNeeded() async {
    if (await db.settingsDao.getValue(key: doneKey) != null) return 0;
    final removed = await db.purgeWalletRowsByReason(testWalletReasons);
    if (removed > 0) {
      for (final child in await db.childrenDao.getAllChildren()) {
        for (final currency in [Currency.xu, Currency.gem]) {
          final balance = await db.walletDao.balance(
            childId: child.id,
            currency: currency,
          );
          if (balance >= 0) continue;
          final id = await db.walletDao.addEntry(
            childId: child.id,
            currency: currency,
            amount: -balance,
            reason: 'test_cleanup',
          );
          await db.customUpdate(
            'UPDATE wallet_ledger SET synced = 1 WHERE id = ?',
            variables: [Variable.withString(id)],
            updates: const {},
          );
        }
      }
    }
    await db.settingsDao.setValue(key: doneKey, value: 'true');
    return removed;
  }
}
