/// Màn làm toán (T1-09, sinh động hóa ở T1-15 theo PLAN điểm (m)).
///
/// Đề luôn hiện song ngữ (PLAN điểm (l)): tiếng Việt chữ to trên,
/// tiếng Anh nhỏ hơn + nhạt hơn dưới; gợi ý và lời giải cũng song ngữ.
/// Nút từ khóa mở bảng từ khóa song ngữ, hình vẽ hiện nếu câu có hình.
/// Trắc nghiệm: 4 nút lớn, thứ tự trộn ngẫu nhiên (xác định theo seed
/// của câu — xem [shuffledChoiceOrder]). Điền số: bàn phím số riêng
/// trong app, nút to, có nút xóa.
///
/// Bố cục 2 cột (sửa sau review PR #11, cân lại ở T1-12 theo điểm
/// (l), sinh động hóa ở T1-15 theo điểm (m)): cột trái là thanh tiến
/// độ + pet ở hàng trên, đề trong thẻ trắng bo tròn có bóng (cuộn
/// được, khối đề căn giữa dọc), gợi ý/lời giải nằm trong băng ở
/// DƯỚI thẻ đề trong luồng bố cục (không chồng lên — sửa sau review
/// PR #14); cột phải là 4 nút trắc nghiệm hoặc ô số + bàn phím,
/// cộng nút "Tiếp" — cả khối căn giữa dọc, chỉ cuộn khi màn thấp
/// quá không vừa (dưới cỡ thiết kế 320 dp; sửa sau review PR #19:
/// máy ảo CI thấp hơn 320 dp nên cột phải tràn 39 px khi băng xanh
/// hiện). Pet không che chữ nào ở bất kỳ trạng thái nào (nằm cạnh
/// thanh tiến độ).
/// Bố cục xếp dọc 1 cột cũ không vừa điện thoại ngang cao 360 dp (máy
/// ảo 640x320: nút choice-3 nằm ngoài màn hình).
///
/// Sinh động (T1-15): thanh tiến độ 5 ô thay chữ "Câu 1/5"; nền theo
/// mảng (màu pastel + họa tiết SVG nhẹ); nút đáp án kiểu nổi (viền
/// dưới đậm, nhấn lún xuống); băng phản hồi trượt lên từ đáy (xanh
/// "Đúng rồi! +N xu" kèm nút Tiếp, cam nhạt "Gần đúng rồi, xem gợi ý
/// nhé" khi sai lần đầu); xu bay về góc ví; đúng liền 3 câu hiện
/// "3 câu liền!"; pet mèo nhỏ cạnh thanh tiến độ phản ứng vui khi
/// đúng, động viên khi sai (không che chữ nào — sửa sau review
/// PR #14). Hiệu ứng dưới 1 giây, không chặn thao tác.
///
/// Sai lần đầu hiện gợi ý và cho làm lại; sai lần hai hiện lời giải
/// từng bước và nút "Tiếp". Đúng thì có hiệu ứng (ngôi sao + số xu)
/// và âm thanh ngắn ([SoundService], xem PLAN điểm (m)), rồi nút
/// "Tiếp". Mỗi câu đã giải quyết ghi một dòng `attempts`, cập nhật
/// bậc/thành thạo, ghi sổ ôn tập và cộng xu (xem [StageSession]).
/// Cuối chặng chuyển sang màn Kết quả chặng.
///
/// Màn nhận một [StageSession] có sẵn (test dùng) hoặc tự tải đề ngày
/// hôm nay và làm chặng đầu tiên chưa xong (nút "Làm toán" ở Thị trấn
/// đi đường này). Chặng cụ thể chọn qua [MathScreenArgs].
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database_provider.dart';
import '../../core/database/models.dart';
import '../daily_set/daily_set_config.dart';
import '../daily_set/daily_set_service.dart';
import '../ladder/ladder_service.dart';
import '../questions/figure_svg.dart';
import '../questions/question.dart';
import '../rewards/reward_config.dart';
import '../rewards/reward_service.dart';
import '../sound/sound_service.dart';
import '../stage_result/stage_result_screen.dart';
import 'math_decor.dart';
import 'math_session.dart';

/// Tham số vào màn làm toán qua GoRouter `extra`.
class MathScreenArgs {
  const MathScreenArgs({this.stageIndex});

  /// Chỉ số chặng cần làm (0–4). Bỏ trống: chặng đầu tiên chưa xong.
  final int? stageIndex;
}

/// Màn làm toán — route `/math`.
class MathScreen extends ConsumerStatefulWidget {
  const MathScreen({super.key, this.session, this.args, this.soundService});

  static const String route = '/math';

  /// Phiên chặng có sẵn (test bơm trực tiếp). Bỏ trống: màn tự tải
  /// đề ngày hôm nay rồi dựng phiên.
  final StageSession? session;

  final MathScreenArgs? args;

  /// Âm thanh (test chích [SoundService] với [SoundPlayer] giả).
  /// Bỏ trống: màn tự dựng [SoundService] khi tải đề; bỏ trống cùng
  /// với `session` thì màn im lặng.
  final SoundService? soundService;

  @override
  ConsumerState<MathScreen> createState() => _MathScreenState();
}

class _MathScreenState extends ConsumerState<MathScreen>
    with TickerProviderStateMixin {
  StageSession? _session;
  SoundService? _soundService;

  /// Màn tự dựng [SoundService] (không chích từ ngoài) thì tự giải
  /// phóng pool player khi dispose; service chích từ test thì test
  /// là chủ, màn không dispose.
  bool _ownsSoundService = false;
  bool _loading = true;
  bool _allDone = false;
  String? _error;
  bool _navigated = false;

  /// Ví xu trên AppBar — đích đến của hiệu ứng xu bay.
  final GlobalKey _walletKey = GlobalKey();

  /// Hiệu ứng xu bay: điều khiển + mục overlay (null khi không bay).
  AnimationController? _coinController;
  OverlayEntry? _coinEntry;

  @override
  void initState() {
    super.initState();
    _soundService = widget.soundService;
    if (widget.session != null) {
      _session = widget.session;
      _session!.addListener(_onSessionChanged);
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _removeCoinFly();
    _session?.removeListener(_onSessionChanged);
    if (_ownsSoundService) unawaited(_soundService?.dispose());
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() {});
    final session = _session;
    if (session == null) return;
    if (session.state == QuestionState.correct) {
      // Đúng: xu bay về góc ví (chỉ khi có xu để cộng).
      if ((session.lastEarnedXu ?? 0) > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startCoinFly();
        });
      }
    } else {
      _removeCoinFly();
    }
    if (session.finished && !_navigated) {
      _navigated = true;
      // Xong chặng: phát hợp âm rải sau 600 ms để tiếng "ting" và
      // tiếng xu của câu cuối dứt hẳn rồi mới tới tiếng xong chặng,
      // lúc này màn Kết quả chặng đã hiện.
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        _soundService?.playStageComplete();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(StageResultScreen.route, extra: _resultArgs(session));
      });
    }
  }

  /// Xu bay từ băng phản hồi lên góc ví (600 ms, không chặn thao tác).
  void _startCoinFly() {
    if (_coinEntry != null || !mounted) return;
    final walletBox =
        _walletKey.currentContext?.findRenderObject() as RenderBox?;
    if (walletBox == null) return;
    final end = walletBox.localToGlobal(walletBox.size.center(Offset.zero));
    final size = MediaQuery.sizeOf(context);
    // Điểm xuất phát: gần ô xu của băng phản hồi (đáy màn, giữa).
    final start = Offset(size.width * 0.55, size.height - 70);
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _coinController = controller;
    final entry = OverlayEntry(
      builder: (_) => _CoinFly(controller: controller, start: start, end: end),
    );
    _coinEntry = entry;
    Overlay.of(context).insert(entry);
    controller.forward().whenComplete(() {
      if (mounted) _removeCoinFly();
    });
  }

  void _removeCoinFly() {
    _coinEntry?.remove();
    _coinEntry = null;
    _coinController?.dispose();
    _coinController = null;
  }

  StageResultArgs _resultArgs(StageSession session) {
    final next =
        session.stageIndex >= 0 &&
            session.stageIndex + 1 < DailySetConfig.stagesPerDay
        ? session.stageIndex + 1
        : null;
    return StageResultArgs(
      stageIndex: session.stageIndex,
      strand: session.resolved.first.spec.strand,
      correctCount: session.correctCount,
      firstTryCorrectCount: session.firstTryCorrectCount,
      totalQuestions: session.resolved.length,
      xuEarned: session.xuEarned,
      nextStageIndex: next,
    );
  }

  /// Tải đề ngày hôm nay và dựng phiên cho chặng cần làm.
  Future<void> _load() async {
    try {
      final db = ref.read(databaseProvider);
      final childId = await db.ensureSeeded();
      final service = DailySetService(
        dailySetsDao: db.dailySetsDao,
        reviewQueueDao: db.reviewQueueDao,
        ladderService: LadderService(
          attemptsDao: db.attemptsDao,
          skillProgressDao: db.skillProgressDao,
        ),
        clock: db.clock,
      );
      final set = await service.getOrCreateTodaySet(childId: childId);
      final statuses = db.dailySetsDao.readStageStatus(set);
      var stageIndex =
          widget.args?.stageIndex ??
          statuses.indexWhere((s) => s != StageStatus.done);
      if (stageIndex < 0 || stageIndex >= DailySetConfig.stagesPerDay) {
        if (!mounted) return;
        setState(() {
          _allDone = true;
          _loading = false;
        });
        return;
      }
      final questions = db.dailySetsDao
          .readQuestions(set)
          .sublist(
            stageIndex * DailySetConfig.questionsPerStage,
            (stageIndex + 1) * DailySetConfig.questionsPerStage,
          );
      // Bảng thưởng đọc từ settings (T1-11): đổi settings thì mức
      // thưởng của phiên này đổi theo.
      final session = StageSession(
        db: db,
        childId: childId,
        dailySetId: set.id,
        stageIndex: stageIndex,
        questions: questions,
        rewardService: RewardService(
          db: db,
          config: await RewardConfig.load(db),
        ),
      );
      session.addListener(_onSessionChanged);
      await session.markStageInProgress();
      if (!mounted) return;
      setState(() {
        _session = session;
        // Âm thanh (PLAN điểm (m)): dựng cùng lúc với phiên, dùng
        // chung DB để đọc `sound_enabled`. Màn tự dựng thì tự giải
        // phóng pool player khi dispose (xem [_ownsSoundService]).
        if (_soundService == null) {
          _soundService = SoundService(db: db);
          _ownsSoundService = true;
        }
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

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (_loading) {
      return const Scaffold(
        key: Key('math-screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        key: const Key('math-screen'),
        appBar: AppBar(title: const Text('Làm toán')),
        body: Center(child: Text('Không tải được đề: $_error')),
      );
    }
    if (_allDone || session == null) {
      return Scaffold(
        key: const Key('math-screen'),
        appBar: AppBar(title: const Text('Làm toán')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Bé đã xong đề ngày hôm nay rồi!'),
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  key: const Key('math-back-button'),
                  onPressed: () => context.go('/'),
                  child: const Text('Về Thị trấn'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final question = session.current;
    final strand = question.spec.strand;
    final strandName = strandNames[strand] ?? strand;
    final background = MathColors.strandBackground(strand);
    final title = session.stageIndex >= 0
        ? 'Chặng ${session.stageIndex + 1} — $strandName'
        : 'Chặng tự chọn — $strandName';
    // Băng phản hồi: đúng thì băng xanh toàn màn (kèm nút Tiếp);
    // sai lần đầu / sai hai lần thì băng cam / xanh dương nằm dưới
    // thẻ đề trong luồng cột trái (không chồng lên — xem
    // [_QuestionColumn], sửa sau review PR #14).
    final showGreenBanner = session.state == QuestionState.correct;
    // Pet vui khi đang làm / đúng, động viên khi gợi ý / lời giải.
    // Pet nằm cạnh thanh tiến độ trong [_QuestionColumn], không
    // còn ở góc dưới-trái (review PR #14: pet không được che chữ).
    final petHappy =
        session.state != QuestionState.hint &&
        session.state != QuestionState.solution;
    // Chừa chỗ dưới cho băng xanh (cột phải lúc đúng chỉ còn nút
    // trắc nghiệm/ô số nên vẫn vừa); băng gợi ý/lời giải nằm trong
    // luồng cột trái nên không cần chừa chỗ toàn màn.
    const greenBannerReserve = 112.0;
    // Các nút trên thanh tiêu đề là nút biểu tượng, tối thiểu 56x56 dp.
    // Biểu tượng là ký tự chữ (←, Aa) thay vì `Icon` vì font
    // MaterialIcons không có trong môi trường test nên golden test sẽ
    // bị ô vuông; các ký tự này có trong font DejaVu dùng ở test và
    // trong Roboto trên máy thật.
    // Nút đổi EN đã bỏ (PLAN điểm (l)): đề luôn hiện song ngữ cùng lúc.
    return Scaffold(
      key: const Key('math-screen'),
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: MathColors.questionText,
        title: Text(title),
        // Bé được rời chặng giữa chừng: chặng đang làm giữ trạng thái
        // `in_progress` nên vào lại vẫn làm tiếp từ đầu chặng.
        leading: IconButton(
          key: const Key('math-back-button'),
          icon: const Text('←', style: TextStyle(fontSize: 30)),
          tooltip: 'Về',
          onPressed: () => context.go('/'),
          style: IconButton.styleFrom(
            minimumSize: const Size(56, 56),
            iconSize: 30,
          ),
        ),
        actions: [
          // Ví xu của chặng (đích đến của hiệu ứng xu bay).
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              key: _walletKey,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _CoinIcon(size: 22),
                  const SizedBox(width: 6),
                  Text(
                    '${session.xuEarned} xu',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: MathColors.questionText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            key: const Key('math-keywords-button'),
            icon: const Text('Aa', style: TextStyle(fontSize: 22)),
            tooltip: 'Từ khóa',
            onPressed: () => _showKeywords(context, question.question),
            style: IconButton.styleFrom(
              minimumSize: const Size(56, 56),
              iconSize: 30,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Nền theo mảng: màu pastel + họa tiết SVG nhẹ.
          const Positioned.fill(child: _MathPattern()),
          Padding(
            padding: EdgeInsets.only(
              bottom: showGreenBanner ? greenBannerReserve : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _QuestionColumn(
                  session: session,
                  question: question,
                  petHappy: petHappy,
                ),
                _AnswerColumn(
                  session: session,
                  question: question,
                  onCorrect: () => _soundService?.playCorrect(),
                  onWrong: () => _soundService?.playWrong(),
                ),
              ],
            ),
          ),
          // Băng phản hồi đúng: trượt lên từ đáy màn, toàn chiều
          // rộng. Pet đã chuyển lên cạnh thanh tiến độ nên băng
          // không cần chừa chỗ trái nữa (sửa sau review PR #14).
          if (showGreenBanner)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _SlideUpBanner(child: _CorrectBanner(session: session)),
            ),
        ],
      ),
    );
  }

  void _showKeywords(BuildContext context, Question question) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('keywords-dialog'),
        title: const Text('Từ khóa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final keyword in question.keywords)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${keyword.en} — ${keyword.vi}',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
          ],
        ),
        actions: [
          SizedBox(
            height: 56,
            child: TextButton(
              key: const Key('keywords-close-button'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Màu viền dưới đậm của nút nổi: mặc định (nút đào), đúng (xanh),
/// sai (đỏ).
const Color _raisedPeachBottom = Color(0xFFF0B48C);
const Color _raisedGreenBottom = Color(0xFF2E7D32);
const Color _raisedRedBottom = Color(0xFFC62828);

/// Họa tiết nền nhẹ theo mảng (PLAN điểm (m)): lát ô SVG trắng mờ
/// trên nền pastel.
class _MathPattern extends StatelessWidget {
  const _MathPattern();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const tile = 120.0;
        final cols = (constraints.maxWidth / tile).ceil();
        final rows = (constraints.maxHeight / tile).ceil();
        // Wrap thay vì lưới Row/Column: ô cuối hàng không vừa sẽ
        // xuống hàng dưới thay vì tràn (Row báo lỗi tràn dù có
        // ClipRect); phần thừa chiều cao được ClipRect cắt.
        return ClipRect(
          child: Opacity(
            opacity: 0.5,
            child: Wrap(
              spacing: 0,
              runSpacing: 0,
              children: [
                for (var i = 0; i < cols * rows; i++)
                  SvgPicture.string(mathPatternSvg, width: tile, height: tile),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Thanh tiến độ 5 ô thay chữ "Câu 1/5" (PLAN điểm (m)): ô đã làm
/// tô xanh, ô hiện tại tím đậm nổi bật, ô chưa làm trắng viền mờ.
class _ProgressCells extends StatelessWidget {
  const _ProgressCells({
    required this.total,
    required this.currentIndex,
    required this.state,
  });

  final int total;
  final int currentIndex;
  final QuestionState state;

  bool _done(int i) =>
      i < currentIndex ||
      (i == currentIndex &&
          (state == QuestionState.correct || state == QuestionState.solution));

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('math-progress'),
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              key: Key('math-progress-cell-$i'),
              height: 14,
              decoration: BoxDecoration(
                color: _done(i)
                    ? MathColors.progressDone
                    : i == currentIndex
                    ? MathColors.progressCurrent
                    : Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: _done(i) || i == currentIndex
                    ? null
                    : Border.all(
                        color: MathColors.progressUpcomingBorder,
                        width: 2,
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Cột trái: hàng trên là thanh tiến độ + pet, dưới là đề trong thẻ
/// trắng (cuộn được, khối đề căn giữa dọc — PLAN điểm (l)), dưới
/// cùng là băng gợi ý/lời giải khi có.
///
/// Gợi ý / lời giải KHÔNG nằm dưới đề trong vùng cuộn (review
/// PR #13: ở 800x360 và 640x320 chúng bị khuất, phải cuộn mới thấy)
/// mà nằm trong băng phản hồi ở đáy cột trái — luôn thấy ngay, bé
/// không phải cuộn. Băng chỉ chiếm cột trái (không che nút đáp án
/// cột phải: bàn phím số ở 640x320 cần tối thiểu 224 dp trong khi
/// thân màn chỉ 264 dp, băng toàn màn không còn chỗ); băng cao tối
/// đa 55% cột, nội dung dài thì cuộn trong băng, băng luôn hiện.
///
/// Sửa sau review PR #14: băng KHÔNG còn chồng lên thẻ đề bằng
/// `Positioned` (trước đây nó đè nửa dưới thẻ, che câu hỏi) mà nằm
/// trong luồng bố cục dưới thẻ — thẻ đề co lại và cuộn phần còn
/// lại. Đã cân nhắc đặt băng ở cột phải dưới 4 nút (chỗ đó trống
/// khi trắc nghiệm): ở 640x320 trạng thái lời giải còn nút "Tiếp"
/// 68 dp nên chỉ còn ~24 dp cho băng, không đủ; giữ băng ở cột
/// trái cho cả hai loại câu.
/// Pet cũng chuyển từ góc dưới-trái (đè dòng tiếng Anh) lên cạnh
/// thanh tiến độ ở hàng trên: nằm trong luồng bố cục nên không che
/// chữ nào ở bất kỳ trạng thái nào.
class _QuestionColumn extends StatelessWidget {
  const _QuestionColumn({
    required this.session,
    required this.question,
    required this.petHappy,
  });

  final StageSession session;
  final ResolvedQuestion question;

  /// Pet vui khi đang làm / đúng, động viên khi gợi ý / lời giải.
  final bool petHappy;

  @override
  Widget build(BuildContext context) {
    final showHintBanner = session.state == QuestionState.hint;
    final showSolutionBanner = session.state == QuestionState.solution;
    return Expanded(
      flex: 6,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Băng gợi ý/lời giải cao tối đa 55% cột (tối đa 240 dp),
          // và luôn chừa chỗ cho hàng tiến độ + pet (60 dp) ở trên:
          // ở màn thấp (máy ảo CI dưới 320 dp) mức tối thiểu 120 dp
          // cũ làm băng + hàng trên vượt chiều cao cột nên tràn, đồng
          // thời thẻ đề bị `minHeight` âm. Băng tự cuộn trong khi
          // nội dung dài (xem [_InfoBanner]) nên thu hẹp vẫn đọc được.
          final bannerMaxHeight = math
              .min(
                constraints.maxHeight * 0.55,
                math.max(0.0, constraints.maxHeight - 60.0),
              )
              .clamp(0.0, 240.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hàng trên: thanh tiến độ + pet (48 dp). Thanh tiến
              // độ cố định ở trên thay vì nằm trong vùng cuộn nên
              // bé luôn thấy đang ở câu mấy; pet trong luồng bố cục
              // nên không che chữ nào.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _ProgressCells(
                        total: session.resolved.length,
                        currentIndex: session.currentIndex,
                        state: session.state,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PetMascot(happy: petHappy),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, innerConstraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          // Màn thấp: chỗ còn lại cho thẻ đề có thể
                          // nhỏ hơn 22 dp (thậm chí 0 khi băng gợi
                          // ý/lời giải chiếm gần hết cột) — kẹp về 0
                          // để không ném lỗi `BoxConstraints` âm.
                          minHeight: math.max(
                            0.0,
                            innerConstraints.maxHeight - 22,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Đề trong thẻ trắng bo tròn có bóng (điểm (m)).
                            // Key để test khóa "băng không chồng thẻ đề".
                            Container(
                              key: const Key('math-question-card'),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Đề luôn song ngữ (PLAN điểm (l)): tiếng
                                  // Việt chữ to trên, tiếng Anh nhỏ hơn +
                                  // nhạt hơn dưới.
                                  Text(
                                    question.question.questionVi,
                                    key: const Key('math-question-text'),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      color: MathColors.questionText,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    question.question.questionEn,
                                    key: const Key('math-question-text-en'),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: MathColors.englishText,
                                    ),
                                  ),
                                  if (question.question.figure != null) ...[
                                    const SizedBox(height: 12),
                                    Center(
                                      child: FigureView(
                                        key: const Key('math-figure'),
                                        figure: question.question.figure!,
                                        width: 220,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Băng gợi ý/lời giải trong luồng bố cục, dưới thẻ đề:
              // thẻ đề co lại, không bị băng chồng lên (review
              // PR #14). Băng trượt lên từ đáy khi vừa hiện.
              if (showHintBanner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _SlideUpBanner(
                    child: _HintBanner(
                      question: question,
                      maxHeight: bannerMaxHeight,
                    ),
                  ),
                ),
              if (showSolutionBanner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _SlideUpBanner(
                    child: _SolutionBanner(
                      question: question,
                      maxHeight: bannerMaxHeight,
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

/// Cột phải: đáp án + nút "Tiếp" (chỉ khi sai hai lần — khi đúng,
/// nút Tiếp nằm trong băng phản hồi) — không cuộn, cả khối căn giữa
/// dọc trong vùng dưới thanh trên (PLAN điểm (l)).
class _AnswerColumn extends StatelessWidget {
  const _AnswerColumn({
    required this.session,
    required this.question,
    required this.onCorrect,
    required this.onWrong,
  });

  final StageSession session;
  final ResolvedQuestion question;

  /// Đúng: "ting" + xu; sai: "è" nhẹ (âm thanh phát nền, không await).
  final VoidCallback onCorrect;
  final VoidCallback onWrong;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showInlineNext = session.state == QuestionState.solution;
            final nextSpace = showInlineNext ? 56.0 + 12 : 0.0;
            final available = constraints.maxHeight - nextSpace;
            // 2 hàng nút trắc nghiệm + khe 12 dp + viền nổi 4 dp/hàng.
            final choiceHeight = ((available - 12) / 2 - 4).clamp(48.0, 64.0);
            // Màn thấp (máy ảo CI dưới 320 dp): khi băng xanh hiện,
            // phần chừa 112 dp cho băng làm cột phải chỉ còn ~56 dp
            // mà 2 hàng nút trắc nghiệm cần tối thiểu 116 dp nên tràn
            // 39–60 px. Bọc cuộn để không tràn: vừa thì
            // `ConstrainedBox` giữ khối căn giữa dọc như trước, không
            // vừa thì cuộn (nút Tiếp lúc đúng nằm ở băng xanh ngoài
            // cột nên luôn bấm được; nút Tiếp lúc xem lời giải và nút
            // gửi bàn phím thì cuộn tới mới thấy).
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    question.displayType == AnswerType.choice
                        ? _ChoiceAnswers(
                            session: session,
                            question: question,
                            buttonHeight: choiceHeight,
                            onCorrect: onCorrect,
                            onWrong: onWrong,
                          )
                        : _NumberPad(
                            session: session,
                            onCorrect: onCorrect,
                            onWrong: onWrong,
                            availableHeight: available,
                          ),
                    if (showInlineNext) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          key: const Key('math-next-button'),
                          onPressed: () => session.next(),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              session.isLastQuestion ? 'Xem kết quả' : 'Tiếp',
                              softWrap: false,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Trượt lên từ đáy khi vừa hiện (350 ms). Chỉ trượt vào; khi ẩn
/// thì widget bị gỡ khỏi cây (không trượt ra).
class _SlideUpBanner extends StatelessWidget {
  const _SlideUpBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: const Offset(0, 1), end: Offset.zero),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, offset, child) =>
          FractionalTranslation(translation: offset, child: child),
      child: child,
    );
  }
}

/// Băng phản hồi đúng (mẫu đã chốt với chủ dự án, PLAN điểm (m)): bo
/// tròn, nền xanh nhạt, viền xanh dày 3, bóng dưới, dấu tích tròn bên
/// trái, số xu trong ô vàng có hình đồng xu, kèm nút Tiếp. Đúng liền
/// 3 câu thì thêm dòng "N câu liền!".
class _CorrectBanner extends StatelessWidget {
  const _CorrectBanner({required this.session});

  final StageSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('math-correct'),
      decoration: BoxDecoration(
        color: MathColors.bannerGreenBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MathColors.bannerGreenBorder, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: MathColors.bannerGreenBorder,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              '✓',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đúng rồi!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: MathColors.bannerGreenText,
                  ),
                ),
                if (session.consecutiveCorrect >= 3)
                  Text(
                    '★ ${session.consecutiveCorrect} câu liền!',
                    key: const Key('math-streak'),
                    style: const TextStyle(
                      fontSize: 16,
                      color: MathColors.bannerGreenText,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: MathColors.coinYellow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _CoinIcon(size: 22),
                const SizedBox(width: 6),
                Text(
                  '+${session.lastEarnedXu ?? 0} xu',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: MathColors.questionText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Nút Tiếp tối đa 180 dp: nhãn "Xem kết quả" dài, ở màn hẹp
          // (640x320) nút phình ra sẽ bóp cột chữ "Đúng rồi!" về 0
          // rồi tràn ngang; nhãn thu nhỏ bằng FittedBox khi cần
          // (trên máy thật chữ Nunito ~130 px nên không bị thu).
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                key: const Key('math-next-button'),
                onPressed: () => session.next(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: MathColors.bannerGreenText,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    session.isLastQuestion ? 'Xem kết quả' : 'Tiếp',
                    softWrap: false,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vỏ chung cho băng gợi ý / lời giải ở đáy cột trái: cùng kiểu với
/// băng đúng (bo tròn, viền dày 3, bóng dưới) nhưng hẹp trong cột
/// trái; cao tối đa [maxHeight], nội dung dài thì cuộn trong băng,
/// băng luôn hiện (review PR #13).
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.bannerKey,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconGlyph,
    required this.header,
    required this.headerColor,
    required this.maxHeight,
    required this.child,
  });

  final Key bannerKey;
  final Color backgroundColor;
  final Color borderColor;
  final String iconGlyph;
  final String header;
  final Color headerColor;
  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: bannerKey,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: borderColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    iconGlyph,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    header,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: headerColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// Băng gợi ý sau sai lần đầu: màu cam nhạt, không có nút Tiếp
/// (bé làm lại ngay). Nội dung gợi ý song ngữ nằm trong băng
/// (key `math-hint` giữ nguyên cho integration test).
class _HintBanner extends StatelessWidget {
  const _HintBanner({required this.question, required this.maxHeight});

  final ResolvedQuestion question;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return _InfoBanner(
      bannerKey: const Key('math-hint-banner'),
      backgroundColor: MathColors.bannerOrangeBg,
      borderColor: MathColors.bannerOrangeBorder,
      iconGlyph: '?',
      header: 'Gần đúng rồi, xem gợi ý nhé',
      headerColor: MathColors.bannerOrangeText,
      maxHeight: maxHeight,
      child: Container(
        key: const Key('math-hint'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              question.question.hintVi,
              style: const TextStyle(
                fontSize: 18,
                color: MathColors.questionText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              question.question.hintEn,
              style: const TextStyle(
                fontSize: 14,
                color: MathColors.englishText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Băng lời giải sau sai hai lần: màu xanh dương nhạt (cùng tông với
/// hộp lời giải cũ ở T1-09). Nút Tiếp vẫn ở cột phải như trước.
/// Nội dung lời giải song ngữ nằm trong băng (key `math-solution`
/// giữ nguyên cho integration test).
class _SolutionBanner extends StatelessWidget {
  const _SolutionBanner({required this.question, required this.maxHeight});

  final ResolvedQuestion question;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return _InfoBanner(
      bannerKey: const Key('math-solution-banner'),
      backgroundColor: MathColors.bannerBlueBg,
      borderColor: MathColors.bannerBlueBorder,
      iconGlyph: 'i',
      header: 'Lời giải từng bước',
      headerColor: MathColors.bannerBlueText,
      maxHeight: maxHeight,
      child: Container(
        key: const Key('math-solution'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              question.question.explanationVi,
              style: const TextStyle(
                fontSize: 18,
                color: MathColors.questionText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              question.question.explanationEn,
              style: const TextStyle(
                fontSize: 14,
                color: MathColors.englishText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Đồng xu vẽ bằng hình khối (không dùng ký tự hay `Icon` để golden
/// test không bị ô vuông).
class _CoinIcon extends StatelessWidget {
  const _CoinIcon({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: MathColors.coinYellow,
        shape: BoxShape.circle,
        border: Border.all(
          color: MathColors.coinYellowDark,
          width: size * 0.12,
        ),
      ),
      child: Center(
        child: Container(
          width: size * 0.45,
          height: size * 0.45,
          decoration: BoxDecoration(
            color: MathColors.coinYellowDark.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Đồng xu bay từ băng phản hồi lên góc ví theo đường cong (600 ms).
class _CoinFly extends StatelessWidget {
  const _CoinFly({
    required this.controller,
    required this.start,
    required this.end,
  });

  final Animation<double> controller;
  final Offset start;
  final Offset end;

  Offset _quadBezier(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return Offset(
      u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
      u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        final control = Offset(
          (start.dx + end.dx) / 2,
          (start.dy + end.dy) / 2 - 90,
        );
        final pos = _quadBezier(start, control, end, t);
        return Stack(
          children: [
            Positioned(
              left: pos.dx - 14,
              top: pos.dy - 14,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 1 - 0.3 * t,
                  child: const _CoinIcon(size: 28, key: Key('math-coin-fly')),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Pet mèo nhỏ cạnh thanh tiến độ (48 dp): vui khi đúng, động viên
/// khi sai. Nằm trong luồng bố cục nên không che chữ nào (sửa sau
/// review PR #14 — trước đây pet 72 dp ở góc dưới-trái, đè dòng
/// tiếng Anh).
class _PetMascot extends StatelessWidget {
  const _PetMascot({required this.happy});

  final bool happy;

  @override
  Widget build(BuildContext context) {
    // Key theo tâm trạng để test phân biệt được pet vui/động viên
    // (chuỗi SVG không đọc được từ ngoài widget).
    return SvgPicture.string(
      happy ? petCatHappySvg : petCatEncouragingSvg,
      key: ValueKey(happy ? 'pet-happy' : 'pet-encouraging'),
      width: 48,
      height: 48,
    );
  }
}

/// Nút kiểu nổi (PLAN điểm (m)): viền dưới đậm, nhấn thì lún xuống
/// 4 dp (hiệu ứng 90 ms, không chặn thao tác).
class _RaisedButton extends StatefulWidget {
  const _RaisedButton({
    super.key,
    required this.height,
    required this.bottomColor,
    required this.backgroundColor,
    required this.enabled,
    required this.onPressed,
    required this.child,
  });

  final double height;
  final Color bottomColor;
  final Color? backgroundColor;
  final bool enabled;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  State<_RaisedButton> createState() => _RaisedButtonState();
}

class _RaisedButtonState extends State<_RaisedButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        if (widget.enabled) setState(() => _pressed = true);
      },
      onPointerUp: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      onPointerCancel: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      // Chiều cao ngoài CỐ ĐỊNH (không hoạt hình): khi nút thu nhỏ
      // theo trạng thái (64 -> 54 lúc đúng), AnimatedContainer cũ
      // thu chiều cao dần trong 90 ms nên hàng nút vẫn cao trong lúc
      // cột đã hẹp lại -> tràn 20 px ở 640x320. Chỉ padding mới
      // hoạt hình: nhấn thì nút lún xuống 3 px (trên 0->3, dưới
      // 4->1, tổng vẫn height+4).
      child: Container(
        height: widget.height + 4,
        decoration: BoxDecoration(
          color: widget.bottomColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 90),
          padding: EdgeInsets.only(
            top: _pressed ? 3 : 0,
            bottom: _pressed ? 1 : 4,
          ),
          child: SizedBox(
            height: widget.height,
            child: ElevatedButton(
              onPressed: widget.enabled ? widget.onPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.backgroundColor,
                // Nút bị vô hiệu sau khi trả lời đúng/sai hai lần nên
                // màu phải đặt ở cả hai chỗ, không thì nút nào cũng xám.
                // Nút đúng giữ xanh, nút sai giữ đỏ; nút thường (nền
                // null) dùng pastel rất nhạt thay cho màu nâu đất mặc
                // định của theme (review PR #14).
                disabledBackgroundColor:
                    widget.backgroundColor ?? MathColors.disabledButtonBg,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 4 nút lựa chọn lớn, xếp 2 cột. Nút đã chọn sai thì đỏ, đáp án đúng
/// thì xanh (chỉ khi đã trả lời đúng).
///
/// Chiều cao nút lấy từ cột phải ([buttonHeight], đã trừ nút "Tiếp"
/// nếu có, kẹp 48–64 dp) để cả khối vừa màn thấp 320 dp.
/// Đáp án hiện song ngữ khi VI khác EN (dạng `choiceOnly` có lựa chọn
/// là chữ song ngữ — dữ liệu đã có sẵn trong [ResolvedQuestion],
/// PLAN điểm (l) chỉ nói đề song ngữ chứ không cấm đáp án song ngữ);
/// đáp án là số thì VI và EN giống nhau nên chỉ hiện một dòng.
class _ChoiceAnswers extends StatelessWidget {
  const _ChoiceAnswers({
    required this.session,
    required this.question,
    required this.buttonHeight,
    required this.onCorrect,
    required this.onWrong,
  });

  final StageSession session;
  final ResolvedQuestion question;
  final double buttonHeight;

  /// Đúng: "ting" + xu; sai: "è" nhẹ (âm thanh phát nền, không await).
  final VoidCallback onCorrect;
  final VoidCallback onWrong;

  @override
  Widget build(BuildContext context) {
    final answering =
        session.state == QuestionState.answering ||
        session.state == QuestionState.hint;
    // Hai hàng, mỗi hàng hai nút.
    Widget choiceButton(int i) {
      final (bg, bottom) = _choiceColors(i);
      final vi = question.choiceTextsVi[i];
      final en = question.choiceTextsEn[i];
      final bilingual = en != vi;
      return Expanded(
        child: _RaisedButton(
          key: Key('choice-$i'),
          height: buttonHeight,
          bottomColor: bottom,
          backgroundColor: bg,
          enabled: answering,
          onPressed: () async {
            final correct = await session.submitChoice(i);
            if (correct) {
              onCorrect();
            } else {
              onWrong();
            }
          },
          // FittedBox scaleDown: đáp án là chữ dài ("Thứ Năm" ~130 px
          // ở 20sp) không được ngắt dòng trong nút hẹp 640x320 — thu
          // nhỏ lại thay vì tràn (nội dung song ngữ 46 px vừa nút
          // 54 px ở trạng thái đúng).
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: bilingual
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        vi,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 18,
                          color: MathColors.buttonNumber,
                        ),
                      ),
                      Text(
                        en,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 14,
                          color: MathColors.englishText,
                        ),
                      ),
                    ],
                  )
                : Text(
                    vi,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 24,
                      color: MathColors.buttonNumber,
                    ),
                  ),
          ),
        ),
      );
    }

    final rows = <Widget>[];
    for (var r = 0; r * 2 < question.choiceCount; r++) {
      final buttons = <Widget>[];
      for (var i = r * 2; i < r * 2 + 2 && i < question.choiceCount; i++) {
        if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 12));
        buttons.add(choiceButton(i));
      }
      rows.add(Row(children: buttons));
      if (r * 2 + 2 < question.choiceCount) {
        rows.add(const SizedBox(height: 12));
      }
    }
    // Chiều cao khối = 2 hàng nút + khe 12 dp; cột cha đã căn giữa
    // nên không cần căn lại ở đây.
    return Column(children: rows);
  }

  (Color?, Color) _choiceColors(int displayIndex) {
    if (session.state == QuestionState.correct &&
        displayIndex == question.correctDisplayIndex) {
      return (Colors.green.shade300, _raisedGreenBottom);
    }
    if (session.selectedDisplayIndex == displayIndex &&
        (session.state == QuestionState.hint ||
            session.state == QuestionState.solution)) {
      return (Colors.red.shade200, _raisedRedBottom);
    }
    return (null, _raisedPeachBottom);
  }
}

/// Bàn phím số riêng trong app: số đã gõ, các phím 0–9, xóa, gửi.
///
/// Chiều cao phím tính theo chỗ còn lại của cột phải ([availableHeight],
/// đã trừ nút "Tiếp" nếu có): ô số 56 + 4 hàng phím + khe 8 + viền
/// nổi 4 dp/hàng. Ở màn thấp 320 dp phím còn ~34 dp, ở màn 360 dp
/// ~44 dp, từ 800 dp trở lên đủ 64 dp. Phím nhỏ nhất 20 dp (chữ và
/// icon co theo bằng `FittedBox` trong [_PadKey]) để ở màn ~269 dp
/// (máy ảo CI) bàn phím vừa đúng, nút gửi vẫn bấm được; dưới nữa thì
/// cột phải cuộn (xem [_AnswerColumn]). Khi câu đã giải quyết xong
/// (đúng/lời giải) thì ẩn các hàng phím — bàn phím đã vô hiệu, chỉ giữ
/// ô số đã gõ để bé còn thấy đáp án của mình; nút "Tiếp" ở cột phải
/// lúc này mới có chỗ.
class _NumberPad extends StatelessWidget {
  const _NumberPad({
    required this.session,
    required this.onCorrect,
    required this.onWrong,
    required this.availableHeight,
  });

  final StageSession session;

  /// Đúng: "ting" + xu; sai: "è" nhẹ (âm thanh phát nền, không await).
  final VoidCallback onCorrect;
  final VoidCallback onWrong;

  /// Chiều cao còn lại của cột phải (đã trừ nút "Tiếp" nếu có).
  final double availableHeight;

  @override
  Widget build(BuildContext context) {
    final answering =
        session.state == QuestionState.answering ||
        session.state == QuestionState.hint;
    final resolved = !answering;
    // Phím nhỏ nhất 20 dp (chữ/icon co theo bằng `FittedBox` trong
    // [_PadKey]): ở màn ~269 dp (máy ảo CI) bàn phím vừa đúng
    // 189 dp nên không cần cuộn, nút gửi vẫn bấm được; dưới nữa
    // thì cột phải cuộn (xem [_AnswerColumn]).
    final keyHeight = ((availableHeight - 56 - 8 - 3 * 8 - 4 * 4) / 4).clamp(
      20.0,
      64.0,
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 56,
          width: double.infinity,
          child: Container(
            key: const Key('math-typed-answer'),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                session.typedAnswer.isEmpty ? '?' : session.typedAnswer,
                style: const TextStyle(
                  fontSize: 32,
                  color: MathColors.questionText,
                ),
              ),
            ),
          ),
        ),
        if (!resolved) ...[
          const SizedBox(height: 8),
          _PadRow(
            keyHeight: keyHeight,
            keys: [
              _PadKeySpec('1', answering, () => session.appendDigit('1')),
              _PadKeySpec('2', answering, () => session.appendDigit('2')),
              _PadKeySpec('3', answering, () => session.appendDigit('3')),
            ],
          ),
          const SizedBox(height: 8),
          _PadRow(
            keyHeight: keyHeight,
            keys: [
              _PadKeySpec('4', answering, () => session.appendDigit('4')),
              _PadKeySpec('5', answering, () => session.appendDigit('5')),
              _PadKeySpec('6', answering, () => session.appendDigit('6')),
            ],
          ),
          const SizedBox(height: 8),
          _PadRow(
            keyHeight: keyHeight,
            keys: [
              _PadKeySpec('7', answering, () => session.appendDigit('7')),
              _PadKeySpec('8', answering, () => session.appendDigit('8')),
              _PadKeySpec('9', answering, () => session.appendDigit('9')),
            ],
          ),
          const SizedBox(height: 8),
          _PadRow(
            keyHeight: keyHeight,
            keys: [
              // Phông Nunito không có ký tự ⌫ (PLAN điểm (m)): phím
              // xóa dùng Icons.backspace_outlined.
              _PadKeySpec.icon(
                Icons.backspace_outlined,
                answering && session.typedAnswer.isNotEmpty,
                session.deleteDigit,
                key: const Key('keypad-delete'),
              ),
              _PadKeySpec('0', answering, () => session.appendDigit('0')),
              _PadKeySpec(
                '✓',
                answering && session.typedAnswer.isNotEmpty,
                () async {
                  final correct = await session.submitNumber();
                  if (correct) {
                    onCorrect();
                  } else {
                    onWrong();
                  }
                },
                key: const Key('keypad-submit'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Một hàng 3 phím của bàn phím số.
class _PadRow extends StatelessWidget {
  const _PadRow({required this.keys, required this.keyHeight});

  final List<_PadKeySpec> keys;

  /// Chiều cao mỗi phím (tính theo chỗ còn lại, xem [_NumberPad]).
  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final spec in keys) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 10));
      children.add(
        Expanded(
          child: _PadKey(
            key: spec.key ?? Key('keypad-${spec.label}'),
            label: spec.label,
            icon: spec.icon,
            enabled: spec.enabled,
            onPressed: spec.onPressed,
            height: keyHeight,
          ),
        ),
      );
    }
    return Row(children: children);
  }
}

/// Mô tả một phím: nhãn (chữ) hoặc biểu tượng, có bấm được không,
/// bấm thì làm gì.
class _PadKeySpec {
  const _PadKeySpec(this.label, this.enabled, this.onPressed, {this.key})
    : icon = null;

  const _PadKeySpec.icon(this.icon, this.enabled, this.onPressed, {this.key})
    : label = '';

  final String label;
  final IconData? icon;
  final bool enabled;
  final VoidCallback onPressed;
  final Key? key;
}

/// Một phím của bàn phím số (chiều cao theo chỗ còn lại, tối đa 64 dp;
/// ở màn 1280x720 vẫn là 64x64 như trước).
class _PadKey extends StatelessWidget {
  const _PadKey({
    super.key,
    required this.label,
    this.icon,
    required this.enabled,
    required this.onPressed,
    required this.height,
  });

  final String label;
  final IconData? icon;
  final bool enabled;
  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return _RaisedButton(
      height: height,
      bottomColor: _raisedPeachBottom,
      backgroundColor: null,
      enabled: enabled,
      onPressed: onPressed,
      // Chữ/icon co lại khi phím thấp (màn thấp): `FittedBox` chỉ
      // thu nhỏ, không phóng to, nên ở cỡ thiết kế không đổi gì.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: icon != null
            ? Icon(icon, size: 28, color: MathColors.buttonNumber)
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 26,
                  color: MathColors.buttonNumber,
                ),
              ),
      ),
    );
  }
}
