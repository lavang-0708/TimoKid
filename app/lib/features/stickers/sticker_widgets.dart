/// Giao diện sticker (T4-03): huy hiệu, nút HUD và cửa sổ "Sticker mới!".
///
/// Khi [stickerArtReady] tắt, huy hiệu là hình vẽ bằng code: vòng tròn
/// viền trắng kiểu sticker, màu của mảng, biểu tượng mảng ở giữa; sticker
/// chưa mở là hình bóng xám với dấu "?".
library;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/app_database.dart';
import '../../core/widgets/game_ui.dart';
import '../math/math_decor.dart';
import '../math/math_session.dart' show strandNames;
import '../residents/resident_widgets.dart' show strandColor, strandInk;
import '../unlocks/unlock_config.dart';
import '../unlocks/unlock_service.dart';
import 'form_labels.dart';
import 'sticker_config.dart';
import 'sticker_service.dart';

IconData strandIcon(String strand) => switch (strand) {
  'logic' => Icons.extension_rounded,
  'arith' => Icons.calculate_rounded,
  'number' => Icons.tag_rounded,
  'geo' => Icons.change_history_rounded,
  'comb' => Icons.casino_rounded,
  _ => Icons.star_rounded,
};

/// Huy hiệu sticker của một dạng bài. [locked] vẽ hình bóng "?".
class StickerBadge extends StatelessWidget {
  const StickerBadge({
    super.key,
    required this.formId,
    this.size = 64,
    this.locked = false,
  });

  final String formId;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final strand = strandOfForm(formId);
    final color = strandColor(strand);
    Widget body;
    if (locked) {
      body = _lockedBody();
    } else if (stickerArtReady && stickerFormIconArtReady) {
      body = Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            StickerConfig.baseAsset(strand),
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _codeBody(color, strand),
          ),
          Image.asset(
            StickerConfig.formIconAsset(formId),
            width: size * StickerConfig.formIconScale,
            height: size * StickerConfig.formIconScale,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      );
    } else if (stickerArtReady) {
      body = Image.asset(
        StickerConfig.frameAsset(strand),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _codeBody(color, strand),
      );
    } else {
      body = _codeBody(color, strand);
    }
    return SizedBox(
      key: Key(locked ? 'sticker-locked-$formId' : 'sticker-$formId'),
      width: size,
      height: size,
      child: body,
    );
  }

  Widget _lockedBody() {
    final art = stickerArtReady
        ? Image.asset(
            StickerConfig.lockedAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _silhouette(),
          )
        : _silhouette();
    return art;
  }

  Widget _silhouette() => Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFD9D3E6),
      border: Border.all(color: const Color(0xFFEFEAF7), width: size * 0.05),
    ),
    alignment: Alignment.center,
    child: Text(
      '?',
      style: TextStyle(
        fontSize: size * 0.5,
        fontWeight: FontWeight.w800,
        color: const Color(0xFFFFFFFF),
        height: 1,
      ),
    ),
  );

  Widget _codeBody(Color color, String strand) => Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [Color.lerp(color, Colors.white, 0.5)!, color],
      ),
      border: Border.all(color: Colors.white, width: size * 0.07),
      boxShadow: const [
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    alignment: Alignment.center,
    child: Icon(strandIcon(strand), size: size * 0.5, color: strandInk(strand)),
  );
}

/// Một ô trong trang sổ: huy hiệu + tên dạng (hoặc "???" khi chưa mở).
class StickerTile extends StatelessWidget {
  const StickerTile({
    super.key,
    required this.formId,
    required this.locked,
    this.isNew = false,
    this.badgeSize = 56,
  });

  final String formId;
  final bool locked;
  final bool isNew;
  final double badgeSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: Key('sticker-tile-$formId'),
      width: badgeSize + 28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              StickerBadge(formId: formId, size: badgeSize, locked: locked),
              if (isNew && !locked)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    key: Key('sticker-new-$formId'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Text(
                      'Mới',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            locked ? '???' : formLabel(formId),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: locked ? const Color(0xFF9C93B5) : MathColors.questionText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút "Sổ sticker" trên HUD Thị trấn / Phòng.
class StickerHudButton extends StatelessWidget {
  const StickerHudButton({super.key, this.onPressed});

  /// Mặc định mở `/stickers`.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GameRoundButton(
      icon: Icons.auto_stories_rounded,
      image: stickerArtReady ? StickerConfig.bookCoverAsset : null,
      color: const Color(0xFF6FC7A6),
      label: 'Sticker',
      tooltip: 'Sổ sticker',
      onPressed: onPressed ?? () => context.push('/stickers'),
    );
  }
}

/// Danh hiệu cạnh tên nhân vật (mốc 4 của mở khóa).
class TitleChip extends StatelessWidget {
  const TitleChip({super.key, this.fontSize = 12});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('title-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9A8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8B930), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unlockArtReady)
            Image.asset(
              UnlockConfig.titleBadgeAsset,
              width: fontSize + 4,
              height: fontSize + 4,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.star_rounded, size: fontSize + 2),
            )
          else
            Icon(
              Icons.star_rounded,
              size: fontSize + 2,
              color: const Color(0xFFE8B930),
            ),
          const SizedBox(width: 3),
          Text(
            UnlockConfig.titleText,
            maxLines: 1,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: MathColors.questionText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cửa sổ chúc mừng "Sticker mới!" (và mốc mở khóa mới). Chỉ hiện khi có
/// sticker/mốc bé chưa được chúc mừng; hiện xong thì đánh dấu đã chúc mừng
/// nên mỗi sticker chỉ có MỘT lần. Trả true nếu đã hiện cửa sổ.
Future<bool> showCelebrationIfAny(BuildContext context, AppDatabase db) async {
  final childId = await db.ensureSeeded();
  final stickers = StickerService(db: db);
  final unlocks = UnlockService(db: db);
  // Cấp bù (máy đã có dạng thành thạo từ trước) rồi mới tìm cái chưa mừng.
  await stickers.awardPending(childId);
  await unlocks.grantRewards(childId);
  final forms = await stickers.pendingCelebrations(childId);
  final tiers = await unlocks.pendingCelebrations(childId);
  if (forms.isEmpty && tiers.isEmpty) return false;
  // Đánh dấu NGAY khi quyết định hiện để không hiện hai lần dù màn dựng lại.
  await stickers.markSeen(childId, forms);
  await unlocks.markSeen(childId, tiers);
  if (!context.mounted) return false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => NewStickerDialog(forms: forms, tiers: tiers),
  );
  return true;
}

class NewStickerDialog extends StatelessWidget {
  const NewStickerDialog({super.key, required this.forms, required this.tiers});

  final List<String> forms;
  final List<UnlockTier> tiers;

  @override
  Widget build(BuildContext context) {
    final shown = forms.take(StickerConfig.maxShownInPopup).toList();
    final more = forms.length - shown.length;
    final gems = forms.length * StickerConfig.gemsPerSticker;
    return Dialog(
      key: const Key('new-sticker-dialog'),
      backgroundColor: const Color(0xFFFFFBEF),
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE8B930), width: 3),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                forms.isEmpty ? 'Mở khóa mới!' : 'Sticker mới!',
                key: const Key('new-sticker-title'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: MathColors.questionText,
                ),
              ),
              if (forms.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    for (final f in shown)
                      StickerTile(formId: f, locked: false, badgeSize: 52),
                  ],
                ),
                if (more > 0)
                  Text(
                    'và $more sticker khác',
                    key: const Key('new-sticker-more'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: MathColors.englishText,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  'Bé đã thành thạo ${forms.length == 1 ? 'dạng "${formLabel(forms.first)}"' : '${forms.length} dạng bài mới'}!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: MathColors.questionText,
                  ),
                ),
                Text(
                  '+$gems kim cương',
                  key: const Key('new-sticker-gems'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7A55C8),
                  ),
                ),
              ],
              for (final t in tiers) ...[
                const SizedBox(height: 6),
                Container(
                  key: Key('new-unlock-${t.id}'),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE9A8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Đã mở ${t.name}! ${t.description}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MathColors.questionText,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    key: const Key('new-sticker-dismiss'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(56, 56),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Hay quá!',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                  OutlinedButton(
                    key: const Key('new-sticker-open-book'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(56, 56),
                    ),
                    onPressed: () {
                      final router = GoRouter.maybeOf(context);
                      Navigator.of(context).pop();
                      router?.push('/stickers');
                    },
                    child: const Text(
                      'Xem sổ sticker',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tên mảng cho tiêu đề trang sổ.
String strandTitle(String strand) => strandNames[strand] ?? strand;
