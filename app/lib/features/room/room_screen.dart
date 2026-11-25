/// Màn Phòng — màn chính từ bản 0.2 (T2-04), nền v3b từ (D).
///
/// T2-06b: khi đã mở khóa và pet đã nở, hai nút tròn "Cho ăn" / "Chơi"
/// ở góc dưới trái: chọn thức ăn/đồ chơi đã có → món hiện trước pet,
/// pet vui (nhảy + tim), thức ăn bị ăn (co nhỏ dần) / đồ chơi nảy lăn
/// rồi pet chạy tới chơi. Chỉ để vui, KHÔNG có đói/ốm/buồn. Chưa có
/// món nào thì nút mở thẳng tab "Đồ cho pet" của Cửa hàng. Nội thất đã
/// mua (khi `furnitureShopArtReady`) vẽ ở ô cố định `roomShopFurniture`,
/// xếp theo chân y cùng nhân vật/pet và chặn đường đi như đồ có sẵn.
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
/// nền `room_v3.webp` (1600x900) + 5 món đồ rời 512x512 đặt khớp món
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
import '../../core/widgets/rarity_badge.dart';
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
import '../pet/dragon_fx.dart';
import '../pet/dragon_fx_config.dart';
import '../pet/pet_care_service.dart';
import '../pet/pet_celebration.dart';
import '../pet/pet_config.dart';
import '../pet/pet_service.dart';
import '../quests/quest_service.dart';
import '../quests/quest_widgets.dart';
import '../rewards/reward_config.dart';
import '../rewards/reward_service.dart';
import '../shop/shop_catalog.dart';
import '../shop/shop_screen.dart';
import '../shop/shop_service.dart';
import '../town/town_screen.dart';
import 'pet_growth.dart';
import 'pet_sprite.dart';
import 'room_assets.dart';
import 'room_themes.dart';
import 'room_variants.dart';
import 'room_service.dart';
import 'room_walk.dart';

class RoomScreen extends ConsumerStatefulWidget {
  /// [cleanBackground] mặc định theo [roomCleanBackgroundReady]; chỉ
  /// đặt khác để test nhánh nền sạch.
  const RoomScreen({
    super.key,
    this.cleanBackground = roomCleanBackgroundReady,
    this.roomThemesReady = roomThemeArtReady,
    this.furnitureArtReady = furnitureShopArtReady,
  });

  /// Vẽ nội thất mua ở Cửa hàng; mặc định theo [furnitureShopArtReady],
  /// chỉ đặt khác để test nhánh bật cờ.
  final bool furnitureArtReady;

  /// Cờ hình phòng chủ đề (mặc định theo const; chỉ đổi trong test).
  final Map<String, bool> roomThemesReady;

  /// true = dùng `room_v3_clean.webp` + vẽ lại 5 PNG nội thất rời;
  /// false = nền `room_v3.webp` đã có sẵn 5 món, chỉ đặt vùng chạm.
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
  bool _questDot = false;
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
  int _petXp = 0;
  PetMood? _mood; // null: chưa có pet / còn là trứng
  int _meals = 0;
  List<PetInfo> _pets = const [];
  bool _canClaimEgg = false;
  List<String> _claimSpecies = const [];
  ({PetStage from, PetStage to, String species, String petId})? _celebration;
  Map<String, int> _foodCounts = const {};
  Set<String> _ownedToys = const {};
  Set<String> _ownedFurniture = const {};

  /// MỘT phòng: biến thể của nền ([roomThemeClassic] = gốc) và của từng
  /// món (mã món -> biến thể; thiếu = gốc), cùng quyền sở hữu biến thể.
  String _background = roomThemeClassic;
  Map<String, String> _variants = const {};
  RoomOwnership _ownership = const RoomOwnership({});

  /// Chế độ Sắp xếp: bé kéo thả đồ; [_layout] = vị trí đã đổi (mã món ->
  /// góc trên-trái, khung 1600x900), chung cho mọi biến thể.
  bool _arranging = false;
  Map<String, Offset> _layout = const {};
  String? _dragId;
  Offset _dragRaw = Offset.zero;
  String? _petMenu; // 'food' | 'toy': bảng chọn đang mở
  bool _petBusy = false;
  _PetProp? _prop;
  late final AnimationController _propCtl = AnimationController(vsync: this);

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

  // Rồng: hành động + bảng 3 nút (chạm rồng hiện, tự ẩn sau vài giây).
  final DragonFxController _dragonFx = DragonFxController();
  bool _dragonMenu = false;
  bool _dragonHintShown = false;
  Timer? _dragonMenuTimer;

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
    _dragonMenuTimer?.cancel();
    _dragonFx.dispose();
    _propCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final db = ref.read(databaseProvider);
      final childId = await db.ensureSeeded();
      final profile = await OnboardingService(db: db).loadProfile(childId);
      final eggs = EggService(db: db);
      final petService = PetService(db: db);
      final care = PetCareService(db: db);
      final activePet = await petService.active(childId);
      final eggSpecies = activePet?.species;
      final hatched = activePet?.hatched ?? false;
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
      final shop = ShopService(db: db);
      final ownedItems = await shop.owned(childId);
      final foodCounts = await shop.foodCounts(childId);
      final ownership = RoomOwnership(
        ownedItems,
        ready: widget.roomThemesReady,
      );
      final look = await RoomLookStore(db).load(childId);
      // Biến thể đã lưu mà bé không còn dùng được (chưa có hình / chưa
      // có) thì về gốc.
      final background = ownership.hasBackground(look.background)
          ? look.background
          : roomThemeClassic;
      final variants = {
        for (final p in roomPlaceables)
          if (look.variantOf(p.id) != roomThemeClassic &&
              ownership.hasItemVariant(look.variantOf(p.id), p.id))
            p.id: look.variantOf(p.id),
      };
      final layout = look.layout;
      final petStage = activePet?.stage ?? PetStage.egg;
      // Pet lớn lên từ lần bé thấy trước → màn ăn mừng (bấm "Tuyệt vời"
      // mới ghi giai đoạn đã thấy). Giá trị lạ/trứng: ghi lặng lẽ.
      final seen = activePet?.stageSeen;
      ({PetStage from, PetStage to, String species, String petId})? celebration;
      if (activePet != null && hatched && seen != petStage) {
        if (seen != null &&
            seen != PetStage.egg &&
            seen.index < petStage.index) {
          celebration = (
            from: seen,
            to: petStage,
            species: activePet.species,
            petId: activePet.id,
          );
        } else {
          await petService.markStageSeen(activePet.id, petStage);
        }
      }
      final mood = await care.mood(childId);
      final meals = await care.mealCount(childId);
      var questDot = false;
      try {
        questDot = await QuestService(db: db).hasClaimable(childId);
      } catch (_) {}
      final allPets = await petService.pets(childId);
      final canClaim = await petService.canClaimStarterEgg(childId);
      final claimSpecies = canClaim
          ? await petService.availableStarterSpecies(childId)
          : const <String>[];
      if (!mounted) return;
      setState(() {
        _childId = childId;
        _questDot = questDot;
        _headAccessory = accessory;
        _glasses = glasses;
        _whiteShoes = whiteShoes;
        _backpack = backpack;
        _foodCounts = foodCounts;
        _ownedToys = {
          for (final id in petToys.keys)
            if (ownedItems.contains(id)) id,
        };
        _ownedFurniture = {
          for (final id in shopFurniture.keys)
            if (ownedItems.contains(id)) id,
        };
        _ownership = ownership;
        _background = background;
        _variants = variants;
        _layout = layout;
        _petXp = activePet?.xp ?? 0;
        _petStage = petStage;
        _mood = mood;
        _meals = meals;
        _pets = allPets;
        _canClaimEgg = canClaim;
        _claimSpecies = claimSpecies;
        _celebration = celebration;
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
      if (mood == PetMood.happy && celebration == null) {
        setState(() => _petBounce++);
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
    if (_arranging) return;
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
    if (species == dragonSpecies) {
      _onDragonTap();
      return;
    }
    setState(() => _petBounce++);
    final happy = petHappyLines[species] ?? 'Vui quá!';
    final next = petXpToNextStage(_petXp);
    _showBubble(switch (_mood) {
      PetMood.hungry => 'Tớ đói rồi, cho tớ ăn nhé!',
      PetMood.sad => 'Chơi với tớ đi, tớ buồn quá!',
      _ => next == null ? happy : '$happy Còn $next câu đúng nữa tớ sẽ lớn!',
    }, seconds: 2);
  }

  /// Chạm rồng: nhảy vui + hiện/ẩn 3 nút hành động (tự ẩn sau
  /// [dragonMenuHideMs]). Rồng chưa lớn nhắc một lần là lớn rồng mới
  /// phun lửa thật.
  void _onDragonTap() {
    _dragonMenuTimer?.cancel();
    final open = !_dragonMenu;
    setState(() {
      _petBounce++;
      _dragonMenu = open;
    });
    if (open) {
      _dragonMenuTimer = Timer(
        const Duration(milliseconds: dragonMenuHideMs),
        _hideDragonMenu,
      );
      if (_petStage != PetStage.adult && !_dragonHintShown) {
        _dragonHintShown = true;
        _showBubble(dragonHintText, seconds: 3);
      }
    }
  }

  void _hideDragonMenu() {
    _dragonMenuTimer?.cancel();
    if (!mounted || !_dragonMenu) return;
    setState(() => _dragonMenu = false);
  }

  void _onDragonAction(DragonAction action) {
    _hideDragonMenu();
    _dragonFx.play(action);
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
    // Góp ý 24/11: mở Tủ đồ là bảng to gần kín màn, ảnh to dễ nhìn.
    final screenH = MediaQuery.sizeOf(context).height;
    final sheetH = screenH * 0.94;
    final tileH = ((sheetH - 200) / 2).clamp(92.0, 220.0);
    final tileW = (tileH * 1.05 + 12).clamp(104.0, 250.0);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: sheetH, maxWidth: double.infinity),
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
                width: tileW,
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
                      height: tileH,
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
                          : '$label\n${_priceText(gender, lockedItemId)}',
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
              label: Text('$label · ${_priceText(gender, itemId)}'),
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
                        for (var n = 1; n <= kidOutfitLimit(); n++)
                          choice(
                            key: Key('room-wardrobe-outfit-$n'),
                            selected: n == outfit,
                            lockedItemId:
                                owned.contains(kidAllOutfitIds[gender]![n - 1])
                                ? null
                                : kidAllOutfitIds[gender]![n - 1],
                            label:
                                kidOutfitNames[kidAllOutfitIds[gender]![n -
                                    1]]!,
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
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: Image.asset(
                                    kidFullAsset(gender, n),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Positioned(
                                  left: -12,
                                  top: -10,
                                  child: RarityBadge(
                                    key: Key('room-wardrobe-rarity-$n'),
                                    rarity: outfitRarityOf(n),
                                    compact: true,
                                    tilted: true,
                                  ),
                                ),
                              ],
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
                            // Giữ đúng tỉ lệ khung 1024x1536 (góp ý 24/11:
                            // ảnh phụ kiện bị méo khi kéo giãn theo ô).
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: kidFrameWidth / kidFrameHeight,
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

  String _priceText(String gender, String itemId) {
    final item = shopItemById(gender, itemId);
    if (item == null) return '';
    return item.usesGems ? '${item.price} kim cương' : '${item.price} xu';
  }

  /// "Thay cả bộ": chọn phòng gốc hoặc một bộ chủ đề bé có nền. Chọn bộ =
  /// đổi nền + MỌI món bé có biến thể của bộ đó (món chưa có giữ nguyên);
  /// "Phòng gốc" = nền và mọi món về gốc. Vị trí đồ không đổi.
  Future<void> _openThemePicker() async {
    final childId = _childId;
    if (childId == null) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          key: const Key('room-theme-sheet'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Text(
                  'Thay\ncả bộ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              for (final (id, name, bg) in [
                (roomThemeClassic, 'Phòng gốc', roomCleanBackgroundAsset),
                for (final t in _ownership.backgroundThemes)
                  (t.id, t.name, roomThemeBackground(t.id)),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    key: Key('room-theme-$id'),
                    onTap: () => Navigator.of(sheetContext).pop(id),
                    child: Container(
                      width: (MediaQuery.sizeOf(sheetContext).height * 0.38)
                          .clamp(140.0, 260.0),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: id == _background
                              ? const Color(0xFFE58FB0)
                              : const Color(0xFFE3DAF5),
                          width: 3,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AspectRatio(
                              aspectRatio: roomFrameWidth / roomFrameHeight,
                              child: Image.asset(
                                bg,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const ColoredBox(color: Color(0xFFF3EEFB)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final variants = roomApplySet(_ownership, _variants, choice);
    final store = RoomLookStore(ref.read(databaseProvider));
    await store.saveBackground(childId, choice);
    await store.saveVariants(childId, variants);
    if (mounted) {
      setState(() {
        _background = choice;
        _variants = variants;
      });
      _fixWalkers();
    }
  }

  /// Biến thể đang dùng của món [p].
  String _variantOf(RoomPlaceable p) => _variants[p.id] ?? roomThemeClassic;

  /// Chế độ Sắp xếp, chạm một món (không kéo): chọn biến thể riêng món đó
  /// (gốc + mọi biến thể bé có). Món chưa có biến thể nào thì không mở.
  Future<void> _openVariantSheet(RoomPlaceable p) async {
    final childId = _childId;
    if (childId == null) return;
    final options = _ownership.variantsOf(p.id);
    if (options.length < 2) return;
    final current = _variantOf(p);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          key: const Key('room-variant-sheet'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              for (final v in options)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    key: Key('room-variant-$v'),
                    onTap: () => Navigator.of(sheetContext).pop(v),
                    child: Container(
                      width: 110,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: v == current
                              ? const Color(0xFFE58FB0)
                              : const Color(0xFFE3DAF5),
                          width: 3,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: 90,
                            child: Image.asset(
                              p.assetFor(v),
                              fit: BoxFit.contain,
                              // Thiếu ảnh biến thể: hiện ảnh gốc.
                              errorBuilder: (_, _, _) => Image.asset(
                                p.item.asset,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                          Text(
                            v == roomThemeClassic
                                ? 'Gốc'
                                : (roomThemeById(v)?.shortName ?? v),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || choice == current || !mounted) return;
    final variants = {..._variants};
    if (choice == roomThemeClassic) {
      variants.remove(p.id);
    } else {
      variants[p.id] = choice;
    }
    setState(() => _variants = variants);
    await RoomLookStore(ref.read(databaseProvider))
        .saveVariants(childId, variants);
  }

  /// Món kéo thả đang vẽ trong phòng: món nhỏ có sẵn (nền sạch; vẽ ở mọi
  /// biến thể nền) + nội thất mua (khi cờ hình bật).
  List<RoomPlaceable> get _activePlaceables => [
    for (final p in roomPlaceables)
      if (p.shopId == null
          ? widget.cleanBackground
          : widget.furnitureArtReady && _ownedFurniture.contains(p.shopId))
        p,
  ];

  /// Góc trên-trái hiện tại của [p] (đã kẹp vào vùng hợp lệ).
  Offset _posOf(RoomPlaceable p) {
    final saved = _layout[p.id];
    return saved == null ? p.defaultPos : roomClampPlaceable(p, saved);
  }

  void _toggleArranging() {
    _hideDragonMenu();
    setState(() {
      _arranging = !_arranging;
      _petMenu = null;
      _dragId = null;
    });
  }

  void _onDragStart(RoomPlaceable p) {
    _dragRaw = _posOf(p);
    setState(() => _dragId = p.id);
  }

  /// [frameDelta]: độ dời ngón tay đã đổi sang khung 1600x900.
  void _onDragUpdate(RoomPlaceable p, Offset frameDelta) {
    _dragRaw += frameDelta;
    final clamped = roomClampPlaceable(p, _dragRaw);
    setState(() => _layout = {..._layout, p.id: clamped});
  }

  Future<void> _onDragEnd() async {
    setState(() => _dragId = null);
    _fixWalkers();
    await _saveLayout();
  }

  Future<void> _saveLayout() async {
    final childId = _childId;
    if (childId == null) return;
    await RoomLookStore(ref.read(databaseProvider))
        .saveLayout(childId, _layout);
  }

  /// "Xếp lại như cũ": xóa vị trí đã lưu (biến thể từng món giữ nguyên).
  Future<void> _resetLayout() async {
    setState(() {
      _layout = const {};
      _dragId = null;
    });
    _fixWalkers();
    final childId = _childId;
    if (childId == null) return;
    await RoomLookStore(ref.read(databaseProvider)).resetLayout(childId);
  }

  /// Món vừa đặt chặn chỗ nhân vật/pet đang đứng: dời họ ra chỗ đứng được.
  void _fixWalkers() {
    if (!mounted) return;
    final extra = _extraObstacles;
    var kid = _kidFeet;
    var pet = _petFeet;
    if (!roomWalkable(kid, extra: extra)) {
      kid = roomWalkTarget(kid, extra: extra);
    }
    if (!roomWalkable(pet, extra: extra)) {
      pet = roomWalkTarget(pet, extra: extra);
    }
    if (kid == _kidFeet && pet == _petFeet) return;
    setState(() {
      _kidFeet = kid;
      _petFeet = pet;
    });
  }

  /// Bấm món chưa mua trong Tủ đồ: đóng bảng, mở Cửa hàng ("Mua ở
  /// Cửa hàng").
  void _openShopFromWardrobe(BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    _openShop();
  }

  /// Sang Cửa hàng, quay lại thì tải lại số dư (mua xong xu giảm).
  /// [tab] (vd `pet`) mở thẳng nhóm hàng đó (`/shop?tab=pet`).
  Future<void> _openShop({String? tab}) async {
    await context.push(
      tab == null ? ShopScreen.route : '${ShopScreen.route}?tab=$tab',
    );
    if (mounted) _refresh();
  }

  /// Bấm vào nhân vật: vẫy tay chào 1,4 giây.
  void _onKidTap() {
    if (_arranging) return;
    _waveTimer?.cancel();
    setState(() => _kidWaving = true);
    final name = _profile?.name ?? '';
    _showBubble(name.isEmpty ? 'Xin chào!' : 'Xin chào, tớ là $name!');
    _waveTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _kidWaving = false);
    });
  }

  /// Dấu chân nội thất mua trên sàn (chặn đường đi như đồ có sẵn),
  /// dời theo chỗ bé đã kéo món tới.
  List<Rect> get _extraObstacles => [
    for (final p in _activePlaceables) ?p.footprintAt(_posOf(p)),
  ];

  bool get _petInteractive => _eggSpecies != null && !_loading;

  /// Nút Cho ăn: chưa có thức ăn/suất ăn nào thì mở Cửa hàng ở tab
  /// Đồ cho pet (suất ăn nhận khi xong chặng), có rồi thì mở/đóng bảng chọn (suất ăn + thức ăn mua).
  void _onFeedButton() {
    if (_petBusy) return;
    final any = _meals > 0 || _foodCounts.values.any((n) => n > 0);
    if (!any) {
      _openShop(tab: ShopCategory.pet.key);
      return;
    }
    setState(() => _petMenu = _petMenu == 'food' ? null : 'food');
  }

  /// Nút Chơi: bảng chọn luôn có "Vuốt ve" + đồ chơi đã mua.
  void _onPlayButton() {
    if (_petBusy) return;
    setState(() => _petMenu = _petMenu == 'toy' ? null : 'toy');
  }

  /// Cho pet ăn [foodId]: trừ một phần (transaction trong
  /// [ShopService.consumeFood]), thức ăn hiện trước pet, pet nhảy vui +
  /// thả tim rồi thức ăn co nhỏ dần như đang nhai và biến mất.
  Future<void> _feed(String foodId) async {
    final childId = _childId;
    if (childId == null || _petBusy) return;
    setState(() {
      _petMenu = null;
      _petBusy = true;
    });
    final db = ref.read(databaseProvider);
    final result = await PetCareService(db: db).feed(childId, foodId: foodId);
    final counts = await ShopService(db: db).foodCounts(childId);
    final meals = await PetCareService(db: db).mealCount(childId);
    final mood = await PetCareService(db: db).mood(childId);
    if (!mounted) return;
    if (result != CareResult.done) {
      setState(() {
        _foodCounts = counts;
        _meals = meals;
        _petBusy = false;
      });
      return;
    }
    final dir = _petFacingLeft ? -1.0 : 1.0;
    final box =
        petBoxSize(_petStage, species: _eggSpecies) *
        roomDepthScale(_petFeet.dy);
    final at = Offset(
      (_petFeet.dx + dir * box * 0.6).clamp(30.0, roomFrameWidth - 30),
      _petFeet.dy + 4,
    );
    setState(() {
      _foodCounts = counts;
      _meals = meals;
      _mood = mood;
      _prop = _PetProp(
        isToy: false,
        id: foodId,
        asset: foodId == petMealId
            ? (petUiArtReady ? petMealAsset : null)
            : petFoods[foodId]!.$2,
        start: at,
        rest: at,
        dir: dir,
      );
    });
    _showBubble('Ngon quá! Cảm ơn bé!');
    _propCtl.duration = const Duration(milliseconds: 2000);
    var cheered = false;
    void tick() {
      if (!cheered && _propCtl.value >= 0.5 && mounted) {
        cheered = true;
        setState(() => _petBounce++);
      }
    }

    _propCtl.addListener(tick);
    try {
      await _propCtl.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    } finally {
      _propCtl.removeListener(tick);
    }
    if (!mounted) return;
    setState(() {
      _prop = null;
      _petBusy = false;
    });
  }

  /// Chơi với [toyId]: đồ chơi hiện cạnh pet, nảy/lăn ra chỗ trống, pet
  /// chạy tới chơi (nhảy vui + tim) rồi đồ chơi mờ dần.
  Future<void> _play(String? toyId) async {
    final childId = _childId;
    if (childId == null || _petBusy) return;
    final db = ref.read(databaseProvider);
    final care = PetCareService(db: db);
    final result = await care.play(childId, toyId: toyId);
    if (!mounted) return;
    if (result != CareResult.done) {
      setState(() => _petMenu = null);
      _showBubble(
        result == CareResult.needStage
            ? petLockedLine
            : 'Chưa chơi được, bé thử lại nhé!',
        seconds: 2,
      );
      return;
    }
    final mood = await care.mood(childId);
    if (!mounted) return;
    if (toyId == null) {
      // Vuốt ve: pet nhảy vui + tim, không cần món.
      setState(() {
        _petMenu = null;
        _mood = mood;
        _petBounce++;
      });
      _showBubble('Ngoan nào! ${petHappyLines[_eggSpecies] ?? 'Vui quá!'}');
      return;
    }
    setState(() {
      _petMenu = null;
      _mood = mood;
      _petBusy = true;
    });
    final extra = _extraObstacles;
    var dir = _petFacingLeft ? -1.0 : 1.0;
    if (_petFeet.dx + dir * 230 < 150 || _petFeet.dx + dir * 230 > 1450) {
      dir = -dir;
    }
    final rest = roomWalkTarget(
      Offset(_petFeet.dx + dir * 230, _petFeet.dy),
      extra: extra,
    );
    final start = Offset(_petFeet.dx + dir * 70, _petFeet.dy - 4);
    final spot = roomWalkTarget(
      Offset(rest.dx - dir * 70, rest.dy),
      extra: extra,
    );
    setState(() {
      _prop = _PetProp(
        isToy: true,
        id: toyId,
        asset: petToys[toyId]!.$2,
        start: start,
        rest: rest,
        dir: dir,
      );
    });
    _showBubble('Chơi nào! ${petHappyLines[_eggSpecies] ?? 'Vui quá!'}');
    // Pet chạy tới chỗ đồ chơi trong lúc đồ chơi nảy/lăn.
    _walk(isKid: false, path: roomWalkPath(_petFeet, spot, extra: extra));
    _propCtl.duration = const Duration(milliseconds: 3600);
    var cheered = false;
    void tick() {
      if (!cheered && _propCtl.value >= 0.6 && mounted) {
        cheered = true;
        setState(() {
          _petBounce++;
          _petFacingLeft = rest.dx < _petFeet.dx;
        });
      }
    }

    _propCtl.addListener(tick);
    try {
      await _propCtl.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    } finally {
      _propCtl.removeListener(tick);
    }
    if (!mounted) return;
    setState(() {
      _prop = null;
      _petBusy = false;
    });
  }

  /// (G) Bé chạm vào sàn: nhân vật đi tới đó, pet đi theo sau lưng.
  void _onFloorTap(Offset frame) {
    if (_arranging) return;
    if (_petMenu != null) setState(() => _petMenu = null);
    _hideDragonMenu();
    _dragonFx.cancel();
    final extra = _extraObstacles;
    final target = roomWalkTarget(frame, extra: extra);
    final path = roomWalkPath(_kidFeet, target, extra: extra);
    _walk(isKid: true, path: path);
    if (_eggSpecies != null && _hatched) {
      final facingLeft = target.dx < _kidFeet.dx;
      final spot = roomPetFollowSpot(
        target,
        kidFacingLeft: facingLeft,
        extra: extra,
      );
      Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _walk(isKid: false, path: roomWalkPath(_petFeet, spot, extra: extra));
      });
    }
  }

  /// Đi lần lượt qua các điểm [path]; lần đi mới hủy lần cũ.
  Future<void> _walk({required bool isKid, required List<Offset> path}) async {
    final controller = isKid ? _kidMove : _petMove;
    final id = isKid ? ++_kidWalkId : ++_petWalkId;
    bool current() => (isKid ? _kidWalkId : _petWalkId) == id;
    controller.stop();
    if (!isKid) _dragonFx.setCruising(false);
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
      // Rồng trưởng thành đi quãng dài thì bay (hạ cánh khi tới nơi).
      if (!isKid &&
          dragonShouldFlyWalk(
            species: _eggSpecies ?? '',
            stage: _petStage,
            length: length,
          )) {
        _dragonFx.setCruising(true);
      }
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
    if (!isKid) _dragonFx.setCruising(false);
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
                    // Cột nút bên trái: Thị trấn, rồi Nhiệm vụ (xếp dọc để
                    // thanh chỉ số không bị ép hẹp ở màn nhỏ).
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GameRoundButton(
                          key: const Key('room-town-button'),
                          icon: Icons.location_city_rounded,
                          image: '$uiArt/ui_icon_town.webp',
                          color: const Color(0xFFA07BE0),
                          label: 'Thị trấn',
                          onPressed: () => context.go(TownScreen.route),
                        ),
                        const SizedBox(height: 4),
                        QuestHudButton(
                          key: const Key('room-quest-button'),
                          showDot: _questDot,
                          onPressed: () async {
                            await showQuestBoardDialog(context);
                            if (mounted) _refresh();
                          },
                        ),
                      ],
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
                              image: '$uiArt/ui_coin.webp',
                              color: const Color(0xFFF5B83D),
                              text: '$_xu',
                              textKey: const Key('room-xu-balance'),
                            ),
                            GameStat(
                              icon: Icons.diamond_rounded,
                              image: '$uiArt/ui_gem.webp',
                              color: const Color(0xFFA07BE0),
                              text: '$_gems',
                              textKey: const Key('room-gem-balance'),
                            ),
                            GameStat(
                              icon: Icons.star_rounded,
                              image: '$uiArt/ui_star.webp',
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
                    if (_arranging) ...[
                      GameRoundButton(
                        key: const Key('room-arrange-reset'),
                        icon: Icons.restart_alt_rounded,
                        color: const Color(0xFFE58FB0),
                        label: 'Xếp lại như cũ',
                        onPressed: _resetLayout,
                      ),
                      const SizedBox(width: 8),
                      GameRoundButton(
                        key: const Key('room-arrange-done'),
                        icon: Icons.check_rounded,
                        color: const Color(0xFF5DC3A8),
                        label: 'Xong',
                        onPressed: _toggleArranging,
                      ),
                    ] else ...[
                      if (_ownership.hasAnyTheme) ...[
                        GameRoundButton(
                          key: const Key('room-theme-button'),
                          icon: Icons.wallpaper_rounded,
                          color: const Color(0xFFE58FB0),
                          label: 'Phong cách',
                          onPressed: _openThemePicker,
                        ),
                        const SizedBox(width: 8),
                      ],
                      GameRoundButton(
                        key: const Key('room-wardrobe-button'),
                        icon: Icons.checkroom_rounded,
                        image: '$uiArt/ui_icon_wardrobe.webp',
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
                        image: '$uiArt/ui_icon_shop.webp',
                        color: const Color(0xFF5DC3A8),
                        label: 'Cửa hàng',
                        locked: !_unlocked,
                        onPressed: () => _unlocked
                            ? _openShop()
                            : _showLockedReminder('Cửa hàng'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Nút Sắp xếp nằm dưới hàng nút góc phải (hàng trên đã đầy ở màn
          // nhỏ); khi đang sắp xếp, hàng đó đổi thành Xếp lại / Xong.
          if (!_arranging)
            Positioned(
              right: 8,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 84),
                  child: GameRoundButton(
                    key: const Key('room-arrange-button'),
                    icon: Icons.open_with_rounded,
                    color: const Color(0xFFF2A65A),
                    label: 'Sắp xếp',
                    onPressed: _toggleArranging,
                  ),
                ),
              ),
            ),
          if (_petInteractive && !_arranging) _petControls(),
          if (_celebration case final c?)
            Positioned.fill(
              child: PetGrowCelebration(
                species: c.species,
                from: c.from,
                to: c.to,
                onDone: () async {
                  final db = ref.read(databaseProvider);
                  await PetService(db: db).markStageSeen(c.petId, c.to);
                  if (mounted) setState(() => _celebration = null);
                },
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

  /// Các nút chăm pet ở góc dưới trái: Cho ăn / Chơi (khi pet đã nở),
  /// "Pet của bé" (khi có từ 2 pet), "Nhận trứng mới" (khi pet trưởng
  /// thành) + bảng chọn món (suất ăn, thức ăn mua, đồ chơi, vuốt ve).
  Widget _petControls() {
    final menu = _petMenu;
    // (mã, tên, ảnh hoặc null → icon, số lượng hoặc null)
    final entries = <(String, String, String?, int?)>[
      if (menu == 'food') ...[
        if (_meals > 0)
          (petMealId, petMealName, petUiArtReady ? petMealAsset : null, _meals),
        for (final e in petFoods.entries)
          if ((_foodCounts[e.key] ?? 0) > 0)
            (e.key, e.value.$1, e.value.$2, _foodCounts[e.key]),
      ],
      if (menu == 'toy') ...[
        (petPatId, 'Vuốt ve', null, null),
        for (final e in petToys.entries)
          if (_ownedToys.contains(e.key)) (e.key, e.value.$1, e.value.$2, null),
      ],
    ];
    return Positioned(
      left: 8,
      bottom: 6,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entries.isNotEmpty)
              Container(
                key: const Key('room-pet-menu'),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xF2FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD0BFF0), width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final e in entries)
                      PressBounce(
                        child: GestureDetector(
                          key: Key(
                            e.$1 == petPatId
                                ? 'room-pet-pat'
                                : 'room-pet-${menu == 'food' ? 'food' : 'toy'}-${e.$1}',
                          ),
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (menu == 'food') {
                              _feed(e.$1);
                            } else {
                              _play(e.$1 == petPatId ? null : e.$1);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (e.$3 != null)
                                  Image.asset(
                                    e.$3!,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.contain,
                                    semanticLabel: e.$2,
                                  )
                                else
                                  SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Icon(
                                      e.$1 == petPatId
                                          ? Icons.back_hand_rounded
                                          : Icons.rice_bowl_rounded,
                                      size: 34,
                                      color: const Color(0xFFFF9E5E),
                                    ),
                                  ),
                                Text(
                                  e.$4 == null ? e.$2 : '${e.$2} ×${e.$4}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: gameInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hatched) ...[
                  GameRoundButton(
                    key: const Key('room-pet-feed-button'),
                    icon: Icons.restaurant_rounded,
                    color: const Color(0xFFFF9E5E),
                    label: 'Cho ăn',
                    onPressed: _onFeedButton,
                  ),
                  const SizedBox(width: 8),
                  GameRoundButton(
                    key: const Key('room-pet-play-button'),
                    icon: Icons.sports_baseball_rounded,
                    color: const Color(0xFF5DB7F0),
                    label: 'Chơi',
                    onPressed: _onPlayButton,
                  ),
                  const SizedBox(width: 8),
                ],
                if (_pets.length > 1)
                  GameRoundButton(
                    key: const Key('room-pets-button'),
                    icon: Icons.pets_rounded,
                    color: const Color(0xFF8E6FD8),
                    label: 'Pet của bé',
                    onPressed: _openPetPicker,
                  ),
                if (_canClaimEgg) ...[
                  const SizedBox(width: 8),
                  GameRoundButton(
                    key: const Key('room-new-egg-button'),
                    icon: Icons.egg_rounded,
                    color: const Color(0xFFFFB84D),
                    label: 'Nhận trứng mới',
                    onPressed: _openNewEggPicker,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "Pet của bé": danh sách pet đã có, bấm để đổi pet đi theo.
  Future<void> _openPetPicker() async {
    final childId = _childId;
    if (childId == null) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              key: const Key('room-pet-picker'),
              children: [
                for (final p in _pets)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: InkWell(
                      key: Key('room-pet-pick-${p.species}'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(sheetContext).pop(p.id),
                      child: Container(
                        width: 120,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: p.active
                              ? const Color(0xFFEDE4FB)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: p.active
                                ? const Color(0xFF8E6FD8)
                                : const Color(0xFFD9C2E8),
                            width: p.active ? 3 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                SizedBox(
                                  height: 56,
                                  child: DragonAura.wrapIf(
                                    p.species,
                                    Image.asset(
                                      p.hatched
                                          ? petAsset(p.species, p.stage)
                                          : (eggSpeciesAssets[p.species] ??
                                                petEggAsset(p.species)),
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.pets_rounded,
                                        size: 48,
                                        color: Color(0xFFB9A3E3),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: -14,
                                  top: -10,
                                  child: RarityBadge(
                                    key: Key('room-pet-rarity-${p.species}'),
                                    rarity:
                                        petShopSpeciesById(p.species)?.rarity ??
                                        PetRarity.common,
                                    compact: true,
                                    tilted: true,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              petDisplayName(p.species),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              p.active
                                  ? 'Đang đi theo'
                                  : petStageNames[p.stage]!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await PetService(db: ref.read(databaseProvider)).setActive(childId, picked);
    if (mounted) await _refresh();
  }

  /// "Nhận trứng mới": chọn 1 trong các loài khởi đầu chưa có.
  Future<void> _openNewEggPicker() async {
    final childId = _childId;
    if (childId == null) return;
    final species = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              key: const Key('room-new-egg-picker'),
              children: [
                for (final sp in _claimSpecies)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: InkWell(
                      key: Key('room-new-egg-$sp'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(sheetContext).pop(sp),
                      child: Container(
                        width: 120,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD9C2E8)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 56,
                              child: Image.asset(
                                eggSpeciesAssets[sp] ?? petEggAsset(sp),
                                fit: BoxFit.contain,
                              ),
                            ),
                            Text(
                              petDisplayName(sp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (species == null || !mounted) return;
    final egg = await PetService(db: ref.read(databaseProvider))
        .claimStarterEgg(childId, species);
    if (!mounted) return;
    await _refresh();
    if (egg != null && mounted) {
      _showBubble('Trứng mới! Xong một chặng là trứng nở nhé!', seconds: 3);
    }
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
          final themed = _background != roomThemeClassic;
          double fx(double x) => x / roomFrameWidth * w;
          double fy(double y) => y / roomFrameHeight * h;

          /// Bóng đổ mềm ngay dưới [anchor]: rộng 85% và cao 10%
          /// chiều rộng món (nhân vật/pet dùng bề rộng hình).
          Widget frameShadow(
            Offset anchor,
            double width, {
            ValueNotifier<double>? lift,
            Key? key,
          }) {
            final sw = width * 0.85;
            final sh = width * 0.10;
            return Positioned(
              key: key,
              left: fx(anchor.dx - sw / 2),
              top: fy(anchor.dy - sh * 0.3),
              width: fx(sw),
              height: fy(sh),
              // Rồng bay: bóng đất co lại + mờ theo độ cao.
              child: lift == null
                  ? const _SoftShadow()
                  : ValueListenableBuilder<double>(
                      valueListenable: lift,
                      builder: (context, l, child) {
                        final k = (l / dragonFlyLift).clamp(0.0, 1.0);
                        return Opacity(
                          opacity: 1 - (1 - dragonShadowMinOpacity) * k,
                          child: Transform.scale(
                            scale: 1 - (1 - dragonShadowMinScale) * k,
                            child: child,
                          ),
                        );
                      },
                      child: const _SoftShadow(),
                    ),
            );
          }

          // 5 món có sẵn của phòng (theo chân y). Món vẽ rời (nền sạch)
          // nằm trong [placeables] và kéo thả được; món còn vẽ sẵn trong
          // nền (chậu cây; cả 5 món khi dùng nền cũ) chỉ có vùng chạm.
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
          final petBox = petBoxSize(_petStage, species: _eggSpecies) * petScale;
          final placeables = _activePlaceables;
          Widget placeableSlot(RoomPlaceable p) {
            final pos = _posOf(p);
            return Positioned(
              key: ValueKey('place-${p.id}'),
              left: fx(pos.dx),
              top: fy(pos.dy),
              width: fx(p.size),
              height: fy(p.size),
              child: _RoomItemSlot(
                item: p.item,
                showImage: true,
                asset: p.assetFor(_variantOf(p)),
                arranging: _arranging,
                dragging: _dragId == p.id,
                onTap: () => _showBubble(p.item.reaction),
                onArrangeTap: () => _openVariantSheet(p),
                onDragStart: () => _onDragStart(p),
                onDragUpdate: (d) => _onDragUpdate(
                  p,
                  Offset(d.dx / w * roomFrameWidth, d.dy / h * roomFrameHeight),
                ),
                onDragEnd: _onDragEnd,
              ),
            );
          }

          final actors = <(double, List<Widget>)>[
            // Đồ trên sàn/mặt phẳng: xếp theo chân y như nhân vật/pet
            // (món gắn tường vẽ riêng, luôn ở sau).
            for (final p in placeables)
              if (!p.wall)
                (
                  _posOf(p).dy + p.anchorOffset.dy,
                  [
                    frameShadow(
                      _posOf(p) + p.anchorOffset,
                      p.size,
                      key: ValueKey('shadow-${p.id}'),
                    ),
                    placeableSlot(p),
                  ],
                ),
            if (_prop case final prop?)
              (
                // Thức ăn ngay trước pet; đồ chơi theo chỗ nó nằm.
                prop.rest.dy + 2,
                [
                  Positioned.fill(
                    child: _PetPropLayer(
                      prop: prop,
                      animation: _propCtl,
                      frameW: w,
                      frameH: h,
                      scale: roomDepthScale(prop.rest.dy),
                    ),
                  ),
                ],
              ),
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
                  frameShadow(
                    _petFeet,
                    petBox * 0.7,
                    lift: _eggSpecies == dragonSpecies ? _dragonFx.lift : null,
                  ),
                  if (_hatched && _mood != null && !_dragonMenu)
                    Positioned(
                      key: const ValueKey('room-pet-mood'),
                      left: fx(_petFeet.dx - 28),
                      top: fy(_petFeet.dy - petBox * 440 / 512 - 44),
                      width: fx(56),
                      height: fy(56),
                      child: _PetMoodBubble(mood: _mood!),
                    ),
                  // Có khóa: bong bóng tâm trạng bật/tắt không làm pet
                  // (và hiệu ứng rồng đang chạy) bị dựng lại.
                  Positioned(
                    key: const ValueKey('room-pet-slot'),
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
                      dragonFx: _dragonFx,
                    ),
                  ),
                ],
              ),
            // Bảng 3 nút của rồng: phía trên đầu, vẽ trên cùng.
            if (_eggSpecies == dragonSpecies && _hatched && _dragonMenu)
              (
                3000,
                [
                  Positioned(
                    left:
                        (fx(_petFeet.dx) - DragonActionMenu.widthFor(fx(1)) / 2)
                            .clamp(
                              4.0,
                              math.max(
                                4.0,
                                fx(roomFrameWidth) -
                                    DragonActionMenu.widthFor(fx(1)) -
                                    4,
                              ),
                            ),
                    top: math.max(
                      4.0,
                      fy(_petFeet.dy - petBox * 440 / 512 - 150),
                    ),
                    child: DragonActionMenu(
                      scale: fx(1),
                      enabled: !_dragonFx.busy,
                      onAction: _onDragonAction,
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
                    themed
                        ? roomThemeBackground(_background)
                        : clean
                        ? roomCleanBackgroundAsset
                        : roomBackgroundAsset,
                    fit: BoxFit.fill,
                    width: w,
                    height: h,
                    // Nền chủ đề lỗi/chưa có: về nền gốc thay vì trống.
                    errorBuilder: (_, _, _) => Image.asset(
                      roomCleanBackgroundAsset,
                      fit: BoxFit.fill,
                      width: w,
                      height: h,
                    ),
                  ),
                ),
              ),
              // Món còn vẽ sẵn trong nền (chậu cây; cả 5 món khi dùng nền
              // cũ): chỉ đặt vùng chạm vô hình đúng chỗ món trong nền, không
              // vẽ PNG rời → không hình đôi. Nền chủ đề (biến thể nền khác gốc)
              // không vẽ sẵn chậu cây của phòng gốc nên bỏ vùng chạm này.
              for (final item in themed ? const <RoomFurniture>[] : itemsByFeet)
                if (!clean || item.inCleanBackground)
                  Positioned(
                    left: fx(item.bakedRect.left),
                    top: fy(item.bakedRect.top),
                    width: fx(item.bakedRect.width),
                    height: fy(item.bakedRect.height),
                    child: _RoomItemSlot(
                      item: item,
                      showImage: false,
                      onTap: () => _showBubble(item.reaction),
                    ),
                  ),
              // Món gắn tường (dưới nhân vật/pet và đồ trên sàn).
              for (final p in placeables)
                if (p.wall) placeableSlot(p),
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
/// = false (nền `room_v3.webp` đã vẽ sẵn món): chỉ là vùng chạm vô
/// hình phủ đúng món trong nền ([RoomFurniture.bakedRect]).
/// Khóa widget giữ nguyên như bản v2 (`room-furniture-<tên>`) để
/// test cũ vẫn tìm được món.
class _RoomItemSlot extends StatefulWidget {
  const _RoomItemSlot({
    required this.item,
    required this.onTap,
    required this.showImage,
    this.asset,
    this.arranging = false,
    this.dragging = false,
    this.onArrangeTap,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final RoomFurniture item;

  /// Chế độ Sắp xếp: chạm (không kéo) vào món, ví dụ mở bảng chọn biến thể.
  final VoidCallback? onArrangeTap;

  /// Ảnh biến thể chủ đề thay ảnh gốc; null = `item.asset`. Lỗi ảnh thì
  /// về `item.asset`.
  final String? asset;
  final VoidCallback onTap;
  final bool showImage;

  /// Chế độ Sắp xếp: món có viền nổi và kéo được ([onDragStart]/
  /// [onDragUpdate] theo px màn hình/[onDragEnd]); chạm không phản ứng.
  /// Ngoài chế độ này kéo không làm gì.
  final bool arranging;
  final bool dragging;
  final VoidCallback? onDragStart;
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragEnd;

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
    if (widget.arranging) {
      widget.onArrangeTap?.call();
      return;
    }
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
      onPanStart: widget.arranging ? (_) => widget.onDragStart?.call() : null,
      onPanUpdate: widget.arranging
          ? (d) => widget.onDragUpdate?.call(d.delta)
          : null,
      onPanEnd: widget.arranging ? (_) => widget.onDragEnd?.call() : null,
      onPanCancel: widget.arranging ? () => widget.onDragEnd?.call() : null,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          if (widget.showImage)
            Image.asset(
              widget.asset ?? widget.item.asset,
              fit: BoxFit.fill,
              // Ảnh biến thể chủ đề chưa về: dùng ảnh gốc của món (như nền
              // chủ đề lỗi thì về nền gốc); ảnh gốc cũng chưa về thì bỏ trống.
              errorBuilder: (_, _, _) =>
                  widget.asset == null || widget.asset == widget.item.asset
                  ? const SizedBox.shrink()
                  : Image.asset(
                      widget.item.asset,
                      fit: BoxFit.fill,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
          if (widget.arranging && widget.showImage)
            // Viền mờ quanh phần nhìn thấy của ảnh (~68% x 70% ô ảnh).
            Positioned.fill(
              child: IgnorePointer(
                child: FractionallySizedBox(
                  key: Key('${widget.item.key}-outline'),
                  widthFactor: 0.68,
                  heightFactor: 0.70,
                  alignment: const Alignment(0, 0.03),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.dragging
                          ? const Color(0x33FFE08A)
                          : const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.dragging
                            ? const Color(0xFFFFC93C)
                            : const Color(0xB3FFFFFF),
                        width: widget.dragging ? 3 : 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
    this.dragonFx,
  });

  final String species;
  final bool hatched;
  final PetStage stage;
  final int bounce;
  final bool walking;
  final bool facingLeft;
  final VoidCallback onTap;

  /// Điều khiển hiệu ứng khi pet là rồng.
  final DragonFxController? dragonFx;

  @override
  Widget build(BuildContext context) {
    final Widget shown;
    final fxCtl = dragonFx;
    if (hatched && species == dragonSpecies && fxCtl != null) {
      shown = DragonPetView(
        controller: fxCtl,
        stage: stage == PetStage.egg ? PetStage.newborn : stage,
        walking: walking,
        facingLeft: facingLeft,
        happyTick: bounce,
      );
    } else if (hatched) {
      shown = PetSprite(
        species: species,
        stage: stage == PetStage.egg ? PetStage.newborn : stage,
        walking: walking,
        facingLeft: facingLeft,
        happyTick: bounce,
      );
    } else {
      Widget egg = Image.asset(
        eggSpeciesAssets[species] ?? petEggAsset(species),
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

/// Bong bóng tâm trạng trên đầu pet: đói / buồn / vui (tim). Chưa có
/// hình Muse (`petUiArtReady` = false) thì vẽ bằng icon Material.
class _PetMoodBubble extends StatelessWidget {
  const _PetMoodBubble({required this.mood});

  final PetMood mood;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (mood) {
      PetMood.hungry => (Icons.restaurant_rounded, const Color(0xFFFF9E5E)),
      PetMood.sad => (
        Icons.sentiment_dissatisfied_rounded,
        const Color(0xFF5DB7F0),
      ),
      PetMood.happy => (Icons.favorite_rounded, const Color(0xFFFF6B8A)),
    };
    return IgnorePointer(
      child: FittedBox(
        child: Container(
          key: Key('room-pet-mood-${mood.name}'),
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
          child: petUiArtReady
              ? Image.asset(petEmoteAsset(mood.name), width: 40, height: 40)
              : Icon(icon, size: 34, color: color),
        ),
      ),
    );
  }
}

/// Món đang hiện trước pet khi cho ăn / chơi (T2-06b).
class _PetProp {
  const _PetProp({
    required this.isToy,
    required this.id,
    required this.asset,
    required this.start,
    required this.rest,
    required this.dir,
  });

  final bool isToy;
  final String id;

  /// Ảnh món; null (suất ăn khi `petUiArtReady` còn tắt) → icon vẽ code.
  final String? asset;

  /// Chỗ xuất hiện và chỗ nằm yên (chân món, khung 1600x900). Thức ăn
  /// đứng yên ở [rest] (= [start]).
  final Offset start;
  final Offset rest;

  /// Hướng đồ chơi lăn: 1 = sang phải, -1 = sang trái.
  final double dir;
}

/// Vẽ món cho ăn / chơi theo tiến độ [animation] (0..1):
/// - thức ăn: phồng lên (0–0.15), nhấp nhô chờ (–0.5), rồi co nhỏ dần
///   như bị nhai (–0.95) và biến mất;
/// - đồ chơi: nảy 2 nhịp + lăn từ [_PetProp.start] ra [_PetProp.rest]
///   (0–0.3), nằm yên rồi nảy nhẹ lúc pet tới chơi (0.6–0.88), mờ dần.
/// Khóa `room-pet-prop-food` / `room-pet-prop-toy`.
class _PetPropLayer extends StatelessWidget {
  const _PetPropLayer({
    required this.prop,
    required this.animation,
    required this.frameW,
    required this.frameH,
    required this.scale,
  });

  final _PetProp prop;
  final Animation<double> animation;
  final double frameW;
  final double frameH;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          var pos = prop.rest;
          var lift = 0.0; // px khung, dương = lên
          var size = (prop.isToy ? 84.0 : 72.0) * scale;
          var angle = 0.0;
          var opacity = 1.0;
          var squash = 1.0;
          if (prop.isToy) {
            if (t < 0.3) {
              final a = t / 0.3;
              final e = Curves.easeOut.transform(a);
              pos = Offset.lerp(prop.start, prop.rest, e)!;
              lift = 70 * (1 - a) * math.sin(a * math.pi * 2).abs();
              if (prop.id != 'pet_toy_plush') {
                angle = prop.dir * e * math.pi * 3;
              } else {
                angle = 0.4 * math.sin(a * math.pi * 4);
              }
            } else if (t >= 0.6 && t < 0.88) {
              lift = 16 * math.sin((t - 0.6) / 0.28 * math.pi * 4).abs();
              angle = 0.25 * math.sin((t - 0.6) / 0.28 * math.pi * 6);
            }
            if (t > 0.88) opacity = (1 - (t - 0.88) / 0.12).clamp(0.0, 1.0);
          } else {
            if (t < 0.15) {
              squash = Curves.easeOutBack.transform(t / 0.15);
            } else if (t < 0.5) {
              lift = 5 * math.sin((t - 0.15) / 0.35 * math.pi * 3).abs();
            } else {
              final e = ((t - 0.5) / 0.45).clamp(0.0, 1.0);
              // Nhai: co lại dần, mỗi miếng cắn rung nhẹ.
              squash =
                  (1 - Curves.easeIn.transform(e)) *
                  (1 + 0.10 * math.sin(e * math.pi * 6));
            }
          }
          size *= squash.clamp(0.0, 1.6);
          if (size < 1) return const SizedBox.shrink();
          double fx(double x) => x / roomFrameWidth * frameW;
          double fy(double y) => y / roomFrameHeight * frameH;
          final shadowW = size * 0.9;
          return Opacity(
            opacity: opacity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: fx(pos.dx - shadowW / 2),
                  top: fy(pos.dy - 4),
                  width: fx(shadowW),
                  height: fy(size * 0.14),
                  child: const _SoftShadow(),
                ),
                Positioned(
                  left: fx(pos.dx - size / 2),
                  top: fy(pos.dy - size * 0.9 - lift),
                  width: fx(size),
                  height: fy(size),
                  child: Transform.rotate(
                    key: Key(
                      prop.isToy ? 'room-pet-prop-toy' : 'room-pet-prop-food',
                    ),
                    angle: angle,
                    child: prop.asset == null
                        ? const FittedBox(
                            child: Icon(
                              Icons.rice_bowl_rounded,
                              color: Color(0xFFFF9E5E),
                            ),
                          )
                        : Image.asset(
                            prop.asset!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
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
