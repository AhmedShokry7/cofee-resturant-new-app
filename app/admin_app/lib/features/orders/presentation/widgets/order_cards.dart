import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_format.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_status_pill.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

class OrderCards extends StatelessWidget {
  const OrderCards({
    super.key,
    required this.orders,
    required this.onChangeStatus,
    required this.onOpen,
  });

  final List<AdminOrder> orders;
  final void Function(AdminOrder order, String status) onChangeStatus;
  final ValueChanged<AdminOrder> onOpen;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: orders.length,
    separatorBuilder: (_, _) => const SizedBox(height: AppSizes.px8),
    itemBuilder: (context, index) {
      final order = orders[index];
      return OrderCard(
        order: order,
        onChangeStatus: (status) => onChangeStatus(order, status),
        onTap: () => onOpen(order),
      );
    },
  );
}

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.onChangeStatus,
    this.onTap,
  });

  final AdminOrder order;
  final ValueChanged<String>? onChangeStatus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppRadius.lg);
    final body = dark ? AppColor.darkText : AppColor.adminBody;
    final subtle = dark ? AppColor.darkTextSecondary : AppColor.adminSubtle;
    final date = dark ? AppColor.darkTextSecondary : AppColor.adminDate;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final contact = _contactLine(order);
    final fulfillment = OrderFulfillmentView.of(order.fulfillmentType);
    final branch = order.branchNameFor(AppLocale.instance.language);
    final method = fulfillment.isDelivery || branch.isEmpty
        ? fulfillment.label
        : '${fulfillment.label} • $branch';
    final payment = OrderPaymentStatusView.of(order.paymentStatus);

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
            border: Border.all(
              color: dark ? AppColor.darkBorder : AppColor.adminCardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '#${order.orderNumber}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColor.adminAccent,
                      fontSize: AppFontSizes.size12,
                      fontWeight: AppFontWeights.bold,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                  const SizedBox(width: AppSizes.px8),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OrderStatusPill(status: order.status),
                    ),
                  ),
                  if (onChangeStatus != null)
                    PopupMenuButton<String>(
                      tooltip: S.changeStatus,
                      onSelected: onChangeStatus,
                      itemBuilder: (_) => [
                        for (final code in OrderStatusView.allCodes)
                          PopupMenuItem(
                            value: code,
                            child: Text(OrderStatusView.of(code).label),
                          ),
                      ],
                      icon: AppIcon(
                        AppIcons.moreHorizontalCircle01,
                        size: 18,
                        color: dark
                            ? AppColor.darkTextSecondary
                            : AppColor.adminMuted,
                      ),
                    ),
                  AppIcon(
                    rtl ? AppIcons.arrowLeft01 : AppIcons.arrowRight01,
                    size: 16,
                    color: AppColor.adminMuted,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.px10),
              Row(
                children: [
                  AdminAvatarImage(url: order.customerAvatarUrl, size: 38),
                  const SizedBox(width: AppSizes.px10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName ?? S.ordersUnknownCustomer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: body,
                            fontSize: AppFontSizes.size12,
                            fontWeight: AppFontWeights.bold,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                        if (contact != null)
                          Text(
                            contact,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: subtle,
                              fontSize: AppFontSizes.size10,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.px10),
              Row(
                children: [
                  Expanded(
                    child: _Info(
                      label: S.orderPlacedAt,
                      child: Text(
                        orderPlacedLabel(order.placedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: date,
                          fontSize: AppFontSizes.size10_5,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _Info(
                      label: S.total,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              orderMoney(order.grandTotal),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: dark
                                    ? AppColor.darkText
                                    : AppColor.adminAmount,
                                fontSize: AppFontSizes.size11,
                                fontWeight: AppFontWeights.semiBold,
                                height: AppTextHeights.line1_5,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.px4),
                          const CurrencyIcon(size: 13),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.px8),
              Row(
                children: [
                  Expanded(
                    child: _Info(
                      label: S.fulfillmentType,
                      child: Text(
                        method,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: body,
                          fontSize: AppFontSizes.size10_5,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _Info(
                      label: S.paymentStatusLabelTitle,
                      child: Text(
                        payment.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dark
                              ? Color.lerp(
                                  payment.color,
                                  AppColor.whiteColor,
                                  .25,
                                )
                              : payment.color,
                          fontSize: AppFontSizes.size10_5,
                          fontWeight: AppFontWeights.semiBold,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
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

String? _contactLine(AdminOrder order) {
  final email = order.customerEmail?.trim() ?? '';
  if (email.isNotEmpty) return email;
  final phone = order.customerPhone?.trim() ?? '';
  return phone.isEmpty ? null : phone;
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
            fontSize: AppFontSizes.size9,
            height: AppTextHeights.line1_5,
          ),
        ),
        child,
      ],
    );
  }
}
