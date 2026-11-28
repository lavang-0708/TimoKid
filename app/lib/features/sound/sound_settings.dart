/// Nút loa nhỏ ở HUD Phòng/Thị trấn + bảng hai công tắc "Âm thanh" và
/// "Nhạc nền" (PLAN T2-08). Bé tự bật tắt được, không cần cổng phụ huynh.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/game_ui.dart';
import 'music_service.dart';
import 'sound_service.dart';

/// Nút loa (key đặt ở nơi dùng: `sound-settings-button`).
class SoundHudButton extends ConsumerWidget {
  const SoundHudButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GameRoundButton(
      icon: Icons.volume_up_rounded,
      size: 26,
      color: const Color(0xFF5BB5C9),
      tooltip: 'Âm thanh',
      onPressed: () {
        ref.read(soundServiceProvider).playSwoosh();
        showSoundSettingsSheet(context);
      },
    );
  }
}

Future<void> showSoundSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 420),
      builder: (_) => const SoundSettingsSheet(),
    );

class SoundSettingsSheet extends ConsumerStatefulWidget {
  const SoundSettingsSheet({super.key});

  @override
  ConsumerState<SoundSettingsSheet> createState() => _SoundSettingsSheetState();
}

class _SoundSettingsSheetState extends ConsumerState<SoundSettingsSheet> {
  bool? _sfx;
  bool? _music;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sfx = await ref.read(soundServiceProvider).isEnabled();
    final music = await ref.read(musicServiceProvider).storedEnabled();
    if (!mounted) return;
    setState(() {
      _sfx = sfx;
      _music = music;
    });
  }

  Future<void> _setSfx(bool v) async {
    setState(() => _sfx = v);
    final sound = ref.read(soundServiceProvider);
    await sound.setEnabled(v);
    if (v) sound.playTap(); // nghe thử
  }

  Future<void> _setMusic(bool v) async {
    setState(() => _music = v);
    await ref.read(musicServiceProvider).setEnabled(v);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          key: const Key('sound-settings-sheet'),
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              key: const Key('toggle-sfx'),
              dense: true,
              secondary: const Icon(Icons.music_note_rounded),
              title: const Text('Âm thanh'),
              value: _sfx ?? true,
              onChanged: _sfx == null ? null : _setSfx,
            ),
            SwitchListTile(
              key: const Key('toggle-music'),
              dense: true,
              secondary: const Icon(Icons.library_music_rounded),
              title: const Text('Nhạc nền'),
              value: _music ?? true,
              onChanged: _music == null ? null : _setMusic,
            ),
          ],
        ),
      ),
    );
  }
}
