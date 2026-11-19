/// Màn mở đầu (T2-03, PLAN + DESIGN "Lần đầu mở app").
///
/// Dáng nữ (bộ nhân vật nữ 1, PR #18 — chưa merge vào main lúc viết
/// T2-03) chỉ có 5 bước: giới tính, màu tóc, váy, đặt tên, chọn
/// trứng. Thân đã có sẵn mắt/miệng/tất/giày/bộ đồ gốc nên KHÔNG có
/// bước màu da/kiểu mắt/kiểu miệng; kiểu tóc cố định `girl_hair_01`.
/// Dáng nam chưa có hình thật nên giữ 7 bước cũ với xem trước tạm.
/// Đổi ý ở bước nào cũng quay lại được (nút "Quay lại" ở mọi bước
/// trừ bước đầu). Lưu một lần ở cuối (xem [OnboardingService]) rồi
/// vào Thị trấn; tắt app giữa chừng thì lần sau mở lại từ đầu.
///
/// Xem trước nhân vật bằng [CharacterView] với lớp tạm xám
/// ([placeholderLayerLoader]) — hình thật chưa có trên main, chỉ
/// hiện đúng màu bé chọn và vị trí các lớp; có nhãn "Hình tạm".
/// Cách dựng bộ nữ là đúng bộ thật ([CharacterOutfit.girlSet1]:
/// thân + tóc + váy, không mắt/miệng/giày) nên khi PR #18 merge,
/// chỉ cần bỏ `loader` ở xem trước để dùng `AssetImage` mặc định.
/// Tắt animation của [CharacterView] ở đây (thở/chớp mắt lặp vô hạn
/// làm `pumpAndSettle` trong test không bao giờ dừng); phòng (T2-04)
/// sẽ bật lại.
///
/// Bố cục ngang: cột trái là xem trước, cột phải là lựa chọn của
/// bước (cuộn được để vừa màn 640x320); bước chọn trứng ẩn cột xem
/// trước để đủ chỗ cho 3 thẻ trứng.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database_provider.dart';
import '../character/character_model.dart';
import '../character/character_view.dart';
import '../character/placeholder_layers.dart';
import '../town/town_screen.dart';
import 'onboarding_config.dart';
import 'onboarding_model.dart';
import 'onboarding_service.dart';

/// Các bước của màn mở đầu, theo đúng thứ tự PLAN T2-03 (nữ 5 bước
/// theo bộ nhân vật nữ 1, nam 7 bước theo manifest v1). Bước đầu
/// (giới tính) chung cho cả hai; bước tên và bước trứng luôn là hai
/// bước cuối.
const List<String> _girlStepTitles = <String>[
  'Bé là bé gái hay bé trai?',
  'Chọn màu tóc',
  'Chọn váy',
  'Đặt tên cho nhân vật',
  'Chọn một quả trứng',
];

/// Mã bước dáng nữ, cùng thứ tự với [_girlStepTitles].
const List<String> _girlStepKeys = <String>[
  'gender',
  'hairColor',
  'dress',
  'name',
  'egg',
];

const List<String> _boyStepTitles = <String>[
  'Bé là bé gái hay bé trai?',
  'Chọn màu da',
  'Chọn kiểu tóc và màu tóc',
  'Chọn kiểu mắt và màu mắt',
  'Chọn kiểu miệng',
  'Đặt tên cho nhân vật',
  'Chọn một quả trứng',
];

/// Mã bước dáng nam, cùng thứ tự với [_boyStepTitles].
const List<String> _boyStepKeys = <String>[
  'gender',
  'skin',
  'hair',
  'eyes',
  'mouth',
  'name',
  'egg',
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const String route = '/onboarding';

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
      context.go(TownScreen.route);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa lưu được, bé thử lại nhé')),
      );
    }
  }

  /// Bộ đồ xem trước từ nháp hiện tại.
  ///
  /// Nữ: bộ nhân vật nữ 1 ([CharacterOutfit.girlSet1]) — thân + tóc
  /// + váy, đúng cờ `recolorable` của PR #18 (thân/váy màu thật,
  /// chỉ tóc nhân màu). Nam: bộ đủ lớp manifest v1 (tủ đồ là T2-05),
  /// chỉ tóc/mắt/miệng theo lựa chọn của bé — dáng nam chưa có hình
  /// thật nên tạm dùng bộ nữ làm xem trước (hình tạm xám).
  CharacterOutfit _previewOutfit() {
    if (_draft.gender == 'girl') {
      return CharacterOutfit.girlSet1(
        hairColor: Color(_draft.hairColor),
        top: _draft.dress,
      );
    }
    return CharacterOutfit.girl(
      palette: CharacterPalette(
        skin: Color(_draft.skinColor),
        hair: Color(_draft.hairColor),
        eyes: Color(_draft.eyeColor),
        mouth: const Color(onboardingMouthColor),
        top: const Color(0xFFF2A7C3),
        bottom: const Color(0xFFB5A8E8),
        shoes: const Color(0xFF8FCB9B),
        accessoryHead: const Color(0xFFF28BB0),
      ),
      hairSet: _draft.hairStyle,
      eyes: _draft.eyeStyle,
      mouth: _draft.mouthStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('onboarding-screen'),
      appBar: AppBar(
        title: const Text('Tạo nhân vật'),
        // Mở đầu là bắt buộc ở lần đầu mở app nên không có nút về
        // của hệ thống; nút "Quay lại" trong thân lo việc đổi ý.
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          children: [
            Row(
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
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
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
                            child: CharacterView(
                              key: const Key('onboarding-preview'),
                              outfit: _previewOutfit(),
                              loader: placeholderLayerLoader,
                              // Tắt thở/chớp mắt (xem ghi chú đầu file).
                              animationsEnabled: false,
                            ),
                          ),
                          const Text(
                            'Hình tạm',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(child: SingleChildScrollView(child: _stepBody())),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_step > 0)
                  ElevatedButton.icon(
                    key: const Key('onboarding-back-button'),
                    icon: const Text('←', style: TextStyle(fontSize: 24)),
                    label: const Text(
                      'Quay lại',
                      style: TextStyle(fontSize: 20),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(56, 56),
                    ),
                    onPressed: _saving ? null : _back,
                  ),
                const Spacer(),
                ElevatedButton.icon(
                  key: Key(
                    _isEggStep
                        ? 'onboarding-finish-button'
                        : 'onboarding-next-button',
                  ),
                  label: Text(
                    _isEggStep ? 'Xong — vào Thị trấn' : 'Tiếp theo',
                    style: const TextStyle(fontSize: 20),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Text('→', style: TextStyle(fontSize: 24)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(56, 56),
                  ),
                  onPressed: (_canContinue && !_saving) ? _next : null,
                ),
              ],
            ),
          ],
        ),
      ),
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
          onSelected: (value) =>
              setState(() => _draft = _draft.copyWith(gender: value)),
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
        // Nữ bộ 1: chọn váy phủ lên bộ đồ gốc; không chọn thì mặc
        // bộ đồ gốc trên thân.
        return _optionList<String?>(
          options: onboardingGirlDresses,
          labels: onboardingGirlDressNames,
          selected: _draft.dress,
          keyPrefix: 'onboarding-dress',
          onSelected: (value) => setState(
            () => _draft = value == null
                ? _draft.copyWith(dressToNull: true)
                : _draft.copyWith(dress: value),
          ),
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
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(56, 56),
        backgroundColor: selected ? const Color(0xFFBFE8CF) : null,
      ),
      child: Text(label, style: const TextStyle(fontSize: 20)),
    );
  }
}

/// Thẻ trứng ở bước cuối: hình trứng tạm + tên loài.
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
              child: SvgPicture.asset(eggSpeciesAssets[species]!),
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
