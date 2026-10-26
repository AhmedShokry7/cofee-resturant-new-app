import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/locale/permission_catalog.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

/// Opens the permission editor of a role or a staff member.
Future<void> showAdminPermissionsDialog({
  required BuildContext context,
  required String title,
  String? subtitle,
  required Set<String> granted,
  required List<Map<String, dynamic>> catalog,
  required bool canManage,
  required Future<void> Function(String code, bool granted) onToggle,
  String? emptyMessage,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AdminPermissionsDialog(
      title: title,
      subtitle: subtitle,
      granted: granted,
      catalog: catalog,
      canManage: canManage,
      onToggle: onToggle,
      emptyMessage: emptyMessage,
    ),
  );
}

/// Every permission of the dashboard, grouped and searchable, checked for one
/// role or staff member.
class AdminPermissionsDialog extends StatefulWidget {
  const AdminPermissionsDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.granted,
    required this.catalog,
    required this.canManage,
    required this.onToggle,
    this.emptyMessage,
  });

  final String title;
  final String? subtitle;
  final Set<String> granted;

  /// The permission catalogue, read once from the database.
  final List<Map<String, dynamic>> catalog;

  /// False for a staff member who may only read the permissions.
  final bool canManage;

  final Future<void> Function(String code, bool granted) onToggle;

  /// Shown instead of the search message when the catalogue itself is empty.
  final String? emptyMessage;

  @override
  State<AdminPermissionsDialog> createState() => _AdminPermissionsDialogState();
}

class _AdminPermissionsDialogState extends State<AdminPermissionsDialog> {
  late final Set<String> _granted;
  late final List<_PermissionEntry> _entries;
  late final TextEditingController _searchController;
  final Set<String> _saving = <String>{};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _granted = Set<String>.from(widget.granted);
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

  Future<void> _toggle(String code, bool value) async {
    if (!widget.canManage || _saving.contains(code)) return;
    setState(() => _saving.add(code));
    try {
      await widget.onToggle(code, value);
      if (!mounted) return;
      setState(() {
        if (value) {
          _granted.add(code);
        } else {
          _granted.remove(code);
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.permissionSaveFailed)));
    } finally {
      if (mounted) setState(() => _saving.remove(code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final size = MediaQuery.sizeOf(context);
    final height = math.min(680.0, size.height - 48);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 680, maxHeight: height),
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                title: widget.title,
                subtitle: widget.subtitle ?? S.permissionsDialogSubtitle,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: AdminSearchField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  hintText: S.permissionsSearchHint,
                ),
              ),
              if (!widget.canManage)
                Container(
                  margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: adminTintedSurfaceColor(theme),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        size: 15,
                        color: adminMutedColor(theme),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          S.permissionsReadOnly,
                          style: TextStyle(
                            color: adminMutedColor(theme),
                            fontSize: AppFontSizes.size10_5,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(child: _list(context, dark)),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: adminRowBorderColor(theme)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        S.permissionsGrantedCount(_granted.length),
                        style: TextStyle(
                          color: adminMutedColor(theme),
                          fontSize: AppFontSizes.size10,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(S.close),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, bool dark) {
    final visible = _visible;
    if (visible.isEmpty) {
      final stillSearching = _query.trim().isNotEmpty;
      return AdminEmptyState(
        icon: HugeIcons.strokeRoundedSearch01,
        message: stillSearching
            ? S.permissionsNoMatches
            : widget.emptyMessage ?? S.permissionsNoMatches,
      );
    }
    final groups = _grouped(visible);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
      children: [
        for (final entry in groups.entries) ...[
          _GroupHeader(group: entry.key, count: entry.value.length),
          for (final permission in entry.value)
            _PermissionRow(
              entry: permission,
              granted: _granted.contains(permission.code),
              enabled: widget.canManage,
              saving: _saving.contains(permission.code),
              onChanged: (value) => _toggle(permission.code, value),
              dark: dark,
            ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: adminRowBorderColor(theme))),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: adminFlagBackground(
                theme,
                AppColor.adminAccent,
                AppColor.adminAccentSurface,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedSecurityCheck,
              size: 19,
              color: adminFlagForeground(theme, AppColor.adminAccent),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size14_5,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size10_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: S.close,
            onPressed: () => Navigator.of(context).pop(),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              size: 18,
              color: adminMutedColor(theme),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.count});

  final String group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              permissionGroupName(group),
              style: TextStyle(
                color: adminBodyColor(theme),
                fontSize: AppFontSizes.size10,
                fontWeight: AppFontWeights.bold,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size9_5,
              height: AppTextHeights.line1_5,
            ),
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
    required this.enabled,
    required this.saving,
    required this.onChanged,
    required this.dark,
  });

  final _PermissionEntry entry;
  final bool granted;
  final bool enabled;
  final bool saving;
  final ValueChanged<bool> onChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = adminBodyColor(theme);
    final muted = adminMutedColor(theme);
    return InkWell(
      onTap: enabled && !saving ? () => onChanged(!granted) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: adminRowBorderColor(theme))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              height: 28,
              child: saving
                  ? const Padding(
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Checkbox(
                      value: granted,
                      onChanged: enabled
                          ? (value) => onChanged(value == true)
                          : null,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled
                          ? color
                          : muted.withValues(alpha: dark ? .9 : .75),
                      fontSize: AppFontSizes.size11_5,
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
  });

  final String code;
  final String name;
  final String description;
  final String group;

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
    );
  }
}
