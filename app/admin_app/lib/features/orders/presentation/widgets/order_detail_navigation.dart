import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';

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
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColor.greyColor),
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
  ) => OutlinedButton.icon(
    onPressed: order == null ? null : () => onSelect(order.id),
    icon: HugeIcon(icon: icon, size: 16, color: AppColor.greyColor),
    label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}
