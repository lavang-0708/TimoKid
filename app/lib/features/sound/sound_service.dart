/// Âm thanh của màn làm toán (PLAN điểm (m), T1-12).
///
/// 4 file WAV trong `assets/sounds/` (đã có trên main, xem README trong
/// đó): đúng → `correct.wav` (3 nốt mộc cầm), sai → `wrong.wav` ("è"
/// nhẹ), xu bay vào ví → `coin.wav` ("bling" kiểu game), xong chặng →
/// `stage_complete.wav`.
/// Tôn trọng cài đặt `sound_enabled` trong `settings` (đã seed `true`
/// từ T1-04 — xem [AppDatabase.ensureSeeded]); tắt thì không phát gì.
///
/// Phát nền, không await: các hàm `play*` trả về `void`, âm thanh
/// không chặn thao tác của bé. Lỗi phát (máy test không có kênh âm
/// thanh, file thiếu) được nuốt — màn làm toán vẫn chạy bình thường.
///
/// Để test được mà không cần file WAV thật, việc phát thật nằm sau
/// [SoundPlayer] và có thể chích [SoundPlayer] giả ghi lại đường dẫn
/// đã phát.
library;

import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';

import '../../core/database/app_database.dart';

/// Phát một file âm thanh trong `assets/sounds/`.
abstract class SoundPlayer {
  Future<void> play(String assetPath);
}

/// Phát bằng `audioplayers`: mỗi lần phát tạo một `AudioPlayer` mới
/// để hai âm chồng nhau (ting rồi xu) không cắt nhau; tự giải phóng
/// khi phát xong.
class AudioPlayersSoundPlayer implements SoundPlayer {
  @override
  Future<void> play(String assetPath) async {
    final player = AudioPlayer();
    player.onPlayerComplete.listen((_) async {
      await player.dispose();
    });
    try {
      await player.play(AssetSource(assetPath));
    } catch (_) {
      await player.dispose();
    }
  }
}

/// Âm thanh của màn làm toán: đúng, sai, xu, xong chặng.
class SoundService {
  SoundService({
    required this.db,
    SoundPlayer? player,
    this.coinDelay = const Duration(milliseconds: 300),
  }) : _player = player ?? AudioPlayersSoundPlayer();

  final AppDatabase db;
  final SoundPlayer _player;

  /// Khoảng chờ giữa "ting" và tiếng xu khi trả lời đúng, để hai âm
  /// không chồng lên nhau. Test chích [Duration.zero].
  final Duration coinDelay;

  /// Trả lời đúng: 3 nốt mộc cầm rồi xu bay vào ví (`coin.wav` sau
  /// [coinDelay] — xu được cộng cùng lúc với câu đúng).
  void playCorrect() {
    _play('sounds/correct.wav');
    Future.delayed(coinDelay, () => _play('sounds/coin.wav'));
  }

  /// Trả lời sai: "è" nhẹ.
  void playWrong() => _play('sounds/wrong.wav');

  /// Xu bay vào ví (phát riêng khi cần).
  void playCoin() => _play('sounds/coin.wav');

  /// Xong chặng.
  void playStageComplete() => _play('sounds/stage_complete.wav');

  Future<void> _play(String assetPath) async {
    if (!await _enabled()) return;
    try {
      await _player.play(assetPath);
    } catch (_) {
      // Không phát được (máy test, file thiếu): bỏ qua, màn làm toán
      // vẫn chạy bình thường.
    }
  }

  /// `sound_enabled` trong `settings`; chưa có khóa thì mặc định bật.
  Future<bool> _enabled() async {
    try {
      final raw = await db.settingsDao.getValue(key: 'sound_enabled');
      if (raw == null) return true;
      return jsonDecode(raw) as bool? ?? true;
    } catch (_) {
      return true;
    }
  }
}
