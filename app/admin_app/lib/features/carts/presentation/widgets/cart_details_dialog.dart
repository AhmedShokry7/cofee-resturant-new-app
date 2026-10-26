import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/carts/data/models/admin_cart.dart';
import 'package:admin_app/features/carts/presentation/models/cart_status.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

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
    final heading = adminHeadingColor(theme);
    final body = adminBodyColor(theme);
    final muted = adminMutedColor(theme);

    return AlertDialog(
      title: Text(S.cartDetailsTitle),
      content: SizedBox(
        width: 520,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .6,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _line(
                  muted: muted,
                  body: body,
                  label: S.customer,
                  value: (cart.customerName?.trim().isEmpty ?? true)
                      ? S.unknownCustomer
                      : cart.customerName!.trim(),
                ),
                if (cart.customerEmail != null &&
                    cart.customerEmail!.isNotEmpty)
                  _line(
                    muted: muted,
                    body: body,
                    label: S.email,
                    value: cart.customerEmail!,
                  ),
                if (branch.isNotEmpty)
                  _line(
                    muted: muted,
                    body: body,
                    label: S.branchLabel,
                    value: branch,
                  ),
                if (updated != '-')
                  _line(
                    muted: muted,
                    body: body,
                    label: S.updatedAt,
                    value: updated,
                  ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${S.status}:',
                      style: TextStyle(
                        color: muted,
                        fontSize: AppFontSizes.size12,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    AdminStatusBadge(label: status.label, color: status.color),
                  ],
                ),
                const SizedBox(height: AppDimensions.md),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: adminTintedSurfaceColor(theme),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(color: adminCardBorderColor(theme)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          S.total,
                          style: TextStyle(
                            color: body,
                            fontSize: AppFontSizes.size12_5,
                            fontWeight: AppFontWeights.semiBold,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                      ),
                      Text(
                        formatMoneyWithCurrency(cart.total),
                        style: TextStyle(
                          color: heading,
                          fontSize: AppFontSizes.size14,
                          fontWeight: AppFontWeights.bold,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),
                Text(
                  S.itemsTitle,
                  style: TextStyle(
                    color: body,
                    fontSize: AppFontSizes.size12_5,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                if (cart.items.isEmpty)
                  Text(
                    S.noCartItems,
                    style: TextStyle(
                      color: muted,
                      fontSize: AppFontSizes.size11_5,
                      height: AppTextHeights.line1_5,
                    ),
                  )
                else
                  for (final item in cart.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                      child: _CartItemRow(item: item, language: language),
                    ),
              ],
            ),
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

  Widget _line({
    required Color muted,
    required Color body,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: muted,
              fontSize: AppFontSizes.size12,
              height: AppTextHeights.line1_5,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: body,
                fontSize: AppFontSizes.size12,
                fontWeight: AppFontWeights.semiBold,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  const _CartItemRow({required this.item, required this.language});

  final AdminCartItem item;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = adminBodyColor(theme);
    final muted = adminMutedColor(theme);
    final image = item.imageUrl?.trim();

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          child: SizedBox(
            width: 40,
            height: 40,
            child: image != null && image.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.fill,
                    errorWidget: (_, _, _) => _ItemImagePlaceholder(
                      color: muted,
                      background: adminTintedSurfaceColor(theme),
                    ),
                  )
                : _ItemImagePlaceholder(
                    color: muted,
                    background: adminTintedSurfaceColor(theme),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productNameFor(language),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: body,
                  fontSize: AppFontSizes.size11_5,
                  fontWeight: AppFontWeights.semiBold,
                  height: AppTextHeights.line1_5,
                ),
              ),
              Text(
                '${localizeDigits('${item.quantity}')} × '
                '${formatMoneyWithCurrency(item.unitPrice)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: muted,
                  fontSize: AppFontSizes.size10_5,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.sm),
        Text(
          formatMoneyWithCurrency(item.lineTotal),
          maxLines: 1,
          style: TextStyle(
            color: body,
            fontSize: AppFontSizes.size11_5,
            fontWeight: AppFontWeights.semiBold,
            height: AppTextHeights.line1_5,
          ),
        ),
      ],
    );
  }
}

class _ItemImagePlaceholder extends StatelessWidget {
  const _ItemImagePlaceholder({required this.color, required this.background});

  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedShoppingBag01,
          size: 18,
          color: color,
        ),
      ),
    );
  }
}
