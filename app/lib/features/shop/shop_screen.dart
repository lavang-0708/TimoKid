/// Màn Cửa hàng (T2-06): bé tiêu xu mua quần áo và phụ kiện.
///
/// Giao diện kiểu game như Phòng/Thị trấn: nút Trở về tròn + thanh
/// chỉ số (xu, kim cương) ở hàng đầu, bốn nút nhóm hàng (Quần áo,
/// Phụ kiện, Đồ cho pet, Nội thất) dạng viên thuốc to, lưới thẻ món
/// (cuộn dọc khi màn thấp).
/// Mỗi thẻ: hình nhân vật cắt theo món (đồ pet/nội thất: ảnh món), tên,
/// giá kèm xu (hoặc kim cương với bộ đồ cao cấp), nút "Mua" (đủ tiền),
/// "Còn thiếu N xu" (mờ, không bấm được) hoặc "Đã có ✓". Thức ăn pet
/// mua nhiều lần nên không có "Đã có" mà hiện nhãn "Có N".
/// Nội thất còn ẩn ([furnitureShopArtReady] = false) thì tab hiện thẻ
/// "Sắp có hàng mới!". Mở bằng `/shop?tab=pet` (từ nút Cho ăn/Chơi
/// của Phòng khi chưa có đồ) thì vào thẳng tab đó.
/// Bấm Mua → hộp xác nhận to ("Mua"/"Thôi") → mua xong có băng
/// "Mua xong!" nảy lên rồi tự tắt.
///
/// Việc mua và kho đồ nằm ở [ShopService]; màn này chỉ hiển thị.
/// Hiệu ứng nảy chạy một lần, tắt hẳn khi [AnimationGate.enabled]
/// là false để `pumpAndSettle` trong test dừng được.
library;

import 'dart:async';

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
import '../character/kid_assets.dart';
import '../onboarding/onboarding_service.dart';
import '../pet/pet_config.dart';
import '../pet/pet_service.dart';
import '../room/room_screen.dart';
import 'shop_catalog.dart';
import 'shop_service.dart';

class ShopScreen extends ConsumerStatefulWidget {
  /// [furnitureReady] / [premiumOutfitsReady] mặc định theo cờ const;
  /// chỉ đặt khác để test nhánh bật cờ.
  const ShopScreen({
    super.key,
    this.furnitureReady = furnitureShopArtReady,
    this.premiumOutfitsReady = premiumOutfitsArtReady,
    this.petArtReady = newPetArtReady,
  });

  final bool furnitureReady;
  final bool premiumOutfitsReady;

  /// Cờ hình từng loài pet mới (tab Pet); mặc định theo
  /// [newPetArtReady], chỉ test đổi.
  final Map<String, bool> petArtReady;

  static const String route = '/shop';

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  bool _loading = true;
  String? _error;
  String? _childId;
  String _gender = 'girl';
  int _outfit = 1;
  int _xu = 0;
  int _gems = 0;
  Set<String> _owned = const {};
  Set<String> _ownedSpecies = const {};
  Map<String, int> _foodCounts = const {};
  ShopCategory _category = ShopCategory.outfits;
  bool _tabFromRoute = false;
  bool _buying = false;
  String? _boughtName;
  int _boughtCount = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabFromRoute) return;
    _tabFromRoute = true;
    // `/shop?tab=pet`: vào thẳng nhóm hàng đó (không có router thì bỏ qua).
    String? tab;
    try {
      tab = GoRouterState.of(context).uri.queryParameters['tab'];
    } catch (_) {}
    for (final c in ShopCategory.values) {
      if (c.key == tab) _category = c;
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  ShopService get _service => ShopService(
    db: ref.read(databaseProvider),
    furnitureReady: widget.furnitureReady,
    premiumOutfitsReady: widget.premiumOutfitsReady,
    petArtReady: widget.petArtReady,
  );

  Future<void> _refresh() async {
    try {
      final db = ref.read(databaseProvider);
      final childId = await db.ensureSeeded();
      final profile = await OnboardingService(db: db).loadProfile(childId);
      final service = _service;
      // Máy cài trước bản có cửa hàng: giữ đồ đang mặc (idempotent).
      await service.grandfather(childId);
      final owned = await service.owned(childId);
      final foodCounts = await service.foodCounts(childId);
      final petsOwned = await PetService(db: db).pets(childId);
      final balances = await service.balances(childId);
      if (!mounted) return;
      setState(() {
        _childId = childId;
        _gender = kidGender(profile?.gender ?? 'girl');
        _outfit = kidOutfitNumber(
          profile?.dress,
          premiumReady: widget.premiumOutfitsReady,
        );
        _owned = owned;
        _ownedSpecies = {for (final p in petsOwned) p.species};
        _foodCounts = foodCounts;
        _xu = balances[Currency.xu] ?? 0;
        _gems = balances[Currency.gem] ?? 0;
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

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoomScreen.route);
    }
  }

  Future<void> _onBuyTap(ShopItem item) async {
    final childId = _childId;
    if (childId == null || _buying) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _ConfirmDialog(item: item, gender: _gender, outfit: _outfit),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _buying = true);
    try {
      final result = item.kind == ShopItemKind.petEgg
          ? await _service.buyPetEgg(childId: childId, species: item.species!)
          : await _service.buy(
              childId: childId,
              gender: _gender,
              itemId: item.id,
            );
      await _refresh();
      if (!mounted) return;
      if (result == BuyResult.bought) {
        _showBought(item.name);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(switch (result) {
              BuyResult.insufficient =>
                item.usesGems
                    ? 'Chưa đủ kim cương rồi, cố gắng thêm nhé!'
                    : 'Chưa đủ xu rồi, làm thêm bài nhé!',
              BuyResult.comingSoon => 'Pet này sắp có, bé đợi nhé!',
              _ => 'Bé đã có món này rồi!',
            }),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa mua được, bé thử lại nhé')),
      );
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  void _showBought(String name) {
    _bannerTimer?.cancel();
    setState(() {
      _boughtName = name;
      _boughtCount++;
    });
    _bannerTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _boughtName = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        key: Key('shop-screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        key: const Key('shop-screen'),
        body: Center(child: Text('Không tải được Cửa hàng: $_error')),
      );
    }
    final items = _category == ShopCategory.pets
        ? shopPetEggItems()
        : [
            for (final i in shopItemsFor(
              _gender,
              furnitureReady: widget.furnitureReady,
              premiumOutfitsReady: widget.premiumOutfitsReady,
            ))
              if (i.category == _category) i,
          ];
    return Scaffold(
      key: const Key('shop-screen'),
      backgroundColor: const Color(0xFFE9DDF7),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/backgrounds/shop_bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                children: [
                  _header(),
                  const SizedBox(height: 6),
                  Expanded(child: _grid(items)),
                ],
              ),
            ),
          ),
          if (_boughtName != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: _BoughtBanner(
                    key: ValueKey('bought-$_boughtCount'),
                    name: _boughtName!,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        RoundBackButton(
          key: const Key('shop-back-button'),
          tooltip: 'Về Phòng',
          onPressed: _back,
        ),
        const SizedBox(width: 8),
        GameHudBar(
          children: [
            GameStat(
              icon: Icons.monetization_on_rounded,
              image: '$uiArt/ui_coin.png',
              color: const Color(0xFFF5B83D),
              text: '$_xu',
              textKey: const Key('shop-xu-balance'),
            ),
            GameStat(
              icon: Icons.diamond_rounded,
              image: '$uiArt/ui_gem.png',
              color: const Color(0xFFA07BE0),
              text: '$_gems',
              textKey: const Key('shop-gem-balance'),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in ShopCategory.values) ...[
                  _TabPill(
                    key: Key('shop-tab-${c.key}'),
                    category: c,
                    selected: c == _category,
                    onTap: () => setState(() => _category = c),
                  ),
                  if (c != ShopCategory.values.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _comingSoon() {
    return Center(
      child: Container(
        key: const Key('shop-furniture-coming-soon'),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD0BFF0), width: 3),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.weekend_rounded, size: 44, color: Color(0xFF8E6FD8)),
            SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sắp có hàng mới!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: gameInk,
                    ),
                  ),
                  Text(
                    'Đồ trang trí cho Phòng đang được vẽ, bé đợi nhé.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: gameInk,
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

  Widget _grid(List<ShopItem> items) {
    final soon = _category == ShopCategory.furniture && !widget.furnitureReady;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x99FFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: soon
            ? _comingSoon()
            : SingleChildScrollView(
                key: const Key('shop-grid'),
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final item in items)
                        _ItemCard(
                          key: Key('shop-item-${item.id}'),
                          item: item,
                          gender: _gender,
                          outfit: _outfit,
                          owned: item.kind == ShopItemKind.petEgg
                              ? _ownedSpecies.contains(item.species)
                              : !item.consumable && _owned.contains(item.id),
                          comingSoon:
                              item.kind == ShopItemKind.petEgg &&
                              !(widget.petArtReady[item.species] ?? false),
                          count: item.consumable
                              ? (_foodCounts[item.id] ?? 0)
                              : null,
                          balance: item.usesGems ? _gems : _xu,
                          onBuy: () => _onBuyTap(item),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Nút nhóm hàng dạng viên thuốc to, có icon.
class _TabPill extends StatelessWidget {
  const _TabPill({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ShopCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? gameInk : const Color(0xFF8E6FD8);
    final icon = switch (category) {
      ShopCategory.outfits => Image.asset(
        '$uiArt/ui_icon_clothes.png',
        width: 30,
        height: 30,
      ),
      ShopCategory.pet => Image.asset(
        '$uiArt/ui_icon_pet_items.png',
        width: 30,
        height: 30,
      ),
      ShopCategory.pets => Icon(Icons.pets_rounded, size: 26, color: iconColor),
      ShopCategory.accessories => Icon(
        Icons.auto_awesome_rounded,
        size: 24,
        color: iconColor,
      ),
      ShopCategory.furniture => Icon(
        Icons.weekend_rounded,
        size: 26,
        color: iconColor,
      ),
    };
    return PressBounce(
      child: GestureDetector(
        onTap: onTap,
        child: Semantics(
          button: true,
          selected: selected,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: selected
                    ? const [Color(0xFFFFE08A), Color(0xFFFFB84D)]
                    : const [Colors.white, Color(0xFFEDE4FB)],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: selected ? Colors.white : const Color(0xFFD0BFF0),
                width: selected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? const Color(0x66FFA726)
                      : const Color(0x22000000),
                  offset: const Offset(0, 3),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: 6),
                Text(
                  category.label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: gameInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hình món: nhân vật (bộ đồ hiện tại của bé) cắt theo món, như thẻ
/// chọn bộ đồ ở mở đầu. Bộ đồ: cả bộ; phụ kiện: ảnh nhân vật + lớp phủ.
class ShopItemArt extends StatelessWidget {
  const ShopItemArt({
    super.key,
    required this.item,
    required this.gender,
    required this.outfit,
  });

  final ShopItem item;
  final String gender;

  /// Bộ đồ 1–3 làm nền cho phụ kiện.
  final int outfit;

  /// Cắt phần nào của ảnh toàn thân: đầu, thân trên hay chân.
  Alignment get _crop => switch (item.kind) {
    ShopItemKind.outfit => Alignment.center,
    ShopItemKind.headAccessory ||
    ShopItemKind.glasses => const Alignment(0, -0.85),
    ShopItemKind.backpack => const Alignment(0, -0.35),
    ShopItemKind.whiteShoes => const Alignment(0, 1),
    _ => Alignment.center,
  };

  @override
  Widget build(BuildContext context) {
    if (item.kind == ShopItemKind.petEgg) {
      // Trứng pet mới: có hình thì hiện ảnh trứng, chưa có thì icon trứng
      // vẽ bằng code.
      final ready = newPetArtReady[item.species] ?? false;
      return Padding(
        padding: const EdgeInsets.all(6),
        child: ready
            ? Image.asset(
                'assets/images/pets/${item.species}_egg.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const _EggIcon(),
              )
            : const _EggIcon(),
      );
    }
    final itemAsset = item.asset;
    if (itemAsset != null) {
      // Đồ pet / nội thất: ảnh món 512x512 trong suốt, không cắt.
      return Padding(
        padding: const EdgeInsets.all(2),
        child: Image.asset(
          itemAsset,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
    }
    final n = item.outfit ?? outfit;
    final base = kidFullAsset(
      gender,
      n,
      backpack: item.kind == ShopItemKind.backpack,
    );
    final overlay = switch (item.kind) {
      ShopItemKind.headAccessory => kidHeadAccessoryAsset(
        gender,
        item.accessory,
      ),
      ShopItemKind.glasses => kidGlassesAsset(gender),
      ShopItemKind.whiteShoes => kidWhiteShoesAsset(gender),
      _ => null,
    };
    Widget layer(String path) => Image(
      image: kidImage(path),
      width: kidFrameWidth,
      height: kidFrameHeight,
      fit: BoxFit.fill,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: FittedBox(
        // Bộ đồ: hiện cả người để thấy rõ váy/áo (bộ càng đắt càng lộng
        // lẫy); phụ kiện: cắt vùng có món đồ.
        fit: item.kind == ShopItemKind.outfit ? BoxFit.contain : BoxFit.cover,
        alignment: _crop,
        child: SizedBox(
          width: kidFrameWidth,
          height: kidFrameHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [layer(base), if (overlay != null) layer(overlay)],
          ),
        ),
      ),
    );
  }
}

/// Trứng vẽ bằng code (khi chưa có hình Muse).
class _EggIcon extends StatelessWidget {
  const _EggIcon();

  @override
  Widget build(BuildContext context) =>
      const FittedBox(child: Icon(Icons.egg_rounded, color: Color(0xFFB9A3E3)));
}

/// Giá kèm biểu tượng xu (hoặc kim cương với bộ đồ cao cấp).
class _Price extends StatelessWidget {
  const _Price(this.item, {this.size = 16});

  final ShopItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          item.usesGems ? '$uiArt/ui_gem.png' : '$uiArt/ui_coin.png',
          width: size + 6,
          height: size + 6,
        ),
        const SizedBox(width: 3),
        Text(
          '${item.price}',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            color: gameInk,
          ),
        ),
      ],
    );
  }
}

/// Nút kẹo to: xanh (Mua), xám (không đủ xu), vàng (Thôi) ...
class _CandyButton extends StatelessWidget {
  const _CandyButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = const Color(0xFF4CC38A),
    this.height = 44,
    this.fontSize = 18,
  });

  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final base = enabled ? color : const Color(0xFFC9C3D6);
    final top = Color.lerp(base, Colors.white, 0.3)!;
    final edge = Color.lerp(base, Colors.black, 0.28)!;
    return PressBounce(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: text,
          child: Container(
            height: height + 4,
            padding: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: edge,
              borderRadius: BorderRadius.circular(height / 2 + 2),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [top, base],
                ),
                borderRadius: BorderRadius.circular(height / 2),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  maxLines: 1,
                  style: gameOutlinedText(fontSize),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ một món.
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.item,
    required this.gender,
    required this.outfit,
    required this.owned,
    required this.balance,
    required this.onBuy,
    this.count,
    this.comingSoon = false,
  });

  /// Trứng pet chưa có hình: thẻ ghi "Sắp có", không mua được.
  final bool comingSoon;

  final ShopItem item;
  final String gender;
  final int outfit;
  final bool owned;

  /// Số đang có của món dùng-một-lần (thức ăn); null với món một-lần.
  final int? count;

  /// Số dư đúng loại tiền của món (xu hoặc kim cương).
  final int balance;
  final VoidCallback onBuy;

  static const double width = 136;
  static const double height = 196;

  @override
  Widget build(BuildContext context) {
    final missing = item.price - balance;
    final Widget action;
    if (comingSoon && !owned) {
      action = Container(
        key: Key('shop-soon-${item.id}'),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFEDE4FB),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFB9A3E3), width: 2),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Sắp có',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF6D4FB8),
            ),
          ),
        ),
      );
    } else if (owned) {
      action = Container(
        key: Key('shop-owned-${item.id}'),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFE3F7E6),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF43A047), width: 2),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Đã có ✓',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
      );
    } else if (missing > 0) {
      action = _CandyButton(
        key: Key('shop-buy-${item.id}'),
        text: item.usesGems
            ? 'Còn thiếu $missing kim cương'
            : 'Còn thiếu $missing xu',
        fontSize: 14,
        onPressed: null,
      );
    } else {
      action = _CandyButton(
        key: Key('shop-buy-${item.id}'),
        text: 'Mua',
        onPressed: onBuy,
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              owned ? '$uiArt/ui_card_selected.png' : '$uiArt/ui_card.png',
              fit: BoxFit.fill,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              children: [
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ShopItemArt(
                            item: item,
                            gender: gender,
                            outfit: outfit,
                          ),
                        ),
                        if (item.rarity != null &&
                            item.rarity != PetRarity.common)
                          Positioned(
                            left: 0,
                            top: 0,
                            child: RarityBadge(
                              key: Key('shop-rarity-${item.id}'),
                              rarity: item.rarity!,
                            ),
                          ),
                        if (count != null)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              key: Key('shop-count-${item.id}'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE08A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                'Có $count',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: gameInk,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 18,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.name,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: gameInk,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 22, child: _Price(item)),
                const SizedBox(height: 2),
                action,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hộp xác nhận mua: to, thân thiện, hai nút "Mua" / "Thôi".
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.item,
    required this.gender,
    required this.outfit,
  });

  final ShopItem item;
  final String gender;
  final int outfit;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('shop-confirm-dialog'),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFD0BFF0), width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 92,
                height: 110,
                child: ShopItemArt(item: item, gender: gender, outfit: outfit),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Mua ${item.name} nhé?',
                        key: const Key('shop-confirm-title'),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: gameInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(child: _Price(item, size: 20)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _CandyButton(
                              key: const Key('shop-confirm-cancel'),
                              text: 'Thôi',
                              color: const Color(0xFFFFA64D),
                              height: 48,
                              onPressed: () => Navigator.of(context).pop(false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CandyButton(
                              key: const Key('shop-confirm-buy'),
                              text: 'Mua',
                              height: 48,
                              onPressed: () => Navigator.of(context).pop(true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Băng "Mua xong!": nảy to rồi lắng (một lần), cổng tắt thì hiện tĩnh.
class _BoughtBanner extends StatelessWidget {
  const _BoughtBanner({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final banner = Container(
      key: const Key('shop-bought-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7BDC9F), Color(0xFF3FB27A)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('$uiArt/ui_star.png', width: 36, height: 36),
          const SizedBox(width: 8),
          Flexible(
            child: Text('Mua xong!', maxLines: 1, style: gameOutlinedText(30)),
          ),
        ],
      ),
    );
    if (!AnimationGate.enabled) return banner;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: banner,
    );
  }
}
