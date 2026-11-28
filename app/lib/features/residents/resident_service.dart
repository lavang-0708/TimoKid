/// Chọn lời thoại cư dân theo ngày (T4-02).
///
/// Lời thoại chọn XÁC ĐỊNH theo (ngày, cư dân, nhóm, phụ) bằng băm FNV-1a:
/// cùng ngày bé thấy cùng một câu (không nhảy lung tung khi mở lại màn),
/// sang ngày khác đổi câu, và golden test ổn định. KHÔNG dùng mã bé trong
/// hạt giống (mã bé là UUID ngẫu nhiên nên làm golden đổi mỗi lần chạy).
library;

import 'dart:convert';

import '../../core/database/app_database.dart';
import '../onboarding/onboarding_service.dart';
import '../unlocks/unlock_service.dart';
import 'resident_config.dart';
import 'resident_content.dart';

/// FNV-1a 32 bit: băm ổn định giữa các lần chạy và nền tảng (khác
/// `String.hashCode`).
int stableHash(String s) {
  var h = 0x811C9DC5;
  for (final c in utf8.encode(s)) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// Thay `{ten}` bằng tên bé (rỗng thì "bé").
String fillChildName(String line, String? childName) {
  final name = (childName ?? '').trim();
  return line.replaceAll(
    ResidentConfig.namePlaceholder,
    name.isEmpty ? ResidentConfig.fallbackChildName : name,
  );
}

/// Hạt giống chọn câu: chỉ phụ thuộc ngày, cư dân, nhóm và phần phụ
/// [extra] (vd chặng nào) — không phụ thuộc bé.
String residentSeed(
  String date,
  String residentId,
  LineKind kind, [
  String extra = '',
]) => '$date|$residentId|${kind.key}|$extra';

/// Chọn một câu của [resident] ở nhóm [kind] cho [date]; đã thay `{ten}`.
/// [variant] > 0 để lấy câu kế tiếp (bé chạm cư dân để nghe câu khác).
/// Nhóm rỗng thì trả chuỗi rỗng.
String pickResidentLine(
  Resident resident,
  LineKind kind, {
  required String date,
  String? childName,
  String extra = '',
  int variant = 0,
}) {
  final lines = resident.linesOf(kind);
  if (lines.isEmpty) return '';
  final index =
      (stableHash(residentSeed(date, resident.id, kind, extra)) + variant) %
      lines.length;
  return fillChildName(lines[index], childName);
}

/// Mọi thứ màn hình cần để chọn lời thoại: nội dung, tên bé, ngày và đã mở
/// lời đặc biệt chưa.
class ResidentContext {
  const ResidentContext({
    required this.book,
    required this.childName,
    required this.date,
    required this.specialUnlocked,
  });

  final ResidentBook book;
  final String? childName;
  final String date;
  final bool specialUnlocked;

  Resident? residentFor(String strand) => book.forStrand(strand);
}

/// Dựng [ResidentContext] cho bé [childId]. Lỗi (không đọc được file nội
/// dung, ...) thì trả null để màn chạy tiếp không có cư dân.
Future<ResidentContext?> loadResidentContext(
  AppDatabase db,
  String childId,
) async {
  try {
    final book = await ResidentBook.load();
    final profile = await OnboardingService(db: db).loadProfile(childId);
    final mastered = await UnlockService(db: db).masteredCount(childId);
    return ResidentContext(
      book: book,
      childName: profile?.name,
      date: db.clock.today(),
      specialUnlocked: UnlockService.specialDialogueUnlocked(mastered),
    );
  } catch (_) {
    return null;
  }
}
