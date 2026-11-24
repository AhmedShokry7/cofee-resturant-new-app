import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription_metrics.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/widgets/subscription_directory.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/widgets/subscription_metrics_cards.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_create_button.dart';

class SubscriptionPageBody extends StatelessWidget {
  const SubscriptionPageBody({
    super.key,
    required this.subscriptions,
    required this.metrics,
    required this.search,
    required this.onSearchChanged,
    required this.onOpen,
    this.errorMessage,
    this.onRefresh,
    this.onCreate,
  });

  final List<AdminSubscription> subscriptions;
  final AdminSubscriptionMetrics metrics;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AdminSubscription> onOpen;
  final String? errorMessage;
  final VoidCallback? onRefresh;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: S.subscriptions,
            subtitle: S.subscriptionsDescription,
            actions: onCreate == null
                ? const <Widget>[]
                : [
                    AdminCreateButton(
                      label: S.subscriptionsCreateAction,
                      onPressed: onCreate,
                    ),
                  ],
          ),
          if (errorMessage != null)
            AdminInlineError(message: errorMessage!, onRetry: onRefresh),
          const SizedBox(height: AppSizes.px8),
          SubscriptionMetricsCards(metrics: metrics),
          const SizedBox(height: AppSizes.px16),
          Expanded(
            child: SubscriptionDirectory(
              subscriptions: subscriptions,
              search: search,
              onSearchChanged: onSearchChanged,
              onOpen: onOpen,
            ),
          ),
        ],
      ),
    );
  }
}
