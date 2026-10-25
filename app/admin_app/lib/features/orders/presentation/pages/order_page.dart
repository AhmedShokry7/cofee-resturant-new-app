import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/data/order_excel_exporter.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_cubit.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_state.dart';
import 'package:admin_app/features/orders/presentation/pages/order_detail_page.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_page_body.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

part 'order_page_export.dart';
part 'order_page_actions.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key, required this.searchController, this.cubit});

  static const String routeName = '/orders';

  final AdminSearchController searchController;
  final AdminOrderCubit? cubit;

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
    if (_ownsCubit) _cubit.load();
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
    setState(() => _searchQuery = query.trim().toLowerCase());
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
            onChangeStatus: _changeStatus,
            onOpen: _openOrder,
            onRefresh: _cubit.load,
            onExport: _exportOrders,
            exporting: _exporting,
            errorMessage: state.errorMessage,
          );
        },
      ),
    );
  }
}
