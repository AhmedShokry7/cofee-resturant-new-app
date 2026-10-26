import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_format.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_status_pill.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

class CustomerPreviousOrderItem extends StatelessWidget {
  const CustomerPreviousOrderItem({super.key, required this.order, this.onTap});

  final AdminOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: adminRowBorderColor(theme)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${order.orderNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColor.adminAccent,
                        fontSize: AppFontSizes.size10_5,
                        fontWeight: AppFontWeights.bold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ),
                  Text(
                    orderMoney(order.grandTotal),
                    style: TextStyle(
                      color: dark ? AppColor.darkText : AppColor.adminAmount,
                      fontSize: AppFontSizes.size11,
                      fontWeight: AppFontWeights.semiBold,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                  const SizedBox(width: AppSizes.px4),
                  const CurrencyIcon(size: 10),
                ],
              ),
              const SizedBox(height: AppSizes.px6),
              Row(
                children: [
                  OrderStatusPill(status: order.status, dense: true),
                  const SizedBox(width: AppSizes.px8),
                  Expanded(
                    child: Text(
                      orderDate(order.placedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size9_5,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ),
                  AppIcon(
                    rtl ? AppIcons.arrowLeft01 : AppIcons.arrowRight01,
                    size: 13,
                    color: adminSubtleColor(theme),
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
