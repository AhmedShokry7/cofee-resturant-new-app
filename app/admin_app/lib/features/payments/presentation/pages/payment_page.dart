import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/payments/data/models/admin_payment.dart';
import 'package:admin_app/features/payments/presentation/manager/admin_payment_cubit.dart';
import 'package:admin_app/features/payments/presentation/manager/admin_payment_state.dart';
import 'package:admin_app/features/payments/presentation/widgets/payment_records.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_page_title.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key, required this.searchController, this.cubit});

  static const String routeName = '/payments';

  final AdminSearchController searchController;
  final AdminPaymentCubit? cubit;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late final AdminPaymentCubit _cubit;
  late final bool _ownsCubit;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminPaymentCubit();
    if (_ownsCubit) _cubit.load();
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() => _searchQuery = query.trim().toLowerCase());
  }

  List<AdminPayment> _filtered(List<AdminPayment> payments) {
    if (_searchQuery.isEmpty) return payments;
    return payments
        .where((p) {
          return (p.customerName ?? '').toLowerCase().contains(_searchQuery) ||
              (p.orderNumber ?? '').toLowerCase().contains(_searchQuery) ||
              p.provider.toLowerCase().contains(_searchQuery) ||
              p.status.toLowerCase().contains(_searchQuery);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminPaymentCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminPaymentCubit, AdminPaymentState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasPayments) {
            return const AdminLoadingView();
          }
          if (state.status == AdminPaymentStatus.failure &&
              !state.hasPayments) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.load,
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.pageHorizontalPadding,
              vertical: AppDimensions.pageVerticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminPageTitle(S.payments),
                const SizedBox(height: AppDimensions.lg),
                Expanded(
                  child: PaymentRecords(payments: _filtered(state.payments)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
