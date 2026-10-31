import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/features/orders/presentation/order_refusal_reasons.dart';
import 'package:admin_app/features/orders/presentation/export/order_excel_exporter.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_cubit.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_state.dart';
import 'package:admin_app/features/orders/presentation/pages/order_detail_page.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_page_body.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

part 'order_page_export.dart';
part 'order_page_actions.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({
    super.key,
    required this.searchController,
    this.cubit,
    this.canManage = true,
  });

  static const String routeName = '/orders';

  final AdminSearchController searchController;
  final AdminOrderCubit? cubit;

  /// False for a role that may read orders but not move them; the shell passes
  /// the same `orders.status.update` the mutation RPCs demand.
  final bool canManage;

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  late final AdminOrderCubit _cubit;
  late final bool _ownsCubit;
  String _searchQuery = '';
  final ValueNotifier<bool> _exporting = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminOrderCubit();
    if (_ownsCubit) {
      _cubit.load();
      _cubit.loadStatusRules();
      _cubit.startLiveUpdates();
    }
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    _exporting.dispose();
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() => _searchQuery = query.trim());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminOrderCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminOrderCubit, AdminOrderState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasOrders) {
            return const AdminLoadingView();
          }
          if (state.status == AdminOrderStatus.failure && !state.hasOrders) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.load,
            );
          }
          return OrderPageBody(
            orders: state.orders,
            branches: state.branches,
            search: _searchQuery,
            canManage: widget.canManage,
            statusRules: state.statusRules,
            onSearchChanged: widget.searchController.update,
            onChangeStatus: _changeStatus,
            onOpen: _openOrder,
            onRefresh: _cubit.refreshLive,
            onExport: _exportOrders,
            exporting: _exporting,
            errorMessage: state.errorMessage,
          );
        },
      ),
    );
  }
}
