import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_page_header.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_records.dart';

/// The header and the grid of the branches, the whole content of the page.
class BranchPageBody extends StatelessWidget {
  const BranchPageBody({
    super.key,
    required this.branches,
    required this.search,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onChangeImage,
    required this.onManageDelivery,
    this.onManagePricing,
  });

  final List<AdminBranch> branches;
  final String search;
  final VoidCallback onAdd;
  final ValueChanged<AdminBranch> onEdit;
  final ValueChanged<AdminBranch> onDelete;
  final ValueChanged<AdminBranch> onToggleActive;
  final ValueChanged<AdminBranch> onChangeImage;
  final ValueChanged<AdminBranch> onManageDelivery;
  final ValueChanged<AdminBranch>? onManagePricing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pageHorizontalPadding,
        vertical: AppDimensions.pageVerticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BranchPageHeader(
            count: filterBranches(branches, search).length,
            onAdd: onAdd,
          ),
          const SizedBox(height: AppDimensions.lg),
          Expanded(
            child: BranchRecords(
              branches: branches,
              search: search,
              onEdit: onEdit,
              onDelete: onDelete,
              onToggleActive: onToggleActive,
              onChangeImage: onChangeImage,
              onManageDelivery: onManageDelivery,
              onManagePricing: onManagePricing,
            ),
          ),
        ],
      ),
    );
  }
}
