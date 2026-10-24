import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';

/// The status, fulfilment and payment status used to filter the orders list.
@immutable
class OrderFilterValues {
  const OrderFilterValues({
    this.status = '',
    this.fulfillment = '',
    this.paymentStatus = '',
    this.branchId = '',
  });

  final String status;
  final String fulfillment;
  final String paymentStatus;
  final String branchId;

  bool get isActive =>
      status.isNotEmpty ||
      fulfillment.isNotEmpty ||
      paymentStatus.isNotEmpty ||
      branchId.isNotEmpty;

  OrderFilterValues copyWith({
    String? status,
    String? fulfillment,
    String? paymentStatus,
    String? branchId,
  }) {
    return OrderFilterValues(
      status: status ?? this.status,
      fulfillment: fulfillment ?? this.fulfillment,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      branchId: branchId ?? this.branchId,
    );
  }
}

/// Responsive filters for the orders list.
class OrderFilters extends StatelessWidget {
  const OrderFilters({
    super.key,
    required this.value,
    required this.onChanged,
    this.branches = const <AdminBranch>[],
  });

  final OrderFilterValues value;
  final ValueChanged<OrderFilterValues> onChanged;
  final List<AdminBranch> branches;

  static const double _compactBreakpoint = 640;

  void _update({
    String? status,
    String? fulfillment,
    String? paymentStatus,
    String? branchId,
  }) {
    onChanged(
      value.copyWith(
        status: status,
        fulfillment: fulfillment,
        paymentStatus: paymentStatus,
        branchId: branchId,
      ),
    );
  }

  Widget _buildDropdown<T>({
    required BuildContext context,
    required String label,
    required T currentValue,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onSelected,
  }) {
    final theme = Theme.of(context);

    return DropdownButtonFormField<T>(
      initialValue: currentValue,
      isExpanded: true,
      isDense: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: theme.inputDecorationTheme.labelStyle,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.fieldVerticalPadding,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
      ),
      items: items,
      onChanged: (selected) {
        if (selected != null) {
          onSelected(selected);
        }
      },
    );
  }

  List<DropdownMenuItem<String>> _buildStatusItems() {
    return [
      DropdownMenuItem(
        value: '',
        child: Text(S.allStatuses),
      ),
      for (final code in OrderStatusView.allCodes)
        DropdownMenuItem(
          value: code,
          child: Text(
            OrderStatusView.of(code).label,
            style: TextStyle(
              color: OrderStatusView.of(code).color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ];
  }

  List<DropdownMenuItem<String>> _buildFulfillmentItems() {
    return [
      DropdownMenuItem(
        value: '',
        child: Text(S.allStatuses),
      ),
      for (final code in OrderFulfillmentView.allCodes)
        DropdownMenuItem(
          value: code,
          child: Text(OrderFulfillmentView.of(code).label),
        ),
    ];
  }

  List<DropdownMenuItem<String>> _buildPaymentItems() {
    return [
      DropdownMenuItem(
        value: '',
        child: Text(S.allStatuses),
      ),
      for (final code in OrderPaymentStatusView.allCodes)
        DropdownMenuItem(
          value: code,
          child: Text(
            OrderPaymentStatusView.of(code).label,
            style: TextStyle(
              color: OrderPaymentStatusView.of(code).color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ];
  }

  List<DropdownMenuItem<String>> _buildBranchItems() {
    return [
      DropdownMenuItem(
        value: '',
        child: Text(S.allStatuses),
      ),
      for (final branch in branches)
        DropdownMenuItem(
          value: branch.id,
          child: Text(branch.nameFor(AppLocale.instance.language)),
        ),
    ];
  }

  Widget _buildClearButton() {
    return IconButton(
      tooltip: S.clearFilters,
      visualDensity: VisualDensity.compact,
      icon: const Icon(
        HugeIcons.strokeRoundedCancel01,
        size: AppDimensions.borderStrong,
        color: AppColor.greyColor,
      ),
      onPressed: () => onChanged(const OrderFilterValues()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactBreakpoint;

        final filters = [
          _buildDropdown<String>(
            context: context,
            label: S.statusFilter,
            currentValue: value.status,
            items: _buildStatusItems(),
            onSelected: (selected) => _update(status: selected),
          ),
          _buildDropdown<String>(
            context: context,
            label: S.fulfillmentFilter,
            currentValue: value.fulfillment,
            items: _buildFulfillmentItems(),
            onSelected: (selected) => _update(fulfillment: selected),
          ),
          _buildDropdown<String>(
            context: context,
            label: S.paymentStatusFilter,
            currentValue: value.paymentStatus,
            items: _buildPaymentItems(),
            onSelected: (selected) => _update(paymentStatus: selected),
          ),
          _buildDropdown<String>(
            context: context,
            label: S.branchLabel,
            currentValue: value.branchId,
            items: _buildBranchItems(),
            onSelected: (selected) => _update(branchId: selected),
          ),
        ];

        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.md),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < filters.length; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == filters.length - 1
                              ? 0
                              : AppDimensions.sm,
                        ),
                        child: filters[index],
                      ),
                    if (value.isActive)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _buildClearButton(),
                      ),
                  ],
                )
              : Row(
                  children: [
                    for (var index = 0; index < filters.length; index++) ...[
                      if (index > 0)
                        const SizedBox(width: AppDimensions.sm),
                      Expanded(child: filters[index]),
                    ],
                    if (value.isActive) ...[
                      const SizedBox(width: AppDimensions.xs),
                      _buildClearButton(),
                    ],
                  ],
                ),
        );
      },
    );
  }
}
