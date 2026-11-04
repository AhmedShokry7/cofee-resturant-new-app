import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/domain/entities/preview_product.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_labels.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_palette.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_struck_price.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/theme/app_icons.dart';

/// صفحة تفاصيل المنتج داخل الهاتف، مما يقرأه صفّ المنتج نفسه.
///
/// الصورة والاسم والتصنيف والوصف والسعر بأسعاره المحسوبة — وهي نفس الأرقام التي
/// طبعتها البطاقة. ما لا تملك اللوحة نسخة منه لا يُعرض: خيارات المنتج وسلة الزبون
/// تخصّ حساب صاحب الجهاز، فيقول السطر ذلك بدل زرّ لا يضيف شيئًا.
class SimulatorProductDetailsScreen extends StatelessWidget {
  const SimulatorProductDetailsScreen({
    super.key,
    required this.product,
    required this.language,
    required this.labels,
    this.onBack,
  });

  final PreviewProduct product;
  final AppLanguage language;
  final SimulatorLabels labels;

  /// رجوع من الشاشة. null يعني لا مخرج: لا يُوهم الموظف بزرّ لا يعمل.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = SimulatorPalette.of(context);
    final oldPrice = product.oldPrice;
    final description = (language.isArabic ? product.descriptionAr : product.descriptionEn)?.trim();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        if (onBack != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(onPressed: onBack, child: Text(labels.back)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: AspectRatio(
            aspectRatio: 1,
            child: AdminNetworkThumb(
              imageUrl: product.imageUrl,
              width: AppDimensions.simulatorProductCardMaxWidth,
              height: AppDimensions.simulatorProductCardMaxWidth,
              fit: product.imageFit,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              icon: AppIcons.image01,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.nameFor(language),
                style: AppFonts.semiBold20(context)
                    .copyWith(color: palette.textPrimary ?? adminHeadingColor(theme)),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                product.categoryFor(language),
                style: AppFonts.regular14(context)
                    .copyWith(color: palette.textSecondary ?? adminMutedColor(theme)),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Flexible(
                    child: AdminMoneyText(
                      value: product.price,
                      fontSize: AppFontSizes.size18,
                      color: palette.primary,
                    ),
                  ),
                  if (oldPrice != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(child: SimulatorStruckPrice(value: oldPrice)),
                  ],
                ],
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  description,
                  style: AppFonts.regular14(context)
                      .copyWith(color: palette.textSecondary ?? adminMutedColor(theme)),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: adminTintedSurfaceColor(theme),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    AppIcon(
                      AppIcons.informationCircle,
                      size: AppSizes.px16,
                      color: palette.textSecondary ?? adminMutedColor(theme),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        labels.detailsNote,
                        style: AppFonts.regular12(context)
                            .copyWith(color: palette.textSecondary ?? adminMutedColor(theme)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
