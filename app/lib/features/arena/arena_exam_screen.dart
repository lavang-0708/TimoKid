/// Màn thi Đấu trường (T2-10) — route `/arena/exam`.
///
/// Toàn màn hình kiểu game như màn làm toán: đề song ngữ + hình (nếu
/// có) bên trái, đáp án bên phải (4 nút trắc nghiệm cho dạng
/// `choiceOnly`, còn lại bàn phím số điền đáp án), nút nổi
/// [RaisedAnswerButton] dùng lại của màn toán.
///
/// Đầu màn: "Phần 2/5 · Số học", "Câu 7/25", đồng hồ đếm ngược 90:00
/// và nút "Nộp bài". Dải 25 chấm là bản đồ câu hỏi: chấm đặc là đã
/// trả lời, bấm chấm để nhảy tới câu đó; có nút Câu trước/Câu sau.
/// TUYỆT ĐỐI không báo đúng sai, không gợi ý, không lời giải (yêu cầu
/// của chủ dự án); đáp án sửa được tới khi nộp.
///
/// Nộp bài: hộp xác nhận nói còn bao nhiêu câu chưa trả lời. Hết giờ
/// thì tự nộp. Rời giữa chừng (nút Trở về hoặc nút Back của máy) hỏi
/// "Bỏ thi?"; đồng ý thì BỎ bài: không lưu, không tính, không thưởng
/// (chọn cách này thay vì tự nộp để bé không lỡ tay mất điểm thấp mà
/// vẫn bị tính một lượt). Tắt app giữa chừng cũng mất bài như vậy
/// (đề không lưu giữa chừng, bản 0.2).
///
/// Đồng hồ tính từ `Clock` của database (mốc bắt đầu trừ giờ hiện
/// tại) nên chạy đúng cả khi app bị tạm dừng; test chỉ cần `advance`
/// đồng hồ giả rồi `pump`. Giống các hiệu ứng lặp khác, số giây chỉ
/// được vẽ lại mỗi giây khi [AnimationGate] bật (máy thật); khi tắt
/// (test) đồng hồ vẫn kiểm hết giờ mỗi giây nhưng không ép vẽ lại,
/// để `pumpAndSettle` dừng được.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/animation/animation_gate.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/widgets/round_back_button.dart';
import '../ladder/ladder_service.dart';
import '../math/math_decor.dart';
import '../math/math_screen.dart';
import '../questions/figure_svg.dart';
import '../questions/question.dart';
import 'arena_config.dart';
import 'arena_exam.dart';
import 'arena_lobby_screen.dart';
import 'arena_result_screen.dart';
import 'arena_service.dart';
import 'arena_session.dart';
import 'arena_widgets.dart';

class ArenaExamScreen extends ConsumerStatefulWidget {
  const ArenaExamScreen({super.key, this.session});

  static const String route = '/arena/exam';

  /// Phiên dựng sẵn (test dùng); bỏ trống thì màn tự dựng đề mới
  /// theo bậc hiện tại của bé.
  final ArenaSession? session;

  @override
  ConsumerState<ArenaExamScreen> createState() => _ArenaExamScreenState();
}

class _ArenaExamScreenState extends ConsumerState<ArenaExamScreen> {
  ArenaSession? _session;
  String? _error;
  String _childId = '';
  late DateTime _startedAt;
  Timer? _timer;
  bool _finishing = false;

  AppDatabase get _db => ref.read(databaseProvider);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _session?.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final db = _db;
      _childId = await db.ensureSeeded();
      var session = widget.session;
      if (session == null) {
        final rungs = await LadderService(
          attemptsDao: db.attemptsDao,
          skillProgressDao: db.skillProgressDao,
        ).rungsFor(childId: _childId);
        session = ArenaSession(
          questions: buildArenaExam(rungs: rungs, random: Random()),
        );
      }
      if (!mounted) return;
      session.addListener(_onChanged);
      _startedAt = db.clock.now();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      setState(() => _session = session);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Duration get _elapsed => _db.clock.now().difference(_startedAt);

  Duration get _remaining {
    final session = _session;
    final total = (session?.format ?? ArenaFormat.heat).duration;
    final left = total - _elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  void _tick() {
    if (!mounted || _finishing) return;
    if (_remaining == Duration.zero) {
      unawaited(_submit());
      return;
    }
    // Số giây chỉ ép vẽ lại khi cổng hiệu ứng bật (xem đầu file).
    if (AnimationGate.enabled) setState(() {});
  }

  /// Nộp bài thật sự (đã xác nhận hoặc hết giờ): chấm, lưu, thưởng,
  /// sang màn Kết quả.
  Future<void> _submit() async {
    final session = _session;
    if (session == null || _finishing) return;
    _finishing = true;
    _timer?.cancel();
    try {
      final elapsed = _elapsed;
      final capped = elapsed > session.format.duration
          ? session.format.duration
          : elapsed;
      final result = await ArenaService(db: _db).submit(
        childId: _childId,
        score: session.score(),
        duration: capped,
        format: session.format,
      );
      if (!mounted) return;
      context.go(ArenaResultScreen.route, extra: result);
    } catch (e) {
      if (!mounted) return;
      // Lưu lỗi: cho bé nộp lại, đồng hồ chạy tiếp.
      _finishing = false;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa nộp được bài, bé thử lại nhé')),
      );
    }
  }

  Future<void> _confirmSubmit() async {
    final session = _session;
    if (session == null || _finishing) return;
    final left = session.unansweredCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('arena-submit-dialog'),
        title: const Text('Nộp bài?'),
        content: Text(
          left == 0
              ? 'Bé đã trả lời hết ${session.total} câu. Nộp bài nhé?'
              : 'Bé còn $left câu chưa trả lời. Nộp bài bây giờ nhé?',
          key: const Key('arena-submit-dialog-text'),
        ),
        actions: [
          TextButton(
            key: const Key('arena-submit-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Làm tiếp'),
          ),
          TextButton(
            key: const Key('arena-submit-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Nộp bài'),
          ),
        ],
      ),
    );
    if (ok == true) await _submit();
  }

  Future<void> _confirmExit() async {
    if (_finishing) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('arena-exit-dialog'),
        title: const Text('Bỏ thi?'),
        content: const Text('Bài sẽ không được tính.'),
        actions: [
          TextButton(
            key: const Key('arena-exit-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Thi tiếp'),
          ),
          TextButton(
            key: const Key('arena-exit-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Bỏ thi'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _finishing = true;
    _timer?.cancel();
    context.go(ArenaLobbyScreen.route);
  }

  static String _mmss(Duration d) {
    final seconds = (d.inMilliseconds + 999) ~/ 1000;
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (_error != null) {
      return Scaffold(
        key: const Key('arena-exam-screen'),
        body: Center(child: Text('Không dựng được đề thi: $_error')),
      );
    }
    if (session == null) {
      return const Scaffold(
        key: Key('arena-exam-screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final index = session.currentIndex;
    final sectionIndex = session.sectionOf(index);
    final section = arenaSections[sectionIndex];
    final remaining = _remaining;
    final lowTime = remaining < const Duration(minutes: 5);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmExit());
      },
      child: Scaffold(
        key: const Key('arena-exam-screen'),
        backgroundColor: MathColors.strandBackground(section.strand),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    RoundBackButton(
                      key: const Key('arena-back-button'),
                      size: 36,
                      tooltip: 'Bỏ thi',
                      onPressed: _confirmExit,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Phần ${sectionIndex + 1}/${session.format.sections}'
                          ' · ${section.name}',
                          key: const Key('arena-section-title'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: MathColors.questionText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Câu ${index + 1}/${session.total}',
                      key: const Key('arena-question-number'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: MathColors.questionText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: lowTime
                            ? const Color(0xFFFFD9D6)
                            : Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_rounded,
                            size: 16,
                            color: lowTime
                                ? const Color(0xFFC62828)
                                : MathColors.questionText,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _mmss(remaining),
                            key: const Key('arena-timer'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: lowTime
                                  ? const Color(0xFFC62828)
                                  : MathColors.questionText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 92,
                      child: ArenaCandyButton(
                        key: const Key('arena-submit-button'),
                        text: 'Nộp bài',
                        color: const Color(0xFFF08A3C),
                        height: 32,
                        fontSize: 15,
                        onPressed: _confirmSubmit,
                      ),
                    ),
                  ],
                ),
              ),
              _Navigator(session: session),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 6, child: _QuestionPanel(session: session)),
                    Expanded(flex: 5, child: _AnswerPanel(session: session)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dải 25 chấm: đặc là đã trả lời, viền đậm là câu đang làm; mỗi 5
/// chấm (một phần) cách nhau một khe nhỏ.
class _Navigator extends StatelessWidget {
  const _Navigator({required this.session});

  final ArenaSession session;

  @override
  Widget build(BuildContext context) {
    final per = session.format.questionsPerSection;
    return Padding(
      key: const Key('arena-navigator'),
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
      child: SizedBox(
        height: 30,
        child: Row(
          children: [
            for (var i = 0; i < session.total; i++) ...[
              if (i > 0 && i % per == 0) const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  key: Key('arena-dot-$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => session.goTo(i),
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final d = min(24.0, min(c.maxWidth - 2, 28.0));
                        final answered = session.isAnswered(i);
                        final current = i == session.currentIndex;
                        return Container(
                          key: Key(
                            'arena-dot-$i-${answered ? 'done' : 'todo'}',
                          ),
                          width: d,
                          height: d,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: answered
                                ? MathColors.progressCurrent
                                : Colors.white,
                            border: Border.all(
                              color: current
                                  ? const Color(0xFFF08A3C)
                                  : MathColors.progressUpcomingBorder,
                              width: current ? 3 : 1.5,
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.all(1),
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: answered
                                      ? Colors.white
                                      : MathColors.questionText,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cột trái: thẻ đề (song ngữ + hình) và nút Câu trước/Câu sau.
class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({required this.session});

  final ArenaSession session;

  @override
  Widget build(BuildContext context) {
    final q = session.current.question;
    final tall = MediaQuery.sizeOf(context).height >= 500;
    final index = session.currentIndex;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              key: const Key('arena-question-card'),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        q.questionVi,
                        key: const Key('arena-question-text'),
                        style: TextStyle(
                          fontSize: tall ? 28 : 21,
                          color: MathColors.questionText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        q.questionEn,
                        key: const Key('arena-question-text-en'),
                        style: TextStyle(
                          fontSize: tall ? 20 : 15,
                          color: MathColors.englishText,
                        ),
                      ),
                      if (q.figure != null) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: FigureView(
                            key: const Key('arena-figure'),
                            figure: q.figure!,
                            width: tall ? 220 : 150,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ArenaCandyButton(
                  key: const Key('arena-prev-button'),
                  text: '‹ Câu trước',
                  color: const Color(0xFF5BA8F5),
                  height: 34,
                  fontSize: 15,
                  onPressed: index > 0 ? session.previous : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ArenaCandyButton(
                  key: const Key('arena-next-button'),
                  text: 'Câu sau ›',
                  color: const Color(0xFF5BA8F5),
                  height: 34,
                  fontSize: 15,
                  onPressed: index < session.total - 1 ? session.next : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cột phải: 4 nút trắc nghiệm (dạng choiceOnly) hoặc ô số + bàn phím.
/// Đáp án chọn được đổi lại, không có màu đúng/sai.
class _AnswerPanel extends StatelessWidget {
  const _AnswerPanel({required this.session});

  final ArenaSession session;

  @override
  Widget build(BuildContext context) {
    final q = session.current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 14, 8),
      child: LayoutBuilder(
        builder: (context, c) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  q.displayType == AnswerType.choice
                      ? _Choices(session: session, available: c.maxHeight)
                      : _Pad(session: session, available: c.maxHeight),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices({required this.session, required this.available});

  final ArenaSession session;
  final double available;

  @override
  Widget build(BuildContext context) {
    final q = session.current;
    final h = ((available - 12) / 2 - 4).clamp(44.0, 64.0);
    Widget button(int i) {
      final selected = session.selectedAt(session.currentIndex) == i;
      final vi = q.choiceTextsVi[i];
      final en = q.choiceTextsEn[i];
      return Expanded(
        child: RaisedAnswerButton(
          key: Key('choice-$i'),
          height: h,
          bottomColor: selected ? const Color(0xFF4B2E83) : raisedPeachBottom,
          backgroundColor: selected ? const Color(0xFFD9CCF5) : null,
          enabled: true,
          onPressed: () => session.selectChoice(i),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: en != vi
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
    for (var r = 0; r * 2 < q.choiceCount; r++) {
      rows.add(
        Row(
          children: [
            for (var i = r * 2; i < r * 2 + 2 && i < q.choiceCount; i++) ...[
              if (i > r * 2) const SizedBox(width: 12),
              button(i),
            ],
          ],
        ),
      );
      if (r * 2 + 2 < q.choiceCount) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }
}

class _Pad extends StatelessWidget {
  const _Pad({required this.session, required this.available});

  final ArenaSession session;
  final double available;

  @override
  Widget build(BuildContext context) {
    final typed = session.typedAt(session.currentIndex);
    final fieldHeight = available < 200 ? 36.0 : 56.0;
    final keyHeight = ((available - fieldHeight - 8 - 3 * 8 - 4 * 4) / 4).clamp(
      20.0,
      64.0,
    );
    Widget key(String label, VoidCallback? onTap, {Key? k, IconData? icon}) {
      return Expanded(
        child: RaisedAnswerButton(
          key: k ?? Key('keypad-$label'),
          height: keyHeight,
          bottomColor: raisedPeachBottom,
          backgroundColor: null,
          enabled: onTap != null,
          onPressed: onTap,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: icon != null
                ? Icon(icon, size: 26, color: MathColors.buttonNumber)
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 26,
                      color: MathColors.buttonNumber,
                    ),
                  ),
          ),
        ),
      );
    }

    Widget row(List<Widget> keys) => Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          keys[i],
        ],
      ],
    );

    Widget digit(String d) => key(d, () => session.appendDigit(d));
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: fieldHeight,
          width: double.infinity,
          child: Container(
            key: const Key('arena-typed-answer'),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                typed.isEmpty ? '?' : typed,
                style: TextStyle(
                  fontSize: fieldHeight < 40 ? 24 : 32,
                  color: MathColors.questionText,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        row([digit('1'), digit('2'), digit('3')]),
        const SizedBox(height: 8),
        row([digit('4'), digit('5'), digit('6')]),
        const SizedBox(height: 8),
        row([digit('7'), digit('8'), digit('9')]),
        const SizedBox(height: 8),
        row([
          key(
            '',
            typed.isEmpty ? null : session.deleteDigit,
            k: const Key('keypad-delete'),
            icon: Icons.backspace_outlined,
          ),
          digit('0'),
          key(
            '',
            typed.isEmpty ? null : session.clearAnswer,
            k: const Key('keypad-clear'),
            icon: Icons.delete_sweep_outlined,
          ),
        ]),
      ],
    );
  }
}
