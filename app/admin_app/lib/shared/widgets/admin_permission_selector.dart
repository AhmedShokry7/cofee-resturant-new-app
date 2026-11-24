import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/locale/permission_catalog.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// A grouped, searchable permission picker that edits a complete set.
///
/// Unlike the per-staff dialog, this component owns no save call: the role
/// editor submits the whole set in one RPC, so every checkbox is local until
/// the dialog is saved. A permission the caller cannot grant is disabled
/// unless it is already selected; owner-only permissions are disabled on both
/// sides because a non-owner may neither add nor remove them.
class AdminPermissionSelector extends StatefulWidget {
  const AdminPermissionSelector({
    super.key,
    required this.catalog,
    required this.selected,
    required this.onChanged,
    this.readOnly = false,
  });

  final List<Map<String, dynamic>> catalog;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool readOnly;

  @override
  State<AdminPermissionSelector> createState() =>
      _AdminPermissionSelectorState();
}

class _AdminPermissionSelectorState extends State<AdminPermissionSelector> {
  late final List<_PermissionEntry> _entries;
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    final isArabic = AppLocale.instance.isArabic;
    _entries = <_PermissionEntry>[
      for (final permission in widget.catalog)
        if ('${permission['code'] ?? ''}'.trim().isNotEmpty)
          _PermissionEntry.fromJson(permission, isArabic: isArabic),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_PermissionEntry> get _visible {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _entries;
    return _entries
        .where(
          (entry) =>
              entry.code.toLowerCase().contains(query) ||
              entry.name.toLowerCase().contains(query) ||
              entry.description.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  Map<String, List<_PermissionEntry>> _grouped(List<_PermissionEntry> entries) {
    final groups = <String, List<_PermissionEntry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(entry.group, () => <_PermissionEntry>[]).add(entry);
    }
    final ordered = groups.keys.toList()
      ..sort((first, second) {
        final firstIndex = kPermissionGroupOrder.indexOf(first);
        final secondIndex = kPermissionGroupOrder.indexOf(second);
        if (firstIndex < 0 && secondIndex < 0) return first.compareTo(second);
        if (firstIndex < 0) return 1;
        if (secondIndex < 0) return -1;
        return firstIndex.compareTo(secondIndex);
      });
    return {for (final group in ordered) group: groups[group]!};
  }

  void _toggle(_PermissionEntry entry, bool value) {
    final next = <String>{...widget.selected};
    if (value) {
      next.add(entry.code);
    } else {
      next.remove(entry.code);
    }
    widget.onChanged(next);
  }

  void _selectGroup(List<_PermissionEntry> entries) {
    final next = <String>{...widget.selected};
    for (final entry in entries) {
      if (entry.canGrant) next.add(entry.code);
    }
    widget.onChanged(next);
  }

  void _clearGroup(List<_PermissionEntry> entries) {
    final next = <String>{...widget.selected};
    for (final entry in entries) {
      // Owner-only permissions cannot be revoked by a non-owner either; the
      // server would reject the whole set, so leave those checks alone.
      if (entry.canRevoke) next.remove(entry.code);
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visible;
    final groups = _grouped(visible);
    final selectedCount = widget.selected.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: AdminSearchField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  hintText: S.permissionsSearchHint,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                S.permissionsSelectedCount(selectedCount),
                style: TextStyle(
                  color: adminMutedColor(theme),
                  fontSize: AppFontSizes.size10_5,
                  fontWeight: AppFontWeights.semiBold,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ],
          ),
        ),
        if (widget.readOnly)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              S.permissionsReadOnly,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size10,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    S.permissionsNoMatches,
                    style: TextStyle(
                      color: adminMutedColor(theme),
                      fontSize: AppFontSizes.size11,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  children: [
                    for (final group in groups.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _PermissionGroup(
                          name: permissionGroupName(group.key),
                          entries: group.value,
                          selected: widget.selected,
                          readOnly: widget.readOnly,
                          onToggle: _toggle,
                          onSelectAll: () => _selectGroup(group.value),
                          onClearAll: () => _clearGroup(group.value),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PermissionGroup extends StatelessWidget {
  const _PermissionGroup({
    required this.name,
    required this.entries,
    required this.selected,
    required this.readOnly,
    required this.onToggle,
    required this.onSelectAll,
    required this.onClearAll,
  });

  final String name;
  final List<_PermissionEntry> entries;
  final Set<String> selected;
  final bool readOnly;
  final void Function(_PermissionEntry entry, bool value) onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = entries
        .where((entry) => selected.contains(entry.code))
        .length;
    final grantable = entries.where((entry) => entry.canGrant).length;
    final selectedGrantable = entries
        .where((entry) => entry.canGrant && selected.contains(entry.code))
        .length;
    final canSelectAll = !readOnly && selectedGrantable < grantable;
    final canClearAll =
        !readOnly &&
        entries.any(
          (entry) => entry.canRevoke && selected.contains(entry.code),
        );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: adminTintedSurfaceColor(theme),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminBodyColor(theme),
                      fontSize: AppFontSizes.size11,
                      fontWeight: AppFontWeights.bold,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ),
                Text(
                  '$selectedCount/${entries.length}',
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                if (!readOnly) ...[
                  const SizedBox(width: AppSpacing.xs),
                  TextButton(
                    onPressed: canSelectAll ? onSelectAll : null,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: AppFontSizes.size10,
                        fontWeight: AppFontWeights.semiBold,
                      ),
                    ),
                    child: Text(S.permissionsSelectAll),
                  ),
                  TextButton(
                    onPressed: canClearAll ? onClearAll : null,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: AppFontSizes.size10,
                        fontWeight: AppFontWeights.semiBold,
                      ),
                    ),
                    child: Text(S.permissionsClearAll),
                  ),
                ],
              ],
            ),
          ),
          for (final entry in entries)
            _PermissionRow(
              entry: entry,
              granted: selected.contains(entry.code),
              readOnly: readOnly,
              onChanged: (value) => onToggle(entry, value),
            ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.entry,
    required this.granted,
    required this.readOnly,
    required this.onChanged,
  });

  final _PermissionEntry entry;
  final bool granted;
  final bool readOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled =
        !readOnly && (entry.canGrant || (granted && entry.canRevoke));
    final color = adminBodyColor(theme);
    final muted = adminMutedColor(theme);
    final checkbox = Checkbox(
      value: granted,
      onChanged: enabled ? (value) => onChanged(value == true) : null,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    return InkWell(
      onTap: enabled ? () => onChanged(!granted) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: adminRowBorderColor(theme))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: AppSizes.px32,
              height: AppSizes.px28,
              child: enabled
                  ? checkbox
                  : Tooltip(
                      message: granted && !entry.canRevoke
                          ? S.permissionsOwnerOnly
                          : S.permissionsCannotGrant,
                      child: checkbox,
                    ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled ? color : muted,
                      fontSize: AppFontSizes.size11,
                      fontWeight: AppFontWeights.semiBold,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                  if (entry.description.isNotEmpty)
                    Text(
                      entry.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: AppFontSizes.size9_5,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                ],
              ),
            ),
            if (!readOnly &&
                ((!entry.canGrant && !granted) ||
                    (granted && !entry.canRevoke)))
              Padding(
                padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
                child: AppIcon(AppIcons.lock, size: 14, color: muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _PermissionEntry {
  const _PermissionEntry({
    required this.code,
    required this.name,
    required this.description,
    required this.group,
    required this.canGrant,
    required this.canRevoke,
  });

  final String code;
  final String name;
  final String description;
  final String group;
  final bool canGrant;
  final bool canRevoke;

  factory _PermissionEntry.fromJson(
    Map<String, dynamic> json, {
    required bool isArabic,
  }) {
    final code = '${json['code'] ?? ''}'.trim();
    final databaseName = isArabic ? json['name_ar'] : json['name_en'];
    return _PermissionEntry(
      code: code,
      name: permissionName(code, isArabic: isArabic) == code
          ? '${databaseName ?? code}'
          : permissionName(code, isArabic: isArabic),
      description: permissionDescription(code, isArabic: isArabic),
      group: permissionGroupCode(code),
      canGrant: json['can_grant'] != false,
      canRevoke: json['can_revoke'] != false,
    );
  }
}
