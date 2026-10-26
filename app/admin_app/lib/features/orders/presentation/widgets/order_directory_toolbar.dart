import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

class OrderDirectoryToolbar extends StatelessWidget {
  const OrderDirectoryToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.filtersActive,
    required this.filtersExpanded,
    required this.onToggleFilters,
    required this.onClearFilters,
    required this.onExport,
    required this.exporting,
    required this.exportEnabled,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final bool filtersActive;
  final bool filtersExpanded;
  final VoidCallback onToggleFilters;
  final VoidCallback onClearFilters;
  final VoidCallback onExport;
  final ValueListenable<bool>? exporting;
  final bool exportEnabled;

  @override
  Widget build(BuildContext context) {
    final search = AdminSearchField(
      controller: searchController,
      onChanged: onSearchChanged,
      hintText: S.searchOrdersHint,
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
              const SizedBox(height: 8),
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
              width: constraints.maxWidth >= 900 ? 320 : 240,
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
      _exportButton(),
      if (compact)
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onToggleFilters,
            borderRadius: BorderRadius.circular(10),
            child: AdminToolbarIcon(
              icon: HugeIcons.strokeRoundedFilter,
              active: filtersActive || filtersExpanded,
            ),
          ),
        )
      else
        AdminToolbarButton(
          label: S.ordersFilter,
          icon: HugeIcons.strokeRoundedFilter,
          active: filtersActive || filtersExpanded,
          onPressed: onToggleFilters,
        ),
      if (filtersActive)
        IconButton(
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
        ),
    ],
  );

  Widget _exportButton() {
    final listenable = exporting;
    if (listenable == null) {
      return AdminToolbarButton(
        label: S.ordersExportExcel,
        icon: HugeIcons.strokeRoundedDownload02,
        onPressed: exportEnabled ? onExport : null,
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, busy, _) => AdminToolbarButton(
        label: busy ? S.ordersExporting : S.ordersExportExcel,
        icon: HugeIcons.strokeRoundedDownload02,
        busy: busy,
        onPressed: exportEnabled && !busy ? onExport : null,
      ),
    );
  }
}
