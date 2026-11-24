/// Màn "Xem thử hiệu ứng rồng" (menu QA): chủ dự án xem vầng sáng +
/// phun lửa / phun nước / bay của rồng ở từng giai đoạn, kể cả khi chưa
/// mua rồng. Không đụng dữ liệu của bé.
library;

import 'package:material_ui/material_ui.dart';

import '../room/pet_growth.dart';
import 'dragon_fx.dart';
import 'dragon_fx_config.dart';

class DragonFxPreviewScreen extends StatefulWidget {
  const DragonFxPreviewScreen({super.key});

  @override
  State<DragonFxPreviewScreen> createState() => _DragonFxPreviewScreenState();
}

class _DragonFxPreviewScreenState extends State<DragonFxPreviewScreen> {
  final DragonFxController _fx = DragonFxController();
  PetStage _stage = PetStage.adult;
  bool _left = false;

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('dragon-fx-preview'),
      appBar: AppBar(title: const Text('Xem thử hiệu ứng rồng')),
      body: ListenableBuilder(
        listenable: _fx,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final st in const [
                    PetStage.newborn,
                    PetStage.teen,
                    PetStage.adult,
                  ])
                    ChoiceChip(
                      key: Key('dragon-preview-stage-${st.name}'),
                      label: Text(petStageNames[st]!),
                      selected: _stage == st,
                      onSelected: (_) => setState(() => _stage = st),
                    ),
                  FilterChip(
                    key: const Key('dragon-preview-flip'),
                    label: const Text('Quay trái'),
                    selected: _left,
                    onSelected: (v) => setState(() => _left = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: DragonPetView(
                      controller: _fx,
                      stage: _stage,
                      facingLeft: _left,
                    ),
                  ),
                ),
              ),
            ),
            if (_stage != PetStage.adult)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(dragonHintText),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6E5A9E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DragonActionMenu(enabled: !_fx.busy, onAction: _fx.play),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
