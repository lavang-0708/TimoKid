/// Màn Phòng — màn chính từ bản 0.2 (T2-04), nền v3b từ (D).
///
/// Nền phòng, nhân vật, pet, nội thất đặt đúng vị trí khung 1600x900;
/// 2 nút ở cột phải: Tủ đồ, Cửa hàng. Nút Trở về tròn ở góc trên trái
/// về Thị trấn (PR (B), xem [RoundBackButton]) thay cho nút chữ
/// "Thị trấn" trước đây. Tủ đồ là bảng chọn đồ (chỉ món đã có), Cửa hàng
/// (T2-06) là màn `/shop`.
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
import '../../core/widgets/game_ui.dart';
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
import '../shop/shop_catalog.dart';
import '../shop/shop_screen.dart';
import '../shop/shop_service.dart';
import '../town/town_screen.dart';
import 'pet_growth.dart';
import 'pet_sprite.dart';
import 'room_assets.dart';
import 'room_service.dart';
import 'room_walk.dart';

class RoomScreen extends ConsumerStatefulWidget {
  /// [cleanBackground] mặc định theo [roomCleanBackgroundReady]; chỉ
  /// đặt khác để test nhánh nền sạch.
  const RoomScreen({
    super.key,
    this.cleanBackground = roomCleanBackgroundReady,
  });

  /// true = dùng `room_v3_clean.png` + vẽ lại 5 PNG nội thất rời;
  /// false = nền `room_v3.png` đã có sẵn 5 món, chỉ đặt vùng chạm.
  final bool cleanBackground;

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
  bool _glasses = false;
  bool _whiteShoes = false;
  bool _backpack = false;
  bool _kidWalkingUp = false;
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
      final looks = KidLookService(db: db);
      final accessory = await looks.headAccessory(childId);
      final glasses = await looks.glasses(childId);
      final whiteShoes = await looks.whiteShoes(childId);
      final backpack = await looks.backpack(childId);
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
        _glasses = glasses;
        _whiteShoes = whiteShoes;
        _backpack = backpack;
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
      _precacheKid();
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

  /// Nạp trước ảnh vẫy + khung đi bộ của bộ đồ hiện tại để lần đi đầu
  /// không bị khựng vì giải mã ảnh (góp ý 21/11: đi bị giật).
  void _precacheKid() {
    final profile = _profile;
    if (profile == null || !AnimationGate.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final g = profile.gender;
      final n = kidOutfitNumber(profile.dress);
      final paths = <String>[
        kidFullAsset(g, n, backpack: _backpack),
        kidFullAsset(g, n, wave: true, backpack: _backpack),
        ...?kidWalkFrames(g, n, up: false),
        ...?kidWalkFrames(g, n, up: true),
      ];
      for (final p in paths) {
        precacheImage(kidImage(p), context, onError: (_, _) {});
      }
      precacheImage(
        AssetImage(kidEyePatch(g, n, wave: true).asset),
        context,
        onError: (_, _) {},
      );
    });
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
    // Máy cài trước bản có cửa hàng: giữ đồ đang mặc rồi mới đọc kho.
    final shop = ShopService(db: db);
    await shop.grandfather(childId);
    final owned = await shop.owned(childId);
    if (!mounted) return;
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
            String? lockedItemId,
          }) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: InkWell(
              key: key,
              onTap: lockedItemId == null
                  ? onTap
                  : () => _openShopFromWardrobe(sheetContext),
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
                    SizedBox(
                      height: 92,
                      child: lockedItemId == null
                          ? child
                          : Stack(
                              children: [
                                Positioned.fill(
                                  child: Opacity(opacity: 0.5, child: child),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: _wardrobeLock(lockedItemId),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lockedItemId == null
                          ? label
                          : '$label\n${_priceOf(gender, lockedItemId)} xu',
                      maxLines: 3,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          );
          // Món bật/tắt (kính, balo, giày): chưa có thì hiện ổ khóa + giá,
          // bấm vào mở Cửa hàng.
          Widget toggle({
            required Key key,
            required String label,
            required String itemId,
            required bool selected,
            required Future<void> Function(bool on) onChanged,
          }) {
            if (owned.contains(itemId)) {
              return FilterChip(
                key: key,
                label: Text(label),
                selected: selected,
                onSelected: onChanged,
              );
            }
            return ActionChip(
              key: key,
              avatar: _wardrobeLock(itemId),
              label: Text('$label · ${_priceOf(gender, itemId)} xu'),
              onPressed: () => _openShopFromWardrobe(sheetContext),
            );
          }

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
                            lockedItemId:
                                owned.contains(kidOutfitIds[gender]![n - 1])
                                ? null
                                : kidOutfitIds[gender]![n - 1],
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
                            lockedItemId:
                                (id == null || owned.contains(headItemId(id)))
                                ? null
                                : headItemId(id),
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
                              glasses: _glasses,
                              whiteShoes: _whiteShoes,
                              backpack: _backpack,
                              animationsEnabled: false,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    children: [
                      toggle(
                        key: const Key('room-wardrobe-glasses'),
                        label: 'Kính tròn',
                        itemId: glassesItemId,
                        selected: _glasses,
                        onChanged: (on) async {
                          await looks.setGlasses(childId, on);
                          if (!mounted) return;
                          setState(() => _glasses = on);
                          setSheet(() {});
                        },
                      ),
                      toggle(
                        key: const Key('room-wardrobe-backpack'),
                        label: 'Balo',
                        itemId: backpackItemId,
                        selected: _backpack,
                        onChanged: (on) async {
                          await looks.setBackpack(childId, on);
                          if (!mounted) return;
                          setState(() => _backpack = on);
                          setSheet(() {});
                        },
                      ),
                      toggle(
                        key: const Key('room-wardrobe-white-shoes'),
                        label: 'Giày trắng',
                        itemId: whiteShoesItemId,
                        selected: _whiteShoes,
                        onChanged: (on) async {
                          await looks.setWhiteShoes(childId, on);
                          if (!mounted) return;
                          setState(() => _whiteShoes = on);
                          setSheet(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Ổ khóa nhỏ cho món chưa mua trong Tủ đồ.
  Widget _wardrobeLock(String itemId) => Container(
    key: Key('room-wardrobe-lock-$itemId'),
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF6E6680),
      border: Border.all(color: Colors.white, width: 1.5),
    ),
    child: const Icon(Icons.lock_rounded, size: 13, color: Colors.white),
  );

  int _priceOf(String gender, String itemId) =>
      shopItemById(gender, itemId)?.priceXu ?? 0;

  /// Bấm món chưa mua trong Tủ đồ: đóng bảng, mở Cửa hàng ("Mua ở
  /// Cửa hàng").
  void _openShopFromWardrobe(BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    _openShop();
  }

  /// Sang Cửa hàng, quay lại thì tải lại số dư (mua xong xu giảm).
  Future<void> _openShop() async {
    await context.push(ShopScreen.route);
    if (mounted) _refresh();
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
    // Cả đường đi là một lượt hoạt ảnh liền (tăng tốc, đi đều, giảm
    // tốc), không dừng ở từng góc — góp ý v0.0.13: đi bị giật cục.
    final start = isKid ? _kidFeet : _petFeet;
    final points = <Offset>[start];
    for (final p in path) {
      if ((p - points.last).distance >= 1) points.add(p);
    }
    if (points.length > 1) {
      final cumulative = <double>[0];
      for (var i = 1; i < points.length; i++) {
        cumulative.add(cumulative.last + (points[i] - points[i - 1]).distance);
      }
      final length = cumulative.last;
      final speed = isKid ? roomWalkSpeed : roomWalkSpeed * 1.15;
      final seconds = roomWalkDuration(length, speed: speed);
      controller.duration = Duration(milliseconds: (seconds * 1000).round());
      var segment = -1;
      void tick() {
        if (!current()) return;
        final d = roomWalkDistanceAt(
          controller.value * seconds,
          length,
          speed: speed,
        );
        final (p, i) = roomPointAlong(points, cumulative, d);
        setState(() {
          if (i != segment) {
            segment = i;
            final from = points[i];
            final to = points[i + 1];
            final segLen = (to - from).distance;
            if (isKid) {
              // Đi lên (xa dần) rõ rệt thì dùng khung đi bộ `ur`.
              _kidWalkingUp = (to.dy - from.dy) < -0.35 * segLen;
            }
            if ((to.dx - from.dx).abs() > 2) {
              if (isKid) {
                _kidFacingLeft = to.dx < from.dx;
              } else {
                _petFacingLeft = to.dx < from.dx;
              }
            }
          }
          if (isKid) {
            _kidFeet = p;
          } else {
            _petFeet = p;
          }
        });
      }

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
    // Góp ý 21/11: Phòng phủ kín màn hình, chỉ số là một dòng trên cùng
    // kiểu game, Tủ đồ/Cửa hàng là nút tròn có icon ở góc phải.
    return Scaffold(
      key: const Key('room-screen'),
      backgroundColor: const Color(0xFFF3E6D8),
      body: Stack(
        children: [
          Positioned.fill(child: _buildScene(profile)),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GameRoundButton(
                      key: const Key('room-town-button'),
                      icon: Icons.location_city_rounded,
                      image: '$uiArt/ui_icon_town.png',
                      color: const Color(0xFFA07BE0),
                      label: 'Thị trấn',
                      onPressed: () => context.go(TownScreen.route),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GameHudBar(
                          children: [
                            if (profile != null)
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    profile.name,
                                    key: const Key('room-character-name'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: gameOutlinedText(16),
                                  ),
                                ),
                              ),
                            GameStat(
                              icon: Icons.monetization_on_rounded,
                              image: '$uiArt/ui_coin.png',
                              color: const Color(0xFFF5B83D),
                              text: '$_xu',
                              textKey: const Key('room-xu-balance'),
                            ),
                            GameStat(
                              icon: Icons.diamond_rounded,
                              image: '$uiArt/ui_gem.png',
                              color: const Color(0xFFA07BE0),
                              text: '$_gems',
                              textKey: const Key('room-gem-balance'),
                            ),
                            GameStat(
                              icon: Icons.star_rounded,
                              image: '$uiArt/ui_star.png',
                              color: const Color(0xFFFFC94D),
                              text: _unlocked
                                  ? '$total/$total'
                                  : '$_done/$total',
                              textKey: const Key('room-progress-text'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    GameRoundButton(
                      key: const Key('room-wardrobe-button'),
                      icon: Icons.checkroom_rounded,
                      image: '$uiArt/ui_icon_wardrobe.png',
                      color: const Color(0xFFB48CF2),
                      label: 'Tủ đồ',
                      locked: !_unlocked,
                      onPressed: () => _unlocked
                          ? _openWardrobe()
                          : _showLockedReminder('Tủ đồ'),
                    ),
                    const SizedBox(width: 8),
                    GameRoundButton(
                      key: const Key('room-shop-button'),
                      icon: Icons.storefront_rounded,
                      image: '$uiArt/ui_icon_shop.png',
                      color: const Color(0xFF5DC3A8),
                      label: 'Cửa hàng',
                      locked: !_unlocked,
                      onPressed: () => _unlocked
                          ? _openShop()
                          : _showLockedReminder('Cửa hàng'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Nhắc khóa ở dưới thanh chỉ số (không che sàn để bé chạm đi).
          if (!_unlocked)
            Positioned(
              left: 0,
              right: 0,
              top: 70,
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: GestureDetector(
                    key: const Key('room-goto-town-button'),
                    onTap: () => context.go(TownScreen.route),
                    child: Container(
                      key: const Key('room-locked-banner'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE6FFF3D6),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFFFC94D),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        'Xong đề ngày ở Thị trấn để mở Tủ đồ, Cửa hàng nhé!',
                        key: const Key('room-locked-hint'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: gameInk,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
      child: GameCoverFrame(
        frameSize: const Size(roomFrameWidth, roomFrameHeight),
        // Giữ đáy (sàn, nơi bé đi lại); phần trần bị cắt khi màn dài.
        alignment: const Alignment(0, 0.9),
        builder: (context, w, h) {
          final clean = widget.cleanBackground;
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
                        glasses: _glasses,
                        whiteShoes: _whiteShoes,
                        backpack: _backpack,
                        waving: _kidWaving,
                        walking: _kidWalking,
                        walkingUp: _kidWalkingUp,
                        idleWave: true,
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
                    clean ? roomCleanBackgroundAsset : roomBackgroundAsset,
                    fit: BoxFit.fill,
                    width: w,
                    height: h,
                  ),
                ),
              ),
              // Nền sạch: bóng đổ do app vẽ (theo chân y). Nền cũ đã có
              // bóng + món vẽ sẵn nên không vẽ thêm.
              if (clean)
                for (final item in itemsByFeet)
                  frameShadow(item.anchor, item.placeSize),
              // 5 món nội thất (theo chân y): nền sạch thì vẽ PNG rời;
              // nền cũ thì chỉ đặt vùng chạm vô hình đúng chỗ món vẽ
              // sẵn trong nền (không vẽ PNG rời → không hình đôi).
              for (final item in itemsByFeet)
                Positioned(
                  left: fx(clean ? item.placeX : item.bakedRect.left),
                  top: fy(clean ? item.placeY : item.bakedRect.top),
                  width: fx(clean ? item.placeSize : item.bakedRect.width),
                  height: fy(clean ? item.placeSize : item.bakedRect.height),
                  child: _RoomItemSlot(
                    item: item,
                    showImage: clean,
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
    );
  }
}

/// Một món nội thất v3b: chạm vào thì hiện bong bóng phản ứng + nháy
/// sao "pop" tại chỗ món.
///
/// [showImage] = true (nền sạch): vẽ PNG 512x512 trong suốt đặt khớp
/// ([RoomFurniture.placeX]/[placeY]/[placeSize]); bóng đổ do app vẽ ở
/// tầng cảnh (xem `_buildScene`), không nướng trong PNG. [showImage]
/// = false (nền `room_v3.png` đã vẽ sẵn món): chỉ là vùng chạm vô
/// hình phủ đúng món trong nền ([RoomFurniture.bakedRect]).
/// Khóa widget giữ nguyên như bản v2 (`room-furniture-<tên>`) để
/// test cũ vẫn tìm được món.
class _RoomItemSlot extends StatefulWidget {
  const _RoomItemSlot({
    required this.item,
    required this.onTap,
    required this.showImage,
  });

  final RoomFurniture item;
  final VoidCallback onTap;
  final bool showImage;

  @override
  State<_RoomItemSlot> createState() => _RoomItemSlotState();
}

class _RoomItemSlotState extends State<_RoomItemSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _onTap() {
    // Hiệu ứng một lần, tắt khi chạy test (cổng AnimationGate) để ảnh
    // chụp xác định.
    if (AnimationGate.enabled) _pop.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key(widget.item.key),
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          if (widget.showImage)
            Image.asset(widget.item.asset, fit: BoxFit.fill),
          AnimatedBuilder(
            animation: _pop,
            builder: (context, _) {
              final t = _pop.value;
              if (t <= 0 || t >= 1) return const SizedBox.shrink();
              return IgnorePointer(
                child: CustomPaint(
                  key: Key('${widget.item.key}-pop'),
                  painter: _PopPainter(t),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Nháy "pop": vòng sáng nở ra + 4 sao nhỏ bay ra 4 góc rồi mờ dần,
/// tâm là giữa vùng chạm của món.
class _PopPainter extends CustomPainter {
  const _PopPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final e = Curves.easeOut.transform(t);
    final fade = 1 - t;
    final r = math.max(size.width, size.height) * (0.25 + 0.45 * e);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0xFFFFE08A).withValues(alpha: 0.9 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * fade + 1,
    );
    final star = Paint()
      ..color = const Color(0xFFFFC93C).withValues(alpha: fade);
    final reach = math.max(size.width, size.height) * (0.3 + 0.5 * e);
    for (var i = 0; i < 4; i++) {
      final a = -math.pi / 4 + i * math.pi / 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * reach;
      final s = 7.0 * (1 - 0.4 * t);
      final path = Path()
        ..moveTo(p.dx, p.dy - s)
        ..lineTo(p.dx + s * 0.35, p.dy - s * 0.35)
        ..lineTo(p.dx + s, p.dy)
        ..lineTo(p.dx + s * 0.35, p.dy + s * 0.35)
        ..lineTo(p.dx, p.dy + s)
        ..lineTo(p.dx - s * 0.35, p.dy + s * 0.35)
        ..lineTo(p.dx - s, p.dy)
        ..lineTo(p.dx - s * 0.35, p.dy - s * 0.35)
        ..close();
      canvas.drawPath(path, star);
    }
  }

  @override
  bool shouldRepaint(covariant _PopPainter old) => old.t != t;
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

/// Ô pet/trứng: trứng chưa nở thì hiện trứng (lắc lư chờ nở), đã nở
/// thì hiện pet theo giai đoạn lớn (F) với động tác riêng
/// ([PetSprite]: đi nước kiệu, thở/vẫy đuôi, động tác ngẫu nhiên,
/// nhảy vui + tim khi bé chạm). [facingLeft] lật ngang.
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
    final Widget shown;
    if (hatched) {
      shown = PetSprite(
        species: species,
        stage: stage == PetStage.egg ? PetStage.newborn : stage,
        walking: walking,
        facingLeft: facingLeft,
        happyTick: bounce,
      );
    } else {
      Widget egg = Image.asset(
        eggSpeciesAssets[species]!,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
      if (facingLeft) egg = Transform.flip(flipX: true, child: egg);
      shown = _RoomEggWiggle(child: egg);
    }
    return GestureDetector(
      key: Key(hatched ? 'room-pet' : 'room-egg'),
      onTap: onTap,
      child: shown,
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
