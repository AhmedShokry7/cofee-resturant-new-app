import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:admin_app/core/locale/app_strings.dart';

class OrderExportButton extends StatelessWidget {
  const OrderExportButton({
    super.key,
    required this.onPressed,
    required this.exporting,
  });
  final VoidCallback? onPressed;
  final ValueListenable<bool>? exporting;

  @override
  Widget build(BuildContext context) {
    final listenable = exporting;
    if (listenable == null) return _button(context, false);
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, busy, _) => _button(context, busy),
    );
  }

  Widget _button(BuildContext context, bool busy) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: busy ? null : onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE3E9E4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              busy ? S.ordersExporting : S.ordersExportExcel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF52635A),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(width: 9),
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const HugeIcon(
                icon: HugeIcons.strokeRoundedDownload02,
                size: 16,
                color: Color(0xFF52635A),
              ),
          ],
        ),
      ),
    ),
  );
}
