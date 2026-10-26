import 'dart:math' as math;

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

class AuditTable extends StatelessWidget {
  const AuditTable({super.key, required this.logs, required this.onOpen});

  final List<AdminAuditLog> logs;
  final ValueChanged<AdminAuditLog> onOpen;

  static const _minWidth = 980.0;
  static const _actorWidth = 196.0;
  static const _branchWidth = 142.0;
  static const _timeWidth = 118.0;
  static const _sensitivityWidth = 100.0;
  static const _chevronWidth = 28.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math
          .min(math.max(constraints.maxWidth, _minWidth), 1760)
          .toDouble();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const _Header(),
                for (final log in logs)
                  _Row(
                    key: Key('audit-row-${log.id}'),
                    log: log,
                    onOpen: () => onOpen(log),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final dark = adminIsDark(Theme.of(context));
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: dark ? AppColor.darkSurfaceContainer : AppColor.adminTableHeader,
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.adminTableBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _cell(S.auditTableEvent, dark)),
          SizedBox(
            width: AuditTable._actorWidth,
            child: _cell(S.auditTableActor, dark),
          ),
          SizedBox(
            width: AuditTable._branchWidth,
            child: _cell(S.auditTableBranch, dark),
          ),
          SizedBox(
            width: AuditTable._timeWidth,
            child: _cell(S.auditTableTime, dark),
          ),
          SizedBox(
            width: AuditTable._sensitivityWidth,
            child: _cell(S.auditTableSensitivity, dark),
          ),
          const SizedBox(width: AuditTable._chevronWidth),
        ],
      ),
    );
  }

  Widget _cell(String label, bool dark) => Text(
    label,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
      fontSize: AppFontSizes.size10,
      fontWeight: AppFontWeights.medium,
      height: AppTextHeights.line1_5,
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({super.key, required this.log, required this.onOpen});

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
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      color: AppColor.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: adminRowBorderColor(theme)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _DomainIcon(domain: domain, color: domainColor),
                    const SizedBox(width: AppSizes.px10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auditEventTitle(log),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adminBodyColor(theme),
                              fontSize: AppFontSizes.size11_5,
                              fontWeight: AppFontWeights.bold,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                          const SizedBox(height: AppSizes.px1),
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: AuditTable._actorWidth,
                child: Row(
                  children: [
                    _ActorInitial(log: log),
                    const SizedBox(width: AppSizes.px8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auditActorName(log),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adminBodyColor(theme),
                              fontSize: AppFontSizes.size10_5,
                              fontWeight: AppFontWeights.semiBold,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                          Text(
                            auditActorRole(log),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adminSubtleColor(theme),
                              fontSize: AppFontSizes.size8_5,
                              height: AppTextHeights.line1_4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: AuditTable._branchWidth,
                child: Text(
                  branch.isEmpty ? S.auditDetailsNoBranch : branch,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: branch.isEmpty
                        ? adminSubtleColor(theme)
                        : adminBodyColor(theme),
                    fontSize: AppFontSizes.size9_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              SizedBox(
                width: AuditTable._timeWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auditDayLabel(log.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size9_5,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    Text(
                      auditClockLabel(log.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminSubtleColor(theme),
                        fontSize: AppFontSizes.size8_5,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: AuditTable._sensitivityWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _SensitivityBadge(isCritical: log.isCritical),
                ),
              ),
              SizedBox(
                width: AuditTable._chevronWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Tooltip(
                    message: S.auditOpenDetails,
                    child: AppIcon(
                      rtl ? AppIcons.arrowLeft01 : AppIcons.arrowRight01,
                      size: 16,
                      color: adminMutedColor(theme),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DomainIcon extends StatelessWidget {
  const _DomainIcon({required this.domain, required this.color});

  final String domain;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: adminFlagBackground(theme, color, auditDomainSurface(domain)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: AppIcon(
        auditDomainIcon(domain),
        size: 17,
        color: adminFlagForeground(theme, color),
      ),
    );
  }
}

class _ActorInitial extends StatelessWidget {
  const _ActorInitial({required this.log});

  final AdminAuditLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 26,
      height: 26,
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
          fontSize: AppFontSizes.size10,
          fontWeight: AppFontWeights.bold,
          height: AppTextHeights.line1_2,
        ),
      ),
    );
  }
}

class _SensitivityBadge extends StatelessWidget {
  const _SensitivityBadge({required this.isCritical});

  final bool isCritical;

  @override
  Widget build(BuildContext context) {
    return AdminStatusBadge(
      label: isCritical ? S.auditCriticalBadge : S.auditNormalBadge,
      color: isCritical ? AppColor.trendNegative : AppColor.adminMuted,
    );
  }
}
