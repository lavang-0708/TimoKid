/// Màn mở đầu (T2-03, PLAN + DESIGN "Lần đầu mở app").
///
/// Từ (E) cả hai dáng có cùng 4 bước: giới tính, bộ đồ (3 bộ ảnh toàn
/// thân của dáng đã chọn, xem `kid_assets.dart`), đặt tên, chọn trứng.
/// Màu da/tóc/mắt cố định theo hình đã duyệt nên không còn bước chọn
/// màu. Đổi ý ở bước nào cũng quay lại được (nút "Quay lại" ở mọi bước
/// trừ bước đầu); đổi dáng thì về bộ 1 của dáng đó. Lưu một lần ở cuối
/// (xem [OnboardingService]) rồi vào Phòng; tắt app giữa chừng thì lần
/// sau mở lại từ đầu.
///
/// Xem trước nhân vật bằng [KidSprite] (ảnh toàn thân thật, thở/chớp
/// mắt), bọc [CharacterBounce] để bấm vào nhảy lên và đổi lựa chọn thì
/// nảy 'pop'; trứng là PNG thật (PR #21) lắc lư nhẹ chờ nở. Cổng
/// [AnimationGate] tắt mọi hiệu ứng lặp khi chạy test để
/// `pumpAndSettle` dừng được.
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
import '../../core/widgets/game_ui.dart';
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Nền phòng thay đồ pastel (ảnh lô 6).
          const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFE4D7FF),
              image: DecorationImage(
                image: AssetImage('$uiArt/ui_onboarding_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _body(),
            ),
          ),
        ],
      ),
    );
  }

  /// Thân mở đầu: một bố cục cố định duy nhất (xem trước + lựa
  /// chọn cạnh nhau, nút điều hướng luôn thấy).
  ///
  /// Không đổi bố cục theo bàn phím ảo (sửa lỗi bản v0.0.2): đổi cây
  /// widget làm ô tên mất focus. Scaffold không co thân theo bàn phím
  /// (`resizeToAvoidBottomInset: false`): bàn phím che phần dưới, ô tên
  /// ở trên vẫn thấy; bấm Xong/Tiếp thì bàn phím đóng.
  Widget _body() {
    return Column(
      children: [
        _headerRow(),
        const SizedBox(height: 6),
        Expanded(child: _middleRow()),
        const SizedBox(height: 6),
        _navRow(),
      ],
    );
  }

  /// Hàng đếm bước (viên tròn cam + chấm tiến độ) + tiêu đề bước.
  Widget _headerRow() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFB86B), Color(0xFFFF8A3D)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                offset: Offset(0, 2),
                blurRadius: 3,
              ),
            ],
          ),
          child: Text(
            'Bước ${_step + 1}/${_stepTitles.length}',
            key: const Key('onboarding-step-counter'),
            style: gameOutlinedText(15),
          ),
        ),
        const SizedBox(width: 8),
        for (var i = 0; i < _stepTitles.length; i++)
          Container(
            width: i == _step ? 18 : 9,
            height: 9,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: i <= _step ? const Color(0xFFFF8A3D) : Colors.white70,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _stepTitles[_step],
            key: const Key('onboarding-step-title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: gameInk,
            ),
          ),
        ),
      ],
    );
  }

  /// Hàng giữa: nhân vật đứng trên bục (trái) + bảng lựa chọn (phải).
  Widget _middleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Xem trước nhân vật (ẩn ở bước chọn trứng để đủ chỗ 3 trứng).
        if (!_isEggStep) ...[
          SizedBox(
            width: 170,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                const Positioned(
                  bottom: 0,
                  left: 10,
                  right: 10,
                  height: 50,
                  child: _Pedestal(),
                ),
                Positioned.fill(
                  bottom: 24,
                  child: CharacterBounce(
                    popKey: _previewPopKey,
                    // Thở/chớp mắt/vẫy tay (kiểu game); cổng
                    // AnimationGate tắt khi chạy test.
                    child: KidSprite(
                      key: const Key('onboarding-preview'),
                      gender: _draft.gender,
                      outfit: kidOutfitNumber(_draft.dress),
                      idleWave: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xD9FFFFFF),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  offset: Offset(0, 3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: SingleChildScrollView(child: _stepBody()),
          ),
        ),
      ],
    );
  }

  /// Hai nút kẹo (Quay lại xanh dương, Tiếp/Xong xanh lá); co lại khi
  /// màn hẹp (chữ trong nút thu nhỏ theo, không tràn).
  Widget _navRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_step > 0)
          Flexible(
            child: PressBounce(
              child: ElevatedButton.icon(
                key: const Key('onboarding-back-button'),
                icon: const Icon(Icons.arrow_back_rounded, size: 26),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Quay lại', style: gameOutlinedText(19)),
                ),
                style: _candyStyle(const Color(0xFF5BA8F5)),
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
                  style: gameOutlinedText(19),
                ),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 26),
              style: _candyStyle(const Color(0xFF4CC46A)),
              onPressed: (_canContinue && !_saving) ? _next : null,
            ),
          ),
        ),
      ],
    );
  }

  /// Kiểu nút kẹo: tròn to, viền trắng, đổ bóng; tắt thì xám nhạt.
  ButtonStyle _candyStyle(Color color) => ElevatedButton.styleFrom(
    minimumSize: const Size(56, 52),
    padding: const EdgeInsets.symmetric(horizontal: 22),
    backgroundColor: color,
    foregroundColor: Colors.white,
    disabledBackgroundColor: const Color(0xFFCFCBD9),
    disabledForegroundColor: Colors.white70,
    elevation: 4,
    shadowColor: const Color(0x66000000),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: const BorderSide(color: Colors.white, width: 3),
    ),
  );

  Widget _stepBody() {
    switch (_stepKey) {
      case 'gender':
        return _pickCards(
          options: onboardingGenders,
          labels: onboardingGenderNames,
          selected: _draft.gender,
          keyPrefix: 'onboarding-gender',
          image: (g) => kidFullAsset(kidGender(g), 1),
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
        return _pickCards(
          options: ids,
          labels: kidOutfitNames,
          selected: _draft.dress ?? ids.first,
          keyPrefix: 'onboarding-dress',
          image: (id) =>
              kidFullAsset(kidGender(_draft.gender), kidOutfitNumber(id)),
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
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: gameInk,
              ),
              decoration: InputDecoration(
                hintText: 'Tên nhân vật',
                errorText: _nameError,
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(
                  Icons.edit_rounded,
                  color: Color(0xFFFF8A3D),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: Color(0xFFFFB86B),
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF8A3D),
                    width: 3,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
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

  /// Hàng thẻ hình (giới tính, bộ đồ): ảnh nửa người trên + tên.
  Widget _pickCards({
    required List<String> options,
    required Map<String, String> labels,
    required String selected,
    required String keyPrefix,
    required String Function(String) image,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final o in options)
          _PickCard(
            key: Key('$keyPrefix-$o'),
            label: labels[o] ?? o,
            image: image(o),
            selected: o == selected,
            onTap: () => onSelected(o),
          ),
      ],
    );
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
    return _GameCard(
      key: Key('onboarding-egg-$species'),
      selected: selected,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 130,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                const Positioned(
                  bottom: 0,
                  left: 14,
                  right: 14,
                  height: 36,
                  child: _Pedestal(),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _EggWiggle(
                    child: Image.asset(
                      eggSpeciesAssets[species]!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: gameInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ chọn kiểu game: nền trắng kem, chọn thì viền cam + nền vàng
/// nhạt + huy hiệu tích xanh; bấm nảy nhẹ.
class _GameCard extends StatelessWidget {
  const _GameCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.width,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return PressBounce(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          // Thẻ trứng nằm trong Expanded: giãn hết bề ngang được cấp.
          fit: StackFit.passthrough,
          children: [
            Container(
              width: width,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: selected
                      ? const [Color(0xFFFFF4C2), Color(0xFFFFD86B)]
                      : const [Colors.white, Color(0xFFF1ECFF)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFFFA726)
                      : const Color(0xFFD8CFF5),
                  width: selected ? 4 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? const Color(0x66FFA726)
                        : const Color(0x22000000),
                    offset: const Offset(0, 3),
                    blurRadius: selected ? 8 : 4,
                  ),
                ],
              ),
              child: child,
            ),
            if (selected)
              const Positioned(
                right: -6,
                top: -6,
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: Color(0xFF4CC46A),
                    child: Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ hình nửa người trên của nhân vật + tên lựa chọn.
class _PickCard extends StatelessWidget {
  const _PickCard({
    super.key,
    required this.label,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String image;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      selected: selected,
      onTap: onTap,
      width: 128,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 92,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.7),
                child: Image.asset(image, width: 1024, height: 1536),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: gameInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bục đứng (ảnh lô 6) dưới nhân vật/trứng.
class _Pedestal extends StatelessWidget {
  const _Pedestal();

  @override
  Widget build(BuildContext context) {
    // Vẽ bằng DecorationImage (không phải widget Image) để mỗi thẻ
    // trứng chỉ có đúng một Image là hình trứng.
    return const DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('$uiArt/ui_pedestal.png'),
          fit: BoxFit.fill,
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
