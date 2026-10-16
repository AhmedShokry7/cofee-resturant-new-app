import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_price.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/presentation/views/leave_review_page.dart';
import 'package:new_coffee/features/orders/presentation/views/order_details_page.dart';
import 'package:new_coffee/features/orders/presentation/views/track_order_page.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order});

  final OrderItemModel order;

  void _openDetails(BuildContext context) {
    Navigator.of(context)
        .pushNamed(OrderDetailsPage.routeName, arguments: order);
  }

  @override
  Widget build(BuildContext context) {
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
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: SizedBox(
                height: 72.w,
                width: 72.w,
                child: ProductImageView(product: order.product),
              ),
            ),
            SizedBox(width: SpacingTokens.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.orderNumber(order.displayNumber),
                    style: AppFonts.regular12(context)
                        .copyWith(color: AppColor.greyColor),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    order.product.name,
                    style: AppFonts.semiBold16(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.h),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: ProductPrice(product: order.product),
                  ),
                ],
              ),
            ),
            if (order.status == OrderStatus.active)
              _ActionButton(
                label: S.trackOrder,
                onTap: () =>
                    Navigator.of(context)
                        .pushNamed(TrackOrderPage.routeName, arguments: order),
              )
            else if (order.status == OrderStatus.completed)
              _ActionButton(
                label: S.leaveReview,
                onTap: () =>
                    Navigator.of(context)
                        .pushNamed(LeaveReviewPage.routeName, arguments: order),
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
              style: AppFonts.regular12(context)
                  .copyWith(color: AppColor.whiteColor),
            ),
          ),
        ),
      ),
    );
  }
}
