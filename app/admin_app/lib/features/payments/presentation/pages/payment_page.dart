import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/payments/data/models/admin_payment.dart';
import 'package:admin_app/features/payments/data/payment_excel_exporter.dart';
import 'package:admin_app/features/payments/data/payment_print_service.dart';
import 'package:admin_app/features/payments/presentation/manager/admin_payment_cubit.dart';
import 'package:admin_app/features/payments/presentation/manager/admin_payment_state.dart';
import 'package:admin_app/features/payments/presentation/widgets/payment_records.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

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
  bool _exporting = false;

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

  Future<void> _exportPayments(List<AdminPayment> payments) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final saved = await PaymentExcelExporter.save(payments);
      if (saved && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.paymentsExportSuccess)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.paymentsExportFailed)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _printPayments(List<AdminPayment> payments) async {
    final printed = await PaymentPrintService.printPayments(payments);
    if (!printed && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.paymentsPrintFailed)));
    }
  }

  Future<void> _printPayment(AdminPayment payment) async {
    final printed = await PaymentPrintService.printPayment(payment);
    if (!printed && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.paymentsPrintFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminPaymentCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminPaymentCubit, AdminPaymentState>(
        builder: (context, state) {
          final firstLoad = !state.hasPayments;
          final failed = state.status == AdminPaymentStatus.failure;
          final payments = filterPayments(state.payments, _searchQuery);
          final searching = _searchQuery.isNotEmpty;
          return AdminPageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminPageHeader(
                  title: S.payments,
                  subtitle: S.paymentsDescription,
                  actions: [
                    AdminToolbarButton(
                      label: S.paymentsExport,
                      icon: HugeIcons.strokeRoundedDownload02,
                      busy: _exporting,
                      onPressed: _exporting || payments.isEmpty
                          ? null
                          : () => _exportPayments(payments),
                    ),
                    AdminToolbarButton(
                      label: S.paymentsPrint,
                      icon: HugeIcons.strokeRoundedPrinter,
                      onPressed: payments.isEmpty
                          ? null
                          : () => _printPayments(payments),
                    ),
                  ],
                ),
                if (failed && !firstLoad)
                  AdminInlineError(
                    message: state.errorMessage ?? '',
                    onRetry: _cubit.load,
                  ),
                const SizedBox(height: AppDimensions.lg),
                Expanded(
                  child: firstLoad && state.isLoading
                      ? const AdminLoadingView()
                      : firstLoad && failed
                      ? AdminFailureView(
                          message: state.errorMessage,
                          onRetry: _cubit.load,
                        )
                      : PaymentRecords(
                          payments: payments,
                          searching: searching,
                          onPrint: _printPayment,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
