import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filter_dropdown.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filter_values.dart';

class OrderFilterControls extends StatelessWidget {
  const OrderFilterControls({
    super.key,
    required this.value,
    required this.branches,
    required this.onChanged,
  });

  final OrderFilterValues value;
  final List<AdminBranch> branches;
  final ValueChanged<OrderFilterValues> onChanged;

  @override
  Widget build(BuildContext context) {
    final all = <String, String>{'': S.ordersAll};
    final filters = <Widget>[
      OrderFilterDropdown(
        label: S.fulfillmentFilter,
        value: value.fulfillment,
        items: _items([
          ...all.entries.map((entry) => (entry.key, entry.value)),
          for (final code in OrderFulfillmentView.allCodes)
            (code, OrderFulfillmentView.of(code).label),
        ]),
        onChanged: (v) => onChanged(value.copyWith(fulfillment: v)),
      ),
      OrderFilterDropdown(
        label: S.paymentStatusFilter,
        value: value.paymentStatus,
        items: _items([
          ...all.entries.map((entry) => (entry.key, entry.value)),
          for (final code in OrderPaymentStatusView.allCodes)
            (code, OrderPaymentStatusView.of(code).label),
        ]),
        onChanged: (v) => onChanged(value.copyWith(paymentStatus: v)),
      ),
      if (branches.isNotEmpty)
        OrderFilterDropdown(
          label: S.ordersBranch,
          value: value.branchId,
          items: _items([
            ...all.entries.map((entry) => (entry.key, entry.value)),
            for (final branch in branches)
              (branch.id, branch.nameFor(AppLocale.instance.language)),
          ]),
          onChanged: (v) => onChanged(value.copyWith(branchId: v)),
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520
            ? (filters.length > 1 ? 2 : 1)
            : filters.length;
        final width =
            (constraints.maxWidth - (columns - 1) * AppDimensions.sm) / columns;
        return Wrap(
          spacing: AppDimensions.sm,
          runSpacing: AppDimensions.sm,
          children: [
            for (final filter in filters) SizedBox(width: width, child: filter),
          ],
        );
      },
    );
  }

  List<DropdownMenuItem<String>> _items(List<(String, String)> values) => [
    for (final (code, label) in values)
      DropdownMenuItem<String>(
        value: code,
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
  ];
}
