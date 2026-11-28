/// Cấu hình đồng bộ (T3-03/T3-04). Hai URL dưới đây là công khai (không
/// phải bí mật), lấy từ Neon project `timokid` (xem `docs/SYNC.md`).
/// Ghi đè khi build bằng `--dart-define=TIMOKID_AUTH_URL=...` và
/// `--dart-define=TIMOKID_API_URL=...`. Không có mật khẩu hay khóa bí mật
/// nào trong app: chỉ dùng JWT của bố/mẹ sau khi đăng nhập.
library;

class SyncConfig {
  SyncConfig._();

  /// Neon Auth (Managed Better Auth).
  static const String authUrl = String.fromEnvironment(
    'TIMOKID_AUTH_URL',
    defaultValue: 'https://ep-damp-waterfall-a1cu82wt.neonauth.ap-southeast-1.aws.neon.tech/timokid/auth',
  );

  /// Neon Data API (PostgREST).
  static const String apiUrl = String.fromEnvironment(
    'TIMOKID_API_URL',
    defaultValue: 'https://ep-damp-waterfall-a1cu82wt.apirest.ap-southeast-1.aws.neon.tech/timokid/rest/v1',
  );

  /// Header `Origin` gửi kèm khi gọi Neon Auth (app không chạy trong
  /// trình duyệt nên tự đặt): dùng domain đã được phép của web admin.
  static const String origin = String.fromEnvironment(
    'TIMOKID_AUTH_ORIGIN',
    defaultValue: 'https://lavang-0708.github.io',
  );

  /// Số dòng tối đa mỗi lô gửi lên (SYNC.md).
  static const int batchSize = 200;

  /// Chu kỳ đồng bộ khi app đang mở.
  static const Duration interval = Duration(minutes: 15);
}

/// Đẩy thêm các bảng `inventory`, `pets`, `arena_attempts` lên server.
/// TẮT cho tới khi chủ dự án chạy `db/migrations/0002_app_tables.sql` trên
/// Neon (bảng chưa có thì server trả 404 và làm hỏng mọi lần đồng bộ).
/// Bật bằng cách đổi thành `true` (hoặc `--dart-define` ở bước sau).
const bool syncExtraTablesEnabled = true;

/// Tải câu hỏi tự soạn (`custom_questions`) từ server và trộn vào đề ngày
/// (T5-03). TẮT cho tới khi chủ dự án chạy
/// `db/migrations/0003_custom_questions.sql` trên Neon (bảng chưa có thì
/// server trả 404 và làm hỏng mọi lần đồng bộ). Khi tắt: không gọi mạng cho
/// bảng này và đề ngày không có câu tự soạn. Bật bằng cách đổi thành `true`.
const bool customQuestionsEnabled = false;
