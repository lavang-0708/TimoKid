/// Dịch vụ album ảnh (T5-05): lưu PNG vào thư mục tài liệu của app + một
/// dòng `photos` trong database (CHỈ TRÊN MÁY, không đồng bộ lên server),
/// xóa, giới hạn [albumPhotoLimit] ảnh mỗi bé (quá thì bỏ ảnh cũ nhất).
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos.dart' show newId;
import 'album_config.dart';

/// Nơi lưu file ảnh. Mặc định `<thư mục tài liệu>/photos`; test ghi đè
/// bằng thư mục tạm.
final photoDirectoryProvider = Provider<Future<Directory> Function()>((ref) {
  return () async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$albumFolderName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  };
});

/// PNG đã chụp từ một [RenderRepaintBoundary].
class CapturedImage {
  const CapturedImage(this.png, this.width, this.height);

  final Uint8List png;
  final int width;
  final int height;
}

/// Chụp [boundary] thành PNG (không gồm gì ngoài cây con của boundary,
/// nên HUD đặt ngoài boundary không lọt vào ảnh). Tỉ lệ điểm ảnh tự hạ
/// để cạnh dài không quá [albumMaxLongSide].
Future<CapturedImage?> captureBoundary(
  RenderRepaintBoundary boundary, {
  double pixelRatio = albumPixelRatio,
}) async {
  final size = boundary.size;
  final longSide = size.longestSide;
  var ratio = pixelRatio;
  if (longSide * ratio > albumMaxLongSide) ratio = albumMaxLongSide / longSide;
  final ui.Image image = await boundary.toImage(pixelRatio: ratio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    return CapturedImage(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      image.width,
      image.height,
    );
  } finally {
    image.dispose();
  }
}

/// Kết quả lưu một ảnh.
class PhotoSaveResult {
  const PhotoSaveResult({required this.photo, required this.removedOldest});

  final Photo photo;

  /// Số ảnh cũ nhất đã bị xóa vì album đầy (0 hoặc 1 thường).
  final int removedOldest;
}

class PhotoAlbumService {
  PhotoAlbumService({
    required this.db,
    required this.directory,
    this.limit = albumPhotoLimit,
  });

  final AppDatabase db;
  final Future<Directory> Function() directory;
  final int limit;

  Future<PhotoSaveResult> save({
    required String childId,
    required Uint8List png,
    required int width,
    required int height,
  }) async {
    final dir = await directory();
    final id = newId();
    final fileName = '$id.png';
    await File('${dir.path}/$fileName').writeAsBytes(png, flush: true);
    final Photo photo;
    try {
      photo = await db.photosDao.insertPhoto(
        id: id,
        childId: childId,
        fileName: fileName,
        width: width,
        height: height,
      );
    } catch (_) {
      await _deleteFile(fileName);
      rethrow;
    }
    var removed = 0;
    final all = await db.photosDao.listForChild(childId);
    if (all.length > limit) {
      // Mới nhất trước, nên phần dư nằm ở cuối (ảnh cũ nhất).
      for (final old in all.sublist(limit)) {
        await db.photosDao.deleteById(old.id);
        await _deleteFile(old.fileName);
        removed++;
      }
    }
    return PhotoSaveResult(photo: photo, removedOldest: removed);
  }

  Future<List<Photo>> list(String childId) =>
      db.photosDao.listForChild(childId);

  Future<File> fileFor(Photo photo) async =>
      File('${(await directory()).path}/${photo.fileName}');

  /// Xóa ảnh (dòng + file). File thiếu thì bỏ qua.
  Future<void> delete(Photo photo) async {
    await db.photosDao.deleteById(photo.id);
    await _deleteFile(photo.fileName);
  }

  Future<void> _deleteFile(String fileName) async {
    try {
      final f = File('${(await directory()).path}/$fileName');
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
