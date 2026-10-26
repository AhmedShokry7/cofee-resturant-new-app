import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/presentation/models/inventory_filters.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_format.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

class InventoryToolbar extends StatelessWidget {
  const InventoryToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.category,
    required this.onCategoryChanged,
    required this.branchId,
    required this.onBranchChanged,
    required this.categories,
    required this.branches,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final InventoryStatusFilter statusFilter;
  final ValueChanged<InventoryStatusFilter> onStatusChanged;
  final String? category;
  final ValueChanged<String?> onCategoryChanged;
  final String? branchId;
  final ValueChanged<String?> onBranchChanged;
  final List<AdminInventoryCategoryOption> categories;
  final List<AdminInventoryBranchOption> branches;
  final VoidCallback onClearFilters;

  bool get _hasActiveFilters =>
      statusFilter != InventoryStatusFilter.all ||
      category != null ||
      branchId != null;

  String get _categoryLabel =>
      category == null ? S.inventoryFilterAllCategories : category!;

  String get _branchLabel {
    if (branchId == null) return S.inventoryFilterAllBranches;
    for (final branch in branches) {
      if (branch.id == branchId) return inventoryBranchName(branch);
    }
    return S.inventoryFilterAllBranches;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final search = AdminSearchField(
          controller: searchController,
          onChanged: onSearchChanged,
          hintText: S.rawMaterialSearchHint,
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _statusMenu(context, compact),
            _categoryMenu(context, compact),
            if (branches.isNotEmpty) _branchMenu(context, compact),
            if (_hasActiveFilters)
              IconButton(
                tooltip: S.clearFilters,
                onPressed: onClearFilters,
                style: IconButton.styleFrom(
                  fixedSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
                icon: const AppIcon(
                  AppIcons.cancel01,
                  size: 18,
                  color: AppColor.adminMuted,
                ),
              ),
          ],
        );
        if (constraints.maxWidth < 660) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: AppSizes.px8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: actions,
              ),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(
              width: constraints.maxWidth >= 980 ? 330 : 250,
              child: search,
            ),
            const Spacer(),
            actions,
          ],
        );
      },
    );
  }

  Widget _statusMenu(BuildContext context, bool compact) {
    final active = statusFilter != InventoryStatusFilter.all;
    return PopupMenuButton<InventoryStatusFilter>(
      tooltip: S.inventoryFilterStatus,
      onSelected: onStatusChanged,
      itemBuilder: (context) => [
        for (final option in InventoryStatusFilter.values)
          _menuItem<InventoryStatusFilter>(
            context,
            value: option,
            label: inventoryStatusFilterLabel(option),
            selected: option == statusFilter,
          ),
      ],
      child: compact
          ? AdminToolbarIcon(icon: AppIcons.package, active: active)
          : AdminToolbarSurface(
              label: inventoryStatusFilterLabel(statusFilter),
              icon: AppIcons.package,
              active: active,
            ),
    );
  }

  Widget _categoryMenu(BuildContext context, bool compact) {
    final active = category != null;
    return PopupMenuButton<String?>(
      tooltip: S.category,
      onSelected: onCategoryChanged,
      itemBuilder: (context) => [
        _menuItem<String?>(
          context,
          value: null,
          label: S.inventoryFilterAllCategories,
          selected: category == null,
        ),
        for (final option in categories)
          _menuItem<String?>(
            context,
            value: option.value,
            label: '${option.value} (${option.count})',
            selected: option.value == category,
          ),
      ],
      child: compact
          ? AdminToolbarIcon(icon: AppIcons.tag01, active: active)
          : AdminToolbarSurface(
              label: _categoryLabel,
              icon: AppIcons.tag01,
              active: active,
            ),
    );
  }

  Widget _branchMenu(BuildContext context, bool compact) {
    final active = branchId != null;
    return PopupMenuButton<String?>(
      tooltip: S.movementBranch,
      onSelected: onBranchChanged,
      itemBuilder: (context) => [
        _menuItem<String?>(
          context,
          value: null,
          label: S.inventoryFilterAllBranches,
          selected: branchId == null,
        ),
        for (final branch in branches)
          _menuItem<String?>(
            context,
            value: branch.id,
            label: inventoryBranchName(branch),
            selected: branch.id == branchId,
          ),
      ],
      child: compact
          ? AdminToolbarIcon(icon: AppIcons.store01, active: active)
          : AdminToolbarSurface(
              label: _branchLabel,
              icon: AppIcons.store01,
              active: active,
            ),
    );
  }

  PopupMenuItem<T> _menuItem<T>(
    BuildContext context, {
    required T value,
    required String label,
    required bool selected,
  }) => PopupMenuItem<T>(
    value: value,
    child: Row(
      children: [
        SizedBox(
          width: AppSizes.px18,
          child: selected
              ? const AppIcon(
                  AppIcons.tick01,
                  size: 15,
                  color: AppColor.adminAccent,
                )
              : null,
        ),
        const SizedBox(width: AppSizes.px6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: adminBodyColor(Theme.of(context)),
              fontSize: AppFontSizes.size12,
            ),
          ),
        ),
      ],
    ),
  );
}
