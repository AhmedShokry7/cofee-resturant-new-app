import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/localized_digits.dart';

class QuantityDialog extends StatefulWidget {
  const QuantityDialog({super.key, this.initial = 1});
  final int initial;
  @override
  State<QuantityDialog> createState() => _OrderQuantityDialogState();
}

class _OrderQuantityDialogState extends State<QuantityDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: localizeDigits('${widget.initial}'));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// الكمية تُقرأ بالأرقام العربية مثل كل رقم في التطبيق؛ الرقم غير المقروء
  /// أو الصفري يُرفض في الحقل بدل أن يُستبدل بالافتراضي صمتًا.
  void _accept() {
    final value = int.tryParse(normalizeDigits(_controller.text.trim()));
    if (value == null || value <= 0) {
      setState(() => _error = S.needsPositiveQuantity);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(S.quantity),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]')),
          ],
          onSubmitted: (_) => _accept(),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(S.ordersCancel),
      ),
      FilledButton(onPressed: _accept, child: Text(S.ordersAdd)),
    ],
  );
}
