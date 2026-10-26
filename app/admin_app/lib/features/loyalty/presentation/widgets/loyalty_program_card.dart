import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_rule.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_format.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// The earning rule the whole program depends on, shown above the catalogue.
class LoyaltyProgramCard extends StatelessWidget {
  const LoyaltyProgramCard({
    super.key,
    required this.rule,
    this.canManage = false,
    this.onEdit,
  });

  final AdminLoyaltyRule? rule;
  final bool canManage;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = rule;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: adminCardBorderColor(theme)),
        boxShadow: adminIsDark(theme)
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x0A1B362B),
                  blurRadius: 24,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final header = _Header(
            rule: current,
            canManage: canManage,
            onEdit: onEdit,
            compact: constraints.maxWidth < 560,
          );
          if (current == null) return header;
          final stats = Wrap(
            spacing: 26,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: _stats(current),
          );
          if (constraints.maxWidth < 640) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                header,
                const SizedBox(height: 9),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 49),
                  child: stats,
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 2, child: header),
              const SizedBox(width: 16),
              Flexible(flex: 3, child: stats),
            ],
          );
        },
      ),
    );
  }

  static List<Widget> _stats(AdminLoyaltyRule rule) => <Widget>[
    _ProgramStat(
      label: S.loyaltyProgramEarnRateLabel,
      value: loyaltyProgramEarnRate(rule),
    ),
    _ProgramStat(
      label: S.loyaltyProgramPointValueLabel,
      value: loyaltyProgramPointValue(rule),
    ),
    _ProgramStat(
      label: S.loyaltyProgramValidityLabel,
      value: loyaltyProgramValidity(rule),
    ),
  ];
}

class _Header extends StatelessWidget {
  const _Header({
    required this.rule,
    required this.canManage,
    this.onEdit,
    this.compact = false,
  });

  final AdminLoyaltyRule? rule;
  final bool canManage;
  final VoidCallback? onEdit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = rule;
    return Row(
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
            icon: HugeIcons.strokeRoundedGift,
            size: 18,
            color: adminFlagForeground(theme, AppColor.adminAccent),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      S.loyaltyProgramTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminHeadingColor(theme),
                        fontSize: AppFontSizes.size12,
                        fontWeight: AppFontWeights.bold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ),
                  if (current != null) ...[
                    const SizedBox(width: 8),
                    AdminStatusBadge(
                      label: loyaltyProgramStatusLabel(current),
                      color: _statusColor(current),
                    ),
                  ],
                ],
              ),
              Text(
                current == null
                    ? S.loyaltyProgramNoRule
                    : _ruleCaption(current),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: adminMutedColor(theme),
                  fontSize: AppFontSizes.size9_5,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ],
          ),
        ),
        if (canManage)
          if (compact)
            IconButton(
              key: const Key('loyalty-program-edit'),
              tooltip: S.loyaltyProgramEditTooltip,
              onPressed: onEdit,
              style: IconButton.styleFrom(
                fixedSize: const Size(30, 30),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColor.adminAccent,
              ),
              icon: const Icon(HugeIcons.strokeRoundedEdit01, size: 16),
            )
          else
            TextButton.icon(
              key: const Key('loyalty-program-edit'),
              onPressed: onEdit,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColor.adminAccent,
                textStyle: const TextStyle(
                  fontSize: AppFontSizes.size10,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
              icon: const Icon(HugeIcons.strokeRoundedEdit01, size: 15),
              label: Text(
                current == null ? S.loyaltyProgramSetup : S.loyaltyProgramEdit,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
      ],
    );
  }

  String _ruleCaption(AdminLoyaltyRule rule) {
    final name = rule.nameFor(AppLocale.instance.language);
    final code = rule.code.trim();
    if (code.isEmpty || code == name) return name;
    return '$name  •  $code';
  }

  Color _statusColor(AdminLoyaltyRule rule) {
    final now = DateTime.now();
    if (!rule.isActive) return AppColor.adminWarning;
    if (rule.isCurrent) return AppColor.trendPositive;
    final end = rule.validTo;
    final start = rule.validFrom;
    if (end != null && end.isBefore(now)) return AppColor.errorColor;
    if (start != null && start.isAfter(now)) return AppColor.adminInfo;
    return AppColor.adminMuted;
  }
}

class _ProgramStat extends StatelessWidget {
  const _ProgramStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size8_5,
            height: AppTextHeights.line1_5,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: adminBodyColor(theme),
            fontSize: AppFontSizes.size10_5,
            fontWeight: AppFontWeights.semiBold,
            height: AppTextHeights.line1_5,
          ),
        ),
      ],
    );
  }
}
