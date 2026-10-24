import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_edit_rules.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_section_card.dart';
import 'package:admin_app/shared/widgets/admin_feedback.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// The lines of one order, each with its picture, its price and a remove.
///
/// A line may only be removed when the order is still editable and the
/// backend returned the identifier the removal RPC needs; otherwise the
/// action stays disabled with a tooltip, and the dashboard never fakes a
/// removal.
class OrderItemsList extends StatelessWidget {
  const OrderItemsList({
    super.key,
    required this.order,
    required this.onRemoveItem,
  });

  final AdminOrder order;

  /// Removes one line of the order and reloads it.
  final void Function(String itemId) onRemoveItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = AppLocale.instance.language;
    return OrderSectionCard(
      title: S.itemsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (order.items.isEmpty)
            Text(
              S.noOrdersForFilter,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColor.greyColor,
              ),
            ),
          for (final item in order.items) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.sm),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: item.imageUrl != null &&
                              item.imageUrl!.trim().isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: item.imageUrl!,
                              fit: BoxFit.contain,
                              errorWidget: (_, _, _) => const ColoredBox(
                                color: AppColor.secondaryColor,
                                child: Icon(
                                  HugeIcons.strokeRoundedShoppingBag01,
                                ),
                              ),
                            )
                          : const ColoredBox(
                              color: AppColor.secondaryColor,
                              child: Icon(
                                HugeIcons.strokeRoundedShoppingBag01,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productNameFor(language),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                         Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Text(
                               '${item.quantity} \u00D7 ${item.unitPrice.toStringAsFixed(2)}',
                               style: theme.textTheme.bodySmall?.copyWith(
                                 color: AppColor.greyColor,
                               ),
                             ),
                             const SizedBox(width: AppDimensions.xs),
                             CurrencyIcon(size: 12, color: AppColor.greyColor),
                           ],
                         ),
                        if (item.note != null && item.note!.trim().isNotEmpty)
                          Text(
                            item.note!.trim(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColor.greyColor,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                   Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Text(
                         item.lineTotal.toStringAsFixed(2),
                         style: theme.textTheme.bodyMedium?.copyWith(
                           fontWeight: FontWeight.w700,
                         ),
                       ),
                       const SizedBox(width: AppDimensions.xs),
                       const CurrencyIcon(size: 14),
                     ],
                   ),
                  const SizedBox(width: AppDimensions.sm),
                  _removeButton(context, item),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _removeButton(BuildContext context, AdminOrderItem item) {
    final allowed = OrderEditRules.canRemoveItem(
      order,
      hasItemId: item.id != null,
    );
    final tooltip = !OrderEditRules.canEditItems(order)
        ? S.orderCannotBeEdited
        : item.id == null
            ? S.removeItemUnavailable
            : S.removeItem;
    return IconButton(
      tooltip: tooltip,
      color: AppColor.errorColor,
      icon: const Icon(HugeIcons.strokeRoundedDelete02, size: 20),
      onPressed: !allowed || item.id == null
          ? null
          : () => showConfirmDeleteSnackBar(
                context,
                message: S.removeItemConfirm,
                onConfirm: () => onRemoveItem(item.id!),
              ),
    );
  }
}
