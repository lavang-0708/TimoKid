/// Màn Phòng — màn chính từ bản 0.2 (T2-04), nền v3b từ (D).
///
/// Nền phòng, nhân vật, pet, nội thất đặt đúng vị trí khung 1600x900;
/// 2 nút ở cột phải: Tủ đồ, Cửa hàng. Nút Trở về tròn ở góc trên trái
/// về Thị trấn (PR (B), xem [RoundBackButton]) thay cho nút chữ
/// "Thị trấn" trước đây. Tủ đồ và Cửa hàng là T2-05/T2-06 nên nút
/// chỉ dẫn tới màn chờ "sắp mở" khi đã mở khóa.
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
/// Hình: nền phòng + nội thất là PNG thật phong cách v3b (D):
/// nền `room_v3.png` (1600x900) + 5 món đồ rời 512x512 đặt khớp món
/// vẽ sẵn trong nền, xem `room_assets.dart` và `docs/ASSETS.md` mục
/// "Phòng v3b" (vị trí đo từ PNG thật, đã hiệu chỉnh bằng code —
/// xem `docs/D_IMAGES.md` mục 8). Bóng đổ dưới mỗi món đặt sàn do
/// app vẽ (ellipse mờ đen 20%), không nướng trong PNG. Trứng/pet
/// mới nở là PNG thật (PR #21, `app/assets/images/pets/`, đọc qua
/// map ở `onboarding_config.dart` như mở đầu/màn nở); nhân vật dùng
/// `CharacterView` + bộ girl thật (nữ) hoặc lớp tạm xám (nam, chưa
/// có hình thật — (E) thay sau).
///
/// Nhân vật ở Phòng linh động kiểu game như ở Thị trấn (PR ưu tiên
/// sau v0.0.3): thở squash/stretch + bấm vào nhảy lên lấp lánh (xem
/// [CharacterBounce]), trứng lắc lư chờ nở; cổng [AnimationGate]
/// tắt mọi hiệu ứng khi chạy test để `pumpAndSettle` dừng được.
/// Nút bấm nảy nhẹ (xem [PressBounce]).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/animation/animation_gate.dart';
import '../../core/database/database_provider.dart';
import '../../core/database/tables.dart';
import '../../core/widgets/press_bounce.dart';
import '../../core/widgets/round_back_button.dart';
import '../character/character_bounce.dart';
import '../character/kid_assets.dart';
import '../character/kid_look_service.dart';
import '../character/kid_sprite.dart';
import '../daily_set/daily_set_config.dart';
import '../onboarding/egg_service.dart';
import '../onboarding/onboarding_config.dart';
import '../onboarding/onboarding_model.dart';
import '../onboarding/onboarding_service.dart';
import '../rewards/reward_config.dart';
import '../rewards/reward_service.dart';
import '../town/town_screen.dart';
import 'coming_soon_screen.dart';
import 'pet_growth.dart';
import 'room_assets.dart';
import 'room_service.dart';
import 'room_walk.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key});

  static const String route = '/room';

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen>
    with TickerProviderStateMixin {
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
  String? _childId;
  String? _headAccessory;
  PetStage _petStage = PetStage.newborn;
  int _petDays = 0;

  // (G) Đi lại trong phòng: chân nhân vật/pet theo khung 1600x900.
  Offset _kidFeet = roomCharacterFeet;
  Offset _petFeet = roomPetFeet;
  bool _kidFacingLeft = false;
  bool _petFacingLeft = false;
  bool _kidWalking = false;
  bool _petWalking = false;
  bool _kidWaving = false;
  Timer? _waveTimer;
  late final AnimationController _kidMove = AnimationController(vsync: this);
  late final AnimationController _petMove = AnimationController(vsync: this);
  int _kidWalkId = 0;
  int _petWalkId = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _waveTimer?.cancel();
    _kidMove.dispose();
    _petMove.dispose();
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
      final accessory = await KidLookService(db: db).headAccessory(childId);
      final growth = PetGrowthService(db: db);
      final petDays = await growth.doneDays(childId);
      final petStage = hatched ? petStageForDays(petDays) : PetStage.egg;
      final seen = await growth.seenStage(childId);
      if (hatched && seen != petStage) {
        await growth.markSeen(childId, petStage);
      }
      final grewUp =
          hatched && seen != null && seen != PetStage.egg && seen != petStage;
      if (!mounted) return;
      setState(() {
        _childId = childId;
        _headAccessory = accessory;
        _petDays = petDays;
        _petStage = petStage;
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
      if (grewUp && eggSpecies != null) {
        _showBubble(
          'Pet đã lớn thành ${petStageNames[petStage]}! Giỏi quá!',
          seconds: 3,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// Hiện bong bóng phản ứng 1,5 giây rồi tự ẩn.
  void _showBubble(String text, {int seconds = 0}) {
    _bubbleTimer?.cancel();
    setState(() => _bubbleText = text);
    final ms = seconds > 0 ? seconds * 1000 : 1500;
    _bubbleTimer = Timer(Duration(milliseconds: ms), () {
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
    final next = petDaysToNextStage(_petDays);
    _showBubble(
      next == null
          ? (petHappyLines[species] ?? 'Vui quá!')
          : '${petHappyLines[species] ?? 'Vui quá!'} '
                'Còn $next ngày học nữa tớ sẽ lớn!',
      seconds: 2,
    );
  }

  /// Tủ đồ (E): chọn 1 trong 3 bộ đồ và phụ kiện đầu, xem trước ngay
  /// trên nhân vật trong phòng, lưu ngay khi chọn.
  Future<void> _openWardrobe() async {
    final profile = _profile;
    final childId = _childId;
    if (profile == null || childId == null) return;
    final db = ref.read(databaseProvider);
    final looks = KidLookService(db: db);
    final gender = kidGender(profile.gender);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final current = _profile ?? profile;
          final outfit = kidOutfitNumber(current.dress);
          Widget choice({
            required Key key,
            required bool selected,
            required Widget child,
            required String label,
            required VoidCallback onTap,
          }) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: InkWell(
              key: key,
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 104,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFEDE4FB) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF8E6FD8)
                        : const Color(0xFFD9C2E8),
                    width: selected ? 3 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 92, child: child),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          );
          final accessories = kidHeadAccessories[gender]!;
          return SafeArea(
            child: SingleChildScrollView(
              key: const Key('room-wardrobe-sheet'),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Bộ đồ', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var n = 1; n <= 3; n++)
                          choice(
                            key: Key('room-wardrobe-outfit-$n'),
                            selected: n == outfit,
                            label:
                                kidOutfitNames[kidOutfitIds[gender]![n - 1]]!,
                            onTap: () async {
                              final updated = await looks.setOutfit(
                                childId,
                                current,
                                n,
                              );
                              if (!mounted) return;
                              setState(() => _profile = updated);
                              setSheet(() {});
                            },
                            child: Image.asset(
                              kidFullAsset(gender, n),
                              fit: BoxFit.contain,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Phụ kiện', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final id in <String?>[null, ...accessories.keys])
                          choice(
                            key: Key('room-wardrobe-accessory-${id ?? 'none'}'),
                            selected: id == _headAccessory,
                            label: id == null
                                ? 'Không đeo'
                                : accessories[id]!.$1,
                            onTap: () async {
                              await looks.setHeadAccessory(childId, id);
                              if (!mounted) return;
                              setState(() => _headAccessory = id);
                              setSheet(() {});
                            },
                            child: KidSprite(
                              gender: gender,
                              outfit: outfit,
                              headAccessory: id,
                              animationsEnabled: false,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Bấm vào nhân vật: vẫy tay chào 1,4 giây.
  void _onKidTap() {
    _waveTimer?.cancel();
    setState(() => _kidWaving = true);
    final name = _profile?.name ?? '';
    _showBubble(name.isEmpty ? 'Xin chào!' : 'Xin chào, tớ là $name!');
    _waveTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _kidWaving = false);
    });
  }

  /// (G) Bé chạm vào sàn: nhân vật đi tới đó, pet đi theo sau lưng.
  void _onFloorTap(Offset frame) {
    final target = roomWalkTarget(frame);
    final path = roomWalkPath(_kidFeet, target);
    _walk(isKid: true, path: path);
    if (_eggSpecies != null && _hatched) {
      final facingLeft = target.dx < _kidFeet.dx;
      final spot = roomPetFollowSpot(target, kidFacingLeft: facingLeft);
      Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _walk(isKid: false, path: roomWalkPath(_petFeet, spot));
      });
    }
  }

  /// Đi lần lượt qua các điểm [path]; lần đi mới hủy lần cũ.
  Future<void> _walk({required bool isKid, required List<Offset> path}) async {
    final controller = isKid ? _kidMove : _petMove;
    final id = isKid ? ++_kidWalkId : ++_petWalkId;
    bool current() => (isKid ? _kidWalkId : _petWalkId) == id;
    controller.stop();
    if (!AnimationGate.enabled) {
      // Test: tới nơi ngay, không chạy hiệu ứng.
      setState(() {
        if (isKid) {
          _kidFeet = path.last;
        } else {
          _petFeet = path.last;
        }
      });
      return;
    }
    setState(() {
      if (isKid) {
        _kidWalking = true;
        _kidWaving = false;
      } else {
        _petWalking = true;
      }
    });
    for (final point in path) {
      if (!mounted || !current()) return;
      final from = isKid ? _kidFeet : _petFeet;
      final dist = (point - from).distance;
      if (dist < 1) continue;
      final speed = isKid ? roomWalkSpeed : roomWalkSpeed * 1.15;
      controller.duration = Duration(
        milliseconds: (dist / speed * 1000).round(),
      );
      void tick() {
        if (!current()) return;
        final p = Offset.lerp(from, point, controller.value)!;
        setState(() {
          if (isKid) {
            _kidFeet = p;
          } else {
            _petFeet = p;
          }
        });
      }

      setState(() {
        if ((point.dx - from.dx).abs() > 2) {
          if (isKid) {
            _kidFacingLeft = point.dx < from.dx;
          } else {
            _petFacingLeft = point.dx < from.dx;
          }
        }
      });
      controller.addListener(tick);
      try {
        await controller.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      } finally {
        controller.removeListener(tick);
      }
    }
    if (!mounted || !current()) return;
    setState(() {
      if (isKid) {
        _kidWalking = false;
      } else {
        _petWalking = false;
        // Tới nơi thì pet quay về phía bé.
        _petFacingLeft = _kidFeet.dx < _petFeet.dx;
      }
    });
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
                const RoundBackButton(key: Key('room-town-button')),
                const SizedBox(width: 8),
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
                          key: const Key('room-wardrobe-button'),
                          label: 'Tủ đồ',
                          icon: _unlocked
                              ? Icons.checkroom_outlined
                              : Icons.lock_outlined,
                          locked: !_unlocked,
                          onPressed: () => _unlocked
                              ? _openWardrobe()
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

  /// Khung cảnh phòng v3b: nền 1600x900 + 5 món đặt khớp món trong nền.
  ///
  /// Cảnh chiếm toàn bộ bề rộng màn hình, tỉ lệ 16:9 cố định nên mọi
  /// vị trí (khung 1600x900, xem [room_assets.dart]) đặt chính xác ở
  /// mọi cỡ màn hình, không bị cắt như `BoxFit.cover` ở bản v2.
  /// Bóng đổ do app vẽ (ellipse mờ đen 20%) ngay dưới điểm neo đáy
  /// của mỗi món; thứ tự vẽ theo chân y (xa trước, gần sau): bình
  /// hoa, cốc bút, gấu bông, đèn sao, chậu cây, rồi nhân vật + pet
  /// đứng trên sàn.
  Widget _buildScene(CharacterProfile? profile) {
    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            double fx(double x) => x / roomFrameWidth * w;
            double fy(double y) => y / roomFrameHeight * h;

            /// Bóng đổ mềm ngay dưới [anchor]: rộng 85% và cao 10%
            /// chiều rộng món (nhân vật/pet dùng bề rộng hình).
            Widget frameShadow(Offset anchor, double width) {
              final sw = width * 0.85;
              final sh = width * 0.10;
              return Positioned(
                left: fx(anchor.dx - sw / 2),
                top: fy(anchor.dy - sh * 0.3),
                width: fx(sw),
                height: fy(sh),
                child: const _SoftShadow(),
              );
            }

            // 5 món xếp theo chân y (xa trước, gần sau) để món gần
            // che đúng món xa khi chồng lấn.
            final itemsByFeet = <RoomFurniture>[
              roomFurniture[3], // bình hoa (neo y = 510)
              roomFurniture[4], // cốc bút (neo y = 515)
              roomFurniture[0], // gấu bông (neo y = 550)
              roomFurniture[1], // đèn sao (neo y = 580)
              roomFurniture[2], // chậu cây (neo y = 686)
            ];
            // (G) Nhân vật và pet: cỡ theo chiều sâu (chân y), vẽ theo
            // chân y (xa trước, gần sau) để ai đứng trước thì che đúng.
            final kidScale = roomDepthScale(_kidFeet.dy);
            final kidBoxH = kidFrameHeight * 360 / kidBodyHeight * kidScale;
            final kidBoxW = kidBoxH * kidFrameWidth / kidFrameHeight;
            final petScale = roomDepthScale(_petFeet.dy);
            final petBox = petBoxSize(_petStage) * petScale;
            final actors = <(double, List<Widget>)>[
              if (profile != null)
                (
                  _kidFeet.dy,
                  [
                    frameShadow(_kidFeet, 240 * kidScale),
                    Positioned(
                      left: fx(_kidFeet.dx - kidBoxW / 2),
                      top: fy(_kidFeet.dy - kidFeetFraction * kidBoxH),
                      width: fx(kidBoxW),
                      height: fy(kidBoxH),
                      child: CharacterBounce(
                        onTap: _onKidTap,
                        child: KidSprite(
                          key: const Key('room-character'),
                          gender: profile.gender,
                          outfit: kidOutfitNumber(profile.dress),
                          headAccessory: _headAccessory,
                          waving: _kidWaving,
                          walking: _kidWalking,
                          facingLeft: _kidFacingLeft,
                        ),
                      ),
                    ),
                  ],
                ),
              if (_eggSpecies != null)
                (
                  _petFeet.dy,
                  [
                    frameShadow(_petFeet, petBox * 0.7),
                    Positioned(
                      left: fx(_petFeet.dx - petBox / 2),
                      top: fy(_petFeet.dy - petBox * 440 / 512),
                      width: fx(petBox),
                      height: fy(petBox),
                      child: _PetSlot(
                        species: _eggSpecies!,
                        hatched: _hatched,
                        stage: _petStage,
                        bounce: _petBounce,
                        walking: _petWalking,
                        facingLeft: _petFacingLeft,
                        onTap: _onPetTap,
                      ),
                    ),
                  ],
                ),
            ]..sort((a, b) => a.$1.compareTo(b.$1));
            return Stack(
              children: [
                // Chạm vào nền (sàn, tường, giường) thì nhân vật đi tới
                // chỗ sàn tương ứng; món đồ/nhân vật/pet nằm trên nên
                // chạm vào chúng vẫn ra phản ứng riêng.
                Positioned.fill(
                  child: GestureDetector(
                    key: const Key('room-floor'),
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _onFloorTap(
                      Offset(
                        d.localPosition.dx / w * roomFrameWidth,
                        d.localPosition.dy / h * roomFrameHeight,
                      ),
                    ),
                    child: Image.asset(
                      roomBackgroundAsset,
                      fit: BoxFit.fill,
                      width: w,
                      height: h,
                    ),
                  ),
                ),
                // Bóng đổ (theo chân y).
                for (final item in itemsByFeet)
                  frameShadow(item.anchor, item.placeSize),
                // 5 món nội thất (theo chân y).
                for (final item in itemsByFeet)
                  Positioned(
                    left: fx(item.placeX),
                    top: fy(item.placeY),
                    width: fx(item.placeSize),
                    height: fy(item.placeSize),
                    child: _RoomItemSlot(
                      item: item,
                      onTap: () => _showBubble(item.reaction),
                    ),
                  ),
                for (final actor in actors) ...actor.$2,
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
        ),
      ),
    );
  }
}

/// Một món nội thất v3b: chạm vào thì hiện bong bóng phản ứng.
///
/// Món là PNG 512x512 trong suốt đặt khớp món vẽ sẵn trong nền
/// (xem [RoomFurniture.placeX]/[placeY]/[placeSize]); bóng đổ do
/// app vẽ ở tầng cảnh (xem `_buildScene`), không nướng trong PNG.
/// Khóa widget giữ nguyên như bản v2 (`room-furniture-<tên>`) để
/// test cũ vẫn tìm được món.
class _RoomItemSlot extends StatelessWidget {
  const _RoomItemSlot({required this.item, required this.onTap});

  final RoomFurniture item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key(item.key),
      onTap: onTap,
      child: Image.asset(item.asset, fit: BoxFit.fill),
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

/// Ô pet/trứng: trứng chưa nở thì hiện trứng, đã nở thì hiện pet theo
/// giai đoạn lớn (F). Chạm vào thì nảy nhẹ + bong bóng lời. Đang đi thì
/// nhún bước; [facingLeft] lật ngang.
class _PetSlot extends StatelessWidget {
  const _PetSlot({
    required this.species,
    required this.hatched,
    required this.stage,
    required this.bounce,
    required this.walking,
    required this.facingLeft,
    required this.onTap,
  });

  final String species;
  final bool hatched;
  final PetStage stage;
  final int bounce;
  final bool walking;
  final bool facingLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final asset = hatched
        ? petAsset(species, stage == PetStage.egg ? PetStage.newborn : stage)
        : eggSpeciesAssets[species]!;
    Widget picture = Image.asset(
      asset,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
    if (facingLeft) picture = Transform.flip(flipX: true, child: picture);
    final shown = hatched
        ? _PetHop(walking: walking, child: picture)
        : _RoomEggWiggle(child: picture);
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

/// Pet nhún nhảy khi đi (nảy 2 lần mỗi chu kỳ 360 ms); đứng yên thì
/// thở nhẹ. Tắt khi chạy test ([AnimationGate]).
class _PetHop extends StatefulWidget {
  const _PetHop({required this.walking, required this.child});

  final bool walking;
  final Widget child;

  @override
  State<_PetHop> createState() => _PetHopState();
}

class _PetHopState extends State<_PetHop> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (!AnimationGate.enabled) return;
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return widget.child;
    return AnimatedBuilder(
      animation: c,
      builder: (context, child) {
        final t = c.value * 2 * math.pi;
        if (widget.walking) {
          // 5 nhịp nảy mỗi chu kỳ 1,8 giây (~360 ms một nhịp).
          final hop = math.sin(t * 5).abs();
          return FractionalTranslation(
            translation: Offset(0, -0.08 * hop),
            child: child,
          );
        }
        final breath = 1 + 0.025 * math.sin(t);
        return Transform(
          alignment: const Alignment(0, 0.72),
          transform: Matrix4.diagonal3Values(2 - breath, breath, 1),
          child: child,
        );
      },
      child: widget.child,
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

/// Nút ở cột phải màn Phòng (Tủ đồ / Cửa hàng).
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
