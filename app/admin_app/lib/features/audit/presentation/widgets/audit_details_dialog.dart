import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_format.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

Future<void> showAuditDetailsDialog({
  required BuildContext context,
  required AdminAuditLog log,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => AuditDetailsDialog(log: log),
  );
}

class AuditDetailsDialog extends StatelessWidget {
  const AuditDetailsDialog({super.key, required this.log});

  final AdminAuditLog log;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final height = math.min(screen.height * .9, 820.0);
    return Dialog(
      key: const Key('audit-details-dialog'),
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width < 700 ? AppDimensions.md : AppDimensions.xxl,
        vertical: AppDimensions.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              AdminDialogHeader(
                title: S.auditDetailsTitle,
                subtitle: localizeDigits(S.auditDetailsSubtitle(log.id)),
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppDimensions.lg,
                    AppDimensions.md,
                    AppDimensions.lg,
                    AppDimensions.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _EventBanner(log: log),
                      const SizedBox(height: 14),
                      _IdentityGrid(log: log),
                      const SizedBox(height: 16),
                      _ChangesSection(log: log),
                      const SizedBox(height: 14),
                      _TechnicalSection(log: log),
                    ],
                  ),
                ),
              ),
              _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventBanner extends StatelessWidget {
  const _EventBanner({required this.log});

  final AdminAuditLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final domain = auditDomainKey(log);
    final color = auditDomainColor(domain);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: adminFlagBackground(theme, color, auditDomainSurface(domain)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: adminIsDark(theme) ? .35 : .16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(
              icon: auditDomainIcon(domain),
              size: 20,
              color: adminFlagForeground(theme, color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auditEventTitle(log),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size14,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AdminStatusBadge(
                      label: auditDomainLabel(domain),
                      color: color,
                    ),
                    AdminStatusBadge(
                      label: log.isCritical
                          ? S.auditCriticalBadge
                          : S.auditNormalBadge,
                      color: log.isCritical
                          ? AppColor.trendNegative
                          : AppColor.adminMuted,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCalendar03,
                          size: 12,
                          color: adminMutedColor(theme),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          auditRelativeTimeLabel(log.createdAt),
                          style: TextStyle(
                            color: adminMutedColor(theme),
                            fontSize: AppFontSizes.size9,
                            height: AppTextHeights.line1_4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityGrid extends StatelessWidget {
  const _IdentityGrid({required this.log});

  final AdminAuditLog log;

  @override
  Widget build(BuildContext context) {
    final actor = _ActorCard(log: log);
    final when = _WhenCard(log: log);
    final entity = _EntityCard(log: log);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              actor,
              const SizedBox(height: 10),
              when,
              const SizedBox(height: 10),
              entity,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: actor),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: when),
              ],
            ),
            const SizedBox(height: 10),
            entity,
          ],
        );
      },
    );
  }
}

class _ActorCard extends StatelessWidget {
  const _ActorCard({required this.log});

  final AdminAuditLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roles = log.actorRolesFor(AppLocale.instance.language);
    return _InfoCard(
      title: S.auditDetailsActor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              shape: BoxShape.circle,
            ),
            child: Text(
              auditActorInitial(log),
              textDirection: TextDirection.ltr,
              style: TextStyle(
                color: adminFlagForeground(theme, AppColor.adminAccent),
                fontSize: AppFontSizes.size14,
                fontWeight: AppFontWeights.bold,
                height: AppTextHeights.line1_2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auditActorName(log),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size11_5,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                if (log.actorEmail != null && log.actorEmail!.trim().isNotEmpty)
                  Text(
                    log.actorEmail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: adminSubtleColor(theme),
                      fontSize: AppFontSizes.size8_5,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    for (final role
                        in roles.isEmpty ? [auditActorRole(log)] : roles)
                      _TextPill(label: role),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhenCard extends StatelessWidget {
  const _WhenCard({required this.log});

  final AdminAuditLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branch = log.branchNameFor(AppLocale.instance.language);
    return _InfoCard(
      title: S.auditDetailsWhen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizedDateTime(log.createdAt),
            style: TextStyle(
              color: adminBodyColor(theme),
              fontSize: AppFontSizes.size10_5,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedStore01,
                size: 12,
                color: adminMutedColor(theme),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  branch.isEmpty ? S.auditDetailsNoBranch : branch,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9,
                    height: AppTextHeights.line1_4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntityCard extends StatelessWidget {
  const _EntityCard({required this.log});

  final AdminAuditLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = auditShortId(log.entityId);
    return _InfoCard(
      title: S.auditDetailsEntity,
      child: Row(
        children: [
          _TextPill(label: auditEntityLabel(log.entityType)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              id.isEmpty ? S.auditDetailsNoValue : '#$id',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                color: adminSubtleColor(theme),
                fontSize: AppFontSizes.size9,
                height: AppTextHeights.line1_4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangesSection extends StatelessWidget {
  const _ChangesSection({required this.log});

  final AdminAuditLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changes = auditChanges(log);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                S.auditDetailsChanges,
                style: TextStyle(
                  color: adminHeadingColor(theme),
                  fontSize: AppFontSizes.size13,
                  fontWeight: AppFontWeights.bold,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ),
            if (changes.isNotEmpty)
              AdminStatusBadge(
                label: localizeDigits(
                  S.auditDetailsChangedFields(changes.length),
                ),
                color: AppColor.adminInfo,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (changes.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: adminCardBorderColor(theme)),
            ),
            child: Text(
              S.auditDetailsNoChanges,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size10,
                height: AppTextHeights.line1_6,
              ),
            ),
          )
        else
          for (final change in changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChangeRow(change: change),
            ),
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change});

  final AuditFieldChange change;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final before = _ValueBlock(
      label: S.auditDetailsBefore,
      value: auditValueLabel(change.key, change.before),
      muted: change.before == null,
    );
    final after = _ValueBlock(
      label: S.auditDetailsAfter,
      value: auditValueLabel(change.key, change.after),
      muted: change.after == null,
    );
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Container(
      key: Key('audit-change-${change.key}'),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            auditFieldLabel(change.key),
            style: TextStyle(
              color: adminHeadingColor(theme),
              fontSize: AppFontSizes.size10_5,
              fontWeight: AppFontWeights.bold,
              height: AppTextHeights.line1_5,
            ),
          ),
          const SizedBox(height: 7),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [before, const SizedBox(height: 5), after],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: before),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: HugeIcon(
                        icon: rtl
                            ? HugeIcons.strokeRoundedArrowLeft01
                            : HugeIcons.strokeRoundedArrowRight01,
                        size: 14,
                        color: adminMutedColor(theme),
                      ),
                    ),
                  ),
                  Expanded(child: after),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ValueBlock extends StatelessWidget {
  const _ValueBlock({
    required this.label,
    required this.value,
    required this.muted,
  });

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: adminRowBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size8,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: muted ? adminMutedColor(theme) : adminBodyColor(theme),
              fontSize: AppFontSizes.size10,
              height: AppTextHeights.line1_6,
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicalSection extends StatelessWidget {
  const _TechnicalSection({required this.log});

  final AdminAuditLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = adminMutedColor(theme);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: adminCardBorderColor(theme)),
        ),
        child: ExpansionTile(
          key: const Key('audit-technical-section'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
          iconColor: muted,
          collapsedIconColor: muted,
          leading: HugeIcon(
            icon: HugeIcons.strokeRoundedSecurityCheck,
            size: 17,
            color: muted,
          ),
          title: Text(
            S.auditDetailsTechnical,
            style: TextStyle(
              color: muted,
              fontSize: AppFontSizes.size10_5,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_5,
            ),
          ),
          children: [
            _MetaLine(
              label: S.auditDetailsActionCode,
              value: log.action,
              ltr: true,
            ),
            _MetaLine(
              label: S.auditDetailsEntityType,
              value: log.entityType,
              ltr: true,
            ),
            _MetaLine(
              label: S.auditDetailsEntityId,
              value: log.entityId ?? S.auditDetailsNoValue,
              ltr: true,
            ),
            const SizedBox(height: 7),
            _RawJson(title: S.auditDetailsBefore, value: log.oldValues),
            const SizedBox(height: 6),
            _RawJson(title: S.auditDetailsAfter, value: log.newValues),
          ],
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value, this.ltr = false});

  final String label;
  final String value;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size8_5,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: ltr ? TextDirection.ltr : null,
              style: TextStyle(
                color: adminBodyColor(theme),
                fontSize: AppFontSizes.size9,
                height: AppTextHeights.line1_5,
                fontFamily: ltr ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RawJson extends StatelessWidget {
  const _RawJson({required this.title, required this.value});

  final String title;
  final Map<String, dynamic>? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = value == null
        ? S.auditDetailsNoValue
        : const JsonEncoder.withIndent(' ').convert(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size8_5,
            fontWeight: AppFontWeights.semiBold,
            height: AppTextHeights.line1_4,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: adminTintedSurfaceColor(theme),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: adminRowBorderColor(theme)),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(
              content,
              style: TextStyle(
                color: value == null
                    ? adminMutedColor(theme)
                    : adminBodyColor(theme),
                fontSize: AppFontSizes.size9,
                height: AppTextHeights.line1_6,
                fontFamily: value == null ? null : 'monospace',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size8_5,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_4,
              letterSpacing: AppLetterSpacings.space0_2,
            ),
          ),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }
}

class _TextPill extends StatelessWidget {
  const _TextPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: adminRowBorderColor(theme)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: adminSubtleColor(theme),
          fontSize: AppFontSizes.size8_5,
          fontWeight: AppFontWeights.semiBold,
          height: AppTextHeights.line1_4,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.lg,
        AppDimensions.sm,
        AppDimensions.lg,
        AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: adminIsDark(theme)
                ? AppColor.darkBorder
                : AppColor.adminRowBorder,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            key: const Key('audit-details-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.auditDetailsClose),
          ),
        ],
      ),
    );
  }
}
