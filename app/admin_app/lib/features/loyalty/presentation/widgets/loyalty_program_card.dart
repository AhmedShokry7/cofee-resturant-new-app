import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_rule.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_format.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_money_bits.dart';
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
        boxShadow: adminIsDark(theme)
            ? const []
            : const [
                BoxShadow(
                  color: AppColor.inkWashFaint,
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
                const SizedBox(height: AppSizes.px10),
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
              const SizedBox(width: AppSizes.px16),
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
      value: loyaltyProgramEarnRateParts(rule),
    ),
    _ProgramStat(
      label: S.loyaltyProgramPointValueLabel,
      value: loyaltyProgramPointValueParts(rule),
    ),
    _ProgramStat(
      label: S.loyaltyProgramValidityLabel,
      value: LoyaltyMoneySentence.plain(loyaltyProgramValidity(rule)),
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
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: AppIcon(
            AppIcons.gift,
            size: 18,
            color: adminFlagForeground(theme, AppColor.adminAccent),
          ),
        ),
        const SizedBox(width: AppSizes.px12),
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
                    const SizedBox(width: AppSizes.px8),
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
              icon: const Icon(AppIcons.edit01, size: 16),
            )
          else
            TextButton.icon(
              key: const Key('loyalty-program-edit'),
              onPressed: onEdit,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColor.adminAccent,
                textStyle: const TextStyle(
                  fontSize: AppFontSizes.size10,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
              icon: const Icon(AppIcons.edit01, size: 15),
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
  final LoyaltyMoneySentence value;

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
        LoyaltyMoneyText(
          sentence: value,
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
