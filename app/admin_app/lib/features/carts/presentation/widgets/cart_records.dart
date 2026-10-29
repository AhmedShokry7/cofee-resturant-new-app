import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/carts/data/models/admin_cart.dart';
import 'package:admin_app/features/carts/presentation/models/cart_status.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

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
    if (q.isEmpty) return carts;
    final language = AppLocale.instance.language;
    return carts
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
    final filtering = search.trim().isNotEmpty;

    return AdminDirectoryPanel(
      child: carts.isEmpty
          ? AdminEmptyState(
              icon: filtering ? AppIcons.search01 : AppIcons.shoppingBag01,
              message: filtering ? S.noCartsFound : S.noCartsYet,
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: carts.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSizes.px8),
              itemBuilder: (context, index) {
                final cart = carts[index];
                return CartCard(
                  cart: cart,
                  onTap: onOpen == null ? null : () => onOpen!(cart),
                );
              },
            ),
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
    final dark = theme.brightness == Brightness.dark;
    final status = CartStatusView.of(cart.status);
    final name = cart.customerName?.trim();
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final radius = BorderRadius.circular(AppRadius.lg);
    final muted = adminSubtleColor(theme);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: adminCardBorderColor(theme)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (name == null || name.isEmpty) ? S.unknownCustomer : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size12,
                        fontWeight: AppFontWeights.bold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AdminStatusBadge(label: status.label, color: status.color),
                  if (onTap != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    AppIcon(
                      rtl ? AppIcons.arrowLeft01 : AppIcons.arrowRight01,
                      size: 16,
                      color: adminMutedColor(theme),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSizes.px10),
              Row(
                children: [
                  AppIcon(AppIcons.shoppingBag01, size: 14, color: muted),
                  const SizedBox(width: AppSizes.px6),
                  Expanded(
                    child: Text(
                      S.cartItemsCount(cart.items.length),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: AppFontSizes.size10_5,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          localizeDigits(formatAmount(cart.total)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: dark
                                ? AppColor.darkText
                                : AppColor.adminAmount,
                            fontSize: AppFontSizes.size12,
                            fontWeight: AppFontWeights.bold,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.px4),
                      CurrencyIcon(
                        size: 14,
                        color: dark ? AppColor.darkText : AppColor.adminAmount,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
