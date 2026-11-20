/// Cổng bật/tắt hiệu ứng lặp vô hạn của app (PR ưu tiên sau v0.0.3).
///
/// Vấn đề: hiệu ứng lặp (`AnimationController.repeat()` — thở/chớp
/// mắt của `CharacterView`, lắc trứng chờ nở) lên lịch khung hình mãi
/// nên `pumpAndSettle` trong test không bao giờ dừng. Mẫu cũ ở T2-02
/// là cờ `animationsEnabled` từng widget; màn Thị trấn/mở đầu giữ
/// `false` nên nhân vật tĩnh từ T2-03 tới giờ. Chủ dự án muốn nhân
/// vật linh động kiểu game trên máy thật, mà test (widget + golden +
/// overflow + integration) vẫn phải bơm bằng `pumpAndSettle` — nên
/// thêm MỘT cổng chung thay vì cờ riêng từng màn:
///
/// * Máy thật: `enabled = true` (mặc định) — mọi hiệu ứng chạy.
/// * Widget test: `test/flutter_test_config.dart` đặt `false` trước
///   mọi file test — màn nào cũng tĩnh, `pumpAndSettle` dừng được.
/// * Integration test: `integration_test/app_test.dart` đặt `false`
///   ngay đầu `main()` (cùng mẫu `sound_enabled = false` vì
///   audioplayers cũng làm `pumpAndSettle` treo).
/// * Test nào muốn kiểm chính hiệu ứng thì bật lại `true` trong file
///   đó và bơm bằng `pump(Duration)` thay vì `pumpAndSettle`
///   (mẫu `character_view_test.dart`).
///
/// Hiệu ứng một lần (nhảy khi bấm, nảy 'pop', sao bung khi nở, nút
/// nảy) tự dừng nên `pumpAndSettle` vẫn qua được; chúng cũng đọc cổng
/// này để test golden/widget chụp trạng thái tĩnh xác định.
library;

class AnimationGate {
  AnimationGate._();

  /// true = hiệu ứng chạy (mặc định, máy thật); false = tắt mọi
  /// hiệu ứng lặp + hiệu ứng bấm (chỉ test đặt false).
  static bool enabled = true;
}
