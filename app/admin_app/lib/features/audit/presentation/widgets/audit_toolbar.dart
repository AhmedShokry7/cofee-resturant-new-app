import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/audit/presentation/models/audit_filters.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_format.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

class AuditToolbar extends StatelessWidget {
  const AuditToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.domain,
    required this.onDomainChanged,
    required this.criticalOnly,
    required this.onCriticalChanged,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final AuditDomainFilter domain;
  final ValueChanged<AuditDomainFilter> onDomainChanged;
  final bool criticalOnly;
  final ValueChanged<bool> onCriticalChanged;
  final VoidCallback onClearFilters;

  bool get _hasActiveFilters => domain != AuditDomainFilter.all || criticalOnly;

  String _domainLabel(AuditDomainFilter filter) {
    final value = filter.value;
    return value == null ? S.auditFilterAllDomains : auditDomainLabel(value);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 780;
        final search = AdminSearchField(
          controller: searchController,
          onChanged: onSearchChanged,
          hintText: S.auditSearchHint,
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PopupMenuButton<AuditDomainFilter>(
              tooltip: S.auditFilterDomain,
              onSelected: onDomainChanged,
              itemBuilder: (context) => [
                for (final option in AuditDomainFilter.values)
                  PopupMenuItem<AuditDomainFilter>(
                    value: option,
                    child: Row(
                      children: [
                        SizedBox(
                          width: AppSizes.px18,
                          child: option == domain
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
                            _domainLabel(option),
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
                      active: domain != AuditDomainFilter.all,
                    )
                  : AdminToolbarSurface(
                      label: _domainLabel(domain),
                      icon: AppIcons.filter,
                      active: domain != AuditDomainFilter.all,
                    ),
            ),
            Tooltip(
              message: S.auditFilterCritical,
              child: InkWell(
                onTap: () => onCriticalChanged(!criticalOnly),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: compact
                    ? AdminToolbarIcon(
                        icon: AppIcons.shield01,
                        active: criticalOnly,
                      )
                    : AdminToolbarSurface(
                        label: S.auditFilterCritical,
                        icon: AppIcons.shield01,
                        active: criticalOnly,
                      ),
              ),
            ),
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
              width: constraints.maxWidth >= 900 ? 340 : 260,
              child: search,
            ),
            const Spacer(),
            actions,
          ],
        );
      },
    );
  }
}
