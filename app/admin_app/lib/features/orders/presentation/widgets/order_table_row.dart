import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_format.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_status_pill.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_table.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

class OrderTableRow extends StatelessWidget {
  const OrderTableRow({super.key, required this.order, this.onTap});

  final AdminOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final body = dark ? AppColor.darkText : AppColor.adminBody;
    final subtle = dark ? AppColor.darkTextSecondary : AppColor.adminSubtle;
    final date = dark ? AppColor.darkTextSecondary : AppColor.adminDate;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final contact = _contactLine(order);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: dark ? AppColor.darkBorder : AppColor.adminRowBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  '#${order.orderNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColor.adminAccent,
                    fontSize: AppFontSizes.size11,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    AdminAvatarImage(url: order.customerAvatarUrl, size: 29),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName ?? S.ordersUnknownCustomer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: body,
                              fontSize: AppFontSizes.size11,
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
                                fontSize: AppFontSizes.size9,
                                height: AppTextHeights.line1_5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
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
              Expanded(
                flex: 3,
                child: Text(
                  _itemsLabel(order),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: body,
                    fontSize: AppFontSizes.size11,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
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
                    const SizedBox(width: 4),
                    const CurrencyIcon(size: 13),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OrderStatusPill(status: order.status, dense: true),
                ),
              ),
              SizedBox(
                width: OrderTable.actionWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: HugeIcon(
                    icon: rtl
                        ? HugeIcons.strokeRoundedArrowLeft01
                        : HugeIcons.strokeRoundedArrowRight01,
                    size: 16,
                    color: dark
                        ? AppColor.darkTextSecondary
                        : AppColor.adminMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _itemsLabel(AdminOrder order) {
    if (order.items.isEmpty) return S.noOrderItems;
    final item = order.items.first;
    final name = item.productNameFor(AppLocale.instance.language);
    return item.quantity > 1 ? '$name × ${orderCount(item.quantity)}' : name;
  }
}

String? _contactLine(AdminOrder order) {
  final email = order.customerEmail?.trim() ?? '';
  if (email.isNotEmpty) return email;
  final phone = order.customerPhone?.trim() ?? '';
  return phone.isEmpty ? null : phone;
}
