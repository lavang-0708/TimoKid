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

/// Ghi lại các đường dẫn đã phát, theo đúng thứ tự.
class FakeSoundPlayer implements SoundPlayer {
  final played = <String>[];

  @override
  Future<void> play(String assetPath) async {
    played.add(assetPath);
  }
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
