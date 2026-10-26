import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/kitchen/data/models/admin_kitchen_filters.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

class KitchenToolbar extends StatelessWidget {
  const KitchenToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.branches,
    required this.branchId,
    required this.onBranchChanged,
    required this.hasActiveFilters,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<AdminKitchenBranchOption> branches;
  final String? branchId;
  final ValueChanged<String?> onBranchChanged;
  final bool hasActiveFilters;
  final VoidCallback onClearFilters;

  String get _branchLabel {
    if (branchId == null) return S.kitchenAllBranches;
    final language = AppLocale.instance.language;
    for (final branch in branches) {
      if (branch.id == branchId) return branch.nameFor(language);
    }
    return S.kitchenAllBranches;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final search = AdminSearchField(
          controller: searchController,
          onChanged: onSearchChanged,
          hintText: S.searchKitchenHint,
        );
        final branchMenu = branches.isEmpty
            ? null
            : PopupMenuButton<String?>(
                tooltip: S.kitchenFilterBranch,
                onSelected: onBranchChanged,
                itemBuilder: (context) => [
                  _menuItem(
                    context,
                    value: null,
                    label: S.kitchenAllBranches,
                    selected: branchId == null,
                  ),
                  for (final branch in branches)
                    _menuItem(
                      context,
                      value: branch.id,
                      label: branch.nameFor(AppLocale.instance.language),
                      selected: branch.id == branchId,
                    ),
                ],
                child: compact
                    ? AdminToolbarIcon(
                        icon: HugeIcons.strokeRoundedStore01,
                        active: branchId != null,
                      )
                    : AdminToolbarSurface(
                        label: _branchLabel,
                        icon: HugeIcons.strokeRoundedStore01,
                        active: branchId != null,
                      ),
              );
        final clear = hasActiveFilters
            ? IconButton(
                tooltip: S.clearFilters,
                onPressed: onClearFilters,
                style: IconButton.styleFrom(
                  fixedSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 18,
                  color: AppColor.adminMuted,
                ),
              )
            : null;

        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              if (branchMenu != null || clear != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ?branchMenu,
                      if (clear != null) ...[const SizedBox(width: 8), clear],
                    ],
                  ),
                ),
              ],
            ],
          );
        }

        return Row(
          children: [
            SizedBox(
              width: constraints.maxWidth >= 980 ? 330 : 260,
              child: search,
            ),
            const Spacer(),
            ?branchMenu,
            if (clear != null) ...[const SizedBox(width: 8), clear],
          ],
        );
      },
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
          width: 18,
          child: selected
              ? const HugeIcon(
                  icon: HugeIcons.strokeRoundedTick01,
                  size: 15,
                  color: AppColor.adminAccent,
                )
              : null,
        ),
        const SizedBox(width: 6),
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
