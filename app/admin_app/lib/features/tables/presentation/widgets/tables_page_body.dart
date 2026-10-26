import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/dining_enums.dart';
import 'package:admin_app/core/models/dining_reservation.dart';
import 'package:admin_app/core/models/dining_table.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/tables/presentation/manager/dining_tables_state.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_directory.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_metrics_cards.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_read_only_hint.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

class TablesPageBody extends StatelessWidget {
  const TablesPageBody({
    super.key,
    required this.state,
    required this.canManage,
    required this.errorMessage,
    required this.onSearchChanged,
    required this.onAreaChanged,
    required this.onBranchChanged,
    required this.onViewChanged,
    required this.onClearFilters,
    required this.onRefresh,
    required this.onAddTable,
    required this.onAddReservation,
    required this.onEditTable,
    required this.onBookTable,
    required this.onOpenReservation,
    required this.onToggleTable,
    required this.onDeleteTable,
    required this.onEditReservation,
    required this.onSeatReservation,
    required this.onCompleteReservation,
    required this.onCancelReservation,
    required this.onNoShowReservation,
  });

  final DiningTablesState state;
  final bool canManage;
  final String? errorMessage;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DiningArea?> onAreaChanged;
  final ValueChanged<String> onBranchChanged;
  final ValueChanged<DiningView> onViewChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onRefresh;
  final VoidCallback onAddTable;
  final VoidCallback onAddReservation;
  final ValueChanged<DiningTable> onEditTable;
  final ValueChanged<DiningTable> onBookTable;
  final ValueChanged<DiningTable> onOpenReservation;
  final ValueChanged<DiningTable> onToggleTable;
  final ValueChanged<DiningTable> onDeleteTable;
  final ValueChanged<DiningReservation> onEditReservation;
  final ValueChanged<DiningReservation> onSeatReservation;
  final ValueChanged<DiningReservation> onCompleteReservation;
  final ValueChanged<DiningReservation> onCancelReservation;
  final ValueChanged<DiningReservation> onNoShowReservation;

  @override
  Widget build(BuildContext context) {
    final metrics = state.metrics;
    return AdminPageFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 840 || constraints.maxHeight < 640;

          final directory = DiningDirectory(
            tables: state.filteredTables,
            allTables: state.tables,
            openReservations: state.openReservations,
            closedReservations: state.closedReservations,
            branches: state.branches,
            branchId: state.branchId,
            search: state.search,
            area: state.area,
            view: state.view,
            canManage: canManage,
            isRefreshing: state.isRefreshing,
            hasActiveFilters: state.hasActiveFilters,
            onSearchChanged: onSearchChanged,
            onAreaChanged: onAreaChanged,
            onBranchChanged: onBranchChanged,
            onViewChanged: onViewChanged,
            onClearFilters: onClearFilters,
            onRefresh: onRefresh,
            onAddTable: onAddTable,
            onAddReservation: onAddReservation,
            onEditTable: onEditTable,
            onBookTable: onBookTable,
            onOpenReservation: onOpenReservation,
            onToggleTable: onToggleTable,
            onDeleteTable: onDeleteTable,
            onEditReservation: onEditReservation,
            onSeatReservation: onSeatReservation,
            onCompleteReservation: onCompleteReservation,
            onCancelReservation: onCancelReservation,
            onNoShowReservation: onNoShowReservation,
          );

          final sections = <Widget>[
            AdminPageHeader(
              title: S.tables,
              subtitle: S.tablesSubtitle,
              actions: [
                if (canManage)
                  CustomBtn(
                    key: const Key('tables-add'),
                    text: S.addTable,
                    onPressed: onAddTable,
                    leadingIcon: const Icon(AppIcons.add01, size: 18),
                    height: 42,
                    borderRadius: AppRadius.pill,
                    backgroundColor: AppColor.primaryColor,
                    textColor: AppColor.whiteColor,
                  ),
                if (canManage)
                  CustomBtn(
                    key: const Key('tables-book'),
                    text: S.addReservation,
                    onPressed: onAddReservation,
                    enabled: state.tables.isNotEmpty,
                    leadingIcon: const Icon(AppIcons.calendarAdd01, size: 17),
                    height: 42,
                    borderRadius: AppRadius.pill,
                    backgroundColor: AppColor.adminAccentSurface,
                    textColor: AppColor.adminAccent,
                  ),
              ],
              footer: canManage
                  ? null
                  : AdminReadOnlyHint(message: S.tablesReadOnly),
            ),
            if (errorMessage != null)
              AdminInlineError(message: errorMessage!, onRetry: onRefresh),
            const SizedBox(height: AppSizes.px8),
            DiningMetricsCards(metrics: metrics),
            const SizedBox(height: AppSizes.px16),
          ];

          if (compact) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...sections,
                  SizedBox(
                    height: AppDimensions.directoryCanvasHeightHuge,
                    child: directory,
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...sections,
              Expanded(child: directory),
            ],
          );
        },
      ),
    );
  }
}
