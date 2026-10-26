import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_filters.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_metrics.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_ticket.dart';
import 'package:admin_app/features/kitchen/presentation/widgets/kitchen_board.dart';
import 'package:admin_app/features/kitchen/presentation/widgets/kitchen_metrics_cards.dart';
import 'package:admin_app/features/kitchen/presentation/widgets/kitchen_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_read_only_hint.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

class KitchenPageBody extends StatelessWidget {
  const KitchenPageBody({
    super.key,
    required this.searchController,
    required this.tickets,
    required this.filters,
    required this.metrics,
    required this.now,
    required this.branchId,
    required this.isRefreshing,
    required this.lastUpdatedAt,
    required this.busyTicketIds,
    required this.busyItemIds,
    required this.hasActiveFilters,
    required this.canManage,
    required this.onSearchChanged,
    required this.onBranchChanged,
    required this.onClearFilters,
    required this.onRefresh,
    required this.onTicketStatus,
    required this.onToggleItem,
    this.errorMessage,
  });

  final TextEditingController searchController;
  final List<AdminKitchenTicket> tickets;
  final AdminKitchenFilters filters;
  final AdminKitchenMetrics metrics;
  final DateTime now;
  final String? branchId;
  final bool isRefreshing;
  final DateTime? lastUpdatedAt;
  final Set<String> busyTicketIds;
  final Set<String> busyItemIds;
  final bool hasActiveFilters;
  final bool canManage;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onBranchChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onRefresh;
  final void Function(AdminKitchenTicket ticket, KitchenTicketStatus status)
  onTicketStatus;
  final ValueChanged<AdminKitchenTicketItem> onToggleItem;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBranch = branchId == null && filters.branches.length > 1;

    return AdminPageFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 900 || constraints.maxHeight < 620;
          final board = KitchenBoard(
            tickets: tickets,
            now: now,
            canManage: canManage,
            showBranch: showBranch,
            hasActiveFilters: hasActiveFilters,
            busyTicketIds: busyTicketIds,
            busyItemIds: busyItemIds,
            onTicketStatus: onTicketStatus,
            onToggleItem: onToggleItem,
            onClearFilters: onClearFilters,
          );
          final sections = <Widget>[
            AdminPageHeader(
              title: S.kitchen,
              subtitle: S.kitchenSubtitle,
              actions: [
                _LivePill(
                  isRefreshing: isRefreshing,
                  lastUpdatedAt: lastUpdatedAt,
                ),
                if (metrics.completedToday > 0)
                  _CompletedTodayChip(count: metrics.completedToday),
                AdminToolbarButton(
                  label: S.refresh,
                  icon: AppIcons.refresh,
                  onPressed: onRefresh,
                  busy: isRefreshing,
                ),
              ],
              footer: canManage
                  ? null
                  : AdminReadOnlyHint(message: S.kitchenReadOnly),
            ),
            if (errorMessage != null)
              AdminInlineError(message: errorMessage!, onRetry: onRefresh),
            const SizedBox(height: AppSizes.px8),
            KitchenMetricsCards(metrics: metrics),
            const SizedBox(height: AppSizes.px14),
            KitchenToolbar(
              searchController: searchController,
              onSearchChanged: onSearchChanged,
              branches: filters.branches,
              branchId: branchId,
              onBranchChanged: onBranchChanged,
              hasActiveFilters: hasActiveFilters,
              onClearFilters: onClearFilters,
            ),
            const SizedBox(height: AppSizes.px6),
            SizedBox(
              height: AppSizes.px2,
              child: isRefreshing
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColor.adminAccent,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: AppSizes.px8),
          ];

          if (compact) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...sections,
                  SizedBox(
                    height: AppDimensions.directoryCanvasHeightXl,
                    child: board,
                  ),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...sections,
              Expanded(child: board),
            ],
          );
        },
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.isRefreshing, required this.lastUpdatedAt});

  final bool isRefreshing;
  final DateTime? lastUpdatedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final updated = lastUpdatedAt == null
        ? S.kitchenUpdatedNow
        : S.kitchenUpdatedAt(localizedTime(lastUpdatedAt!));
    return Tooltip(
      message: updated,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: adminFlagBackground(
            theme,
            AppColor.trendPositive,
            AppColor.trendPositiveSurface,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColor.trendPositive.withValues(alpha: .25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColor.trendPositive,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSizes.px6),
            Text(
              S.kitchenLive,
              style: TextStyle(
                color: adminFlagForeground(theme, AppColor.trendPositive),
                fontSize: AppFontSizes.size10_5,
                fontWeight: AppFontWeights.semiBold,
                height: AppTextHeights.line1_5,
              ),
            ),
            if (isRefreshing) ...[
              const SizedBox(width: AppSizes.px6),
              SizedBox(
                width: AppSizes.px12,
                height: AppSizes.px12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: adminFlagForeground(theme, AppColor.trendPositive),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompletedTodayChip extends StatelessWidget {
  const _CompletedTodayChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminControlBorderColor(theme)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.taskDone01, size: 14, color: adminMutedColor(theme)),
          const SizedBox(width: AppSizes.px6),
          Text(
            localizeDigits(S.kitchenCompletedTodayValue(count)),
            style: TextStyle(
              color: adminBodyColor(theme),
              fontSize: AppFontSizes.size10,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_5,
            ),
          ),
        ],
      ),
    );
  }
}
