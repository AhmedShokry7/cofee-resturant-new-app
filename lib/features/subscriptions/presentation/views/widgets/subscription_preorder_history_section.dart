import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/orders/presentation/views/order_details_page.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_preorder_repository.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

class SubscriptionPreorderHistorySection extends StatefulWidget {
  const SubscriptionPreorderHistorySection({
    super.key,
    required this.subscriptionId,
    this.repository = const SubscriptionPreorderRepository(),
  });

  final String subscriptionId;
  final SubscriptionPreorderRepository repository;

  @override
  State<SubscriptionPreorderHistorySection> createState() =>
      _SubscriptionPreorderHistorySectionState();
}

class _SubscriptionPreorderHistorySectionState
    extends State<SubscriptionPreorderHistorySection> {
  late Future<List<SubscriptionPreorderRecord>> _history;

  @override
  void initState() {
    super.initState();
    _history = widget.repository.history(widget.subscriptionId);
  }

  @override
  void didUpdateWidget(covariant SubscriptionPreorderHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subscriptionId != widget.subscriptionId ||
        oldWidget.repository != widget.repository) {
      _history = widget.repository.history(widget.subscriptionId);
    }
  }

  Future<void> _openOrder(SubscriptionPreorderRecord record) async {
    final repository = context.read<OrdersRepository>();
    if (repository is! OrderLinesRepository) return;
    final linesRepository = repository as OrderLinesRepository;
    final lines = await linesRepository.orderLines(record.orderId);
    if (!mounted || lines.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailsPage(order: lines.first, lines: lines),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(S.subscriptionPreorderHistory),
      SizedBox(height: AppSpacing.xs),
      FutureBuilder<List<SubscriptionPreorderRecord>>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(S.couldNotLoadSubscriptionPreorders),
              ),
            );
          }
          if (!snapshot.hasData) {
            return Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: SizedBox.square(
                    dimension: AppSizes.px24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            );
          }
          final records = snapshot.data!;
          if (records.isEmpty) {
            return Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(S.noUsageYet),
              ),
            );
          }
          return Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final record in records)
                  ListTile(
                    title: Text(S.orderNumber(record.orderNumber)),
                    subtitle: Padding(
                      padding: EdgeInsets.only(top: AppSpacing.xs),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(record.branchName),
                          Text(
                            '${S.pickupSchedule}: ${Formatters.date(record.scheduledPickupAt)}',
                          ),
                          Text(
                            '${record.orderStatus.label} • ${record.consumptionStatusLabel}',
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openOrder(record),
                  ),
              ],
            ),
          );
        },
      ),
    ],
  );
}
