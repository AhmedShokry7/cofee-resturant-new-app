import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_stock_movement_metrics.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_format.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';

class StockMovementsMetricsCards extends StatelessWidget {
  const StockMovementsMetricsCards({super.key, required this.metrics});

  final AdminStockMovementMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final quiet = S.stockMovementsMetricNoActivity;
    final cards = <_MetricData>[
      _MetricData(
        label: S.stockMovementsMetricTotal,
        caption: localizeDigits(
          S.stockMovementsMetricTotalHint(metrics.counts, metrics.actors),
        ),
        value: localizeDigits('${metrics.total}'),
        icon: AppIcons.exchange01,
        iconBackground: AppColor.adminAccentSurface,
        iconColor: AppColor.adminAccent,
      ),
      _MetricData(
        label: S.stockMovementsMetricReceipts,
        caption: metrics.total == 0
            ? quiet
            : S.stockMovementsMetricReceiptsHint(
                inventoryMoney(metrics.receivedValue),
              ),
        captionIsMoney: metrics.total != 0,
        value: localizeDigits('${metrics.receipts}'),
        icon: AppIcons.arrowDown01,
        iconBackground: AppColor.trendPositiveSurface,
        iconColor: AppColor.trendPositive,
      ),
      _MetricData(
        label: S.stockMovementsMetricIssues,
        caption: metrics.total == 0
            ? quiet
            : S.stockMovementsMetricIssuesHint(
                inventoryMoney(metrics.issuedValue),
              ),
        captionIsMoney: metrics.total != 0,
        value: localizeDigits('${metrics.issues}'),
        icon: AppIcons.arrowUp01,
        iconBackground: AppColor.adminInfoSurface,
        iconColor: AppColor.adminInfo,
      ),
      _MetricData(
        label: S.stockMovementsMetricWaste,
        caption: metrics.total == 0
            ? quiet
            : S.stockMovementsMetricWasteHint(
                inventoryMoney(metrics.wasteValue),
              ),
        captionIsMoney: metrics.total != 0,
        value: localizeDigits('${metrics.waste}'),
        icon: AppIcons.delete02,
        iconBackground: AppColor.trendNegativeSurface,
        iconColor: AppColor.trendNegative,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < AppBreakpoints.wideLayout ? 2 : 4;
        const spacing = 13.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: AdminMetricCard(
                  label: card.label,
                  caption: card.caption,
                  captionIsMoney: card.captionIsMoney,
                  value: card.value,
                  icon: card.icon,
                  iconBackground: card.iconBackground,
                  iconColor: card.iconColor,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.caption,
    required this.value,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    this.captionIsMoney = false,
  });

  final String label;
  final String caption;
  final String value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final bool captionIsMoney;
}
