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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import 'audio_gate.dart';

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
    if (!AudioGate.enabled) return;
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

/// Player không phát gì: mặc định của [soundPlayerProvider] để widget
/// test không đụng kênh âm thanh thật. `main()` ghi đè bằng player thật.
class NoopSoundPlayer implements SoundPlayer {
  const NoopSoundPlayer();

  @override
  Future<void> play(String assetPath) async {}

  @override
  Future<void> dispose() async {}
}

/// Player hiệu ứng dùng chung toàn app (mặc định: không phát).
final soundPlayerProvider = Provider<SoundPlayer>(
  (ref) => const NoopSoundPlayer(),
);

/// [SoundService] dùng chung cho Phòng, Thị trấn, Cửa hàng, hộp thư...
final soundServiceProvider = Provider<SoundService>(
  (ref) => SoundService(
    db: ref.watch(databaseProvider),
    player: ref.watch(soundPlayerProvider),
  ),
);

/// Các hiệu ứng ngắn (T2-08), tên file trong `assets/sounds/`.
enum Sfx {
  correct('correct'),
  wrong('wrong'),
  coin('coin'),
  stageComplete('stage_complete'),
  tap('tap'),
  hatch('hatch'),
  levelUp('level_up'),
  purchase('purchase'),
  giftOpen('gift_open'),
  streak('streak'),
  errorSoft('error_soft'),
  swoosh('swoosh');

  const Sfx(this.file);
  final String file;

  String get asset => 'sounds/$file.wav';
}

/// Âm thanh của app: màn làm toán (đúng, sai, xu, xong chặng) và các
/// hiệu ứng game (bấm nút HUD, nở trứng, lên cấp, mua, mở quà...).
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

  /// Phát một hiệu ứng bất kỳ (không chặn, tôn trọng `sound_enabled`).
  void play(Sfx sfx) => _play(sfx.asset);

  /// Bấm nút HUD chính (chỉ nút game chính, không phải mọi nút).
  void playTap() => play(Sfx.tap);

  /// Trứng nở (nứt vỏ + lấp lánh).
  void playHatch() => play(Sfx.hatch);

  /// Pet lên giai đoạn mới.
  void playLevelUp() => play(Sfx.levelUp);

  /// Mua đồ thành công.
  void playPurchase() => play(Sfx.purchase);

  /// Mở quà trong hộp thư.
  void playGiftOpen() => play(Sfx.giftOpen);

  /// Nhận thưởng nhiệm vụ / rương chuỗi ngày.
  void playStreak() => play(Sfx.streak);

  /// Bấm vào chức năng đang khóa: "bùm" nhẹ, không phạt.
  void playErrorSoft() => play(Sfx.errorSoft);

  /// Mở bảng / màn mới.
  void playSwoosh() => play(Sfx.swoosh);

  /// Giải phóng player (màn hình gọi khi dispose nếu tự dựng service).
  Future<void> dispose() => _player.dispose();

  Future<void> _play(String assetPath) async {
    if (!AudioGate.enabled) return;
    if (!await _enabled()) return;
    try {
      await _player.play(assetPath);
    } catch (_) {
      // Không phát được (máy test, file thiếu): bỏ qua, màn làm toán
      // vẫn chạy bình thường.
    }
  }

  /// Công tắc "Âm thanh" (hiệu ứng) trong cài đặt của bé.
  Future<bool> isEnabled() => _enabled();

  Future<void> setEnabled(bool value) =>
      db.settingsDao.setValue(key: 'sound_enabled', value: jsonEncode(value));

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
