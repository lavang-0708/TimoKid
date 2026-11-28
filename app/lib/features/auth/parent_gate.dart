/// Cổng phụ huynh (T3-03): bé lớp 2 dùng app nên các mục của bố/mẹ
/// (đăng nhập, đăng xuất, thêm bé) nằm sau một phép nhân ba chữ số mà bé
/// chưa làm được. Trả lời đúng mới vào.
library;

import 'dart:math';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Hiện cổng; trả true khi trả lời đúng.
Future<bool> showParentGate(BuildContext context, {Random? random}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => ParentGateDialog(random: random),
  );
  return ok ?? false;
}

class ParentGateDialog extends StatefulWidget {
  const ParentGateDialog({super.key, this.random});

  final Random? random;

  @override
  State<ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<ParentGateDialog> {
  late final int _a;
  late final int _b;
  final _controller = TextEditingController();
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    final r = widget.random ?? Random();
    // Hai số 13–29: tích có ba chữ số (169–841).
    _a = 13 + r.nextInt(17);
    _b = 13 + r.nextInt(17);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (int.tryParse(_controller.text.trim()) == _a * _b) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _wrong = true);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cả hộp cuộn được (màn thấp + bàn phím số mở).
    return Dialog(
      key: const Key('parent-gate'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dành cho bố/mẹ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '$_a × $_b = ?',
                key: const Key('parent-gate-question'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextField(
                key: const Key('parent-gate-input'),
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Nhập kết quả',
                  isDense: true,
                  errorText: _wrong ? 'Chưa đúng, thử lại nhé.' : null,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('parent-gate-cancel'),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Hủy'),
                  ),
                  ElevatedButton(
                    key: const Key('parent-gate-submit'),
                    onPressed: _submit,
                    child: const Text('Xác nhận'),
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
