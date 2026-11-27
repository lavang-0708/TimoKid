/// Giao diện hộp thư (T3-06): nút trên HUD Phòng có chấm đỏ, danh sách
/// thư, và thư có hiệu ứng mở quà.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/sync/sync_providers.dart';
import '../../core/widgets/game_ui.dart';
import 'mailbox_service.dart';

/// Nút hộp thư trên HUD; [showDot] vẽ chấm đỏ khi còn thư chưa mở.
class MailHudButton extends StatelessWidget {
  const MailHudButton({
    super.key,
    required this.onPressed,
    required this.showDot,
  });

  final VoidCallback onPressed;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GameRoundButton(
          icon: Icons.mail_rounded,
          size: 26,
          color: const Color(0xFF4FA3E0),
          tooltip: 'Hộp thư',
          onPressed: onPressed,
        ),
        if (showDot)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              key: const Key('mail-red-dot'),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Mở hộp thư của bé; xong (đóng) thì chạy tiếp để HUD tải lại số dư/chấm đỏ.
Future<void> showMailboxDialog(BuildContext context, String childId) =>
    showDialog<void>(
      context: context,
      builder: (_) => MailboxDialog(childId: childId),
    );

class MailboxDialog extends ConsumerStatefulWidget {
  const MailboxDialog({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<MailboxDialog> createState() => _MailboxDialogState();
}

class _MailboxDialogState extends ConsumerState<MailboxDialog> {
  List<Message>? _letters;

  MailboxService get _service => MailboxService(
    db: ref.read(databaseProvider),
    client: ref.read(neonClientProvider),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _service.list(widget.childId);
    if (mounted) setState(() => _letters = list);
  }

  Future<void> _open(Message m) async {
    await showDialog<void>(
      context: context,
      builder: (_) => MailLetterDialog(messageId: m.id),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final letters = _letters;
    return Dialog(
      key: const Key('mailbox-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Hộp thư',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: letters == null
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      )
                    : letters.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Chưa có thư nào.',
                          key: Key('mailbox-empty'),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final m in letters)
                            ListTile(
                              key: Key('mail-tile-${m.id}'),
                              dense: true,
                              leading: Icon(
                                m.openedAt == null
                                    ? Icons.mark_email_unread_rounded
                                    : Icons.drafts_rounded,
                                color: m.openedAt == null
                                    ? const Color(0xFFE53935)
                                    : Colors.grey,
                              ),
                              title: Text(
                                m.body,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: m.hasGift && m.claimedAt == null
                                  ? const Icon(
                                      Icons.card_giftcard_rounded,
                                      color: Color(0xFFF0A23B),
                                    )
                                  : null,
                              onTap: () => _open(m),
                            ),
                        ],
                      ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('mailbox-close'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Một lá thư: lời nhắn, và nếu có quà thì nút "Mở quà" với hiệu ứng mở.
class MailLetterDialog extends ConsumerStatefulWidget {
  const MailLetterDialog({super.key, required this.messageId});

  final String messageId;

  @override
  ConsumerState<MailLetterDialog> createState() => _MailLetterDialogState();
}

class _MailLetterDialogState extends ConsumerState<MailLetterDialog> {
  Message? _msg;
  bool _opening = false;
  ClaimResult? _result;
  String? _error;

  MailboxService get _service => MailboxService(
    db: ref.read(databaseProvider),
    client: ref.read(neonClientProvider),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = _service;
    await service.markRead(widget.messageId);
    final m = await service.get(widget.messageId);
    if (mounted) setState(() => _msg = m);
    // Gửi trạng thái "đã mở" lên server (không chờ, không ném lỗi).
    ref.read(syncControllerProvider.notifier).syncSoon();
  }

  Future<void> _openGift() async {
    setState(() {
      _opening = true;
      _error = null;
    });
    final r = await _service.claim(widget.messageId);
    if (!mounted) return;
    if (r.status == ClaimStatus.failed) {
      setState(() {
        _opening = false;
        _error = 'Chưa mở được quà. Kiểm tra mạng rồi thử lại nhé.';
      });
      return;
    }
    final m = await _service.get(widget.messageId);
    if (!mounted) return;
    setState(() {
      _opening = false;
      _result = r;
      _msg = m;
    });
    ref.read(syncControllerProvider.notifier).syncSoon();
  }

  @override
  Widget build(BuildContext context) {
    final m = _msg;
    return Dialog(
      key: const Key('mail-letter-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 340),
        child: m == null
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              m.body,
                              key: const Key('mail-letter-body'),
                              style: const TextStyle(fontSize: 18),
                            ),
                            if (m.hasGift) ...[
                              const SizedBox(height: 10),
                              _giftArea(m),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('mail-letter-close'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Đóng'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _giftArea(Message m) {
    final r = _result;
    if (r != null && r.status == ClaimStatus.claimed) {
      return _GiftReveal(result: r);
    }
    if (m.claimedAt != null) {
      return const Text(
        'Quà đã nhận rồi.',
        key: Key('mail-gift-claimed'),
        style: TextStyle(fontWeight: FontWeight.w700),
      );
    }
    return Column(
      children: [
        ElevatedButton.icon(
          key: const Key('mail-gift-open-button'),
          onPressed: _opening ? null : _openGift,
          icon: const Icon(Icons.card_giftcard_rounded),
          label: Text(_opening ? 'Đang mở...' : 'Mở quà'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _error!,
              key: const Key('mail-gift-error'),
              style: const TextStyle(color: Color(0xFFC62828)),
            ),
          ),
      ],
    );
  }
}

/// Hiệu ứng mở quà: hộp quà bật lên rồi lộ phần quà.
class _GiftReveal extends StatelessWidget {
  const _GiftReveal({required this.result});

  final ClaimResult result;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: const Key('mail-gift-reveal'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Transform.scale(
        scale: 0.4 + 0.6 * t,
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.celebration_rounded,
            size: 26,
            color: Color(0xFFF0A23B),
          ),
          if (result.xu > 0)
            Text(
              '+${result.xu} xu',
              key: const Key('mail-gift-xu'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          if (result.gems > 0)
            Text(
              '+${result.gems} kim cương',
              key: const Key('mail-gift-gem'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          if (result.itemId != null)
            const Text(
              'Một món đồ mới đã vào Tủ đồ!',
              key: Key('mail-gift-item'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}
