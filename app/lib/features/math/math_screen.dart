/// Màn làm toán (T1-09): bé làm một chặng 5 câu của đề ngày.
///
/// Đề hiện bằng tiếng Việt, chữ to; nút "EN" đổi sang đề tiếng Anh,
/// nút từ khóa mở bảng từ khóa song ngữ, hình vẽ hiện nếu câu có hình.
/// Trắc nghiệm: 4 nút lớn, thứ tự trộn ngẫu nhiên (xác định theo seed
/// của câu — xem [shuffledChoiceOrder]). Điền số: bàn phím số riêng
/// trong app, nút to, có nút xóa.
///
/// Bố cục 2 cột (sửa sau review PR #11): cột trái là đề, hình vẽ,
/// gợi ý hoặc lời giải — cuộn được; cột phải là 4 nút trắc nghiệm
/// hoặc ô số + bàn phím, cộng nút "Tiếp" — không cuộn. Bố cục xếp
/// dọc 1 cột cũ không vừa điện thoại ngang cao 360 dp (máy ảo
/// 640x320: nút choice-3 nằm ngoài màn hình).
///
/// Sai lần đầu hiện gợi ý và cho làm lại; sai lần hai hiện lời giải
/// từng bước và nút "Tiếp". Đúng thì có hiệu ứng (ngôi sao + số xu)
/// và âm thanh ngắn ([SystemSound], không cần asset), rồi nút "Tiếp".
/// Mỗi câu đã giải quyết ghi một dòng `attempts`, cập nhật bậc/thành
/// thạo, ghi sổ ôn tập và cộng xu (xem [StageSession]). Cuối chặng
/// chuyển sang màn Kết quả chặng.
///
/// Màn nhận một [StageSession] có sẵn (test dùng) hoặc tự tải đề ngày
/// hôm nay và làm chặng đầu tiên chưa xong (nút "Làm toán" ở Thị trấn
/// đi đường này). Chặng cụ thể chọn qua [MathScreenArgs].
library;

import 'package:flutter/services.dart';
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
  const MathScreen({super.key, this.session, this.args});

  static const String route = '/math';

  /// Phiên chặng có sẵn (test bơm trực tiếp). Bỏ trống: màn tự tải
  /// đề ngày hôm nay rồi dựng phiên.
  final StageSession? session;

  final MathScreenArgs? args;

  @override
  ConsumerState<MathScreen> createState() => _MathScreenState();
}

class _MathScreenState extends ConsumerState<MathScreen> {
  StageSession? _session;
  bool _loading = true;
  bool _allDone = false;
  String? _error;
  bool _showEnglish = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
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
      final session = StageSession(
        db: db,
        childId: childId,
        dailySetId: set.id,
        stageIndex: stageIndex,
        questions: questions,
      );
      session.addListener(_onSessionChanged);
      await session.markStageInProgress();
      if (!mounted) return;
      setState(() {
        _session = session;
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

  Future<void> _playCorrectSound() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Máy test không có kênh âm thanh hệ thống: bỏ qua, không làm
      // hỏng luồng làm bài.
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
    // Biểu tượng là ký tự chữ (←, EN/VI, Aa) thay vì `Icon` vì font
    // MaterialIcons không có trong môi trường test nên golden test sẽ
    // bị ô vuông; các ký tự này có trong font DejaVu dùng ở test và
    // trong Roboto trên máy thật.
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
            key: const Key('math-en-toggle'),
            icon: Text(
              _showEnglish ? 'VI' : 'EN',
              style: const TextStyle(fontSize: 22),
            ),
            tooltip: _showEnglish ? 'Tiếng Việt' : 'English',
            onPressed: () => setState(() => _showEnglish = !_showEnglish),
            style: IconButton.styleFrom(
              minimumSize: const Size(56, 56),
              iconSize: 30,
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
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cột trái: đề, hình vẽ, gợi ý/lời giải — cuộn được.
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Câu ${session.currentIndex + 1}/${session.resolved.length}',
                    key: const Key('math-progress'),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showEnglish
                        ? question.question.questionEn
                        : question.question.questionVi,
                    key: const Key('math-question-text'),
                    style: const TextStyle(fontSize: 28),
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
                      child: Text(
                        'Sai rồi, xem gợi ý rồi thử lại nhé!\n${_showEnglish ? question.question.hintEn : question.question.hintVi}',
                        style: const TextStyle(fontSize: 22),
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
                      child: Text(
                        'Lời giải:\n${_showEnglish ? question.question.explanationEn : question.question.explanationVi}',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  if (session.state == QuestionState.correct)
                    Container(
                      key: const Key('math-correct'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '★',
                            style: TextStyle(fontSize: 36, color: Colors.amber),
                          ),
                          const SizedBox(width: 8),
                          // Chữ phải bọc Expanded để xuống dòng khi cột
                          // trái hẹp (640x320): không bọc thì Row tràn
                          // ngang vì chữ ở fontSize 26 dài hơn chỗ còn.
                          Expanded(
                            child: Text(
                              'Đúng rồi! +${session.lastEarnedXu ?? 0} xu',
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Cột phải: đáp án + nút "Tiếp" — không cuộn, phải vừa cả
          // ở màn thấp 320 dp nên chiều cao phím số tính theo chỗ còn
          // lại (xem [_NumberPad]).
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showNext =
                      session.state == QuestionState.correct ||
                      session.state == QuestionState.solution;
                  final nextSpace = showNext ? 56.0 + 12 : 0.0;
                  final available = constraints.maxHeight - nextSpace;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: question.displayType == AnswerType.choice
                            ? _ChoiceAnswers(
                                session: session,
                                question: question,
                                showEnglish: _showEnglish,
                                onCorrect: _playCorrectSound,
                              )
                            : _NumberPad(
                                session: session,
                                onCorrect: _playCorrectSound,
                                availableHeight: available,
                              ),
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
class _ChoiceAnswers extends StatelessWidget {
  const _ChoiceAnswers({
    required this.session,
    required this.question,
    required this.showEnglish,
    required this.onCorrect,
  });

  final StageSession session;
  final ResolvedQuestion question;
  final bool showEnglish;
  final Future<void> Function() onCorrect;

  @override
  Widget build(BuildContext context) {
    final answering =
        session.state == QuestionState.answering ||
        session.state == QuestionState.hint;
    // Hai hàng, mỗi hàng hai nút: chiều cao cố định để cả màn vừa
    // khung ngang 1280x720 mà không phải cuộn.
    Widget choiceButton(int i) {
      return Expanded(
        child: SizedBox(
          height: 64,
          child: ElevatedButton(
            key: Key('choice-$i'),
            onPressed: answering
                ? () async {
                    final correct = await session.submitChoice(i);
                    if (correct) await onCorrect();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _choiceColor(i),
              // Nút bị vô hiệu sau khi trả lời đúng/sai hai lần nên màu
              // phải đặt ở cả hai chỗ, không thì nút nào cũng xám.
              disabledBackgroundColor: _choiceColor(i),
            ),
            child: Text(
              showEnglish
                  ? question.choiceTextsEn[i]
                  : question.choiceTextsVi[i],
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
    // Căn giữa dọc trong cột phải: 2 hàng nút cao 64 vừa cả ở màn
    // thấp 320 dp (cột phải còn ~240 dp sau lề), chỗ thừa để trống.
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: rows);
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
    required this.availableHeight,
  });

  final StageSession session;
  final Future<void> Function() onCorrect;

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
              _PadKeySpec(
                'Xóa',
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
                  if (correct) await onCorrect();
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

/// Mô tả một phím: nhãn, có bấm được không, bấm thì làm gì.
class _PadKeySpec {
  const _PadKeySpec(this.label, this.enabled, this.onPressed, {this.key});

  final String label;
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
    required this.enabled,
    required this.onPressed,
    required this.height,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        child: Text(label, style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}
