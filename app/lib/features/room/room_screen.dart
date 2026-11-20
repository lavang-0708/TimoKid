/// Màn Phòng — màn chính từ bản 0.2 (T2-04).
///
/// Nền phòng, nhân vật, pet, nội thất ở các ô cố định; 3 nút: Thị trấn
/// (luôn mở), Tủ đồ, Cửa hàng. Tủ đồ và Cửa hàng là T2-05/T2-06 nên
/// nút chỉ dẫn tới màn chờ "sắp mở" khi đã mở khóa.
///
/// Cổng mỗi ngày: chưa xong đề ngày thì Tủ đồ, Cửa hàng và chơi với
/// pet bị khóa ([RoomService.isPlayUnlocked] đọc trạng thái 5 chặng
/// của đề ngày); bấm nút khóa thì hiện lời nhắc dễ thương + nút ra
/// Thị trấn. Xong đề ngày thì mở khóa đến hết ngày; sang ngày mới
/// (đề mới chưa xong) khóa lại. Chạm pet/nội thất có phản ứng nhỏ
/// (nảy + bong bóng lời, 1,5 giây).
///
/// Không có AppBar (khác Thị trấn): tiết kiệm ~56 dp chiều cao để vừa
/// màn 608x248; tiêu đề + số dư + tiến độ nằm ở hàng đầu màn.
///
/// Hình: nền phòng + nội thất là PNG thật phong cách v2 (A1):
/// nền `room_v2.png` (1600x900) + 8 món đồ rời 512x512, xem
/// `room_assets.dart` và `docs/ASSETS.md` mục "Phòng v2". Bóng đổ
/// dưới mỗi món đặt sàn do app vẽ (ellipse mờ đen 20%), không
/// nướng trong PNG. Trứng/pet mới nở là PNG thật (PR #21,
/// `app/assets/images/pets/`, đọc qua map ở `onboarding_config.dart`
/// như mở đầu/màn nở); nhân vật dùng `CharacterView` + bộ girl thật
/// (nữ) hoặc lớp tạm xám (nam, chưa có hình thật).
///
/// Nhân vật ở Phòng linh động kiểu game như ở Thị trấn (PR ưu tiên
/// sau v0.0.3): thở squash/stretch + bấm vào nhảy lên lấp lánh (xem
/// [CharacterBounce]), trứng lắc lư chờ nở; cổng [AnimationGate]
/// tắt mọi hiệu ứng khi chạy test để `pumpAndSettle` dừng được.
/// Nút bấm nảy nhẹ (xem [PressBounce]).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/animation/animation_gate.dart';
import '../../core/database/database_provider.dart';
import '../../core/database/tables.dart';
import '../../core/widgets/press_bounce.dart';
import '../character/character_bounce.dart';
import '../character/character_model.dart';
import '../character/character_view.dart';
import '../character/placeholder_layers.dart';
import '../daily_set/daily_set_config.dart';
import '../onboarding/egg_service.dart';
import '../onboarding/onboarding_config.dart';
import '../onboarding/onboarding_model.dart';
import '../onboarding/onboarding_service.dart';
import '../rewards/reward_config.dart';
import '../rewards/reward_service.dart';
import '../town/town_screen.dart';
import 'coming_soon_screen.dart';
import 'room_assets.dart';
import 'room_service.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key});

  static const String route = '/room';

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  bool _loading = true;
  String? _error;
  CharacterProfile? _profile;
  String? _eggSpecies;
  bool _hatched = false;
  bool _hatchPending = false;
  int _xu = 0;
  int _gems = 0;
  int _done = 0;
  bool _unlocked = false;
  String? _bubbleText;
  int _petBounce = 0;
  Timer? _bubbleTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final db = ref.read(databaseProvider);
      final childId = await db.ensureSeeded();
      final profile = await OnboardingService(db: db).loadProfile(childId);
      final eggs = EggService(db: db);
      final eggSpecies = await eggs.selectedEgg(childId);
      final hatched = await eggs.isHatched(childId);
      final hatchPending = await eggs.isHatchPending(childId);
      final rewardService = RewardService(
        db: db,
        config: await RewardConfig.load(db),
      );
      final balances = await rewardService.balances(childId);
      final roomService = RoomService(db: db);
      final unlocked = await roomService.isPlayUnlocked(childId);
      final done = await roomService.doneStageCount(childId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _eggSpecies = eggSpecies;
        _hatched = hatched;
        _hatchPending = hatchPending;
        _xu = balances[Currency.xu] ?? 0;
        _gems = balances[Currency.gem] ?? 0;
        _done = done;
        _unlocked = unlocked;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// Hiện bong bóng phản ứng 1,5 giây rồi tự ẩn.
  void _showBubble(String text) {
    _bubbleTimer?.cancel();
    setState(() => _bubbleText = text);
    _bubbleTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (_bubbleText == text) setState(() => _bubbleText = null);
    });
  }

  /// Nhắc mở khóa khi bé bấm nút đang khóa: SnackBar có nút ra Thị trấn.
  void _showLockedReminder(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName mở khi xong đề ngày nhé!'),
        action: SnackBarAction(
          label: 'Ra Thị trấn',
          onPressed: () => context.go(TownScreen.route),
        ),
      ),
    );
  }

  void _onPetTap() {
    final species = _eggSpecies;
    if (species == null) return;
    if (!_hatched) {
      _showBubble(
        _hatchPending
            ? 'Trứng sắp nở rồi!'
            : 'Trứng sẽ nở sau chặng đầu tiên nhé!',
      );
      return;
    }
    if (!_unlocked) {
      _showBubble(petLockedLine);
      return;
    }
    setState(() => _petBounce++);
    _showBubble(petHappyLines[species] ?? 'Vui quá!');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        key: Key('room-screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        key: const Key('room-screen'),
        body: Center(child: Text('Không tải được Phòng: $_error')),
      );
    }
    final profile = _profile;
    final total = DailySetConfig.stagesPerDay;
    return Scaffold(
      key: const Key('room-screen'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Phòng của bé', style: TextStyle(fontSize: 20)),
                if (profile != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      profile.name,
                      key: const Key('room-character-name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ] else
                  const Spacer(),
                Text(
                  '$_xu xu',
                  key: const Key('room-xu-balance'),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  '◆ $_gems',
                  key: const Key('room-gem-balance'),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _unlocked
                        ? 'Xong đề ngày hôm nay!'
                        : 'Đề ngày: $_done/$total chặng',
                    key: const Key('room-progress-text'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Canh phải để khi đủ chỗ thì chữ vẫn nằm ở mép
                    // phải như trước khi bọc Flexible (Flexible chia
                    // chỗ trống với tên nên chữ mặc định sẽ dồn trái).
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            if (!_unlocked) ...[
              const SizedBox(height: 6),
              Container(
                key: const Key('room-locked-banner'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD166)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Chưa xong đề ngày — ra Thị trấn giúp các bạn nhé!',
                        key: const Key('room-locked-hint'),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    PressBounce(
                      child: TextButton(
                        key: const Key('room-goto-town-button'),
                        onPressed: () => context.go(TownScreen.route),
                        child: const Text('Ra Thị trấn'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildScene(profile)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 132,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RoomButton(
                          key: const Key('room-town-button'),
                          label: 'Thị trấn',
                          icon: Icons.map_outlined,
                          locked: false,
                          onPressed: () => context.go(TownScreen.route),
                        ),
                        const SizedBox(height: 8),
                        _RoomButton(
                          key: const Key('room-wardrobe-button'),
                          label: 'Tủ đồ',
                          icon: _unlocked
                              ? Icons.checkroom_outlined
                              : Icons.lock_outlined,
                          locked: !_unlocked,
                          onPressed: () => _unlocked
                              ? context.push(
                                  ComingSoonScreen.route,
                                  extra: const ComingSoonArgs(
                                    title: 'Tủ đồ',
                                    message: 'Tủ đồ sắp mở ở bản sau nhé! Xong đề ngày là được thay đồ.',
                                  ),
                                )
                              : _showLockedReminder('Tủ đồ'),
                        ),
                        const SizedBox(height: 8),
                        _RoomButton(
                          key: const Key('room-shop-button'),
                          label: 'Cửa hàng',
                          icon: _unlocked
                              ? Icons.shopping_bag_outlined
                              : Icons.lock_outlined,
                          locked: !_unlocked,
                          onPressed: () => _unlocked
                              ? context.push(
                                  ComingSoonScreen.route,
                                  extra: const ComingSoonArgs(
                                    title: 'Cửa hàng',
                                    message: 'Cửa hàng sắp mở ở bản sau nhé! Xong đề ngày là được mua đồ.',
                                  ),
                                )
                              : _showLockedReminder('Cửa hàng'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Khung cảnh phòng: nền + nội thất ở ô cố định + nhân vật + pet/trứng.
  /// Vị trí tính theo tỉ lệ khung cảnh (LayoutBuilder) để vừa cả
  /// 608x248 lẫn 640x320.
  Widget _buildScene(CharacterProfile? profile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        // Nhân vật cao 92% khung cảnh, rộng theo tỉ lệ 2:3 của khung
        // 1024x1536, không quá 28% chiều rộng khung cảnh.
        final charHeight = h * 0.92;
        final charWidth = (charHeight * 2 / 3).clamp(0.0, w * 0.28);
        final charLeft = w * 0.34;
        final petSize = h * 0.38;
        final petLeft = charLeft + charWidth + 10;
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(roomBackgroundAsset, fit: BoxFit.cover),
            ),
            // Nội thất v2 (A1): 8 món, ô vuông (rộng = cao) để ảnh
            // 512x512 lấp đầy ô và mép đáy khớp `bottomRow` khi vẽ
            // bóng (xem `_FurnitureSlot`). Dây cờ + đèn sao treo
            // trên tường, khung ảnh treo tường trái, còn lại đặt sàn.
            Positioned(
              left: w * 0.01,
              top: 0,
              width: w * 0.36,
              height: w * 0.36,
              child: _FurnitureSlot(
                furniture: roomFurniture[0],
                onTap: () => _showBubble(roomFurniture[0].reaction),
              ),
            ),
            Positioned(
              right: w * 0.02,
              top: h * 0.01,
              width: w * 0.19,
              height: w * 0.19,
              child: _FurnitureSlot(
                furniture: roomFurniture[1],
                onTap: () => _showBubble(roomFurniture[1].reaction),
              ),
            ),
            Positioned(
              left: w * 0.03,
              top: h * 0.32,
              width: w * 0.13,
              height: w * 0.13,
              child: _FurnitureSlot(
                furniture: roomFurniture[2],
                onTap: () => _showBubble(roomFurniture[2].reaction),
              ),
            ),
            Positioned(
              left: w * 0.02,
              bottom: h * 0.02,
              width: w * 0.14,
              height: w * 0.14,
              child: _FurnitureSlot(
                furniture: roomFurniture[3],
                onTap: () => _showBubble(roomFurniture[3].reaction),
              ),
            ),
            Positioned(
              left: w * 0.17,
              bottom: h * 0.01,
              width: w * 0.14,
              height: w * 0.14,
              child: _FurnitureSlot(
                furniture: roomFurniture[4],
                onTap: () => _showBubble(roomFurniture[4].reaction),
              ),
            ),
            Positioned(
              right: w * 0.01,
              bottom: h * 0.02,
              width: w * 0.16,
              height: w * 0.16,
              child: _FurnitureSlot(
                furniture: roomFurniture[7],
                onTap: () => _showBubble(roomFurniture[7].reaction),
              ),
            ),
            if (profile != null)
              Positioned(
                left: charLeft,
                bottom: 0,
                width: charWidth,
                height: charHeight,
                child: CharacterBounce(
                  child: CharacterView(
                    key: const Key('room-character'),
                    outfit: _outfitFor(profile),
                    loader: _loaderFor(profile),
                    // Thở/chớp mắt bật (kiểu game, như ở Thị trấn);
                    // cổng AnimationGate tắt khi chạy test để
                    // pumpAndSettle dừng được (xem chú thích đầu file).
                    animationsEnabled: true,
                  ),
                ),
              ),
            // Gấu bông + cốc đặt TRƯỚC chân nhân vật (vẽ sau nhân
            // vật): để sau thì bị nhân vật che gần hết, chỉ ló một
            // mép; đặt trước thì như đồ chơi để trên sàn trước mặt bé.
            Positioned(
              left: w * 0.31,
              bottom: 0,
              width: w * 0.13,
              height: w * 0.13,
              child: _FurnitureSlot(
                furniture: roomFurniture[5],
                onTap: () => _showBubble(roomFurniture[5].reaction),
              ),
            ),
            Positioned(
              left: w * 0.45,
              bottom: 0,
              width: w * 0.08,
              height: w * 0.08,
              child: _FurnitureSlot(
                furniture: roomFurniture[6],
                onTap: () => _showBubble(roomFurniture[6].reaction),
              ),
            ),
            if (_eggSpecies != null)
              Positioned(
                left: petLeft,
                bottom: 0,
                width: petSize,
                height: petSize,
                child: _PetSlot(
                  species: _eggSpecies!,
                  hatched: _hatched,
                  bounce: _petBounce,
                  onTap: _onPetTap,
                ),
              ),
            if (_bubbleText != null)
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD9C2E8)),
                    ),
                    child: Text(
                      _bubbleText!,
                      key: const Key('room-reaction-bubble'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Bộ đồ xem trước cho hồ sơ đã lưu (giữ đồng bộ với `_outfitFor`
  /// ở màn Thị trấn): nữ dùng bộ nhân vật nữ 1 (thân + tóc + váy),
  /// nam dùng bộ đủ lớp manifest v1.
  CharacterOutfit _outfitFor(CharacterProfile profile) {
    if (profile.gender == 'girl') {
      return CharacterOutfit.girlSet1(
        hairColor: Color(profile.hairColor),
        top: profile.dress,
      );
    }
    return CharacterOutfit.girl(
      palette: CharacterPalette(
        skin: Color(profile.skinColor),
        hair: Color(profile.hairColor),
        eyes: Color(profile.eyeColor),
        mouth: const Color(onboardingMouthColor),
        top: const Color(0xFFF2A7C3),
        bottom: const Color(0xFFB5A8E8),
        shoes: const Color(0xFF8FCB9B),
        accessoryHead: const Color(0xFFF28BB0),
      ),
      hairSet: profile.hairStyle,
      eyes: profile.eyeStyle,
      mouth: profile.mouthStyle,
    );
  }

  /// Bộ nạp lớp: nữ dùng `AssetImage` mặc định (hình thật đã có
  /// trên main từ PR #18); nam chưa có hình thật nên dùng lớp tạm
  /// xám như ở màn mở đầu.
  CharacterLayerLoader? _loaderFor(CharacterProfile profile) =>
      profile.gender == 'girl' ? null : placeholderLayerLoader;
}

/// Một món nội thất: chạm vào thì hiện bong bóng phản ứng.
///
/// Món đặt sàn có bóng đổ mềm do app vẽ (ellipse mờ đen 20% ngay
/// dưới mép đáy, neo theo [RoomFurniture.bottomRow]); món treo
/// ([RoomFurniture.hanging]) thì không có bóng. PNG đồ rời không
/// còn bóng nướng sẵn (xem `docs/ASSETS.md` mục "Phòng v2").
class _FurnitureSlot extends StatelessWidget {
  const _FurnitureSlot({required this.furniture, required this.onTap});

  final RoomFurniture furniture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key(furniture.key),
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Ô luôn vuông (rộng = cao) nên ảnh 512x512 lấp đầy ô,
          // mép đáy nằm đúng ở bottomRow/512 chiều cao ô.
          final size = constraints.maxWidth;
          final bottom = size * furniture.bottomRow / 512;
          final shadowHeight = size * 0.10;
          return Stack(
            children: [
              if (!furniture.hanging)
                Positioned(
                  left: size * 0.075,
                  top: bottom - shadowHeight * 0.3,
                  width: size * 0.85,
                  height: shadowHeight,
                  child: const _SoftShadow(),
                ),
              Positioned.fill(
                child: Image.asset(furniture.asset, fit: BoxFit.contain),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bóng đổ mềm: ellipse đen 20%, viền mờ dần (làm mờ bằng
/// MaskFilter để bóng loang đều theo ellipse, không bị viền cứng).
class _SoftShadow extends StatelessWidget {
  const _SoftShadow();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SoftShadowPainter());
  }
}

class _SoftShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Ô pet/trứng: trứng chưa nở thì hiện trứng, đã nở thì hiện pet mới nở.
/// Chạm vào thì nảy nhẹ (khi đã mở khóa) + bong bóng lời.
class _PetSlot extends StatelessWidget {
  const _PetSlot({
    required this.species,
    required this.hatched,
    required this.bounce,
    required this.onTap,
  });

  final String species;
  final bool hatched;
  final int bounce;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final asset = hatched
        ? newbornSpeciesAssets[species]!
        : eggSpeciesAssets[species]!;
    // Trứng/pet là PNG thật (PR #21); trứng chưa nở lắc lư nhẹ
    // chờ nở như ở bước chọn trứng (bản sao nhỏ của `_EggWiggle`
    // ở mở đầu — để ở đây để không sửa file mở đầu của PR ưu tiên).
    final picture = Image.asset(asset, fit: BoxFit.contain);
    final shown = hatched ? picture : _RoomEggWiggle(child: picture);
    return GestureDetector(
      key: Key(hatched ? 'room-pet' : 'room-egg'),
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(bounce),
        tween: Tween(begin: 0.85, end: 1.0),
        duration: const Duration(milliseconds: 300),
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: shown,
      ),
    );
  }
}

/// Trứng lắc lư nhẹ chờ nở: xoay qua lại ±0.05 rad, chu kỳ 1,6 giây
/// (cùng mẫu `_EggWiggle` ở màn mở đầu).
///
/// Hiệu ứng lặp nên chỉ chạy khi cổng [AnimationGate] bật (máy thật);
/// khi chạy test thì trả trứng nguyên vẹn để `pumpAndSettle` dừng
/// được.
class _RoomEggWiggle extends StatefulWidget {
  const _RoomEggWiggle({required this.child});

  final Widget child;

  @override
  State<_RoomEggWiggle> createState() => _RoomEggWiggleState();
}

class _RoomEggWiggleState extends State<_RoomEggWiggle>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late final Animation<double> _angle;

  @override
  void initState() {
    super.initState();
    if (!AnimationGate.enabled) return;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _angle = Tween<double>(
      begin: -0.05,
      end: 0.05,
    ).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.child;
    return AnimatedBuilder(
      animation: _angle,
      builder: (context, child) => Transform.rotate(
        key: const Key('room-egg-wiggle'),
        angle: _angle.value,
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Nút ở cột phải màn Phòng (Thị trấn / Tủ đồ / Cửa hàng).
class _RoomButton extends StatelessWidget {
  const _RoomButton({
    super.key,
    required this.label,
    required this.icon,
    required this.locked,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool locked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PressBounce(
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: locked
                ? Colors.grey.shade300
                : const Color(0xFFC9B8F0),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 18)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
