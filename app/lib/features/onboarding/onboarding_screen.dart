/// Màn mở đầu (T2-03, PLAN + DESIGN "Lần đầu mở app").
///
/// Dáng nữ (bộ nhân vật nữ 1, PR #18 đã merge) chỉ có 5 bước: giới tính, màu tóc, váy, đặt tên, chọn
/// trứng. Thân đã có sẵn mắt/miệng/tất/giày/bộ đồ gốc nên KHÔNG có
/// bước màu da/kiểu mắt/kiểu miệng; kiểu tóc cố định `girl_hair_01`.
/// Dáng nam chưa có hình thật nên giữ 7 bước cũ với xem trước tạm.
/// Đổi ý ở bước nào cũng quay lại được (nút "Quay lại" ở mọi bước
/// trừ bước đầu). Lưu một lần ở cuối (xem [OnboardingService]) rồi
/// vào Thị trấn; tắt app giữa chừng thì lần sau mở lại từ đầu.
///
/// Xem trước nhân vật bằng [CharacterView]: dáng nữ dùng hình thật
/// bộ girlSet1 ([CharacterOutfit.girlSet1]: thân + tóc + váy, không
/// mắt/miệng/giày) qua `AssetImage` mặc định — PR #18 đã merge nên
/// không còn lớp tạm ở đây; dáng nam chưa có hình thật nên vẫn dùng
/// lớp tạm xám ([placeholderLayerLoader]) và có nhãn "Hình tạm".
/// Test bơm loader tạm qua [OnboardingScreen.previewLoader] để
/// golden cũ vẫn dùng lớp tạm xám (không cần file hình thật ở local).
/// Nhân vật xem trước thở/chớp mắt + bấm vào nhảy lên lấp lánh, đổi
/// màu tóc/váy thì nảy 'pop' (xem [CharacterBounce]); trứng là PNG
/// thật (PR #21) lắc lư nhẹ chờ nở. Cổng [AnimationGate] tắt mọi
/// hiệu ứng lặp khi chạy test để `pumpAndSettle` dừng được.
///
/// Bố cục ngang: cột trái là xem trước, cột phải là lựa chọn của
/// bước (cuộn được để vừa màn 640x320); bước chọn trứng ẩn cột xem
/// trước để đủ chỗ cho 3 thẻ trứng.
///
/// Bố cục ngang: cột trái là xem trước, cột phải là lựa chọn của
/// bước (cuộn được để vừa màn 640x320); bước chọn trứng ẩn cột xem
/// trước để đủ chỗ cho 3 thẻ trứng.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/animation/animation_gate.dart';
import '../../core/database/database_provider.dart';
import '../../core/widgets/press_bounce.dart';
import '../character/character_bounce.dart';
import '../character/character_view.dart' show CharacterLayerLoader;
import '../character/kid_assets.dart';
import '../character/kid_sprite.dart';
import '../room/room_screen.dart';
import 'onboarding_config.dart';
import 'onboarding_model.dart';
import 'onboarding_service.dart';

/// Các bước của màn mở đầu, theo đúng thứ tự PLAN T2-03 (nữ 5 bước
/// theo bộ nhân vật nữ 1, nam 7 bước theo manifest v1). Bước đầu
/// (giới tính) chung cho cả hai; bước tên và bước trứng luôn là hai
/// bước cuối.
const List<String> _girlStepTitles = <String>[
  'Bé là bé gái hay bé trai?',
  'Chọn bộ đồ',
  'Đặt tên cho nhân vật',
  'Chọn một quả trứng',
];

/// Mã bước dáng nữ, cùng thứ tự với [_girlStepTitles].
const List<String> _girlStepKeys = <String>['gender', 'dress', 'name', 'egg'];

/// Dáng nam: cùng 4 bước như dáng nữ (E: ảnh toàn thân, bé chỉ chọn
/// bộ đồ; màu da/tóc/mắt cố định theo hình đã duyệt).
const List<String> _boyStepTitles = _girlStepTitles;

/// Mã bước dáng nam, cùng thứ tự với [_boyStepTitles].
const List<String> _boyStepKeys = _girlStepKeys;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.previewLoader});

  static const String route = '/onboarding';

  /// Không còn dùng từ (E): xem trước là ảnh toàn thân [KidSprite].
  /// Giữ tham số để router/test cũ không phải đổi chữ ký.
  final CharacterLayerLoader? previewLoader;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  var _step = 0;
  var _draft = CharacterProfile.defaults();
  String? _selectedEgg;
  String? _nameError;
  bool _saving = false;
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Tiêu đề các bước theo giới tính đã chọn ở bước đầu (mặc định
  /// nữ, 5 bước; chọn nam thì 7 bước).
  List<String> get _stepTitles =>
      _draft.gender == 'girl' ? _girlStepTitles : _boyStepTitles;

  /// Mã bước hiện tại (xem [_girlStepKeys]/[_boyStepKeys]).
  String get _stepKey =>
      (_draft.gender == 'girl' ? _girlStepKeys : _boyStepKeys)[_step];

  bool get _isEggStep => _stepKey == 'egg';

  /// Bước hiện tại đã chọn đủ để sang bước sau chưa. Các bước chọn
  /// đều có sẵn lựa chọn mặc định; bước tên cần tên hợp lệ, bước
  /// trứng cần đã chọn một quả.
  bool get _canContinue {
    if (_stepKey == 'name') return isValidCharacterName(_draft.name);
    if (_isEggStep) return _selectedEgg != null;
    return true;
  }

  void _next() {
    // Bỏ focus TRƯỚC khi đổi bước: bàn phím ảo mở ở bước đặt tên
    // mà không đóng thì bóp cả Thị trấn/màn toán sau đó — review
    // PR #19 vòng 2: tapCorrect(1) chạm hụt vì cột bị bóp, Column
    // mở đầu báo RenderFlex DISPOSED sau khi rời màn.
    FocusScope.of(context).unfocus();
    if (!_canContinue) {
      if (_stepKey == 'name') {
        setState(() {
          _nameError = 'Tên dài 1–12 ký tự nhé';
        });
      }
      return;
    }
    if (_isEggStep) {
      _finish();
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    // Như _next: bỏ focus để bàn phím đóng khi quay lại bước trước.
    FocusScope.of(context).unfocus();
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _finish() async {
    if (_saving || _selectedEgg == null) return;
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      final childId = await db.ensureSeeded();
      await OnboardingService(db: db).completeOnboarding(
        childId: childId,
        profile: _draft,
        eggSpecies: _selectedEgg!,
      );
      if (!mounted) return;
      // Bỏ focus ở gốc trước khi sang Phòng (vòng 3 review
      // PR #19): bàn phím ảo mở ở bước tên có thể còn mở trên máy
      // ảo CI dù `_next()` đã unfocus — yêu cầu đóng bàn phím lần
      // nữa ở điểm rời mở đầu duy nhất, để Phòng/Thị trấn/màn toán
      // không bị bóp viewport. Không có gì focus thì đây là no-op.
      FocusManager.instance.primaryFocus?.unfocus();
      context.go(RoomScreen.route);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa lưu được, bé thử lại nhé')),
      );
    }
  }

  /// Khóa pop cho xem trước: đổi lựa chọn nào của nhân vật thì
  /// nhân vật nảy 'pop' một cái (xem [CharacterBounce.popKey]).
  String get _previewPopKey =>
      '${_draft.gender}|${_draft.skinColor}|${_draft.hairStyle}|'
      '${_draft.hairColor}|${_draft.eyeStyle}|${_draft.eyeColor}|'
      '${_draft.mouthStyle}|${_draft.dress}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('onboarding-screen'),
      // Không co thân khi bàn phím ảo mở (xem [_body]).
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Tạo nhân vật'),
        // Mở đầu là bắt buộc ở lần đầu mở app nên không có nút về
        // của hệ thống; nút "Quay lại" trong thân lo việc đổi ý.
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: _body(),
      ),
    );
  }

  /// Thân mở đầu: một bố cục cố định duy nhất (xem trước + lựa
  /// chọn cạnh nhau, nút điều hướng luôn thấy).
  ///
  /// Không đổi bố cục theo bàn phím ảo (sửa lỗi bản v0.0.2): bản
  /// trước chuyển sang bố cục cuộn khi `viewInsets.bottom > 0`, cây
  /// widget đổi nên ô tên bị dựng lại, mất focus, bàn phím đóng ngay
  /// khi bé vừa bấm vào ô tên — không gõ được. Giờ Scaffold không co
  /// thân theo bàn phím (`resizeToAvoidBottomInset: false`): bàn phím
  /// che phần dưới, ô tên ở trên vẫn thấy; bấm Xong/Tiếp thì bàn phím
  /// đóng (unfocus trong `_next`/`onSubmitted`).
  Widget _body() {
    return Column(
      children: [
        _headerRow(),
        const SizedBox(height: 8),
        Expanded(child: _middleRow()),
        const SizedBox(height: 8),
        _navRow(),
      ],
    );
  }

  /// Hàng đếm bước + tiêu đề bước.
  Widget _headerRow() {
    return Row(
      children: [
        Text(
          'Bước ${_step + 1}/${_stepTitles.length}',
          key: const Key('onboarding-step-counter'),
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _stepTitles[_step],
            key: const Key('onboarding-step-title'),
            style: const TextStyle(fontSize: 22),
          ),
        ),
      ],
    );
  }

  /// Hàng giữa: xem trước nhân vật + lựa chọn của bước (cuộn được
  /// để vừa màn 640x320).
  Widget _middleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Xem trước nhân vật (ẩn ở bước chọn trứng để đủ
        // chỗ cho 3 thẻ trứng).
        if (!_isEggStep) ...[
          SizedBox(
            width: 170,
            child: Column(
              children: [
                Expanded(
                  child: CharacterBounce(
                    popKey: _previewPopKey,
                    // Thở/chớp mắt bật (kiểu game); cổng AnimationGate
                    // tắt khi chạy test để pumpAndSettle dừng được.
                    child: KidSprite(
                      key: const Key('onboarding-preview'),
                      gender: _draft.gender,
                      outfit: kidOutfitNumber(_draft.dress),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(child: SingleChildScrollView(child: _stepBody())),
      ],
    );
  }

  /// Hai nút điều hướng co lại khi màn hẹp (chữ trong nút
  /// thu nhỏ theo, không tràn): nút "Xong — vào Phòng" ở
  /// bước trứng dài nên ở màn 608 dp (font DejaVu trong
  /// test) hai nút cộng lại vượt chiều rộng; khi chạy app
  /// (font Nunito) vẫn vừa như trước, không đổi gì.
  Widget _navRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_step > 0)
          Flexible(
            child: PressBounce(
              child: ElevatedButton.icon(
                key: const Key('onboarding-back-button'),
                icon: const Text('←', style: TextStyle(fontSize: 24)),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Quay lại', style: TextStyle(fontSize: 20)),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(56, 56),
                ),
                onPressed: _saving ? null : _back,
              ),
            ),
          )
        else
          const SizedBox.shrink(),
        Flexible(
          child: PressBounce(
            child: ElevatedButton.icon(
              key: Key(
                _isEggStep
                    ? 'onboarding-finish-button'
                    : 'onboarding-next-button',
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _isEggStep ? 'Xong — vào Phòng' : 'Tiếp theo',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const Text('→', style: TextStyle(fontSize: 24)),
              style: ElevatedButton.styleFrom(minimumSize: const Size(56, 56)),
              onPressed: (_canContinue && !_saving) ? _next : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepBody() {
    switch (_stepKey) {
      case 'gender':
        return _optionList<String>(
          options: onboardingGenders,
          labels: onboardingGenderNames,
          selected: _draft.gender,
          keyPrefix: 'onboarding-gender',
          // Đổi dáng thì về bộ 1 của dáng đó (mã bộ đồ theo dáng).
          onSelected: (value) => setState(
            () => _draft = value == _draft.gender
                ? _draft
                : _draft.copyWith(gender: value, dressToNull: true),
          ),
        );
      case 'skin':
        return _colorRow(
          colors: onboardingSkinColors,
          selected: _draft.skinColor,
          keyPrefix: 'onboarding-skin',
          onSelected: (value) =>
              setState(() => _draft = _draft.copyWith(skinColor: value)),
        );
      case 'hair':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _optionList<String>(
              options: onboardingHairStyles,
              labels: onboardingHairStyleNames,
              selected: _draft.hairStyle,
              keyPrefix: 'onboarding-hair-style',
              onSelected: (value) =>
                  setState(() => _draft = _draft.copyWith(hairStyle: value)),
            ),
            const SizedBox(height: 12),
            const Text('Màu tóc', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            _colorRow(
              colors: onboardingHairColors,
              selected: _draft.hairColor,
              keyPrefix: 'onboarding-hair-color',
              onSelected: (value) =>
                  setState(() => _draft = _draft.copyWith(hairColor: value)),
            ),
          ],
        );
      case 'hairColor':
        // Nữ bộ 1: kiểu tóc cố định `girl_hair_01`, chỉ chọn màu.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _colorRow(
              colors: onboardingHairColors,
              selected: _draft.hairColor,
              keyPrefix: 'onboarding-hair-color',
              onSelected: (value) =>
                  setState(() => _draft = _draft.copyWith(hairColor: value)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tóc dài xoăn buộc hai bên, đổi màu theo ý bé.',
              style: TextStyle(fontSize: 18),
            ),
          ],
        );
      case 'dress':
        // E: 3 bộ đồ toàn thân của dáng đã chọn; chưa chọn (null) =
        // bộ 1.
        final ids = kidOutfitIds[kidGender(_draft.gender)]!;
        return _optionList<String>(
          options: ids,
          labels: kidOutfitNames,
          selected: _draft.dress ?? ids.first,
          keyPrefix: 'onboarding-dress',
          onSelected: (value) =>
              setState(() => _draft = _draft.copyWith(dress: value)),
        );
      case 'eyes':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _optionList<String>(
              options: onboardingEyeStyles,
              labels: onboardingEyeStyleNames,
              selected: _draft.eyeStyle,
              keyPrefix: 'onboarding-eye-style',
              onSelected: (value) =>
                  setState(() => _draft = _draft.copyWith(eyeStyle: value)),
            ),
            const SizedBox(height: 12),
            const Text('Màu mắt', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            _colorRow(
              colors: onboardingEyeColors,
              selected: _draft.eyeColor,
              keyPrefix: 'onboarding-eye-color',
              onSelected: (value) =>
                  setState(() => _draft = _draft.copyWith(eyeColor: value)),
            ),
          ],
        );
      case 'mouth':
        return _optionList<String>(
          options: onboardingMouthStyles,
          labels: onboardingMouthStyleNames,
          selected: _draft.mouthStyle,
          keyPrefix: 'onboarding-mouth',
          onSelected: (value) =>
              setState(() => _draft = _draft.copyWith(mouthStyle: value)),
        );
      case 'name':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('onboarding-name-field'),
              controller: _nameController,
              maxLength: onboardingMaxNameLength,
              // Bấm Done trên bàn phím ảo thì đóng bàn phím ngay
              // (cùng hiệu ứng với unfocus trong _next/_back).
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              style: const TextStyle(fontSize: 24),
              decoration: InputDecoration(
                hintText: 'Tên nhân vật',
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _draft = _draft.copyWith(name: value);
                  _nameError = null;
                });
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Tên dài tối đa 12 ký tự, có dấu hay không đều được.',
              style: TextStyle(fontSize: 18),
            ),
          ],
        );
      default: // 'egg'
        return Row(
          children: [
            for (final entry in eggSpeciesNames.entries) ...[
              Expanded(
                child: _EggCard(
                  species: entry.key,
                  name: entry.value,
                  selected: _selectedEgg == entry.key,
                  onTap: () => setState(() => _selectedEgg = entry.key),
                ),
              ),
              if (entry.key != eggSpeciesNames.keys.last)
                const SizedBox(width: 12),
            ],
          ],
        );
    }
  }

  /// Danh sách lựa chọn dạng nút lớn (giới tính, kiểu tóc/mắt/miệng).
  Widget _optionList<T>({
    required List<T> options,
    required Map<T, String> labels,
    required T selected,
    required String keyPrefix,
    required ValueChanged<T> onSelected,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var i = 0; i < options.length; i++)
          _OptionButton(
            key: Key('$keyPrefix-${options[i]}'),
            label: labels[options[i]] ?? '${options[i]}',
            selected: options[i] == selected,
            onPressed: () => onSelected(options[i]),
          ),
      ],
    );
  }

  /// Hàng ô màu tròn để chọn màu (da/tóc/mắt).
  Widget _colorRow({
    required List<int> colors,
    required int selected,
    required String keyPrefix,
    required ValueChanged<int> onSelected,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var i = 0; i < colors.length; i++)
          InkWell(
            key: Key('$keyPrefix-$i'),
            onTap: () => onSelected(colors[i]),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Color(colors[i]),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors[i] == selected ? Colors.black : Colors.black26,
                  width: colors[i] == selected ? 4 : 2,
                ),
              ),
              child: colors[i] == selected
                  ? const Icon(Icons.check, size: 28, color: Colors.black)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Nút lựa chọn lớn (tối thiểu 56x56 dp như các nút khác của app).
class _OptionButton extends StatelessWidget {
  const _OptionButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PressBounce(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(56, 56),
          backgroundColor: selected ? const Color(0xFFBFE8CF) : null,
        ),
        child: Text(label, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

/// Thẻ trứng ở bước cuối: hình trứng PNG thật (PR #21) + tên loài.
/// Trứng lắc lư nhẹ chờ nở ([_EggWiggle]).
class _EggCard extends StatelessWidget {
  const _EggCard({
    required this.species,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String species;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('onboarding-egg-$species'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFBFE8CF) : Colors.white,
          border: Border.all(
            color: selected ? Colors.green.shade700 : Colors.black26,
            width: selected ? 4 : 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 120,
              child: _EggWiggle(
                child: Image.asset(
                  eggSpeciesAssets[species]!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trứng lắc lư nhẹ chờ nở: xoay qua lại ±0.05 rad, chu kỳ 1,6 giây.
///
/// Hiệu ứng lặp nên chỉ chạy khi cổng [AnimationGate] bật (máy thật);
/// khi chạy test thì trả trứng nguyên vẹn để `pumpAndSettle` dừng
/// được (cùng mẫu `CharacterView`).
class _EggWiggle extends StatefulWidget {
  const _EggWiggle({required this.child});

  final Widget child;

  @override
  State<_EggWiggle> createState() => _EggWiggleState();
}

class _EggWiggleState extends State<_EggWiggle>
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
        key: const Key('egg-wiggle'),
        angle: _angle.value,
        child: child,
      ),
      child: widget.child,
    );
  }
}
