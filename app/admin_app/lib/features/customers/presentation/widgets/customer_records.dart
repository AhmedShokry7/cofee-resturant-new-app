import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/customers/data/models/admin_customer.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';

class CustomerRecords extends StatelessWidget {
  const CustomerRecords({super.key, required this.customers, this.onOpen});

  final List<AdminCustomer> customers;
  final ValueChanged<AdminCustomer>? onOpen;

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return Center(
        child: Text(
          'No customers found',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColor.greyColor),
        ),
      );
    }

    final colors = <Color>[
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    final top = [...customers]
      ..sort((a, b) => b.ordersCount.compareTo(a.ordersCount));
    final top5 = top.take(5).where((c) => c.ordersCount > 0).toList();
    final colorById = <String, Color>{};
    for (var i = 0; i < top5.length; i++) {
      colorById[top5[i].id] = colors[i % colors.length];
    }

    return ListView.separated(
      itemCount: customers.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.md),
      itemBuilder: (context, index) {
        final customer = customers[index];
        return _CustomerCard(
          customer: customer,
          dotColor: colorById[customer.id],
          onTap: onOpen == null ? null : () => onOpen!(customer),
        );
      },
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, this.dotColor, this.onTap});

  final AdminCustomer customer;
  final Color? dotColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = AppLocale.instance.language;

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
        child: Row(
          children: [
            if (dotColor != null)
              Container(
                width: 8,
                height: 48,
                margin: const EdgeInsets.only(right: AppDimensions.sm),
                color: dotColor,
              ),
            AdminAvatarImage(url: customer.avatarUrl),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.displayName(language),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (customer.email != null && customer.email!.isNotEmpty)
                    Text(
                      customer.email!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColor.greyColor,
                      ),
                    ),
                  if (customer.phone != null && customer.phone!.isNotEmpty)
                    Text(
                      customer.phone!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColor.greyColor,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${customer.ordersCount} orders',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${customer.totalSpent.toStringAsFixed(2)} SAR',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColor.primaryColor,
                    fontWeight: FontWeight.w700,
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
