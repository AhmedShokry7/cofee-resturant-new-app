import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/features/orders/data/model/order_group.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/presentation/views/leave_review_page.dart';
import 'package:new_coffee/features/orders/presentation/views/order_details_page.dart';
import 'package:new_coffee/features/orders/presentation/views/track_order_page.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';

/// One order in the history list: number, date, status, item count and the
/// header's real grand total, all frozen snapshots from the invoice.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order});

  final OrderGroup order;

  void _openDetails(BuildContext context) {
    Navigator.of(context).pushNamed(
      OrderDetailsPage.routeName,
      arguments: order,
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstLine = order.header;
    final total = order.grandTotal ?? firstLine.chargedTotal;
    return GestureDetector(
      onTap: () => _openDetails(context),
      child: Container(
        margin: EdgeInsets.only(bottom: SpacingTokens.md.h),
        padding: EdgeInsets.all(SpacingTokens.md.w),
        decoration: BoxDecoration(
          color: AppColor.whiteColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColor.borderColor),
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
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: SpacingTokens.sm.w,
                    vertical: SpacingTokens.xs.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColor.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100.r),
                  ),
                  child: Text(
                    order.status.label,
                    style: AppFonts.regular12(
                      context,
                    ).copyWith(color: AppColor.primaryColor),
                  ),
                ),
              ],
            ),
            SizedBox(height: SpacingTokens.xs.h),
            Text(
              order.placedAt != null
                  ? Formatters.date(order.placedAt!)
                  : '',
              style: AppFonts.regular12(context).copyWith(
                color: AppColor.greyColor,
              ),
            ),
            SizedBox(height: SpacingTokens.sm.h),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: SizedBox(
                    height: 56.w,
                    width: 56.w,
                    child: ProductImageView(product: firstLine.product),
                  ),
                ),
                SizedBox(width: SpacingTokens.md.w),
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
                      SizedBox(height: 2.h),
                      Text(
                        '${S.itemsCount}: ${order.itemCount}',
                        style: AppFonts.regular12(
                          context,
                        ).copyWith(color: AppColor.greyColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: SpacingTokens.sm.h),
            Row(
              children: [
                Text(
                  S.total,
                  style: AppFonts.regular12(
                    context,
                  ).copyWith(color: AppColor.greyColor),
                ),
                SizedBox(width: SpacingTokens.xs.w),
                PriceLabel(
                  amount: total,
                  style: AppFonts.semiBold16(
                    context,
                  ).copyWith(color: AppColor.primaryColor),
                  iconSize: 16,
                  iconColor: AppColor.primaryColor,
                ),
                const Spacer(),
                if (order.status == OrderStatus.active)
                  _ActionButton(
                    label: S.trackOrder,
                    onTap: () => Navigator.of(context).pushNamed(
                      TrackOrderPage.routeName,
                      arguments: order.header,
                    ),
                  )
                else if (order.status == OrderStatus.completed)
                  _ActionButton(
                    label: S.leaveReview,
                    onTap: () => Navigator.of(context).pushNamed(
                      LeaveReviewPage.routeName,
                      arguments: order.header,
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Padding(
        padding: EdgeInsets.only(left: SpacingTokens.sm.w),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: SpacingTokens.md.w,
              vertical: SpacingTokens.sm.h,
            ),
            decoration: BoxDecoration(
              color: AppColor.primaryColor,
              borderRadius: BorderRadius.circular(100.r),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.regular12(context).copyWith(
                color: AppColor.whiteColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
