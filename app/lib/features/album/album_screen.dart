/// Màn Album ảnh (T5-05, route `/album`): lưới ảnh bé đã chụp trong Phòng,
/// bấm để xem to, xóa có hỏi lại. Ảnh chỉ nằm trên máy (không đồng bộ).
/// Chưa có gói chia sẻ trong app nên chưa có nút chia sẻ.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/widgets/game_ui.dart';
import '../../core/widgets/round_back_button.dart';
import '../room/room_screen.dart';
import 'album_config.dart';
import 'photo_service.dart';

class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key});

  static const String route = '/album';

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  List<Photo>? _photos;
  String? _error;
  File Function(Photo)? _resolver;

  @override
  void initState() {
    super.initState();
    _load();
  }

  PhotoAlbumService get _service => PhotoAlbumService(
    db: ref.read(databaseProvider),
    directory: ref.read(photoDirectoryProvider),
  );

  Future<void> _load() async {
    try {
      final db = ref.read(databaseProvider);
      final childId = await db.ensureSeeded();
      final dir = await ref.read(photoDirectoryProvider)();
      final photos = await _service.list(childId);
      if (!mounted) return;
      setState(() {
        _resolver = (p) => File('${dir.path}/${p.fileName}');
        _photos = photos;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoomScreen.route);
    }
  }

  Future<void> _open(Photo photo) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => _PhotoViewer(photo: photo, file: _resolver!(photo)),
    );
    if (deleted == true) {
      await _service.delete(photo);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    return Scaffold(
      key: const Key('album-screen'),
      backgroundColor: const Color(0xFFE9DDF7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            children: [
              Row(
                children: [
                  RoundBackButton(
                    key: const Key('album-back-button'),
                    tooltip: 'Về Phòng',
                    onPressed: _back,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Album ảnh${photos == null ? '' : ' (${photos.length}/$albumPhotoLimit)'}',
                        key: const Key('album-title'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: gameInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(child: _body(photos)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(List<Photo>? photos) {
    if (_error != null) {
      return Center(child: Text('Không tải được album: $_error'));
    }
    if (photos == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (photos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Chưa có ảnh nào. Vào Phòng, bấm nút máy ảnh để chụp nhé!',
            key: Key('album-empty'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: gameInk,
            ),
          ),
        ),
      );
    }
    return GridView.extent(
      key: const Key('album-grid'),
      maxCrossAxisExtent: 170,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 16 / 10,
      children: [
        for (final p in photos)
          GestureDetector(
            key: Key('album-photo-${p.id}'),
            onTap: () => _open(p),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.file(
                  _resolver!(p),
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image_rounded, color: gameInk),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Xem ảnh to, có nút Xóa (hỏi lại) và Đóng. Trả `true` nếu bé xác nhận xóa.
class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photo, required this.file});

  final Photo photo;
  final File file;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('album-delete-confirm'),
        title: const Text('Xóa ảnh này?'),
        content: const Text('Ảnh bị xóa sẽ không lấy lại được.'),
        actions: [
          TextButton(
            key: const Key('album-delete-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Thôi'),
          ),
          TextButton(
            key: const Key('album-delete-ok'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('album-viewer'),
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              child: Image.file(
                file,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            right: 6,
            top: 6,
            child: Row(
              children: [
                IconButton.filled(
                  key: const Key('album-delete-button'),
                  tooltip: 'Xóa ảnh',
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_rounded),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  key: const Key('album-close-button'),
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
