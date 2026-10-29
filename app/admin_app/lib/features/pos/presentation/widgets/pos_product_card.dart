import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/pos/domain/entities/pos_catalog.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_format.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

class PosProductCard extends StatelessWidget {
  const PosProductCard({
    super.key,
    required this.product,
    required this.inCart,
    required this.remaining,
    required this.onTap,
  });

  final PosProduct product;
  final int inCart;

  /// Null means the branch does not cap this product's quantity.
  final int? remaining;
  final VoidCallback onTap;

  bool get _enabled =>
      product.isSellable && (remaining == null || remaining! > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = AppLocale.instance.language;
    final disabled = !product.isSellable;
    final category = product.categoryNameFor(language);
    final prep = product.prepMinutes;
    final discount = product.discountPercentage.round();

    return Semantics(
      button: true,
      enabled: _enabled,
      label: product.nameFor(language),
      child: Opacity(
        opacity: disabled ? .58 : 1,
        child: Stack(
          children: [
            Material(
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: BorderSide(color: adminCardBorderColor(theme)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _enabled ? onTap : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The image takes every pixel the content does not need.
                    Expanded(child: _ProductImage(product: product)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.nameFor(language),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adminHeadingColor(theme),
                              fontSize: AppFontSizes.size13,
                              fontWeight: AppFontWeights.bold,
                              height: AppTextHeights.line1_35,
                            ),
                          ),
                          if (category.isNotEmpty || prep != null) ...[
                            const SizedBox(height: AppSizes.px4),
                            Row(
                              children: [
                                if (category.isNotEmpty)
                                  Expanded(
                                    child: Text(
                                      category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: adminMutedColor(theme),
                                        fontSize: AppFontSizes.size10,
                                        height: AppTextHeights.line1_5,
                                      ),
                                    ),
                                  ),
                                if (prep != null) ...[
                                  if (category.isNotEmpty)
                                    const SizedBox(width: AppSizes.px6),
                                  _MetaChip(
                                    icon: AppIcons.timer01,
                                    label: S.posPrepTimeShort(prep),
                                    color: AppColor.adminInfo,
                                    surface: AppColor.adminInfoSurface,
                                  ),
                                ],
                              ],
                            ),
                          ],
                          const SizedBox(height: AppSizes.px8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          posAmount(product.unitPrice),
                                          style: TextStyle(
                                            color: adminFlagForeground(
                                              theme,
                                              AppColor.adminAccent,
                                            ),
                                            fontSize: AppFontSizes.size14_5,
                                            fontWeight: AppFontWeights.bold,
                                            height: AppTextHeights.line1_2,
                                          ),
                                        ),
                                        const SizedBox(width: AppSizes.px4),
                                        CurrencyIcon(
                                          size: 13,
                                          color: adminFlagForeground(
                                            theme,
                                            AppColor.adminAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (product.hasDiscount) ...[
                                      const SizedBox(height: AppSizes.px4),
                                      Row(
                                        children: [
                                          if (discount > 0) ...[
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: AppSpacing.xs,
                                                    vertical: AppSpacing.xxs,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: adminFlagBackground(
                                                  theme,
                                                  AppColor.trendNegative,
                                                  AppColor.trendNegativeSurface,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.sm,
                                                    ),
                                              ),
                                              child: Text(
                                                '-${localizeDigits('$discount')}%',
                                                textDirection:
                                                    TextDirection.ltr,
                                                style: TextStyle(
                                                  color: adminFlagForeground(
                                                    theme,
                                                    AppColor.trendNegative,
                                                  ),
                                                  fontSize:
                                                      AppFontSizes.size8_5,
                                                  fontWeight:
                                                      AppFontWeights.bold,
                                                  height:
                                                      AppTextHeights.line1_3,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: AppSizes.px4),
                                          ],
                                          Flexible(
                                            child: Text(
                                              posAmount(product.regularPrice),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: adminMutedColor(theme),
                                                fontSize: AppFontSizes.size9_5,
                                                decoration:
                                                    TextDecoration.lineThrough,
                                                height: AppTextHeights.line1_2,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: AppSizes.px4),
                                          CurrencyIcon(
                                            size: 11,
                                            color: adminMutedColor(theme),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSizes.px8),
                              if (_enabled)
                                _AddButton(
                                  tooltip: product.hasOptions
                                      ? S.posOptionsTitle
                                      : S.posAddToCart,
                                  onTap: onTap,
                                )
                              else
                                _DisabledBadge(
                                  label: product.soldOut
                                      ? S.posSoldOut
                                      : S.posUnavailable,
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
            if (inCart > 0)
              PositionedDirectional(
                top: 8,
                end: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: adminFlagForeground(theme, AppColor.adminAccent),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: adminIsDark(theme)
                        ? const []
                        : const [
                            BoxShadow(
                              color: AppColor.inkWashStrong,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Text(
                    localizeDigits('$inCart'),
                    style: const TextStyle(
                      color: AppColor.whiteColor,
                      fontSize: AppFontSizes.size9_5,
                      fontWeight: AppFontWeights.bold,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.product});

  final PosProduct product;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => AdminNetworkThumb(
            imageUrl: product.imageUrl,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            fit: BoxFit.fill,
            borderRadius: BorderRadius.zero,
            icon: AppIcons.coffee01,
          ),
        ),
        if (product.isFeatured)
          PositionedDirectional(
            top: 8,
            start: 8,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColor.adminAccent,
                shape: BoxShape.circle,
              ),
              child: const AppIcon(
                AppIcons.star,
                size: 12,
                color: AppColor.whiteColor,
              ),
            ),
          ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.surface,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: adminFlagBackground(theme, color, surface),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 10, color: adminFlagForeground(theme, color)),
          const SizedBox(width: AppSizes.px2),
          Text(
            label,
            style: TextStyle(
              color: adminFlagForeground(theme, color),
              fontSize: AppFontSizes.size8_5,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_3,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: adminFlagBackground(
          theme,
          AppColor.adminAccent,
          AppColor.adminAccentSurface,
        ),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: AppSizes.px34,
            height: AppSizes.px34,
            child: AppIcon(
              AppIcons.add01,
              size: 17,
              color: adminFlagForeground(theme, AppColor.adminAccent),
            ),
          ),
        ),
      ),
    );
  }
}

class _DisabledBadge extends StatelessWidget {
  const _DisabledBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.errorColor,
          AppColor.errorColor.withValues(alpha: .08),
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColor.errorColor.withValues(alpha: .22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: adminFlagForeground(theme, AppColor.errorColor),
          fontSize: AppFontSizes.size8_5,
          fontWeight: AppFontWeights.semiBold,
          height: AppTextHeights.line1_4,
        ),
      ),
    );
  }
}
