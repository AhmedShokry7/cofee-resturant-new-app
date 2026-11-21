import 'package:material_ui/material_ui.dart';

import 'package:admin_app/shared/widgets/currency_icon.dart';

/// Places a currency input beside its currency mark, outside the input border.
class CurrencyInputRow extends StatelessWidget {
  const CurrencyInputRow({
    super.key,
    required this.child,
    this.iconSize = 14,
    this.gap = 8,
  });

  final Widget child;
  final double iconSize;
  final double gap;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(child: child),
      SizedBox(width: gap),
      CurrencyIcon(size: iconSize),
    ],
  );
}
