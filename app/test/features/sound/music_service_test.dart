/// MusicService (PLAN T2-08): máy trạng thái nhạc nền với player giả —
/// màn → bản nhạc, tạm dừng/phát tiếp theo lifecycle và màn tập trung,
/// công tắc tắt thì không bao giờ phát.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/arena/arena_exam_screen.dart';
import 'package:timokid/features/math/math_screen.dart';
import 'package:timokid/features/room/room_screen.dart';
import 'package:timokid/features/shop/shop_screen.dart';
import 'package:timokid/features/sound/music_service.dart';
import 'package:timokid/features/town/town_screen.dart';

class FakeMusicPlayer implements MusicPlayer {
  final events = <String>[];
  double volume = 0;

  @override
  Future<void> play(String assetPath, double volume) async {
    this.volume = volume;
    events.add('play:$assetPath');
  }

  @override
  Future<void> setVolume(double volume) async {
    this.volume = volume;
    events.add('vol');
  }

  @override
  Future<void> pause() async => events.add('pause');

  @override
  Future<void> resume() async => events.add('resume');

  @override
  Future<void> stop() async => events.add('stop');

  @override
  Future<void> dispose() async => events.add('dispose');

  List<String> get actions => events.where((e) => e != 'vol').toList();
}

void main() {
  late AppDatabase db;
  late FakeMusicPlayer fake;
  late MusicService music;

  MusicService build({Duration fade = Duration.zero}) =>
      MusicService(db: db, player: fake, fade: fade);

  setUp(() async {
    db = AppDatabase(
      executor: NativeDatabase.memory(),
      clock: const SystemClock(),
    );
    addTearDown(db.close);
    await db.ensureSeeded();
    fake = FakeMusicPlayer();
    music = build();
    await music.load();
  });

  test('sceneForLocation: Thị trấn, Phòng, màn tập trung, màn khác', () {
    expect(sceneForLocation(TownScreen.route), MusicScene.town);
    expect(sceneForLocation(RoomScreen.route), MusicScene.room);
    expect(sceneForLocation(MathScreen.route), MusicScene.focus);
    expect(sceneForLocation(ArenaExamScreen.route), MusicScene.focus);
    expect(sceneForLocation(ShopScreen.route), isNull);
  });

  test('chưa vào màn nào thì im', () {
    expect(music.playingTrack, isNull);
    expect(fake.actions, isEmpty);
  });

  test('Thị trấn phát town, Phòng phát room (dừng bản cũ)', () async {
    await music.setScene(MusicScene.town);
    expect(music.playingTrack, MusicTrack.town);
    expect(fake.actions, ['play:sounds/music_town.ogg']);
    expect(fake.volume, 0.35);

    await music.setScene(MusicScene.room);
    expect(music.playingTrack, MusicTrack.room);
    expect(fake.actions, [
      'play:sounds/music_town.ogg',
      'stop',
      'play:sounds/music_room.ogg',
    ]);
  });

  test('cùng cảnh gọi lại không phát lại', () async {
    await music.setScene(MusicScene.town);
    await music.setScene(MusicScene.town);
    expect(fake.actions, ['play:sounds/music_town.ogg']);
  });

  test('màn khác (cửa hàng) giữ nhạc đang phát', () async {
    await music.onLocation(RoomScreen.route);
    await music.onLocation(ShopScreen.route);
    expect(music.playingTrack, MusicTrack.room);
    expect(fake.actions, ['play:sounds/music_room.ogg']);
  });

  test('vào màn làm toán/đấu trường: tạm dừng, ra thì phát tiếp', () async {
    await music.onLocation(TownScreen.route);
    await music.onLocation(MathScreen.route);
    expect(music.playingTrack, isNull);
    expect(fake.actions.last, 'pause');
    await music.onLocation(TownScreen.route);
    expect(music.playingTrack, MusicTrack.town);
    expect(fake.actions, ['play:sounds/music_town.ogg', 'pause', 'resume']);

    await music.onLocation('${ArenaExamScreen.route}/x');
    expect(music.playingTrack, isNull);
    await music.onLocation(RoomScreen.route);
    // Đổi Thị trấn → Phòng sau tập trung: bản mới, không phát tiếp bản cũ.
    expect(music.playingTrack, MusicTrack.room);
  });

  test('app xuống nền thì tạm dừng, quay lại thì phát tiếp', () async {
    await music.onLocation(RoomScreen.route);
    await music.setForeground(false);
    expect(music.playingTrack, isNull);
    expect(fake.actions.last, 'pause');
    // Đổi màn khi đang ở nền không phát gì.
    await music.onLocation(TownScreen.route);
    expect(fake.actions.last, 'pause');
    await music.setForeground(true);
    expect(music.playingTrack, MusicTrack.town);
  });

  test('tắt Nhạc nền: dừng, lưu settings, không bao giờ phát', () async {
    await music.onLocation(TownScreen.route);
    await music.setEnabled(false);
    expect(music.playingTrack, isNull);
    expect(fake.actions.last, 'stop');
    expect(await db.settingsDao.getValue(key: 'music_enabled'), 'false');

    final before = fake.actions.length;
    await music.onLocation(RoomScreen.route);
    await music.setForeground(false);
    await music.setForeground(true);
    expect(fake.actions.length, before);

    await music.setEnabled(true);
    expect(music.playingTrack, MusicTrack.room);
    expect(await db.settingsDao.getValue(key: 'music_enabled'), 'true');
  });

  test('music_enabled=false trong settings: load rồi không phát', () async {
    await db.settingsDao.setValue(key: 'music_enabled', value: 'false');
    final p = FakeMusicPlayer();
    final m = MusicService(db: db, player: p, fade: Duration.zero);
    await m.load();
    await m.onLocation(TownScreen.route);
    expect(m.isEnabled, isFalse);
    expect(p.events, isEmpty);
  });

  test('mờ dần vào: âm lượng tăng đều tới 0,35', () async {
    final p = FakeMusicPlayer();
    final m = MusicService(
      db: db,
      player: p,
      fade: const Duration(milliseconds: 100),
      fadeSteps: 5,
    );
    await m.load();
    await m.onLocation(TownScreen.route);
    expect(p.volume, closeTo(0.35, 1e-9));
    expect(p.events.where((e) => e == 'vol').length, 5);
  });

  test('mờ ra rồi tạm dừng khi vào màn tập trung', () async {
    final p = FakeMusicPlayer();
    final m = MusicService(
      db: db,
      player: p,
      fade: const Duration(milliseconds: 100),
      fadeSteps: 5,
    );
    await m.load();
    await m.onLocation(TownScreen.route);
    await m.onLocation(MathScreen.route);
    expect(p.volume, closeTo(0, 1e-9));
    expect(p.actions.last, 'pause');
  });
}
