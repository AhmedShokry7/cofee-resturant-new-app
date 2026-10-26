import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class OrderDetailNavigation extends StatelessWidget {
  const OrderDetailNavigation({
    super.key,
    required this.orders,
    required this.orderId,
    required this.onSelect,
  });

  final List<AdminOrder> orders;
  final String orderId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...orders]
      ..sort(
        (a, b) =>
            (b.placedAt ?? DateTime(0)).compareTo(a.placedAt ?? DateTime(0)),
      );
    final index = sorted.indexWhere((order) => order.id == orderId);
    final older = index >= 0 && index + 1 < sorted.length
        ? sorted[index + 1]
        : null;
    final newer = index > 0 ? sorted[index - 1] : null;
    final current = index < 0 ? '' : '#${sorted[index].orderNumber}';
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _button(
          context,
          S.olderOrder,
          older,
          rtl
              ? HugeIcons.strokeRoundedArrowRight01
              : HugeIcons.strokeRoundedArrowLeft01,
        ),
        Text(
          current,
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size10,
            height: AppTextHeights.line1_5,
          ),
        ),
        _button(
          context,
          S.newerOrder,
          newer,
          rtl
              ? HugeIcons.strokeRoundedArrowLeft01
              : HugeIcons.strokeRoundedArrowRight01,
        ),
      ],
    );
  }

  Widget _button(
    BuildContext context,
    String label,
    AdminOrder? order,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: order == null ? null : () => onSelect(order.id),
      style: OutlinedButton.styleFrom(
        foregroundColor: adminBodyColor(theme),
        disabledForegroundColor: adminSubtleColor(theme),
        side: BorderSide(color: adminControlBorderColor(theme)),
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(
          fontSize: AppFontSizes.size10_5,
          fontWeight: AppFontWeights.medium,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      icon: HugeIcon(icon: icon, size: 14, color: adminMutedColor(theme)),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
