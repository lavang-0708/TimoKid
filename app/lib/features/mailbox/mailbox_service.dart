/// Hộp thư và quà từ bố (T3-06, phía app).
///
/// Thư do bộ đồng bộ tải về bảng `messages` (xem `sync_engine.dart`). Mở
/// quà gọi `rpc/claim_message`: server trả `claimed = true` đúng một lần.
/// Quà chỉ vào ví/tủ khi `claimed = true` VÀ chưa có dòng `wallet_ledger`
/// nào mang `ref_id` = id thư, nên quà không cộng hai lần kể cả khi gọi
/// lại hay đồng bộ lại (SYNC.md, mục "Đồng bộ chiều xuống").
library;

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/database/tables.dart' show Currency;
import '../../core/sync/neon_client.dart';

/// Lý do ghi trong `wallet_ledger` cho quà từ thư.
const mailGiftReason = 'mail_gift';

/// Nguồn của món đồ nhận từ thư trong `inventory`.
const mailGiftSource = 'gift';

enum ClaimStatus {
  /// Vừa nhận quà (đã cộng vào ví/tủ).
  claimed,

  /// Quà đã nhận trước đó (không cộng lại).
  alreadyClaimed,

  /// Thư không có quà.
  noGift,

  /// Không gọi được server (mạng, đăng nhập...). Chưa mất gì, thử lại được.
  failed,
}

class ClaimResult {
  const ClaimResult(
    this.status, {
    this.xu = 0,
    this.gems = 0,
    this.itemId,
    this.message,
  });

  final ClaimStatus status;
  final int xu;
  final int gems;
  final String? itemId;
  final String? message;
}

extension MessageGift on Message {
  bool get hasGift => giftXu > 0 || giftGem > 0 || giftItemId != null;
}

class MailboxService {
  MailboxService({required this.db, this.client});

  final AppDatabase db;

  /// Cần khi nhận quà (gọi server); chỉ đọc thư thì bỏ trống.
  final NeonClient? client;

  /// Thư của bé, mới nhất trước.
  Future<List<Message>> list(String childId) =>
      (db.select(db.messages)
            ..where((t) => t.childId.equals(childId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<Message?> get(String id) =>
      (db.select(db.messages)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Số thư chưa mở (hiện chấm đỏ).
  Future<int> unreadCount(String childId) async {
    final rows = await (db.select(
      db.messages,
    )..where((t) => t.childId.equals(childId) & t.openedAt.isNull())).get();
    return rows.length;
  }

  /// Đánh dấu bé đã mở thư; bộ đồng bộ gửi `opened_at` lên server.
  Future<void> markRead(String id) => db.customUpdate(
    'UPDATE messages SET opened_at = ?, updated_at = ?, synced = 0 '
    'WHERE id = ? AND opened_at IS NULL',
    variables: [
      Variable.withInt(_sec(db.clock.now())),
      Variable.withInt(_sec(db.clock.now())),
      Variable.withString(id),
    ],
    updates: const {},
  );

  int _sec(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  /// Mở quà của thư [id]: gọi `claim_message`, cộng quà đúng một lần.
  Future<ClaimResult> claim(String id) async {
    final msg = await get(id);
    if (msg == null || !msg.hasGift) {
      return const ClaimResult(ClaimStatus.noGift);
    }
    if (msg.claimedAt != null) {
      return const ClaimResult(ClaimStatus.alreadyClaimed);
    }
    final api = client;
    if (api == null) {
      return const ClaimResult(ClaimStatus.failed, message: 'Chưa đăng nhập.');
    }
    final Object? body;
    try {
      body = (await api.api(
        'POST',
        'rpc/claim_message',
        body: {'p_message_id': id},
      )).body;
    } on NeonException catch (e) {
      return ClaimResult(ClaimStatus.failed, message: e.message);
    }
    final row = body is List && body.isNotEmpty
        ? body.first
        : (body is Map ? body : null);
    if (row is! Map) {
      return const ClaimResult(
        ClaimStatus.failed,
        message: 'Máy chủ trả lời không đúng.',
      );
    }
    final claimed = row['claimed'] == true;
    final xu = (row['gift_xu'] as num?)?.toInt() ?? 0;
    final gems = (row['gift_gem'] as num?)?.toInt() ?? 0;
    final item = row['gift_item_id'] as String?;
    final now = db.clock.now();

    return db.transaction(() async {
      if (claimed) {
        // Chặn cộng trùng ở máy: đã có dòng ví mang id thư thì thôi.
        final hasLedger = await db.walletDao.hasEntryWithRefId(
          childId: msg.childId,
          refId: id,
        );
        if (!hasLedger) {
          if (xu > 0) {
            await db.walletDao.addEntry(
              childId: msg.childId,
              currency: Currency.xu,
              amount: xu,
              reason: mailGiftReason,
              refId: id,
            );
          }
          if (gems > 0) {
            await db.walletDao.addEntry(
              childId: msg.childId,
              currency: Currency.gem,
              amount: gems,
              reason: mailGiftReason,
              refId: id,
            );
          }
        }
        if (item != null) {
          // `grant` bỏ qua nếu bé đã có món này.
          await db.inventoryDao.grant(
            childId: msg.childId,
            itemId: item,
            source: mailGiftSource,
          );
        }
      }
      // Server đã ghi claimed_at/opened_at nên không cần gửi lại (synced).
      await db.customUpdate(
        'UPDATE messages SET claimed_at = COALESCE(claimed_at, ?), '
        'opened_at = COALESCE(opened_at, ?), synced = 1 WHERE id = ?',
        variables: [
          Variable.withInt(_sec(now)),
          Variable.withInt(_sec(now)),
          Variable.withString(id),
        ],
        updates: const {},
      );
      if (!claimed) return const ClaimResult(ClaimStatus.alreadyClaimed);
      return ClaimResult(ClaimStatus.claimed, xu: xu, gems: gems, itemId: item);
    });
  }
}
