import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer_metrics.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_directory.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_metrics_cards.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_page_header.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';

class CustomerPageBody extends StatelessWidget {
  const CustomerPageBody({
    super.key,
    required this.customers,
    required this.metrics,
    required this.search,
    required this.onSearchChanged,
    required this.onOpen,
    required this.onExport,
    required this.exporting,
    this.errorMessage,
    this.onRefresh,
  });

  final List<AdminCustomer> customers;
  final AdminCustomerMetrics metrics;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AdminCustomer> onOpen;
  final ValueChanged<List<AdminCustomer>> onExport;
  final ValueListenable<bool> exporting;
  final String? errorMessage;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CustomerPageHeader(),
          if (errorMessage != null)
            AdminInlineError(message: errorMessage!, onRetry: onRefresh),
          const SizedBox(height: AppSizes.px8),
          CustomerMetricsCards(metrics: metrics),
          const SizedBox(height: AppSizes.px16),
          Expanded(
            child: CustomerDirectory(
              customers: customers,
              search: search,
              onSearchChanged: onSearchChanged,
              onOpen: onOpen,
              onExport: onExport,
              exporting: exporting,
            ),
          ),
        ],
      ),
    );
  }
}
