/// Màn làm toán (T1-09): bé làm một chặng 5 câu của đề ngày.
///
/// Đề luôn hiện song ngữ (PLAN điểm (l)): tiếng Việt chữ to trên,
/// tiếng Anh nhỏ hơn + nhạt hơn dưới; gợi ý và lời giải cũng song ngữ.
/// Nút từ khóa mở bảng từ khóa song ngữ, hình vẽ hiện nếu câu có hình.
/// Trắc nghiệm: 4 nút lớn, thứ tự trộn ngẫu nhiên (xác định theo seed
/// của câu — xem [shuffledChoiceOrder]). Điền số: bàn phím số riêng
/// trong app, nút to, có nút xóa.
///
/// Bố cục 2 cột (sửa sau review PR #11, cân lại ở T1-12 theo điểm
/// (l)): cột trái là đề, hình vẽ, gợi ý hoặc lời giải — cuộn được,
/// khối đề căn giữa dọc; cột phải là 4 nút trắc nghiệm hoặc ô số +
/// bàn phím, cộng nút "Tiếp" — không cuộn, cả khối căn giữa dọc. Bố
/// cục xếp dọc 1 cột cũ không vừa điện thoại ngang cao 360 dp (máy
/// ảo 640x320: nút choice-3 nằm ngoài màn hình).
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class _MathScreenState extends ConsumerState<MathScreen> {
  StageSession? _session;
  SoundService? _soundService;
  bool _loading = true;
  bool _allDone = false;
  String? _error;
  bool _navigated = false;

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
    _session?.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() {});
    final session = _session;
    if (session != null && session.finished && !_navigated) {
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
        // chung DB để đọc `sound_enabled`.
        _soundService ??= SoundService(db: db);
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
    final strandName =
        strandNames[question.spec.strand] ?? question.spec.strand;
    final title = session.stageIndex >= 0
        ? 'Chặng ${session.stageIndex + 1} — $strandName'
        : 'Chặng tự chọn — $strandName';
    // Các nút trên thanh tiêu đề là nút biểu tượng, tối thiểu 56x56 dp.
    // Biểu tượng là ký tự chữ (←, Aa) thay vì `Icon` vì font
    // MaterialIcons không có trong môi trường test nên golden test sẽ
    // bị ô vuông; các ký tự này có trong font DejaVu dùng ở test và
    // trong Roboto trên máy thật.
    // Nút đổi EN đã bỏ (PLAN điểm (l)): đề luôn hiện song ngữ cùng lúc.
    return Scaffold(
      key: const Key('math-screen'),
      appBar: AppBar(
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
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cột trái: đề, hình vẽ, gợi ý/lời giải — cuộn được, khối đề
          // căn giữa dọc khi vừa màn (PLAN điểm (l)): đề dài thì cuộn,
          // đề ngắn thì khối đề nằm giữa vùng dưới thanh trên, không
          // dính góc trên trái. Banner "Đúng rồi! +N xu" ở cột phải
          // (không cuộn) nên không có ở đây.
          Expanded(
            flex: 6,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 24,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Câu ${session.currentIndex + 1}/${session.resolved.length}',
                          key: const Key('math-progress'),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 8),
                        // Đề luôn song ngữ (PLAN điểm (l)): tiếng Việt
                        // chữ to trên, tiếng Anh nhỏ hơn + nhạt hơn dưới.
                        Text(
                          question.question.questionVi,
                          key: const Key('math-question-text'),
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          question.question.questionEn,
                          key: const Key('math-question-text-en'),
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.black54,
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
                        const SizedBox(height: 12),
                        if (session.state == QuestionState.hint)
                          Container(
                            key: const Key('math-hint'),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Sai rồi, xem gợi ý rồi thử lại nhé!\n${question.question.hintVi}',
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  question.question.hintEn,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (session.state == QuestionState.solution)
                          Container(
                            key: const Key('math-solution'),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Lời giải:\n${question.question.explanationVi}',
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  question.question.explanationEn,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.black54,
                                  ),
                                ),
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
          // Cột phải: đáp án + nút "Tiếp" — không cuộn. Cả khối
          // (banner "Đúng rồi" + đáp án + nút Tiếp) căn giữa dọc
          // trong vùng dưới thanh trên (PLAN điểm (l)), không để đáp
          // án lệch xuống góc dưới phải; nút Tiếp nằm ngay dưới đáp án
          // chứ không dính đáy. Đề song ngữ dài hơn nên ở màn thấp
          // 320 dp chiều cao nút trắc nghiệm tính theo chỗ còn lại
          // (kẹp 48–64 dp), phím số theo [_NumberPad].
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCorrect = session.state == QuestionState.correct;
                  final showNext =
                      isCorrect || session.state == QuestionState.solution;
                  final bannerSpace = isCorrect ? 48.0 + 8 : 0.0;
                  final nextSpace = showNext ? 56.0 + 12 : 0.0;
                  final available =
                      constraints.maxHeight - bannerSpace - nextSpace;
                  // 2 hàng nút trắc nghiệm + khoảng cách 12 dp.
                  final choiceHeight = ((available - 12) / 2).clamp(48.0, 64.0);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isCorrect) ...[
                        Container(
                          key: const Key('math-correct'),
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '★ Đúng rồi! +${session.lastEarnedXu ?? 0} xu',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      question.displayType == AnswerType.choice
                          ? _ChoiceAnswers(
                              session: session,
                              question: question,
                              buttonHeight: choiceHeight,
                              onCorrect: () => _soundService?.playCorrect(),
                              onWrong: () => _soundService?.playWrong(),
                            )
                          : _NumberPad(
                              session: session,
                              onCorrect: () => _soundService?.playCorrect(),
                              onWrong: () => _soundService?.playWrong(),
                              availableHeight: available,
                            ),
                      if (showNext) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            key: const Key('math-next-button'),
                            onPressed: () => session.next(),
                            child: Text(
                              session.isLastQuestion ? 'Xem kết quả' : 'Tiếp',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
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

/// 4 nút lựa chọn lớn, xếp 2 cột. Nút đã chọn sai thì đỏ, đáp án đúng
/// thì xanh (chỉ khi đã trả lời đúng).
///
/// Chiều cao nút lấy từ cột phải ([buttonHeight], đã trừ banner và nút
/// "Tiếp" nếu có, kẹp 48–64 dp) để cả khối vừa màn thấp 320 dp.
/// Đáp án luôn tiếng Việt (PLAN điểm (l) bỏ nút đổi EN; đề, gợi ý và
/// lời giải đã song ngữ, còn đáp án trắc nghiệm là số hoặc từ ngắn
/// nên chỉ hiện tiếng Việt).
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
      return Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: ElevatedButton(
            key: Key('choice-$i'),
            onPressed: answering
                ? () async {
                    final correct = await session.submitChoice(i);
                    if (correct) {
                      onCorrect();
                    } else {
                      onWrong();
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _choiceColor(i),
              // Nút bị vô hiệu sau khi trả lời đúng/sai hai lần nên màu
              // phải đặt ở cả hai chỗ, không thì nút nào cũng xám.
              disabledBackgroundColor: _choiceColor(i),
            ),
            child: Text(
              question.choiceTextsVi[i],
              style: const TextStyle(fontSize: 24),
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

  Color? _choiceColor(int displayIndex) {
    if (session.state == QuestionState.correct &&
        displayIndex == question.correctDisplayIndex) {
      return Colors.green.shade300;
    }
    if (session.selectedDisplayIndex == displayIndex &&
        (session.state == QuestionState.hint ||
            session.state == QuestionState.solution)) {
      return Colors.red.shade200;
    }
    return null;
  }
}

/// Bàn phím số riêng trong app: số đã gõ, các phím 0–9, xóa, gửi.
///
/// Chiều cao phím tính theo chỗ còn lại của cột phải ([availableHeight],
/// đã trừ nút "Tiếp" nếu có): ô số 56 + 4 hàng phím + khe 8. Ở màn
/// thấp 320 dp phím còn ~38 dp, ở màn 360 dp ~48 dp, từ 800 dp trở lên
/// đủ 64 dp. Cột phải không cuộn nên phím không được cố định 64 dp.
/// Khi câu đã giải quyết xong (đúng/lời giải) thì ẩn các hàng phím —
/// bàn phím đã vô hiệu, chỉ giữ ô số đã gõ để bé còn thấy đáp án
/// của mình; nút "Tiếp" ở cột phải lúc này mới có chỗ.
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
    final keyHeight = ((availableHeight - 56 - 8 - 3 * 8) / 4).clamp(
      36.0,
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
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                session.typedAnswer.isEmpty ? '?' : session.typedAnswer,
                style: const TextStyle(fontSize: 32),
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
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        child: icon != null
            ? Icon(icon, size: 28)
            : Text(label, style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}
