/// Sổ sticker (T4-03): mỗi dạng bài bé THÀNH THẠO được một sticker và
/// [StickerConfig.gemsPerSticker] kim cương, một lần duy nhất.
///
/// Lưu trữ (không đổi schema, không cần migration máy chủ):
/// - sticker đã nhận: `settings` của bé, khóa `sticker.<mã dạng>`, giá trị
///   là ngày nhận (JSON) — `settings` của bé tự đồng bộ;
/// - kim cương: dòng `wallet_ledger` `refId = sticker:<mã dạng>`. Có cả hai
///   lớp chống trùng: dù khóa settings mất (đồng bộ lệch) mà dòng ví còn
///   thì không cộng lần hai, và ngược lại.
/// - đã chúc mừng: `sticker_seen.<mã dạng>`.
library;

import 'dart:convert';

import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import '../questions/question_registry.dart';
import 'sticker_config.dart';

/// Mọi dạng bài của một mảng, theo thứ tự trong [allQuestionGenerators].
List<String> formIdsOfStrand(String strand) => [
  for (final g in allQuestionGenerators)
    if (g.topic == strand) g.formId,
];

/// Mọi dạng bài của cả 5 mảng.
List<String> get allFormIds => [
  for (final s in Strand.all) ...formIdsOfStrand(s),
];

/// Mảng của một mã dạng (`logic.age` -> `logic`).
String strandOfForm(String formId) => formId.split('.').first;

/// Tiến độ sổ sticker của một bé.
class StickerProgress {
  const StickerProgress({required this.earned, required this.newForms});

  /// Mã dạng đã có sticker.
  final Set<String> earned;

  /// Mã dạng có sticker mà bé chưa được chúc mừng.
  final Set<String> newForms;

  int get total => earned.length;

  int earnedInStrand(String strand) =>
      earned.where((f) => strandOfForm(f) == strand).length;

  int totalInStrand(String strand) => formIdsOfStrand(strand).length;
}

class StickerService {
  StickerService({required this.db});

  final AppDatabase db;

  /// Mã dạng bé đã có sticker.
  Future<Set<String>> earned(String childId) async {
    final rows = await db.settingsDao.getAllSettings(childId: childId);
    return {
      for (final r in rows)
        if (r.key.startsWith(StickerConfig.earnedPrefix))
          r.key.substring(StickerConfig.earnedPrefix.length),
    };
  }

  Future<Set<String>> _seen(String childId) async {
    final rows = await db.settingsDao.getAllSettings(childId: childId);
    return {
      for (final r in rows)
        if (r.key.startsWith(StickerConfig.seenPrefix))
          r.key.substring(StickerConfig.seenPrefix.length),
    };
  }

  /// Cấp sticker + kim cương cho mọi dạng đã thành thạo mà chưa có sticker.
  /// Chạy lại bao nhiêu lần cũng được (không cộng trùng). Trả mã các dạng
  /// vừa được cấp sticker lần này.
  Future<List<String>> awardPending(String childId) {
    return db.transaction(() async {
      final mastered = await db.skillProgressDao.getMasteredForms(childId);
      final known = allFormIds.toSet();
      final have = await earned(childId);
      final awarded = <String>[];
      for (final row in mastered) {
        final formId = row.key;
        if (!known.contains(formId) || have.contains(formId)) continue;
        await db.settingsDao.setValue(
          childId: childId,
          key: StickerConfig.earnedKey(formId),
          value: jsonEncode(db.clock.today()),
        );
        final ref = StickerConfig.refId(formId);
        if (!await db.walletDao.hasEntryWithRefId(
          childId: childId,
          refId: ref,
        )) {
          await db.walletDao.addEntry(
            childId: childId,
            currency: Currency.gem,
            amount: StickerConfig.gemsPerSticker,
            reason: StickerConfig.ledgerReason,
            refId: ref,
          );
        }
        awarded.add(formId);
      }
      return awarded;
    });
  }

  /// Tiến độ hiện tại (đã nhận gì, cái nào chưa chúc mừng).
  Future<StickerProgress> progress(String childId) async {
    final have = await earned(childId);
    final seen = await _seen(childId);
    return StickerProgress(earned: have, newForms: have.difference(seen));
  }

  /// Sticker đã có mà chưa chúc mừng, theo thứ tự trong sổ.
  Future<List<String>> pendingCelebrations(String childId) async {
    final p = await progress(childId);
    return [
      for (final f in allFormIds)
        if (p.newForms.contains(f)) f,
    ];
  }

  /// Đánh dấu đã chúc mừng (cửa sổ chỉ hiện một lần cho mỗi sticker).
  Future<void> markSeen(String childId, Iterable<String> formIds) async {
    for (final f in formIds) {
      await db.settingsDao.setValue(
        childId: childId,
        key: StickerConfig.seenKey(f),
        value: '1',
      );
    }
  }
}
