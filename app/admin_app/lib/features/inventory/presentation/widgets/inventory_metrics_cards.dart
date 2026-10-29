import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_metrics.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_format.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';

class InventoryMetricsCards extends StatelessWidget {
  const InventoryMetricsCards({super.key, required this.metrics});

  final AdminInventoryMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final latest = metrics.latestMovementAt == null
        ? S.inventoryMetricNoMovement
        : S.inventoryMetricMovementHint(
            inventoryRelativeLabel(metrics.latestMovementAt),
          );
    final cards = <_MetricData>[
      _MetricData(
        label: S.inventoryMetricTotal,
        caption: localizeDigits(
          S.inventoryMetricTotalHint(metrics.categories, metrics.branches),
        ),
        value: localizeDigits('${metrics.total}'),
        icon: AppIcons.package,
        iconBackground: AppColor.adminAccentSurface,
        iconColor: AppColor.adminAccent,
      ),
      _MetricData(
        label: S.inventoryMetricValue,
        caption: S.inventoryMetricValueHint,
        value: inventoryMoney(metrics.stockValue),
        icon: AppIcons.coins01,
        iconBackground: AppColor.trendPositiveSurface,
        iconColor: AppColor.trendPositive,
        isMoney: true,
      ),
      _MetricData(
        label: S.inventoryMetricLow,
        caption: S.inventoryMetricLowHint,
        value: localizeDigits('${metrics.low}'),
        icon: AppIcons.alert02,
        iconBackground: AppColor.adminWarningSurface,
        iconColor: AppColor.adminWarning,
      ),
      _MetricData(
        label: S.inventoryMetricOut,
        caption: latest,
        value: localizeDigits('${metrics.out}'),
        icon: AppIcons.packageRemove,
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
                  value: card.value,
                  icon: card.icon,
                  iconBackground: card.iconBackground,
                  iconColor: card.iconColor,
                  isMoney: card.isMoney,
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
    this.isMoney = false,
  });

  final String label;
  final String caption;
  final String value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final bool isMoney;
}
