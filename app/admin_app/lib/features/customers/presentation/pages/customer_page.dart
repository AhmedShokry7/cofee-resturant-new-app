import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/customers/presentation/export/customer_excel_exporter.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';
import 'package:admin_app/features/customers/presentation/manager/admin_customer_cubit.dart';
import 'package:admin_app/features/customers/presentation/manager/admin_customer_state.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_detail_dialog.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_page_body.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

part 'customer_page_export.dart';

class CustomerPage extends StatefulWidget {
  const CustomerPage({
    super.key,
    required this.searchController,
    this.canManage = false,
    this.cubit,
  });

  static const String routeName = '/customers';

  final AdminSearchController searchController;

  /// customers.write وحدها تفتح لوحة الأوسمة والملاحظات: القراءة تعرض السجل.
  final bool canManage;
  final AdminCustomerCubit? cubit;

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  late final AdminCustomerCubit _cubit;
  late final bool _ownsCubit;
  String _searchQuery = '';
  final ValueNotifier<bool> _exporting = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminCustomerCubit();
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
    setState(() => _searchQuery = query.trim());
  }

  void _openCustomer(AdminCustomer customer) {
    showCustomerDetailDialog(
      context: context,
      cubit: _cubit,
      customer: customer,
      canManage: widget.canManage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminCustomerCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminCustomerCubit, AdminCustomerState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasCustomers) {
            return const AdminLoadingView();
          }
          if (state.status == AdminCustomerStatus.failure &&
              !state.hasCustomers) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.load,
            );
          }
          return CustomerPageBody(
            customers: state.customers,
            metrics: state.metrics,
            search: _searchQuery,
            onSearchChanged: widget.searchController.update,
            onOpen: _openCustomer,
            onExport: _exportCustomers,
            exporting: _exporting,
            errorMessage: state.status == AdminCustomerStatus.failure
                ? state.errorMessage
                : null,
            onRefresh: _cubit.load,
          );
        },
      ),
    );
  }
}
