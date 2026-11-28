/// Nhạc nền (PLAN T2-08): một player lặp duy nhất, mờ dần vào/ra ~500 ms.
///
/// Máy trạng thái thuần Dart, test được bằng [MusicPlayer] giả:
///  - [MusicScene] (màn đang hiện) → bản nhạc: Thị trấn → `town`, Phòng →
///    `room`; màn làm toán / thi đấu trường là [MusicScene.focus] (yên
///    lặng để bé tập trung): tạm dừng, ra khỏi đó thì phát tiếp. Màn khác
///    (Cửa hàng, công trình...) giữ nguyên cảnh hiện tại.
///  - App xuống nền (lifecycle) → tạm dừng; quay lại → phát tiếp.
///  - Công tắc "Nhạc nền" (`music_enabled` trong `settings`, mặc định
///    bật) tắt thì không bao giờ phát.
/// Âm lượng nhạc mặc định 0,35 (nhỏ hơn hiệu ứng).
library;

import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../arena/arena_exam_screen.dart';
import '../math/math_screen.dart';
import '../room/room_screen.dart';
import '../town/town_screen.dart';
import 'audio_gate.dart';

/// Màn đang hiện, xét theo nhạc.
enum MusicScene { none, town, room, focus }

/// Hai bản nhạc lặp.
enum MusicTrack {
  town('sounds/music_town.ogg'),
  room('sounds/music_room.ogg');

  const MusicTrack(this.asset);
  final String asset;
}

/// Đường dẫn màn → cảnh nhạc; `null` = màn không đổi nhạc (giữ cảnh cũ).
MusicScene? sceneForLocation(String path) {
  if (path == TownScreen.route) return MusicScene.town;
  if (path == RoomScreen.route) return MusicScene.room;
  if (path == MathScreen.route ||
      path == ArenaExamScreen.route ||
      path.startsWith('${ArenaExamScreen.route}/')) {
    return MusicScene.focus;
  }
  return null;
}

/// Player nhạc tối thiểu để test được bằng bản giả.
abstract class MusicPlayer {
  /// Nạp [assetPath], phát lặp ở âm lượng [volume].
  Future<void> play(String assetPath, double volume);
  Future<void> setVolume(double volume);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

/// Player không phát gì (mặc định cho test).
class NoopMusicPlayer implements MusicPlayer {
  const NoopMusicPlayer();
  @override
  Future<void> play(String assetPath, double volume) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

/// `audioplayers` thật, tạo player lười (lần phát đầu tiên).
class AudioPlayersMusicPlayer implements MusicPlayer {
  AudioPlayer? _p;

  AudioPlayer get _player => _p ??= AudioPlayer();

  @override
  Future<void> play(String assetPath, double volume) async {
    if (!AudioGate.enabled) return;
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource(assetPath), volume: volume);
  }

  @override
  Future<void> setVolume(double volume) async {
    if (_p != null) await _p!.setVolume(volume);
  }

  @override
  Future<void> pause() async {
    if (_p != null) await _p!.pause();
  }

  @override
  Future<void> resume() async {
    if (_p != null && AudioGate.enabled) await _p!.resume();
  }

  @override
  Future<void> stop() async {
    if (_p != null) await _p!.stop();
  }

  @override
  Future<void> dispose() async {
    await _p?.dispose();
    _p = null;
  }
}

class MusicService {
  MusicService({
    required this.db,
    required this.player,
    this.volume = 0.35,
    this.fade = const Duration(milliseconds: 500),
    this.fadeSteps = 10,
  });

  final AppDatabase db;
  final MusicPlayer player;

  /// Âm lượng nhạc khi phát (0..1).
  final double volume;

  /// Thời gian mờ dần vào/ra; [Duration.zero] = đổi ngay (test).
  final Duration fade;
  final int fadeSteps;

  MusicScene _scene = MusicScene.none;
  bool _foreground = true;
  bool _enabled = true;

  MusicTrack? _track; // bản đã nạp vào player
  bool _playing = false;
  int _gen = 0; // hủy các lần mờ dần cũ
  double _current = 0; // âm lượng hiện tại của player

  MusicScene get scene => _scene;
  bool get isEnabled => _enabled;

  /// Bản nhạc đang phát (null = im).
  MusicTrack? get playingTrack => _playing ? _track : null;

  /// `music_enabled` đang lưu trong settings (mặc định bật).
  Future<bool> storedEnabled() async {
    try {
      final raw = await db.settingsDao.getValue(key: 'music_enabled');
      return raw == null ? true : (jsonDecode(raw) as bool? ?? true);
    } catch (_) {
      return true;
    }
  }

  /// Đọc công tắc từ settings rồi áp dụng.
  Future<void> load() async {
    _enabled = await storedEnabled();
    await _reconcile();
  }

  Future<void> setScene(MusicScene scene) async {
    _scene = scene;
    await _reconcile();
  }

  /// Đổi cảnh theo đường dẫn màn (xem [sceneForLocation]).
  Future<void> onLocation(String path) async {
    final s = sceneForLocation(path);
    if (s != null) await setScene(s);
  }

  /// App lên/xuống nền.
  Future<void> setForeground(bool value) async {
    _foreground = value;
    await _reconcile();
  }

  /// Công tắc "Nhạc nền": ghi vào settings rồi áp dụng ngay.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      await db.settingsDao.setValue(
        key: 'music_enabled',
        value: jsonEncode(value),
      );
    } catch (_) {}
    await _reconcile();
  }

  MusicTrack? get _wanted {
    if (!_enabled || !_foreground) return null;
    return switch (_scene) {
      MusicScene.town => MusicTrack.town,
      MusicScene.room => MusicTrack.room,
      _ => null,
    };
  }

  Future<void> _reconcile() async {
    final want = _wanted;
    final gen = ++_gen;
    try {
      if (want == null) {
        if (_playing) {
          await _fadeTo(0, gen);
          if (gen != _gen) return;
          // Tắt hẳn công tắc thì dừng hẳn, còn lại chỉ tạm dừng để phát
          // tiếp đúng chỗ.
          if (!_enabled) {
            await player.stop();
            _track = null;
          } else {
            await player.pause();
          }
          _playing = false;
        } else if (!_enabled && _track != null) {
          await player.stop();
          _track = null;
        }
        return;
      }
      if (_playing && _track == want) {
        // Đang mờ ra dở thì mờ vào lại.
        await _fadeTo(volume, gen);
        return;
      }
      if (_playing) {
        // Đổi bản (Thị trấn ↔ Phòng): mờ ra rồi vào bản mới.
        await _fadeTo(0, gen);
        if (gen != _gen) return;
        await player.stop();
        _playing = false;
        _track = null;
      }
      if (_track == want) {
        // Tạm dừng trước đó: phát tiếp từ chỗ cũ.
        _current = fade == Duration.zero ? volume : 0;
        await player.setVolume(_current);
        await player.resume();
      } else {
        _current = fade == Duration.zero ? volume : 0;
        await player.play(want.asset, _current);
        _track = want;
      }
      _playing = true;
      await _fadeTo(volume, gen);
    } catch (_) {
      // Không phát được (máy test, thiếu file): bỏ qua, app vẫn chạy.
    }
  }

  Future<void> _fadeTo(double target, int gen) async {
    final from = _current;
    if (fade == Duration.zero) {
      _current = target;
      await player.setVolume(target);
      return;
    }
    final stepDur = fade ~/ fadeSteps;
    for (var i = 1; i <= fadeSteps; i++) {
      await Future<void>.delayed(stepDur);
      if (gen != _gen) return;
      final v = from + (target - from) * i / fadeSteps;
      _current = v;
      await player.setVolume(v);
    }
  }

  Future<void> dispose() async {
    _gen++;
    await player.dispose();
  }
}

/// Player nhạc dùng chung (mặc định: không phát; `main()` ghi đè).
final musicPlayerProvider = Provider<MusicPlayer>(
  (ref) => const NoopMusicPlayer(),
);

/// [MusicService] dùng chung toàn app.
final musicServiceProvider = Provider<MusicService>((ref) {
  final service = MusicService(
    db: ref.watch(databaseProvider),
    player: ref.watch(musicPlayerProvider),
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});
