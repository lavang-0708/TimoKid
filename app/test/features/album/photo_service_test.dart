/// Test dịch vụ album (T5-05): lưu file + dòng, giới hạn 60 ảnh (xóa ảnh
/// cũ nhất), xóa, mỗi bé một album.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/album/album_config.dart';
import 'package:timokid/features/album/photo_service.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late Directory dir;
  late PhotoAlbumService service;
  final png = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);

  setUp(() async {
    clock = FakeClock(DateTime(2027, 3, 1, 9));
    db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    dir = Directory.systemTemp.createTempSync('timokid_album_');
    addTearDown(() => dir.deleteSync(recursive: true));
    service = PhotoAlbumService(db: db, directory: () async => dir);
  });

  Future<PhotoSaveResult> shoot({String? child}) {
    clock.advance(const Duration(minutes: 1));
    return service.save(
      childId: child ?? childId,
      png: png,
      width: 800,
      height: 450,
    );
  }

  test('lưu ảnh: có file PNG và một dòng photos', () async {
    final r = await shoot();
    expect(r.removedOldest, 0);
    final f = await service.fileFor(r.photo);
    expect(f.existsSync(), isTrue);
    expect(await f.readAsBytes(), png);
    expect(r.photo.width, 800);
    expect(await service.list(childId), hasLength(1));
  });

  test(
    'giới hạn 60: ảnh thứ 61 làm mất ảnh cũ nhất (dòng và file), có báo',
    () async {
      expect(albumPhotoLimit, 60);
      final first = await shoot();
      final firstFile = await service.fileFor(first.photo);
      for (var i = 1; i < 60; i++) {
        final r = await shoot();
        expect(r.removedOldest, 0);
      }
      expect(await db.photosDao.countForChild(childId), 60);
      expect(firstFile.existsSync(), isTrue);
      final extra = await shoot();
      expect(extra.removedOldest, 1);
      final left = await service.list(childId);
      expect(left, hasLength(60));
      expect(left.any((p) => p.id == first.photo.id), isFalse);
      expect(left.first.id, extra.photo.id); // mới nhất đứng đầu
      expect(firstFile.existsSync(), isFalse);
      expect(dir.listSync().length, 60);
    },
  );

  test('mỗi bé một album: đầy của bé này không xóa ảnh bé kia', () async {
    final other = (await db.childrenDao.createChild(name: 'Bé hai')).id;
    final a = await shoot(child: other);
    for (var i = 0; i < 61; i++) {
      await shoot();
    }
    expect(await db.photosDao.countForChild(other), 1);
    expect((await service.fileFor(a.photo)).existsSync(), isTrue);
  });

  test('xóa ảnh: mất cả dòng và file; file đã mất thì không lỗi', () async {
    final r = await shoot();
    final f = await service.fileFor(r.photo);
    f.deleteSync();
    await service.delete(r.photo);
    expect(await service.list(childId), isEmpty);
    final r2 = await shoot();
    await service.delete(r2.photo);
    expect((await service.fileFor(r2.photo)).existsSync(), isFalse);
  });

  test('hạn mức nhỏ qua tham số limit', () async {
    final small = PhotoAlbumService(
      db: db,
      directory: () async => dir,
      limit: 2,
    );
    for (var i = 0; i < 3; i++) {
      clock.advance(const Duration(minutes: 1));
      await small.save(childId: childId, png: png, width: 1, height: 1);
    }
    expect(await db.photosDao.countForChild(childId), 2);
  });
}
