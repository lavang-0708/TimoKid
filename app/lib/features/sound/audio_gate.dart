/// Cổng tắt âm thanh toàn app khi chạy integration test trên máy ảo.
///
/// Phát âm thanh qua `audioplayers` trên máy ảo CI làm `pumpAndSettle`
/// không bao giờ dừng (đã khoanh vùng ở PR #13). Integration test đặt
/// `AudioGate.enabled = false` ngay đầu `main()` của test (cùng mẫu
/// `AnimationGate.enabled`): hiệu ứng và nhạc nền đều không phát, dù
/// cài đặt `sound_enabled` / `music_enabled` đang bật. Máy thật luôn
/// để mặc định `true`.
library;

class AudioGate {
  AudioGate._();

  /// `false` = không phát bất cứ âm thanh nào (hiệu ứng lẫn nhạc nền).
  static bool enabled = true;
}
