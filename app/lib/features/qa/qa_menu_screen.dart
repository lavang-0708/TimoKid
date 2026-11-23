/// Màn menu QA ẩn (T1-13).
///
/// Chỉ mở được bằng cách nhấn giữ 5 giây ở góc trên-trái màn hình
/// (xem [QaMenuOpener]) và chỉ có trong bản debug / bản có cờ QA
/// (xem [QaConfig]). Màn này là công cụ kiểm tra cho Claude, không
/// phải màn cho bé: chữ nhỏ, nhiều chữ, không cần đẹp.
///
/// Chức năng (PLAN mục T1-13):
/// - Nhảy sang ngày hôm sau / về hôm nay (ngày ảo trong bộ nhớ).
/// - Đặt bậc từng mảng (1–6).
/// - Xem sổ ôn tập.
/// - Xem 20 lượt trả lời gần nhất.
/// - Xem thử một dạng bài bất kỳ ở bậc bất kỳ (chỉ sinh để xem,
///   không ghi gì vào database).
/// - Xóa dữ liệu (về trạng thái mới cài).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import '../arena/league_service.dart';
import '../ladder/ladder_config.dart';
import '../math/math_session.dart' show strandNames;
import '../questions/figure_svg.dart';
import '../questions/question.dart';
import '../questions/question_registry.dart';
import '../town/town_screen.dart';
import 'qa_service.dart';

/// Tên mức nội dung: 1 Dễ, 2 Vừa, 3 Khó.
const Map<int, String> _levelNames = {1: 'Dễ', 2: 'Vừa', 3: 'Khó'};

/// Màn menu QA. Nhận database qua constructor (mở từ [QaMenuOpener]
/// qua route `/qa`, hoặc bơm trực tiếp trong test).
class QaMenuScreen extends ConsumerStatefulWidget {
  const QaMenuScreen({super.key, required this.db});

  /// Route của menu QA trong [AppRouter].
  static const String route = '/qa';

  final AppDatabase db;

  @override
  ConsumerState<QaMenuScreen> createState() => _QaMenuScreenState();
}

class _QaMenuScreenState extends ConsumerState<QaMenuScreen> {
  late final QaService _service;
  String? _childId;
  Map<String, int> _rungs = {};
  List<ReviewQueueData> _reviewEntries = [];
  List<Attempt> _attempts = [];
  bool _loading = true;
  String _leagueText = '';

  // Xem thử dạng bài: dạng và mức đang chọn + câu đang xem.
  String _previewFormId = allQuestionGenerators.first.formId;
  int _previewLevel = 1;
  Question? _previewQuestion;

  @override
  void initState() {
    super.initState();
    _service = QaService(db: widget.db);
    _previewLevel = _supportedLevels(_previewFormId).first;
    _load();
  }

  List<int> _supportedLevels(String formId) {
    final generator = questionGeneratorFor(formId);
    final levels = (generator?.supportedLevels ?? {1}).toList()..sort();
    return levels;
  }

  Future<void> _load() async {
    final childId = await _service.ensureChildId();
    final rungs = await _service.rungs(childId: childId);
    final entries = await _service.reviewEntries(childId: childId);
    final attempts = await _service.recentAttempts(childId: childId);
    final league = LeagueService(db: widget.db);
    final week = await league.week(childId);
    final chest = await league.pendingChest(childId);
    final leagueText =
        'Tuần bắt đầu thứ Hai ${week.weekStart.substring(8)}/${week.weekStart.substring(5, 7)}: ${week.points} câu đúng, '
        '${week.attempts} ngày thi, hạng ${week.tier?.label ?? 'chưa có'}, '
        'còn ${week.daysLeft} ngày. '
        'Rương tuần trước: ${chest == null ? 'không có/đã nhận' : '${chest.tier.label} (${chest.gems} kim cương)'}';
    if (!mounted) return;
    setState(() {
      _leagueText = leagueText;
      _childId = childId;
      _rungs = rungs;
      _reviewEntries = entries;
      _attempts = attempts;
      _loading = false;
    });
  }

  String get _todayText => _service.today;

  String get _offsetText {
    final days = _service.dayOffset.inDays;
    if (days == 0) return 'đang ở ngày thật';
    return 'đang lệch +$days ngày so với ngày thật';
  }

  Future<void> _advanceDay() async {
    _service.advanceOneDay();
    await _load();
  }

  Future<void> _resetDay() async {
    _service.resetDay();
    await _load();
  }

  Future<void> _setRung(String strand, int rung) async {
    final childId = _childId;
    if (childId == null) return;
    await _service.setRung(childId: childId, strand: strand, rung: rung);
    await _load();
  }

  void _generatePreview() {
    setState(() {
      _previewQuestion = _service.previewQuestion(
        formId: _previewFormId,
        level: _previewLevel,
      );
    });
  }

  Future<void> _confirmClearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('qa-clear-confirm-dialog'),
        title: const Text('Xóa hết dữ liệu?'),
        content: const Text(
          'Xóa toàn bộ dữ liệu của bé: lượt trả lời, bậc từng mảng, '
          'sổ ôn tập, đề ngày, xu và kim cương. App về trạng thái mới '
          'cài (bé mặc định, bậc 1). Không khôi phục được.',
        ),
        actions: [
          TextButton(
            key: const Key('qa-clear-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            key: const Key('qa-clear-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Xóa hết dữ liệu',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _service.clearAllData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã xóa hết dữ liệu, về trạng thái mới cài.'),
      ),
    );
    // Về màn Thị trấn để tải lại trạng thái mới (tránh hiện số liệu cũ).
    context.go(TownScreen.route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('qa-menu'),
      appBar: AppBar(
        title: const Text('Menu QA (bản debug)'),
        leading: IconButton(
          key: const Key('qa-close-button'),
          icon: const Text('✕', style: TextStyle(fontSize: 22)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionTitle('Ngày QA'),
                  Text(
                    'Hôm nay (theo app): $_todayText — $_offsetText',
                    key: const Key('qa-today-text'),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        key: const Key('qa-advance-day'),
                        onPressed: _advanceDay,
                        child: const Text('Sang ngày mai (+1 ngày)'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        key: const Key('qa-reset-day'),
                        onPressed: _service.dayOffset == Duration.zero
                            ? null
                            : _resetDay,
                        child: const Text('Về hôm nay'),
                      ),
                    ],
                  ),
                  const Text(
                    'Nhảy ngày chỉ lệch trong bộ nhớ (tắt app là về ngày '
                    'thật). Đề ngày mới tạo khi mở Thị trấn ở ngày mới; '
                    'mục ôn tập đến hạn sẽ hiện trong đề.',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  _sectionTitle('Hạng đấu trường tuần'),
                  Text(
                    _leagueText,
                    key: const Key('qa-league-text'),
                    style: const TextStyle(fontSize: 14),
                  ),
                  _sectionTitle('Bậc từng mảng'),
                  ...Strand.all.map((strand) {
                    final rung = _rungs[strand] ?? LadderConfig.initialRung;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(
                              strandNames[strand] ?? strand,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          DropdownButton<int>(
                            key: Key('qa-rung-$strand'),
                            value: rung,
                            items: [
                              for (
                                var i = LadderConfig.minRung;
                                i <= LadderConfig.maxRung;
                                i++
                              )
                                DropdownMenuItem(value: i, child: Text('$i')),
                            ],
                            onChanged: (value) {
                              if (value != null) _setRung(strand, value);
                            },
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Đặt bậc thì cửa sổ 10 câu tính lại từ đầu.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  _sectionTitle('Sổ ôn tập'),
                  if (_reviewEntries.isEmpty)
                    const Text(
                      'Sổ trống.',
                      key: Key('qa-review-empty'),
                      style: TextStyle(fontSize: 16),
                    )
                  else
                    ..._reviewEntries.map((entry) {
                      final due = !entry.dueDate.isAfter(widget.db.clock.now());
                      return ListTile(
                        key: Key('qa-review-${entry.formId}'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${entry.formId} — bậc ${entry.rung}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        subtitle: Text(
                          'Chuỗi đúng: ${entry.correctStreak}/3 — '
                          'hỏi lại: ${_formatDate(entry.dueDate)}'
                          '${due ? ' — ĐẾN HẠN' : ''}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }),
                  _sectionTitle('20 lượt trả lời gần nhất'),
                  if (_attempts.isEmpty)
                    const Text(
                      'Chưa có lượt trả lời nào.',
                      key: Key('qa-attempts-empty'),
                      style: TextStyle(fontSize: 16),
                    )
                  else
                    ..._attempts.map((attempt) {
                      return ListTile(
                        key: Key('qa-attempt-${attempt.id}'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${attempt.formId} — mức ${attempt.level} '
                          '— bậc ${attempt.rung}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        subtitle: Text(
                          '${attempt.correctFirstTry ? 'Đúng ngay' : 'Chưa đúng ngay'}'
                          '${attempt.isReview ? ' — ôn tập' : ''} — '
                          '${_formatTime(attempt.createdAt)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }),
                  _sectionTitle('Xem thử dạng bài'),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          key: const Key('qa-preview-form'),
                          value: _previewFormId,
                          isExpanded: true,
                          items: [
                            for (final generator in allQuestionGenerators)
                              DropdownMenuItem(
                                value: generator.formId,
                                child: Text(generator.formId),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _previewFormId = value;
                              _previewLevel = _supportedLevels(value).first;
                              _previewQuestion = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        key: const Key('qa-preview-level'),
                        value: _previewLevel,
                        items: [
                          for (final level in _supportedLevels(_previewFormId))
                            DropdownMenuItem(
                              value: level,
                              child: Text(_levelNames[level] ?? '$level'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _previewLevel = value;
                            _previewQuestion = null;
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        key: const Key('qa-preview-generate'),
                        onPressed: _generatePreview,
                        child: const Text('Sinh câu'),
                      ),
                    ],
                  ),
                  const Text(
                    'Chỉ sinh để xem, không ghi lượt trả lời, không động '
                    'vào bậc/thành thạo/sổ ôn tập.',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  if (_previewQuestion != null) ...[
                    const SizedBox(height: 8),
                    _PreviewCard(question: _previewQuestion!),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        key: const Key('qa-preview-again'),
                        onPressed: _generatePreview,
                        child: const Text('Câu khác'),
                      ),
                    ),
                  ],
                  _sectionTitle('Xóa dữ liệu'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      key: const Key('qa-clear-data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _confirmClearData,
                      child: const Text('Xóa hết dữ liệu'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  static String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$h:$min ${_formatDate(time)}';
  }
}

/// Thẻ hiện một câu xem thử: đề song ngữ, hình (nếu có), lựa chọn
/// (đánh dấu đáp án đúng) hoặc đáp án số, gợi ý và lời giải.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('qa-preview-question'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question.questionVi, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              question.questionEn,
              style: const TextStyle(fontSize: 15, color: Colors.black54),
            ),
            if (question.figure != null) ...[
              const SizedBox(height: 8),
              FigureView(figure: question.figure!, width: 240),
            ],
            const SizedBox(height: 8),
            if (question.isChoice)
              ...question.choices.asMap().entries.map((entry) {
                final isCorrect = entry.key == question.answer;
                return Text(
                  '${isCorrect ? '✓ ' : ''}${entry.value.vi}'
                  ' (${entry.value.en})'
                  '${isCorrect ? ' — đáp án đúng' : ''}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              })
            else
              Text(
                'Đáp án: ${question.answer}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Gợi ý: ${question.hintVi} (${question.hintEn})',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Lời giải: ${question.explanationVi} '
              '(${question.explanationEn})',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
