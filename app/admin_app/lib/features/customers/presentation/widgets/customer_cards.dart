import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_avatar.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_format.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_table.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

class CustomerCards extends StatelessWidget {
  const CustomerCards({
    super.key,
    required this.customers,
    required this.isSelected,
    required this.onToggle,
    required this.onOpen,
  });

  final List<AdminCustomer> customers;
  final bool Function(AdminCustomer customer) isSelected;
  final ValueChanged<AdminCustomer> onToggle;
  final ValueChanged<AdminCustomer> onOpen;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: customers.length,
    separatorBuilder: (_, _) => const SizedBox(height: AppSizes.px8),
    itemBuilder: (context, index) {
      final customer = customers[index];
      return _CustomerCard(
        customer: customer,
        selected: isSelected(customer),
        onToggle: () => onToggle(customer),
        onOpen: () => onOpen(customer),
      );
    },
  );
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.selected,
    required this.onToggle,
    required this.onOpen,
  });

  final AdminCustomer customer;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppRadius.lg);
    final body = dark ? AppColor.darkText : AppColor.adminBody;
    final subtle = dark ? AppColor.darkTextSecondary : AppColor.adminSubtle;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final contact = customerContactLine(customer);
    return Material(
      color: selected
          ? (dark
                ? AppColor.adminAccent.withValues(alpha: .12)
                : AppColor.adminRowSelected)
          : theme.colorScheme.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onOpen,
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
                  CustomerCheckbox(
                    value: selected,
                    onChanged: (_) => onToggle(),
                  ),
                  const SizedBox(width: AppSizes.px8),
                  CustomerAvatar(customer: customer, size: 38),
                  const SizedBox(width: AppSizes.px10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerDisplayName(customer),
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
                  Expanded(
                    child: _Info(
                      label: S.ordersCountLabel,
                      child: Text(
                        customerOrders(customer.ordersCount),
                        style: TextStyle(
                          color: body,
                          fontSize: AppFontSizes.size11,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _Info(
                      label: S.totalSpent,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              customerMoney(customer.totalSpent),
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
                      label: S.lastOrder,
                      child: Text(
                        customerLastOrder(customer.lastOrderAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dark
                              ? AppColor.darkTextSecondary
                              : AppColor.adminDate,
                          fontSize: AppFontSizes.size10_5,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _Info(
                      label: S.customersJoinDate,
                      child: Text(
                        customerDate(customer.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dark
                              ? AppColor.darkTextSecondary
                              : AppColor.adminDate,
                          fontSize: AppFontSizes.size10_5,
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
