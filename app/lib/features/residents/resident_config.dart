/// Cấu hình 5 cư dân Thị trấn Diệu Kỳ (T4-02): MỌI hằng số và cờ hình
/// nằm ở file này (một chỗ duy nhất).
///
/// Lời thoại nằm trong file nội dung `app/assets/content/residents.json`
/// (sửa không cần đụng code); file này chỉ giữ giới hạn kiểm tra file đó
/// và cờ hình.
library;

/// Đã có hình cư dân (chân dung + dáng nói) chưa. `false`: chân dung là
/// vòng tròn màu của khu + biểu tượng vẽ bằng code. `true`: dùng ảnh
/// [ResidentConfig.portraitAsset] / [ResidentConfig.talkAsset]; ảnh nào
/// thiếu thì tự về hình vẽ bằng code. Khi Muse giao lô 17 (xem
/// `docs/briefs/lot17_v04.md`): thêm `assets/images/residents/` vào
/// `pubspec.yaml`, đặt cờ `true`.
const bool residentArtReady = true;

class ResidentConfig {
  const ResidentConfig._();

  /// File nội dung lời thoại (khai báo trong `pubspec.yaml`).
  static const String contentAsset = 'assets/content/residents.json';

  /// Số cư dân: mỗi mảng một cư dân.
  static const int residentCount = 5;

  /// Số câu tối thiểu / tối đa của mỗi nhóm lời thoại.
  static const int minVariants = 5;
  static const int maxVariants = 8;

  /// Nhóm `special` (mở khóa theo số dạng thành thạo) cho phép ít câu hơn.
  static const int minSpecialVariants = 3;

  /// Độ dài tối đa (số ký tự) để bong bóng không tràn trên màn nhỏ.
  static const int maxGreetingLength = 60;
  static const int maxLineLength = 110;
  static const int maxBioLength = 90;
  static const int maxNameLength = 20;

  /// Tên gọi khi bé chưa có tên (thay cho `{ten}`).
  static const String fallbackChildName = 'bé';

  /// Dấu chỗ trống được phép trong lời thoại.
  static const String namePlaceholder = '{ten}';

  /// Bé làm chặng mà đúng ngay lần đầu NHIỀU NHẤT chừng này câu (trên 5)
  /// thì cư dân nói câu động viên thay cho lời cảm ơn thường.
  static const int struggleMaxFirstTryCorrect = 2;

  /// Ảnh chân dung / dáng đang nói (webp trong suốt 512x512).
  static String portraitAsset(String id) =>
      'assets/images/residents/${id}_portrait.webp';
  static String talkAsset(String id) =>
      'assets/images/residents/${id}_talk.webp';
}
