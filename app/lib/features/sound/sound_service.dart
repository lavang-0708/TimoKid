/// Âm thanh của màn làm toán (PLAN điểm (m), T1-12; pool player T1-15).
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

  /// Giải phóng tài nguyên (mặc định không làm gì — player giả).
  Future<void> dispose() async {}
}

/// Phát bằng `audioplayers` với một pool nhỏ player cố định, tái dùng
/// vòng tròn.
///
/// Bản cũ (T1-12) tạo một `AudioPlayer` mới cho mỗi lần phát rồi tự
/// giải phóng khi phát xong — nghi là nguyên nhân máy ảo CI treo
/// `pumpAndSettle` sau câu đúng (khoanh vùng ở PR #13): tạo/giải
/// phóng player liên tục làm kênh nền bận. Pool 4 player tạo một lần
/// lúc dựng [SoundService] (đủ cho 2 âm chồng nhau ting + xu, sai,
/// xong chặng) nên mỗi lần phát chỉ gọi `play` trên player có sẵn;
/// không tạo/giải phóng gì thêm trong lúc chơi. Giải phóng cả pool
/// khi màn hình dispose.
/// Player tối thiểu mà pool cần: phát một file asset và giải phóng.
///
/// Tách riêng để test được pool mà không cần `AudioPlayer` thật —
/// tạo `AudioPlayer` thật trong unit test treo vì kênh nền không trả
/// lời (xem test pool trong `sound_service_test.dart`).
abstract class PooledPlayer {
  Future<void> play(String assetPath);
  Future<void> dispose();
}

/// Bọc `AudioPlayer` thật theo [PooledPlayer].
class _AudioPlayerAdapter implements PooledPlayer {
  _AudioPlayerAdapter(this._player);

  final AudioPlayer _player;

  @override
  Future<void> play(String assetPath) => _player.play(AssetSource(assetPath));

  @override
  Future<void> dispose() => _player.dispose();
}

class AudioPlayersSoundPlayer implements SoundPlayer {
  AudioPlayersSoundPlayer({
    this.poolSize = 4,
    PooledPlayer Function()? createPlayer,
  }) : _players = [
         for (var i = 0; i < poolSize; i++)
           (createPlayer ?? () => _AudioPlayerAdapter(AudioPlayer()))(),
       ];

  /// Số player trong pool (mặc định 4).
  final int poolSize;

  final List<PooledPlayer> _players;
  var _next = 0;

  @override
  Future<void> play(String assetPath) async {
    // Vòng tròn: hai âm chồng nhau (ting rồi xu sau 300 ms) rơi vào
    // hai player khác nhau nên không cắt nhau.
    final player = _players[_next];
    _next = (_next + 1) % _players.length;
    try {
      await player.play(assetPath);
    } catch (_) {
      // Máy test / máy ảo không có kênh âm thanh: bỏ qua, màn làm
      // toán vẫn chạy bình thường.
    }
  }

  @override
  Future<void> dispose() async {
    for (final player in _players) {
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

  /// Giải phóng player (màn hình gọi khi dispose nếu tự dựng service).
  Future<void> dispose() => _player.dispose();

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
