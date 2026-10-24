import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/customers/data/models/admin_customer.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_analytics.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_records.dart';

/// The list of the customers beside the analytics panel, side by side on a
/// wide screen and stacked on a narrow one.
class CustomerPageBody extends StatelessWidget {
  const CustomerPageBody({
    super.key,
    required this.customers,
    required this.search,
    required this.onOpen,
  });

  /// Every loaded customer; the body filters them with [search].
  final List<AdminCustomer> customers;

  /// The word the admin is looking for.
  final String search;

  final void Function(AdminCustomer customer) onOpen;

  List<AdminCustomer> get _filtered {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return customers;
    return customers
        .where(
          (c) =>
              (c.fullName ?? '').toLowerCase().contains(q) ||
              (c.email ?? '').toLowerCase().contains(q) ||
              (c.phone ?? '').toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final list = CustomerRecords(customers: _filtered, onOpen: onOpen);
    final analytics = CustomerAnalyticsPanel(customers: customers);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: list),
              const SizedBox(width: AppDimensions.lg),
              SizedBox(width: 360, child: analytics),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(height: 320, child: analytics),
            const SizedBox(height: AppDimensions.lg),
            Expanded(child: list),
          ],
        );
      },
    );
  }
}
