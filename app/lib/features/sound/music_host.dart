/// Nối [MusicService] với vòng đời app và router (PLAN T2-08).
///
/// Gắn trong `builder` của `MaterialApp.router` (chỉ khi `main()` bật):
/// nghe router để đổi nhạc theo màn, nghe lifecycle để tạm dừng khi app
/// xuống nền.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'music_service.dart';

class MusicHost extends ConsumerStatefulWidget {
  const MusicHost({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<MusicHost> createState() => _MusicHostState();
}

class _MusicHostState extends ConsumerState<MusicHost>
    with WidgetsBindingObserver {
  late final MusicService _music = ref.read(musicServiceProvider);
  String? _last;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.router.routerDelegate.addListener(_onRoute);
    _music.load().then((_) => _onRoute());
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRoute);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onRoute() {
    final path = widget.router.routerDelegate.currentConfiguration.uri.path;
    if (path == _last) return;
    _last = path;
    _music.onLocation(path);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _music.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
