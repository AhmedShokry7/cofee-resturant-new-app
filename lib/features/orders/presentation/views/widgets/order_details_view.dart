import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/presentation/views/leave_review_page.dart';
import 'package:new_coffee/features/orders/presentation/views/track_order_page.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_status_badge.dart';
import 'package:new_coffee/shared/widgets/app_icon.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/labeled_value_row.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';

/// The frozen invoice of one order: its lines, its discounts and what was
/// actually charged.
///
/// Every figure here comes from the row the order was billed with, so repricing
/// a product later cannot rewrite this receipt.
///
/// Leaving with `true` says the order changed underneath — a cancellation or a
/// submitted review — so whoever opened this page drops the row it still holds.
class OrderDetailsView extends StatefulWidget {
  const OrderDetailsView({super.key, required this.order, this.lines});

  final OrderItemModel order;

  /// The other lines of the same invoice, when whoever opened this page holds
  /// them. A route is built by the root navigator, so the only way a line can
  /// arrive here is as an argument — the list page's providers are not above it.
  final List<OrderItemModel>? lines;

  @override
  State<OrderDetailsView> createState() => _OrderDetailsViewState();
}

class _OrderDetailsViewState extends State<OrderDetailsView> {
  Future<void> _openAction() async {
    final routeName = switch (widget.order.status) {
      OrderStatus.active => TrackOrderPage.routeName,
      OrderStatus.completed => LeaveReviewPage.routeName,
      OrderStatus.cancelled => null,
    };
    if (routeName == null) return;
    final navigator = Navigator.of(context);
    final changed = await navigator.pushNamed(
      routeName,
      arguments: widget.order,
    );
    if (changed == true) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final allLines = widget.lines ?? const <OrderItemModel>[];
    final lines = allLines.isEmpty ? [widget.order] : allLines;
    final totalItems = lines.fold<int>(0, (sum, line) => sum + line.quantity);
    final total =
        widget.order.grandTotal ??
        lines.fold<double>(0.0, (sum, line) => sum + line.chargedTotal);
    final order = widget.order;

    return Scaffold(
      appBar: AppBar(title: Text(S.orderDetails)),
      body: ListView(
        padding: AppLayout.pageBody,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  S.orderNumber(order.displayNumber),
                  style: AppFonts.semiBold18(context),
                ),
              ),
              OrderStatusBadge(status: order.status, large: true),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          _InvoiceCard(lines: lines),
          SizedBox(height: AppSpacing.lg),
          if (order.isDelivery) ...[
            _DetailRow(label: S.fulfillmentMethod, value: S.deliveryMethod),
            if (order.deliveryZoneName != null)
              _DetailRow(label: S.deliveryZone, value: order.deliveryZoneName!),
            if (order.deliveryAddress != null)
              _DetailRow(
                label: S.shippingAddress,
                value: order.deliveryAddress!,
              ),
            if (order.deliveryFee > 0)
              _DetailRow(label: S.deliveryFee, priceValue: order.deliveryFee),
            SizedBox(height: AppSpacing.lg),
          ],
          _DetailRow(label: S.itemsCount, value: "$totalItems"),
          if (order.productDiscountTotal != null &&
              order.productDiscountTotal! > 0)
            _DetailRow(
              label: S.productDiscount,
              priceValue: order.productDiscountTotal!,
              pricePrefix: '-',
            ),
          if (order.discountTotal != null && order.discountTotal! > 0)
            _DetailRow(
              label: S.couponDiscount,
              priceValue: order.discountTotal!,
              pricePrefix: '-',
            ),
          _DetailRow(label: S.total, priceValue: total, emphasized: true),
        ],
      ),
      bottomNavigationBar: order.status == OrderStatus.cancelled
          ? null
          : _BottomAction(
              label: order.status == OrderStatus.active
                  ? S.trackOrder
                  : S.leaveReview,
              onPressed: _openAction,
            ),
    );
  }
}

/// The lines of one invoice, each with the discounts taken on it.
class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.lines});

  final List<OrderItemModel> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            _LineTile(line: lines[i]),
            if (i != lines.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(color: AppColor.borderColor),
              ),
          ],
        ],
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line});

  final OrderItemModel line;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
              child: SizedBox(
                height: AppSizes.px72,
                width: AppSizes.px72,
                child: ProductImageView(product: line.product),
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.product.category,
                    style: AppFonts.regular12(context)
                        .copyWith(color: AppColor.greyColor),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(line.product.name, style: AppFonts.semiBold16(context)),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    S.quantityLabel(line.quantity),
                    style: AppFonts.regular14(context)
                        .copyWith(color: AppColor.greyColor),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            PriceLabel(
              amount: line.chargedTotal,
              style: AppFonts.semiBold16(context)
                  .copyWith(color: AppColor.primaryColor),
              iconSize: AppIconSize.md,
              iconColor: AppColor.primaryColor,
            ),
          ],
        ),
        if (line.lineDiscountTotal != null && line.lineDiscountTotal! > 0)
          _DiscountRow(label: S.lineDiscount, amount: line.lineDiscountTotal!),
        if (line.lineProductDiscountTotal != null &&
            line.lineProductDiscountTotal! > 0)
          _DiscountRow(
            label: S.productDiscount,
            amount: line.lineProductDiscountTotal!,
          ),
      ],
    );
  }
}

/// The two discount lines a single invoice row can carry, which read the same.
class _DiscountRow extends StatelessWidget {
  const _DiscountRow({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AppIcon(
            AppIcons.discount,
            size: AppIconSize.xs,
            color: AppColor.primaryColor,
          ),
          SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppFonts.regular12(context)
                .copyWith(color: AppColor.primaryColor),
          ),
          SizedBox(width: AppSpacing.xs),
          PriceLabel(
            amount: amount,
            prefix: '-',
            style: AppFonts.regular12(context)
                .copyWith(color: AppColor.primaryColor),
            iconSize: AppIconSize.xs,
            iconColor: AppColor.primaryColor,
          ),
        ],
      ),
    );
  }
}

/// A figure or fact of the invoice header, in the breakdown's own size.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    this.value = '',
    this.priceValue,
    this.pricePrefix = '',
    this.emphasized = false,
  });

  final String label;
  final String value;
  final double? priceValue;
  final String pricePrefix;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: LabeledValueRow(
        label: label,
        value: value,
        priceValue: priceValue,
        pricePrefix: pricePrefix,
        emphasized: emphasized,
        valueSize: LabeledValueRow.detailValueSize,
        labelExpanded: true,
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        border: Border(top: BorderSide(color: AppColor.borderColor)),
      ),
      child: CustomBtn(text: label, onPressed: onPressed),
    );
  }
}
