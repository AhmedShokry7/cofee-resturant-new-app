import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

/// The search box and the single filter menu shared by the admin directories.
class AdminDirectoryToolbar<T> extends StatelessWidget {
  const AdminDirectoryToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.searchHint,
    required this.filter,
    required this.allLabel,
    required this.options,
    required this.optionLabel,
    required this.onFilterChanged,
    required this.onClearFilter,
    required this.filterLabel,
    this.hasActiveFilter = false,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String searchHint;

  final T filter;
  final String allLabel;
  final List<T> options;
  final String Function(T option) optionLabel;
  final ValueChanged<T> onFilterChanged;
  final VoidCallback onClearFilter;

  /// The name of the filter menu, used for its tooltip.
  final String filterLabel;

  final bool hasActiveFilter;

  @override
  Widget build(BuildContext context) {
    final search = AdminSearchField(
      controller: searchController,
      onChanged: onSearchChanged,
      hintText: searchHint,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final actions = _actions(compact: compact);
        if (compact) {
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
              width: constraints.maxWidth >= AppBreakpoints.wideLayout
                  ? AppDimensions.searchFieldWidth
                  : AppDimensions.searchFieldWidthCompact,
              child: search,
            ),
            const Spacer(),
            actions,
          ],
        );
      },
    );
  }

  Widget _actions({required bool compact}) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      _filterButton(compact: compact),
      if (hasActiveFilter)
        IconButton(
          tooltip: S.clearFilters,
          onPressed: onClearFilter,
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

  Widget _filterButton({required bool compact}) => PopupMenuButton<T>(
    tooltip: filterLabel,
    onSelected: onFilterChanged,
    itemBuilder: (context) => [
      for (final option in options)
        PopupMenuItem<T>(
          value: option,
          child: Row(
            children: [
              SizedBox(
                width: AppSizes.px18,
                child: option == filter
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
                  optionLabel(option),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: AppFontSizes.size12,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
    child: compact
        ? AdminToolbarIcon(icon: AppIcons.filter, active: hasActiveFilter)
        : AdminToolbarSurface(
            label: hasActiveFilter ? optionLabel(filter) : allLabel,
            icon: AppIcons.filter,
            active: hasActiveFilter,
          ),
  );
}
