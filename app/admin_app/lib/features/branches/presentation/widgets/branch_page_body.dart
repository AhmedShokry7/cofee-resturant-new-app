import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/branches/domain/entities/admin_branch_metrics.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_directory.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_metrics_cards.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_read_only_hint.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

class BranchPageBody extends StatelessWidget {
  const BranchPageBody({
    super.key,
    required this.branches,
    required this.metrics,
    required this.search,
    required this.onSearchChanged,
    required this.canManage,
    required this.canManagePricing,
    required this.onAdd,
    required this.onEdit,
    required this.onChangeImage,
    required this.onManageDelivery,
    required this.onToggleActive,
    required this.onDelete,
    this.onManagePricing,
    this.errorMessage,
    this.onRefresh,
  });

  final List<AdminBranch> branches;
  final AdminBranchMetrics metrics;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final bool canManage;
  final bool canManagePricing;
  final VoidCallback onAdd;
  final ValueChanged<AdminBranch> onEdit;
  final ValueChanged<AdminBranch> onChangeImage;
  final ValueChanged<AdminBranch> onManageDelivery;
  final ValueChanged<AdminBranch>? onManagePricing;
  final ValueChanged<AdminBranch> onToggleActive;
  final ValueChanged<AdminBranch> onDelete;
  final String? errorMessage;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 840 || constraints.maxHeight < 640;
          final directory = BranchDirectory(
            branches: branches,
            search: search,
            onSearchChanged: onSearchChanged,
            canManage: canManage,
            canManagePricing: canManagePricing,
            onAdd: onAdd,
            onEdit: onEdit,
            onChangeImage: onChangeImage,
            onManageDelivery: onManageDelivery,
            onManagePricing: onManagePricing,
            onToggleActive: onToggleActive,
            onDelete: onDelete,
          );
          final sections = <Widget>[
            AdminPageHeader(
              title: S.branches,
              subtitle: S.branchesDescription,
              actions: [
                if (canManage)
                  CustomBtn(
                    key: const Key('branch-add'),
                    text: S.addBranch,
                    onPressed: onAdd,
                    leadingIcon: const Icon(AppIcons.add01, size: 18),
                    height: 42,
                    borderRadius: AppRadius.pill,
                    backgroundColor: AppColor.primaryColor,
                    textColor: AppColor.whiteColor,
                  ),
              ],
              footer: canManage
                  ? null
                  : AdminReadOnlyHint(message: S.branchesReadOnly),
            ),
            if (errorMessage != null)
              AdminInlineError(message: errorMessage!, onRetry: onRefresh),
            const SizedBox(height: AppSizes.px8),
            BranchMetricsCards(metrics: metrics),
            const SizedBox(height: AppSizes.px16),
          ];
          if (compact) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...sections,
                  SizedBox(
                    height: AppDimensions.directoryCanvasHeightMd,
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
