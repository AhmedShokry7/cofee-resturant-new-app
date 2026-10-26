import 'dart:math' as math;

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
import 'package:admin_app/shared/widgets/currency_icon.dart';

class CustomerTable extends StatelessWidget {
  const CustomerTable({
    super.key,
    required this.customers,
    required this.isSelected,
    required this.allSelected,
    required this.onToggle,
    required this.onToggleAll,
    required this.onOpen,
  });

  final List<AdminCustomer> customers;
  final bool Function(AdminCustomer customer) isSelected;
  final bool? allSelected;
  final ValueChanged<AdminCustomer> onToggle;
  final VoidCallback onToggleAll;
  final ValueChanged<AdminCustomer> onOpen;

  static const _checkboxWidth = 52.0;
  static const _actionWidth = 44.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math
          .min(math.max(constraints.maxWidth, 1000), 1600)
          .toDouble();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _Header(allSelected: allSelected, onToggleAll: onToggleAll),
                for (final customer in customers)
                  _Row(
                    customer: customer,
                    selected: isSelected(customer),
                    onToggle: () => onToggle(customer),
                    onTap: () => onOpen(customer),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.allSelected, required this.onToggleAll});

  final bool? allSelected;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: dark ? AppColor.darkSurfaceContainer : AppColor.adminTableHeader,
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.adminTableBorder,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: CustomerTable._checkboxWidth,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: CustomerCheckbox(
                value: allSelected,
                onChanged: (_) => onToggleAll(),
                label: S.customersSelectAll,
              ),
            ),
          ),
          Expanded(flex: 5, child: _cell(S.customer, dark)),
          Expanded(flex: 2, child: _cell(S.ordersCountLabel, dark)),
          Expanded(flex: 2, child: _cell(S.totalSpent, dark)),
          Expanded(flex: 2, child: _cell(S.lastOrder, dark)),
          Expanded(flex: 2, child: _cell(S.customersJoinDate, dark)),
          const SizedBox(width: CustomerTable._actionWidth),
        ],
      ),
    );
  }

  Widget _cell(String label, bool dark) => Text(
    label,
    textAlign: TextAlign.start,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
      fontSize: AppFontSizes.size10,
      fontWeight: AppFontWeights.medium,
      height: AppTextHeights.line1_5,
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.customer,
    required this.selected,
    required this.onToggle,
    required this.onTap,
  });

  final AdminCustomer customer;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final selectedColor = dark
        ? AppColor.adminAccent.withValues(alpha: .12)
        : AppColor.adminRowSelected;
    final body = dark ? AppColor.darkText : AppColor.adminBody;
    final subtle = dark ? AppColor.darkTextSecondary : AppColor.adminSubtle;
    final date = dark ? AppColor.darkTextSecondary : AppColor.adminDate;
    final contact = customerContactLine(customer);
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Material(
      color: selected ? selectedColor : AppColor.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: dark ? AppColor.darkBorder : AppColor.adminRowBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: CustomerTable._checkboxWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: CustomerCheckbox(
                    value: selected,
                    onChanged: (_) => onToggle(),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    CustomerAvatar(customer: customer),
                    const SizedBox(width: AppSizes.px10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerDisplayName(customer),
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
                  customerOrders(customer.ordersCount),
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
              Expanded(
                flex: 2,
                child: Text(
                  customerLastOrder(customer.lastOrderAt),
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
                flex: 2,
                child: Text(
                  customerDate(customer.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: date,
                    fontSize: AppFontSizes.size10_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              SizedBox(
                width: CustomerTable._actionWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: AppIcon(
                    rtl ? AppIcons.arrowLeft01 : AppIcons.arrowRight01,
                    size: 16,
                    color: AppColor.adminMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerCheckbox extends StatelessWidget {
  const CustomerCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool? value;
  final ValueChanged<bool?> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final checkbox = SizedBox(
      width: AppSizes.px20,
      height: AppSizes.px20,
      child: Checkbox(
        value: value,
        tristate: true,
        onChanged: (next) => onChanged(next ?? false),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        side: BorderSide(
          color: dark ? AppColor.darkTextSecondary : AppColor.quietNeutralInk,
          width: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        activeColor: AppColor.adminAccent,
        checkColor: AppColor.whiteColor,
      ),
    );
    final text = label?.trim() ?? '';
    if (text.isEmpty) return checkbox;
    return Semantics(label: text, child: checkbox);
  }
}
