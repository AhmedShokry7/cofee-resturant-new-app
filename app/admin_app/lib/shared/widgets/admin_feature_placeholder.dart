import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/navigation/admin_destination.dart';

/// Placeholder for a feature that already exists in the database but is not
/// implemented in the admin app yet.
///
/// It shows the tables that back the feature so it is clear what the database
/// holds and what the dashboard is still missing.
class AdminFeaturePlaceholder extends StatelessWidget {
  const AdminFeaturePlaceholder({super.key, required this.destination});

  final AdminDestination destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pageHorizontalPadding,
        vertical: AppDimensions.pageVerticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            destination.label,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: AppFontWeights.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.pageCardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: AppDimensions.placeholderIconBox,
                        height: AppDimensions.placeholderIconBox,
                        decoration: BoxDecoration(
                          color: AppColor.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.xxl),
                        ),
                        child: Icon(
                          destination.icon,
                          size: 36,
                          color: AppColor.primaryColor,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.comingSoon,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: AppFontWeights.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              S.featureNotBuilt,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColor.greyColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    S.databaseTables,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: AppFontWeights.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (destination.tables.isEmpty)
                    Text(
                      S.noDatabaseTables,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColor.greyColor,
                      ),
                    )
                  else
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final table in destination.tables)
                          _TableChip(table: table),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableChip extends StatelessWidget {
  const _TableChip({required this.table});

  final String table;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        table,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
