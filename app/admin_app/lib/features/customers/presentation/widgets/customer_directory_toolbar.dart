import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customers/presentation/models/customer_filter.dart';
import 'package:admin_app/shared/widgets/admin_export_button.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

class CustomerDirectoryToolbar extends StatelessWidget {
  const CustomerDirectoryToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.filter,
    required this.onFilterChanged,
    required this.onClearFilter,
    required this.onExport,
    required this.exporting,
    required this.exportEnabled,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final CustomerFilter filter;
  final ValueChanged<CustomerFilter> onFilterChanged;
  final VoidCallback onClearFilter;
  final VoidCallback onExport;
  final ValueListenable<bool>? exporting;
  final bool exportEnabled;

  @override
  Widget build(BuildContext context) {
    final search = AdminSearchField(
      controller: searchController,
      onChanged: onSearchChanged,
      hintText: S.customersSearchHint,
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
      AdminExportButton(
        label: S.customersExport,
        busyLabel: S.customersExporting,
        onPressed: onExport,
        busy: exporting,
        enabled: exportEnabled,
      ),
      _filterButton(compact: compact),
      if (filter != CustomerFilter.all)
        IconButton(
          tooltip: S.customersClearFilter,
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

  Widget _filterButton({required bool compact}) =>
      PopupMenuButton<CustomerFilter>(
        tooltip: S.customersFilter,
        onSelected: onFilterChanged,
        itemBuilder: (context) => [
          for (final option in CustomerFilter.values)
            PopupMenuItem<CustomerFilter>(
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
                      option.label,
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
            ? AdminToolbarIcon(
                icon: AppIcons.filter,
                active: filter != CustomerFilter.all,
              )
            : AdminToolbarSurface(
                label: filter == CustomerFilter.all
                    ? S.customersFilter
                    : filter.label,
                icon: AppIcons.filter,
                active: filter != CustomerFilter.all,
              ),
      );
}
