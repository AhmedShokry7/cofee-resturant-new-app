import 'package:flutter/material.dart';
import 'package:admin_app/core/locale/app_strings.dart';

class QuantityDialog extends StatefulWidget {
  const QuantityDialog({super.key, this.initial = 1});
  final int initial;
  @override
  State<QuantityDialog> createState() => _OrderQuantityDialogState();
}

class _OrderQuantityDialogState extends State<QuantityDialog> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initial}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _accept() {
    final value = int.tryParse(_controller.text.trim());
    Navigator.of(context)
        .pop(value != null && value > 0 ? value : widget.initial);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(S.quantity),
    content: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      onSubmitted: (_) => _accept(),
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
