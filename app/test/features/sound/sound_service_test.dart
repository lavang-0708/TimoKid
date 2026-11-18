/// Unit test cho SoundService (PLAN điểm (m), T1-12).
///
/// Phát thật nằm sau [SoundPlayer] nên test dùng [SoundPlayer] giả ghi
/// lại đường dẫn đã phát — không cần file WAV thật, không cần loa.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/sound/sound_service.dart';

/// Player giả cho test pool: ghi lại các lần phát, đánh dấu dispose.
class _FakePooledPlayer implements PooledPlayer {
  final played = <String>[];
  var disposed = false;

  @override
  Future<void> play(String assetPath) async {
    played.add(assetPath);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

/// Ghi lại các đường dẫn đã phát, theo đúng thứ tự.
class FakeSoundPlayer implements SoundPlayer {
  final played = <String>[];

  @override
  Future<void> play(String assetPath) async {
    played.add(assetPath);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late AppDatabase db;
  late FakeSoundPlayer fake;
  late SoundService sound;

  setUp(() async {
    db = AppDatabase(
      executor: NativeDatabase.memory(),
      clock: const SystemClock(),
    );
    addTearDown(db.close);
    await db.ensureSeeded();
    fake = FakeSoundPlayer();
    // coinDelay bằng 0 để test không phải chờ 300 ms thật.
    sound = SoundService(db: db, player: fake, coinDelay: Duration.zero);
  });

  test('đúng phát correct rồi coin', () async {
    sound.playCorrect();

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(fake.played, ['sounds/correct.wav', 'sounds/coin.wav']);
  });

  test('sai phát wrong', () async {
    sound.playWrong();

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(fake.played, ['sounds/wrong.wav']);
  });

  test('xong chặng phát stage_complete', () async {
    sound.playStageComplete();

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(fake.played, ['sounds/stage_complete.wav']);
  });

  test('tắt sound_enabled thì không phát gì', () async {
    await db.settingsDao.setValue(key: 'sound_enabled', value: 'false');

    sound.playCorrect();
    sound.playWrong();
    sound.playStageComplete();

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(fake.played, isEmpty);
  });

  test('pool tái dùng player, không tạo mới mỗi lần phát', () async {
    // T1-15 (review PR #13): bản cũ tạo AudioPlayer mới cho mỗi lần
    // phát — nghi là nguyên nhân máy ảo CI treo pumpAndSettle.
    // Pool cố định tạo đúng poolSize player lúc dựng, phát 10 lần
    // cũng không tạo thêm player nào; các lần phát chia đều vòng
    // tròn cho các player (âm chồng nhau không cắt nhau).
    final created = <_FakePooledPlayer>[];
    final pool = AudioPlayersSoundPlayer(
      poolSize: 3,
      createPlayer: () {
        final player = _FakePooledPlayer();
        created.add(player);
        return player;
      },
    );
    addTearDown(pool.dispose);

    expect(created, hasLength(3));
    for (var i = 0; i < 10; i++) {
      await pool.play('sounds/correct.wav');
    }
    expect(created, hasLength(3));
    // 10 lần phát chia vòng tròn 4-3-3 cho 3 player.
    expect(created.map((p) => p.played.length), [4, 3, 3]);

    await pool.dispose();
    expect(created.every((p) => p.disposed), isTrue);
  });

  test('chưa có khóa sound_enabled thì mặc định bật', () async {
    // DB mới chưa seed nên bảng settings trống: getValue trả null và
    // _enabled() phải coi như bật.
    final freshDb = AppDatabase(
      executor: NativeDatabase.memory(),
      clock: const SystemClock(),
    );
    addTearDown(freshDb.close);
    final freshSound = SoundService(
      db: freshDb,
      player: fake,
      coinDelay: Duration.zero,
    );

    freshSound.playWrong();

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(fake.played, ['sounds/wrong.wav']);
  });
}
