import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// بطاقة مجموعة أحجام أو إضافات: ما هي، وأين تظهر، وكم يزيد كل خيار سعرها.
///
/// السطر الأخير من البطاقة هو ما يطلبه الأدمن حين يراجع مشروبًا: الحجم الكبير
/// بكم، والإضافة بكم — فلا يُفتَح الحوار لمعرفة رقمٍ كان معروضًا أصلًا.
class OptionGroupCard extends StatelessWidget {
  const OptionGroupCard({
    super.key,
    required this.group,
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
  });

  final AdminOptionGroup group;

  /// أدوات الكتابة: تُحجب كلها عمن لا يملك `catalog.product.write`، فالبطاقة
  /// تُقرأ كما تُقرأ بقية البطاقات ولا توهم بفعلٍ ترفضه القاعدة.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleActive;

  /// كم سطر خيار تُظهر البطاقة قبل «والبقية…»، فالشبكة تقيس خلية واحدة لكل
  /// البطاقات ولا تُطيل عمودًا على حساب غيره.
  static const int visibleValueRows = 3;

  /// ما لا يكبر مع الخط: الحشو والفاصل وشريط الأزرار وحدّ البطاقة.
  static const double chromeExtent =
      AppSpacing.lg * 2 + AppSizes.px8 + AppDimensions.recordFooterHeight + 3.0;

  /// ما يكبر مع الخط: سطر الاسم وسطر الشارتين وأسطر الخيارات.
  static const double textBlockExtent = 20 + 20 + visibleValueRows * 22;

  static double extent(double cardWidth, TextScaler scaler) =>
      chromeExtent + scaler.scale(textBlockExtent);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final language = AppLocale.instance.language;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.nameFor(language),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminHeadingColor(theme),
                      fontSize: AppFontSizes.size13,
                      fontWeight: AppFontWeights.bold,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                  const SizedBox(height: AppSizes.px6),
                  Wrap(
                    spacing: AppSizes.px6,
                    runSpacing: AppSizes.px4,
                    children: [
                      AdminStatusBadge(
                        label: _scopeLabel(group),
                        color: group.isActive
                            ? AppColor.adminAccent
                            : AppColor.adminWarning,
                      ),
                      AdminStatusBadge(
                        label:
                            group.selectionType ==
                                AdminOptionSelectionType.single
                            ? S.singleChoiceLabel
                            : S.multipleChoicesLabel,
                        color: AppColor.greyColor,
                      ),
                      if (!group.isActive)
                        AdminStatusBadge(
                          label: S.inactive,
                          color: AppColor.errorColor,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.px8),
                  Expanded(
                    child: _ValueLines(
                      values: group.values
                          .where((value) => value.isActive)
                          .toList(growable: false),
                      language: language,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onEdit != null || onDelete != null || onToggleActive != null)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: adminRowBorderColor(theme)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _FooterAction(
                      icon: AppIcons.edit01,
                      label: S.edit,
                      color: adminMutedColor(theme),
                      onTap: onEdit,
                    ),
                  ),
                  Expanded(
                    child: _FooterAction(
                      icon: group.isActive
                          ? AppIcons.checkmarkCircle01
                          : AppIcons.cancelCircle,
                      label: group.isActive ? S.active : S.inactive,
                      color: onToggleActive == null
                          ? adminMutedColor(theme)
                          : (dark
                                ? AppColor.secondaryColor
                                : AppColor.primaryColor),
                      divider: adminRowBorderColor(theme),
                      onTap: onToggleActive,
                    ),
                  ),
                  Expanded(
                    child: _FooterAction(
                      icon: AppIcons.delete01,
                      label: S.delete,
                      color: AppColor.errorColor,
                      divider: adminRowBorderColor(theme),
                      onTap: onDelete,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _scopeLabel(AdminOptionGroup group) {
    if (group.scope == AdminOptionGroupScope.products &&
        group.productIds.isEmpty) {
      return S.unassignedOptionTemplate;
    }
    return switch (group.scope) {
      AdminOptionGroupScope.all => S.scopeAllProducts,
      AdminOptionGroupScope.category => S.scopeCategories,
      AdminOptionGroupScope.products => S.scopeProducts,
    };
  }
}

/// أسطر الخيارات بأسعارها، مع سطر أخير يسمّي ما لم يُعرض.
class _ValueLines extends StatelessWidget {
  const _ValueLines({required this.values, required this.language});

  final List<AdminOptionValue> values;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (values.isEmpty) {
      return Text(
        S.addOptionValue,
        style: TextStyle(
          color: adminMutedColor(theme),
          fontSize: AppFontSizes.size10_5,
          height: AppTextHeights.line1_5,
        ),
      );
    }
    final shown = values.take(visibleRows).toList(growable: false);
    final hidden = values.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final value in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.px2),
            child: Row(
              children: [
                if (value.isDefault)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSizes.px4,
                    ),
                    child: Icon(
                      AppIcons.checkmarkCircle01,
                      size: 12,
                      color: AppColor.adminAccent,
                    ),
                  ),
                Expanded(
                  child: Text(
                    value.nameFor(language),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminBodyColor(theme),
                      fontSize: AppFontSizes.size10_5,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.px4),
                Text(
                  localizeDigits(formatDelta(value.priceDelta)),
                  style: TextStyle(
                    color: adminAmountColor(theme),
                    fontSize: AppFontSizes.size10_5,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                const SizedBox(width: AppSizes.px2),
                const CurrencyIcon(size: 10),
              ],
            ),
          ),
        if (hidden > 0)
          Text(
            localizeDigits(S.optionValuesCount(values.length)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size9_5,
              height: AppTextHeights.line1_5,
            ),
          ),
      ],
    );
  }

  static const int visibleRows = OptionGroupCard.visibleValueRows;
}

/// خلية فعل في ذيل البطاقة، على قياس ذيل بطاقة الفئة.
class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.divider,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final Color? divider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: divider == null
            ? null
            : BorderDirectional(start: BorderSide(color: divider!)),
      ),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: AppDimensions.recordFooterHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: AppSizes.px6),
                Text(
                  label,
                  maxLines: 1,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontSize: AppFontSizes.size12,
                    fontWeight: AppFontWeights.medium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
