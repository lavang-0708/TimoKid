/// Màn Sổ sticker (T4-03) — route `/stickers`.
///
/// Mỗi dạng bài bé đã thành thạo là một sticker, xếp theo 5 mảng (mỗi mảng
/// một trang, vuốt hoặc bấm tab để đổi trang). Sticker chưa có hiện hình
/// bóng với dấu "?"; mỗi tab và đầu trang hiện tiến độ "N/M". Đầu màn có
/// dòng "Còn N dạng nữa để mở ..." (mở khóa theo số dạng thành thạo, xem
/// `unlock_config.dart`). Có mốc đầu thì trang sổ có khung vàng.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database_provider.dart';
import '../../core/database/tables.dart';
import '../../core/widgets/round_back_button.dart';
import '../math/math_decor.dart';
import '../residents/resident_widgets.dart' show strandColor, strandInk;
import '../room/room_screen.dart';
import '../unlocks/unlock_config.dart';
import '../unlocks/unlock_service.dart';
import 'sticker_config.dart';
import 'sticker_service.dart';
import 'sticker_widgets.dart';

class StickerBookScreen extends ConsumerStatefulWidget {
  const StickerBookScreen({super.key});

  static const String route = '/stickers';

  @override
  ConsumerState<StickerBookScreen> createState() => _StickerBookScreenState();
}

class _StickerBookScreenState extends ConsumerState<StickerBookScreen> {
  final PageController _pages = PageController();
  int _page = 0;
  bool _loading = true;
  String? _error;
  Set<String> _earned = {};
  Set<String> _new = {};
  int _mastered = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final db = ref.read(databaseProvider);
      final childId = await db.ensureSeeded();
      final stickers = StickerService(db: db);
      final unlocks = UnlockService(db: db);
      // Cấp bù cho dạng đã thành thạo từ trước (idempotent).
      await stickers.awardPending(childId);
      await unlocks.grantRewards(childId);
      final progress = await stickers.progress(childId);
      final mastered = await unlocks.masteredCount(childId);
      // Nhãn "Mới" hiện trong lần xem này; sau đó coi như đã thấy.
      await stickers.markSeen(childId, progress.newForms);
      if (!mounted) return;
      setState(() {
        _earned = progress.earned;
        _new = progress.newForms;
        _mastered = mastered;
        _loading = false;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        key: Key('sticker-book-screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        key: const Key('sticker-book-screen'),
        body: Center(child: Text('Không tải được Sổ sticker: $_error')),
      );
    }
    final total = allFormIds.length;
    final strand = Strand.all[_page];
    final goldFrame = _mastered >= UnlockConfig.goldFrameThreshold;
    return Scaffold(
      key: const Key('sticker-book-screen'),
      backgroundColor: Color.lerp(strandColor(strand), Colors.white, 0.72),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  RoundBackButton(
                    key: const Key('sticker-back-button'),
                    size: 44,
                    tooltip: 'Quay lại',
                    onPressed: _back,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sổ sticker',
                        key: const Key('sticker-book-title'),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: MathColors.questionText,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_mastered >= UnlockConfig.titleThreshold) ...[
                    const Flexible(child: FittedBox(child: TitleChip())),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    key: const Key('sticker-total-progress'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_earned.length}/$total',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: MathColors.questionText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  UnlockService.progressText(_mastered),
                  key: const Key('sticker-unlock-progress'),
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MathColors.buttonNumber,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (var i = 0; i < Strand.all.length; i++)
                    Expanded(child: _tab(i)),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: PageView(
                  key: const Key('sticker-pages'),
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    for (final s in Strand.all) _pageFor(s, goldFrame),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(int i) {
    final s = Strand.all[i];
    final selected = i == _page;
    final progress =
        '${_earned.where((f) => strandOfForm(f) == s).length}/'
        '${formIdsOfStrand(s).length}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        key: Key('sticker-tab-$s'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _pages.animateToPage(
          i,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        ),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? strandColor(s) : Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? strandInk(s) : strandColor(s),
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${strandTitle(s)} $progress',
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: strandInk(s),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageFor(String strand, bool goldFrame) {
    final forms = formIdsOfStrand(strand);
    final have = forms.where(_earned.contains).length;
    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${strandTitle(strand)}: $have/${forms.length} sticker',
          key: Key('sticker-page-progress-$strand'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: strandInk(strand),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: SingleChildScrollView(
            key: Key('sticker-grid-$strand'),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 8,
              children: [
                for (final f in forms)
                  StickerTile(
                    formId: f,
                    locked: !_earned.contains(f),
                    isNew: _new.contains(f),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    // Giấy nền trang sổ (lô 17): lặp theo chiều ngang, không có chữ.
    final paper = stickerArtReady
        ? const DecorationImage(
            image: AssetImage(StickerConfig.bookCoverAsset),
            fit: BoxFit.fitHeight,
            repeat: ImageRepeat.repeatX,
          )
        : null;
    if (goldFrame && unlockArtReady) {
      // Khung vàng 9 mảnh: ảnh 192x192, viền 48 px. `centerSlice` tính theo
      // điểm ảnh nên vẽ ở cỡ x4 rồi thu 1/4 (viền hiện 12 dp).
      const slice = 4.0;
      return Container(
        key: Key('sticker-gold-frame-$strand'),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEF),
          borderRadius: BorderRadius.circular(16),
          image: paper,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, c) => FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: c.maxWidth * slice,
                      height: c.maxHeight * slice,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage(UnlockConfig.goldFrameAsset),
                            fit: BoxFit.fill,
                            centerSlice: Rect.fromLTRB(48, 48, 144, 144),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.all(18), child: inner),
          ],
        ),
      );
    }
    final BoxDecoration decoration;
    if (goldFrame) {
      decoration = BoxDecoration(
        color: const Color(0xFFFFFBEF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8B930), width: 4),
        boxShadow: const [BoxShadow(color: Color(0x55E8B930), blurRadius: 10)],
        image: paper,
      );
    } else {
      decoration = BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: strandColor(strand), width: 3),
        image: paper,
      );
    }
    return Container(
      key: goldFrame ? Key('sticker-gold-frame-$strand') : null,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      padding: const EdgeInsets.all(8),
      decoration: decoration,
      child: inner,
    );
  }
}
