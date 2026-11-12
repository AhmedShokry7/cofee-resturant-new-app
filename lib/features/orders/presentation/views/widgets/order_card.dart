import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/features/orders/data/model/order_group.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/presentation/manager/orders/orders_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/leave_review_page.dart';
import 'package:new_coffee/features/orders/presentation/views/order_details_page.dart';
import 'package:new_coffee/features/orders/presentation/views/track_order_page.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_status_badge.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';

/// One order in the history list: number, date, status, item count and the
/// header's real grand total, all frozen snapshots from the invoice.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order});

  final OrderGroup order;

  /// Opens one of the order's pages and reloads the list once that page reports
  /// the order changed underneath — a cancellation is the only way it can.
  Future<void> _open(
    BuildContext context,
    String routeName,
    Object argument,
  ) async {
    final cubit = context.read<OrdersCubit>();
    final changed = await Navigator.of(context)
        .pushNamed(routeName, arguments: argument);
    if (changed == true) await cubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final firstLine = order.header;
    final total = order.grandTotal ?? firstLine.chargedTotal;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        button: true,
        label: S.orderNumber(order.displayNumber),
        child: Material(
          color: AppColor.cardSurface,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          child: InkWell(
            // The whole group travels with the route: a pushed page is built by
            // the root navigator, so its lines can only arrive as an argument.
            onTap: () => _open(context, OrderDetailsPage.routeName, order),
            borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            child: Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: AppColor.borderColor),
                borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          S.orderNumber(order.displayNumber),
                          style: AppFonts.semiBold16(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      OrderStatusBadge(status: order.status),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xs),
                  if (order.placedAt != null)
                    Text(
                      Formatters.date(order.placedAt!),
                      style: AppFonts.regular12(context)
                          .copyWith(color: AppColor.greyColor),
                    ),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.r8),
                        child: SizedBox(
                          height: AppSizes.px56,
                          width: AppSizes.px56,
                          child: ProductImageView(product: firstLine.product),
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              firstLine.product.name,
                              style: AppFonts.medium14(context),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: AppSpacing.xxs),
                            Text(
                              '${S.itemsCount}: ${order.itemCount}',
                              style: AppFonts.regular12(context)
                                  .copyWith(color: AppColor.greyColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text(
                        S.total,
                        style: AppFonts.regular12(context)
                            .copyWith(color: AppColor.greyColor),
                      ),
                      SizedBox(width: AppSpacing.xs),
                      PriceLabel(
                        amount: total,
                        style: AppFonts.semiBold16(context)
                            .copyWith(color: AppColor.primaryColor),
                        iconSize: AppIconSize.md,
                        iconColor: AppColor.primaryColor,
                      ),
                      const Spacer(),
                      if (order.status == OrderStatus.active)
                        _PillButton(
                          label: S.trackOrder,
                          onTap: () => _open(
                            context,
                            TrackOrderPage.routeName,
                            order.header,
                          ),
                        )
                      else if (order.status == OrderStatus.completed)
                        _PillButton(
                          label: S.leaveReview,
                          onTap: () => _open(
                            context,
                            LeaveReviewPage.routeName,
                            order.header,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one action this order offers, drawn beside its total.
class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: AppSpacing.sm),
        child: Semantics(
          button: true,
          label: label,
          child: Material(
            color: AppColor.primaryColor,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              // A control keeps the smallest target the app holds any tappable
              // thing to, even though its own text is 12pt.
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppDimensions.tapTargetMin,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.regular12(context)
                              .copyWith(color: AppColor.whiteColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
