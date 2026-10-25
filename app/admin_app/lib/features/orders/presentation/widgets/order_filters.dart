import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filter_button_bar.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filter_controls.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filter_values.dart';

export 'order_filter_values.dart';

part 'order_filters_state.dart';

class OrderFilters extends StatefulWidget {
  const OrderFilters({
    super.key,
    required this.value,
    required this.onChanged,
    this.branches = const [],
    this.trailing,
  });

  final OrderFilterValues value;
  final ValueChanged<OrderFilterValues> onChanged;
  final List<AdminBranch> branches;
  final Widget? trailing;

  @override
  State<OrderFilters> createState() => _OrderFiltersState();
}
