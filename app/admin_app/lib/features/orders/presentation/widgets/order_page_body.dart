import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filters.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_page_header.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_records.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_status_filter_tabs.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_summary_cards.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_inline_error.dart';

part 'order_page_body_state.dart';

class OrderPageBody extends StatefulWidget {
  const OrderPageBody({
    super.key,
    required this.orders,
    this.branches = const [],
    required this.search,
    required this.onChangeStatus,
    required this.onOpen,
    required this.onRefresh,
    this.onExport,
    this.exporting,
    this.errorMessage,
  });
  final List<AdminOrder> orders;
  final List<AdminBranch> branches;
  final String search;
  final void Function(AdminOrder order, String status) onChangeStatus;
  final ValueChanged<AdminOrder> onOpen;
  final VoidCallback onRefresh;
  final ValueChanged<List<AdminOrder>>? onExport;
  final ValueListenable<bool>? exporting;
  final String? errorMessage;

  @override
  State<OrderPageBody> createState() => _OrderPageBodyState();
}
