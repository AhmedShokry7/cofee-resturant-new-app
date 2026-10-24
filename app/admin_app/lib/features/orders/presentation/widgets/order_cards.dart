
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';


class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.onChangeStatus,
    this.onTap,
  });

  final AdminOrder order;
  final void Function(String status)? onChangeStatus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNarrow = MediaQuery.sizeOf(context).width < 600;

    final status = OrderStatusView.of(order.status);
    final payment = OrderPaymentStatusView.of(order.paymentStatus);
    final fulfillment =
        OrderFulfillmentView.of(order.fulfillmentType);
    final branch =
        order.branchNameFor(AppLocale.instance.language);

    final customerName = order.customerName ?? S.unknownCustomer;
    final total = order.grandTotal.toStringAsFixed(2);
    final date = formatDateTime(order.placedAt);

    final fulfillmentText = fulfillment.isDelivery || branch.isEmpty
        ? fulfillment.label
        : '${fulfillment.label} • $branch';

    return Material(
      color: AppColor.whiteColor,
      borderRadius:
          BorderRadius.circular(AppDimensions.recordCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(AppDimensions.recordCardRadius),
        child: Container(
          padding: EdgeInsets.all(
            isNarrow ? AppDimensions.sm : AppDimensions.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              AppDimensions.recordCardRadius,
            ),
            border: Border.all(
              color: AppColor.recordBorder,
            ),
          ),
          child: isNarrow
              ? _buildCompactLayout(
                  theme: theme,
                  status: status,
                  payment: payment,
                  customerName: customerName,
                  total: total,
                  date: date,
                  fulfillmentText: fulfillmentText,
                )
              : _buildWideLayout(
                  theme: theme,
                  status: status,
                  payment: payment,
                  customerName: customerName,
                  total: total,
                  fulfillmentText: fulfillmentText,
                ),
        ),
      ),
    );
  }

  Widget _buildCompactLayout({
    required ThemeData theme,
    required OrderStatusView status,
    required OrderPaymentStatusView payment,
    required String customerName,
    required String total,
    required String date,
    required String fulfillmentText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '#${order.orderNumber}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppDimensions.xs),
            AdminStatusBadge(
              label: status.label,
              color: status.color,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        Row(
          children: [
            AdminAvatarImage(
              url: order.customerAvatarUrl,
              size: 42,
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(
                customerName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      total,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColor.primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  CurrencyIcon(
                    size: 14,
                    color: AppColor.primaryColor,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        const Divider(height: 1),
        const SizedBox(height: AppDimensions.sm),
        _metaRow(
          theme,
          icon: HugeIcons.strokeRoundedClock03,
          text: date,
        ),
        _metaRow(
          theme,
          icon: HugeIcons.strokeRoundedDeliveryTruck01,
          text: fulfillmentText,
        ),
        _metaRow(
          theme,
          icon: HugeIcons.strokeRoundedMoney03,
          text: '${S.paymentStatusLabelTitle}: ${payment.label}',
          color: payment.color,
        ),
      ],
    );
  }

  Widget _buildWideLayout({
    required ThemeData theme,
    required OrderStatusView status,
    required OrderPaymentStatusView payment,
    required String customerName,
    required String total,
    required String fulfillmentText,
  }) {
    final placedAt = order.placedAt;
    final dateOnly = placedAt == null
        ? '-'
        : '${placedAt.year}-${placedAt.month.toString().padLeft(2, '0')}-${placedAt.day.toString().padLeft(2, '0')}';
    final timeOnly = placedAt == null
        ? '-'
        : '${placedAt.hour.toString().padLeft(2, '0')}:${placedAt.minute.toString().padLeft(2, '0')}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AdminAvatarImage(
          url: order.customerAvatarUrl,
          size: 48,
        ),
        const SizedBox(width: AppDimensions.md),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimensions.xs),
              Text(
                '#${order.orderNumber}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColor.greyColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              _metaRow(
                theme,
                icon: HugeIcons.strokeRoundedDeliveryTruck01,
                text: fulfillmentText,
              ),
              _metaRow(
                theme,
                icon: HugeIcons.strokeRoundedMoney03,
                text: '${S.paymentStatusLabelTitle}: ${payment.label}',
                color: payment.color,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.md),
        Container(
          width: 130,
          padding: const EdgeInsets.all(AppDimensions.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AdminStatusBadge(
                  label: status.label,
                  color: status.color,
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      total,
                      textAlign: TextAlign.start,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColor.primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  CurrencyIcon(
                    size: 14,
                    color: AppColor.primaryColor,
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              const Divider(height: 1),
              const SizedBox(height: AppDimensions.xs),
              _metaRow(
                theme,
                icon: HugeIcons.strokeRoundedCalendar03,
                text: dateOnly,
              ),
              _metaRow(
                theme,
                icon: HugeIcons.strokeRoundedClock03,
                text: timeOnly,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaRow(
    ThemeData theme, {
    required dynamic icon,
    required String text,
    Color? color,
  }) {
    final foreground = color ?? AppColor.greyColor;

    return Padding(
      padding: const EdgeInsets.only(
        top: AppDimensions.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: icon,
            size: 15,
            color: foreground,
          ),
          const SizedBox(width: AppDimensions.xs),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: foreground,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
