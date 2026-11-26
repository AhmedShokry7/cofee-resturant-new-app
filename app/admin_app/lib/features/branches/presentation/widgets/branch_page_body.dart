import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/features/branches/domain/entities/admin_branch_metrics.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_directory.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_metrics_cards.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_directory_page_layout.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_read_only_hint.dart';
import 'package:admin_app/shared/widgets/admin_create_button.dart';

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
    this.onManagePickupSchedules,
    this.onManageCancellationPolicy,
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
  final VoidCallback? onManagePickupSchedules;
  final VoidCallback? onManageCancellationPolicy;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: LayoutBuilder(
        builder: (context, _) {
          // السكرول على الصفحة كاملة: الترويسة والبطاقات والقائمة تتحرك
          // معًا، والقائمة تأخذ ارتفاعًا متجاوبًا مع مساحة الشاشة.

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
                if (canManage && onManagePickupSchedules != null)
                  AdminCreateButton(
                    label: S.pickupScheduleTitle,
                    onPressed: onManagePickupSchedules!,
                  ),
                if (canManage && onManageCancellationPolicy != null)
                  AdminCreateButton(
                    label: S.reservationCancellationPolicy,
                    onPressed: onManageCancellationPolicy!,
                  ),
                if (canManage)
                  AdminCreateButton(
                    key: const Key('branch-add'),
                    label: S.addBranch,
                    onPressed: onAdd,
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
          return AdminDirectoryPageLayout(
            sections: sections,
            directory: directory,
          );
        },
      ),
    );
  }
}
