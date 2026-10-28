import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_selection_checkbox.dart';

/// A category card: image area on top, name and product count below.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.category,
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
    this.onChangeImage,
    this.countLabel,
    this.isSelected = false,
    this.onSelect,
  });

  final AdminCategory category;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleActive;
  final VoidCallback? onChangeImage;

  /// Overrides the product count under the name, such as the number of
  /// components of a bundle.
  final String? countLabel;

  /// The category is picked for a bulk action.
  final bool isSelected;

  final VoidCallback? onSelect;

  /// كتلة الأسطر تحت الصورة: سطر الاسم وسطر العدد على قياس العنوان الصغير
  /// والنصّ الصغير في الثيم، وهما سطران لا يلفّ أحدهما لأن كليهما `maxLines:
  /// 1`؛ لذلك يُضرب هذا القياس في مقياس النصّ بدل أن يبقى على حجمه الافتراضي
  /// حين يكبّر الأدمن الخط.
  static const double textBlockExtent = 36.0;

  /// ما لا يكبر مع النصّ: حشو كتلة النصّ العمودي والفاصل بين سطريها وشريط
  /// الأزرار وحدود البطاقة.
  static const double chromeExtent =
      AppSpacing.sm * 2 + AppSizes.px4 + AppDimensions.recordFooterHeight + 3.0;

  /// ارتفاع بطاقة بعرض [cardWidth]: صورتها مربّعة، فطولها هو عرضها زائد
  /// جسمها. تُسأل الشبكة هذا الرقم بدل أن تُخمِن نسبة طول إلى عرض.
  static double extent(double cardWidth, TextScaler scaler) =>
      cardWidth + chromeExtent + scaler.scale(textBlockExtent);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.greyColor;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.recordBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image area
          AspectRatio(
            aspectRatio: 1,
            child: GestureDetector(
              onTap: onChangeImage,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CategoryImage(url: category.imageUrl),
                  PositionedDirectional(
                    top: AppDimensions.recordImageInset,
                    end: AppDimensions.recordImageInset,
                    child: AdminSelectionCheckBox(
                      checked: isSelected,
                      onTap: onSelect,
                    ),
                  ),
                  if (!category.isActive)
                    PositionedDirectional(
                      top: AppDimensions.recordImageInset,
                      start: AppDimensions.recordImageInset,
                      child: _InactiveBadge(onTap: onToggleActive),
                    ),
                  PositionedDirectional(
                    bottom: AppDimensions.recordImageInset,
                    start: AppDimensions.recordImageInset,
                    child: _ImagePill(onTap: onChangeImage),
                  ),
                ],
              ),
            ),
          ),
          // Name and count
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.nameFor(AppLocale.instance.language),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: AppFontWeights.semiBold,
                    color: dark ? AppColor.darkText : AppColor.recordTextStrong,
                  ),
                ),
                const SizedBox(height: AppSizes.px4),
                Text(
                  countLabel ?? S.productsCount(category.productCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          // Footer
          _CategoryCardFooter(
            isActive: category.isActive,
            onEdit: onEdit,
            onDelete: onDelete,
            onToggleActive: onToggleActive,
          ),
        ],
      ),
    );
  }
}

class _CategoryImage extends StatelessWidget {
  const _CategoryImage({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark
        ? AppColor.darkSurfaceContainer
        : AppColor.imagePlaceholder;
    final iconColor = dark ? AppColor.darkTextSecondary : AppColor.greyColor;
    final image = url?.trim();
    if (image == null || image.isEmpty) {
      return ColoredBox(
        color: background,
        child: Center(
          child: Icon(AppIcons.folder01, size: 40, color: iconColor),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: image,
      fit: BoxFit.fill,
      placeholder: (context, url) => ColoredBox(
        color: background,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => ColoredBox(
        color: background,
        child: Center(
          child: Icon(AppIcons.folder01, size: 40, color: iconColor),
        ),
      ),
    );
  }
}

class _InactiveBadge extends StatelessWidget {
  const _InactiveBadge({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.errorColor,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                AppIcons.cancel01,
                size: 12,
                color: AppColor.whiteColor,
              ),
              const SizedBox(width: AppSizes.px4),
              Text(
                S.inactive,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColor.whiteColor,
                  fontSize: AppFontSizes.size11,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePill extends StatelessWidget {
  const _ImagePill({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.whiteColor,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.addImageOrVideo,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColor.primaryColor,
                  fontSize: AppFontSizes.size12,
                ),
              ),
              const SizedBox(width: AppSizes.px6),
              const Icon(
                AppIcons.imageAdd01,
                size: 14,
                color: AppColor.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCardFooter extends StatelessWidget {
  const _CategoryCardFooter({
    required this.isActive,
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
  });

  final bool isActive;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final border = dark ? AppColor.darkBorder : AppColor.recordBorder;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.greyColor;
    final activeColor = dark ? AppColor.secondaryColor : AppColor.primaryColor;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FooterAction(
              icon: AppIcons.edit01,
              label: S.edit,
              color: dark ? AppColor.darkTextSecondary : AppColor.recordText,
              onTap: onEdit,
            ),
          ),
          Expanded(
            child: _FooterAction(
              divider: border,
              icon: isActive
                  ? AppIcons.checkmarkCircle01
                  : AppIcons.cancelCircle,
              label: isActive ? S.active : S.inactive,
              color: onToggleActive == null ? muted : activeColor,
              onTap: onToggleActive,
            ),
          ),
          Expanded(
            child: _FooterAction(
              divider: border,
              icon: AppIcons.delete01,
              label: S.delete,
              color: AppColor.errorColor,
              onTap: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

/// خلية فعل في ذيل البطاقة: أيقونة وسطر واحد.
///
/// البطاقة تتقلّص مع الشبكة إلى عرضٍ لا يسع ثلاثة أفعال، وحين يكبّر الأدمن
/// الخط تطول التسمية أكثر من خليتها، فتنكسر البطاقة بفيضانٍ أفقي. التصغير
/// عند الضرورة وحدها يبقي الأزرار الثلاثة مرئية على أي عرض بدل أن يقطع
/// «غير نشط» أو يدفع الزرّ خلف حافة البطاقة.
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

  /// حدّ الخلية الذي يفصلها عن يساريها في اللاتجاهين.
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
