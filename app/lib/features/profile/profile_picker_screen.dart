/// Màn chọn bé (T3-03), hiện khi máy có từ 2 bé. Bé chạm tên mình để
/// vào chơi (không cần mật khẩu). "Thêm bé" nằm sau cổng phụ huynh và đi
/// qua mở đầu như bé đầu tiên.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database_provider.dart';
import '../auth/parent_gate.dart';
import '../onboarding/onboarding_screen.dart';
import '../room/room_screen.dart';
import 'profile_service.dart';

class ProfilePickerScreen extends ConsumerStatefulWidget {
  const ProfilePickerScreen({super.key});

  static const String route = '/profiles';

  @override
  ConsumerState<ProfilePickerScreen> createState() =>
      _ProfilePickerScreenState();
}

class _ProfilePickerScreenState extends ConsumerState<ProfilePickerScreen> {
  List<ChildSummary>? _children;

  ProfileService get _service => ProfileService(db: ref.read(databaseProvider));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _service.children();
    if (mounted) setState(() => _children = list);
  }

  Future<void> _pick(ChildSummary c) async {
    await _service.select(c.id);
    if (mounted) context.go(RoomScreen.route);
  }

  Future<void> _add() async {
    if (!await showParentGate(context) || !mounted) return;
    await _service.addChild();
    if (mounted) context.go(OnboardingScreen.route);
  }

  @override
  Widget build(BuildContext context) {
    final children = _children;
    return Scaffold(
      key: const Key('profile-picker-screen'),
      backgroundColor: const Color(0xFFF3E6D8),
      body: SafeArea(
        child: children == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Ai đang chơi nào?',
                              key: Key('profile-picker-title'),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                for (final c in children)
                                  _ProfileCard(
                                    key: Key('profile-card-${c.id}'),
                                    name: c.name,
                                    onTap: () => _pick(c),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              key: const Key('profile-add-button'),
                              onPressed: _add,
                              icon: const Icon(Icons.add_circle_rounded),
                              label: const Text('Thêm bé'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({super.key, required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFA07BE0), width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFA07BE0),
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
