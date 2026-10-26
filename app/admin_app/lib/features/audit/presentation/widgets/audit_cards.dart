import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_format.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class AuditCards extends StatelessWidget {
  const AuditCards({super.key, required this.logs, required this.onOpen});

  final List<AdminAuditLog> logs;
  final ValueChanged<AdminAuditLog> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.px10),
      itemBuilder: (context, index) {
        final log = logs[index];
        return _AuditCard(
          key: Key('audit-card-${log.id}'),
          log: log,
          onOpen: () => onOpen(log),
        );
      },
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({super.key, required this.log, required this.onOpen});

  final AdminAuditLog log;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final domain = auditDomainKey(log);
    final domainColor = auditDomainColor(domain);
    final branch = log.branchNameFor(AppLocale.instance.language);
    final entityId = auditShortId(log.entityId);
    final subtitle = entityId.isEmpty
        ? auditEntityLabel(log.entityType)
        : '${auditEntityLabel(log.entityType)} • $entityId';
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: adminCardBorderColor(theme)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: adminFlagBackground(
                    theme,
                    domainColor,
                    auditDomainSurface(domain),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: AppIcon(
                  auditDomainIcon(domain),
                  size: 17,
                  color: adminFlagForeground(theme, domainColor),
                ),
              ),
              const SizedBox(width: AppSizes.px10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            auditEventTitle(log),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adminHeadingColor(theme),
                              fontSize: AppFontSizes.size11_5,
                              fontWeight: AppFontWeights.bold,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                        ),
                        if (log.isCritical) ...[
                          const SizedBox(width: AppSizes.px6),
                          AdminStatusBadge(
                            label: S.auditCriticalBadge,
                            color: AppColor.trendNegative,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSizes.px2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminSubtleColor(theme),
                        fontSize: AppFontSizes.size9,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                    const SizedBox(height: AppSizes.px8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Meta(
                          icon: null,
                          label: auditActorName(log),
                          leading: _Initial(log: log),
                        ),
                        _Meta(
                          icon: AppIcons.store01,
                          label: branch.isEmpty
                              ? S.auditDetailsNoBranch
                              : branch,
                        ),
                        _Meta(
                          icon: AppIcons.calendar03,
                          label: auditRelativeTimeLabel(log.createdAt),
                        ),
                      ],
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
}

class _Initial extends StatelessWidget {
  const _Initial({required this.log});

  final AdminAuditLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.adminAccent,
          AppColor.adminAccentSurface,
        ),
        shape: BoxShape.circle,
      ),
      child: Text(
        auditActorInitial(log),
        textDirection: TextDirection.ltr,
        style: TextStyle(
          color: adminFlagForeground(theme, AppColor.adminAccent),
          fontSize: AppFontSizes.size8,
          fontWeight: AppFontWeights.bold,
          height: AppTextHeights.line1_2,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, this.leading});

  final IconData? icon;
  final String label;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = adminMutedColor(theme);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null)
          leading!
        else if (icon != null)
          AppIcon(icon!, size: 11, color: color),
        const SizedBox(width: AppSizes.px4),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: AppFontSizes.size8_5,
                height: AppTextHeights.line1_4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
