import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/carts/data/models/admin_cart.dart';
import 'package:admin_app/features/carts/presentation/models/cart_status.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';

/// The list of the carts, empty when nothing matches.
class CartRecords extends StatelessWidget {
  const CartRecords({
    super.key,
    required this.carts,
    this.search = '',
    this.onOpen,
  });

  /// Every loaded cart; the list filters them with [search].
  final List<AdminCart> carts;

  /// The word the admin is looking for.
  final String search;

  final ValueChanged<AdminCart>? onOpen;

  List<AdminCart> get _filtered {
    final q = search.trim().toLowerCase();
    final visible = carts.where((cart) => cart.total > 0).toList(
      growable: false,
    );
    if (q.isEmpty) return visible;
    final language = AppLocale.instance.language;
    return visible
        .where(
          (cart) =>
              (cart.customerName ?? '').toLowerCase().contains(q) ||
              (cart.customerEmail ?? '').toLowerCase().contains(q) ||
              cart.items.any(
                (item) =>
                    item.productNameFor(language).toLowerCase().contains(q),
              ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final carts = _filtered;
    if (carts.isEmpty) {
      return Center(
        child: Text(
          S.noCartsFound,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColor.greyColor),
        ),
      );
    }

    return ListView.separated(
      itemCount: carts.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.md),
      itemBuilder: (context, index) {
        final cart = carts[index];
        return CartCard(
          cart: cart,
          onTap: onOpen == null ? null : () => onOpen!(cart),
        );
      },
    );
  }
}

/// The outer summary of one cart: who owns it, what it is worth, how many
/// items it holds and whether it is still active.
///
/// The branch, the products and their pictures belong to the details view of
/// the cart; a cart is not an order, so this card never shows order fields.
class CartCard extends StatelessWidget {
  const CartCard({super.key, required this.cart, this.onTap});

  final AdminCart cart;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = CartStatusView.of(cart.status);
    final name = cart.customerName?.trim();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
      child: Container(
        decoration: BoxDecoration(
          color: AppColor.whiteColor,
          borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
          border: Border.all(color: AppColor.recordBorder),
        ),
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (name == null || name.isEmpty) ? S.unknownCustomer : name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AdminStatusBadge(label: status.label, color: status.color),
              ],
            ),
            const SizedBox(height: AppDimensions.xs),
            Row(
              children: [
                Icon(
                  HugeIcons.strokeRoundedShoppingBag01,
                  size: 14,
                  color: AppColor.greyColor,
                ),
                const SizedBox(width: AppDimensions.xs),
                Text(
                  S.cartItemsCount(cart.items.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColor.greyColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '${cart.total.toStringAsFixed(2)} SAR',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColor.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
