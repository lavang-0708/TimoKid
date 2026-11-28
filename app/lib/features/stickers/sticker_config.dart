/// Cấu hình Sổ sticker (T4-03): hằng số và cờ hình ở một chỗ.
///
/// Mỗi dạng bài bé THÀNH THẠO (xem `LadderService.evaluateFormMastery`)
/// được một sticker và [StickerConfig.gemsPerSticker] kim cương, đúng một
/// lần cho mỗi sticker (dòng ví có `refId` `sticker:<mã dạng>`).
library;

/// Đã có hình sticker (khung huy hiệu theo mảng, ổ khóa) chưa. `false`:
/// sticker là huy hiệu vẽ bằng code (màu mảng + tên dạng). `true`: dùng ảnh
/// [StickerConfig.frameAsset] / [StickerConfig.lockedAsset] / ảnh sổ.
/// Khi Muse giao lô 17 (`docs/briefs/lot17_v04.md`): thêm
/// `assets/images/stickers/` vào `pubspec.yaml`, đặt cờ `true`.
const bool stickerArtReady = false;

/// Đã có biểu tượng riêng cho TỪNG dạng bài (90 ảnh, tùy chọn) chưa. Chỉ
/// có nghĩa khi [stickerArtReady] cũng bật. Tách riêng vì 90 ảnh vẽ sau 5
/// huy hiệu mảng: khi bật, huy hiệu = `sticker_base_<mảng>` + biểu tượng.
const bool stickerFormIconArtReady = false;

class StickerConfig {
  const StickerConfig._();

  /// Kim cương thưởng cho mỗi sticker mới.
  static const int gemsPerSticker = 2;

  /// Lý do dòng ví (`wallet_ledger.reason`).
  static const String ledgerReason = 'sticker_award';

  /// Tiền tố khóa `settings` của sticker đã nhận: `sticker.<mã dạng>`,
  /// giá trị là ngày nhận (JSON). Khóa của bé nên tự đồng bộ.
  static const String earnedPrefix = 'sticker.';

  /// Tiền tố khóa đã chúc mừng: `sticker_seen.<mã dạng>`.
  static const String seenPrefix = 'sticker_seen.';

  /// Số sticker tối đa hiện trong cửa sổ chúc mừng (còn lại gộp "và N khác").
  static const int maxShownInPopup = 4;

  static String refId(String formId) => 'sticker:$formId';

  static String earnedKey(String formId) => '$earnedPrefix$formId';
  static String seenKey(String formId) => '$seenPrefix$formId';

  /// Ảnh khi [stickerArtReady] bật.
  static String frameAsset(String strand) =>
      'assets/images/stickers/sticker_frame_$strand.webp';
  static const String lockedAsset =
      'assets/images/stickers/sticker_locked.webp';
  static const String bookCoverAsset =
      'assets/images/stickers/sticker_book_cover.webp';

  /// Huy hiệu trống của mảng (không có biểu tượng giữa), dùng khi có biểu
  /// tượng riêng từng dạng ([stickerFormIconArtReady]): app đặt biểu tượng
  /// của dạng lên giữa huy hiệu này.
  static String baseAsset(String strand) =>
      'assets/images/stickers/sticker_base_$strand.webp';

  /// Tỉ lệ biểu tượng dạng so với huy hiệu khi đặt lên [baseAsset].
  static const double formIconScale = 0.62;

  /// Biểu tượng riêng của một dạng ([stickerFormIconArtReady]).
  static String formIconAsset(String formId) =>
      'assets/images/stickers/form_${formId.replaceAll('.', '_')}.webp';
}
