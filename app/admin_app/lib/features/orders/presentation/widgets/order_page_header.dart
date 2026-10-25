import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_export_button.dart';

class OrderPageHeader extends StatelessWidget {
  const OrderPageHeader({super.key, this.onExport, this.exporting});
  final VoidCallback? onExport;
  final ValueListenable<bool>? exporting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.orders,
          textAlign: TextAlign.right,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: const Color(0xFF22332D),
            fontSize: 23,
            fontWeight: FontWeight.w700,
            height: 1.5,
            letterSpacing: -0.4,
          ),
        ),
        Text(
          S.ordersDescription,
          textAlign: TextAlign.right,
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFF819087),
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 620
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerRight, child: title),
                if (onExport != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OrderExportButton(
                      onPressed: onExport,
                      exporting: exporting,
                    ),
                  ),
              ],
            )
          : Row(
              textDirection: TextDirection.ltr,
              children: [
                if (onExport != null)
                  OrderExportButton(onPressed: onExport, exporting: exporting),
                const Spacer(),
                title,
              ],
            ),
    );
  }
}
