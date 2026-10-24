import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/carts/data/models/admin_cart.dart';
import 'package:admin_app/features/carts/presentation/models/cart_status.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';

/// Opens the dialog that shows the whole content of one cart.
Future<void> showCartDetailsDialog({
  required BuildContext context,
  required AdminCart cart,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => CartDetailsDialog(cart: cart),
  );
}

/// The full content of a cart: the customer, its branch association, every
/// line, the total and when it was last written.
///
/// This view is a CART, never an order: it offers no status change and no
/// checkout actions, because an order is only created by the checkout flow.
class CartDetailsDialog extends StatelessWidget {
  const CartDetailsDialog({super.key, required this.cart});

  final AdminCart cart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = AppLocale.instance.language;
    final status = CartStatusView.of(cart.status);
    final branch = cart.branchNameFor(language);
    final updated = formatDateTime(cart.updatedAt ?? cart.createdAt);

    return AlertDialog(
      title: Text(S.cartDetailsTitle),
      content: SizedBox(
        width: 520,
        height: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(
                theme,
                S.customer,
                (cart.customerName?.trim().isEmpty ?? true)
                    ? S.unknownCustomer
                    : cart.customerName!.trim(),
              ),
              if (cart.customerEmail != null && cart.customerEmail!.isNotEmpty)
                _line(theme, S.email, cart.customerEmail!),
              if (branch.isNotEmpty) _line(theme, S.branchLabel, branch),
              if (updated != '-') _line(theme, S.updatedAt, updated),
              Row(
                children: [
                  Text(
                    '${S.status}:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColor.greyColor,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.xs),
                  AdminStatusBadge(label: status.label, color: status.color),
                ],
              ),
              const SizedBox(height: AppDimensions.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      S.total,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${cart.total.toStringAsFixed(2)} SAR',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColor.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
              Text(
                S.itemsTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              for (final item in cart.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child:
                              item.imageUrl != null &&
                                  item.imageUrl!.trim().isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: item.imageUrl!,
                                  fit: BoxFit.fill,
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
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        child: Text(
                          '${item.productNameFor(language)} \u00D7${item.quantity}',
                        ),
                      ),
                      Text('${item.lineTotal.toStringAsFixed(2)} SAR'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.close),
        ),
      ],
    );
  }

  Widget _line(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColor.greyColor,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
