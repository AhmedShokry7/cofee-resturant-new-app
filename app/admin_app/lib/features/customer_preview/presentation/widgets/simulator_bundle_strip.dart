import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';
import 'package:admin_app/features/customer_preview/domain/entities/customer_feed.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_struck_price.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// شريط الباقات في آخر صفحة العميل: صف بطاقات عَرْضها ثابت وارتفاعه كامل
/// المقطع، والسعر فيها سعر الباقة لا جمع مكوّناتها.
class SimulatorBundleStrip extends StatelessWidget {
  const SimulatorBundleStrip({
    super.key,
    required this.bundles,
    required this.feed,
    required this.language,
  });

  final List<AdminBundle> bundles;
  final CustomerFeed feed;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.simulatorBundleRowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: bundles.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) => SimulatorBundleCard(
          bundle: bundles[index],
          original: feed.bundleOriginalTotal(bundles[index]),
          language: language,
        ),
      ),
    );
  }
}

/// بطاقة باقة واحدة: صورتها، اسمها، سطر وصفها، وسعرها أمام السعر لو كان
/// مجتمَع المكوّنات أعلى.
///
/// الصورة لأوّل مكوّن حين لا صورة للباقة نفسها، كما يفعل العميل: الباقة تُشاهَد
/// بما فيها، لا بمربع فارغ.
class SimulatorBundleCard extends StatelessWidget {
  const SimulatorBundleCard({
    super.key,
    required this.bundle,
    required this.original,
    required this.language,
  });

  final AdminBundle bundle;
  final double original;
  final AppLanguage language;

  static const double _imageRadius = AppRadius.lg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = bundle.effectivePrice;
    final hasDiscount = original > price;
    return Container(
      width: AppDimensions.simulatorBundleCardWidth,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => AdminNetworkThumb(
                imageUrl: _image(),
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                fit: BoxFit.fill,
                borderRadius: BorderRadius.circular(_imageRadius),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            bundle.nameFor(language),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.semiBold14(context)
                .copyWith(color: adminHeadingColor(theme)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _subtitle(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.regular12(context)
                .copyWith(color: adminMutedColor(theme)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Flexible(
                child: AdminMoneyText(
                  value: price,
                  fontSize: AppFontSizes.size14,
                  color: AppColor.primaryColor,
                ),
              ),
              if (hasDiscount) ...[
                const SizedBox(width: AppSpacing.xs),
                Flexible(child: SimulatorStruckPrice(value: original)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// صورة الباقة، وإلا صورة أوّل مكوّن لها.
  String? _image() => bundleImage(bundle);

  /// سطر الوصف كسطر العميل: وصف باقتين لا واحدة، فإن خلا الوصف بقي الاسم وحده.
  String _subtitle() => bundleSubtitle(bundle, language);
}

/// صف باقة كامل العرض، كما تظهر في قائمة تبويب الباقات عند العميل: صورة
/// مربّعة، ثم اسمها ووصفها وسعرها، ثم سهم يفتح تفاصيلها.
///
/// السهم علامة على أن الصف يُفتح لا زرّ: تفاصيل الباقة شاشة في تطبيق الزبون،
/// واللوحة لا تفتحها من داخل الهاتف، فتُترك بلا فعل ظاهر.
class SimulatorBundleListTile extends StatelessWidget {
  const SimulatorBundleListTile({
    super.key,
    required this.bundle,
    required this.original,
    required this.language,
  });

  final AdminBundle bundle;
  final double original;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = bundle.effectivePrice;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: SizedBox(
              height: AppDimensions.simulatorBundleThumbSize,
              width: AppDimensions.simulatorBundleThumbSize,
              child: AdminNetworkThumb(
                imageUrl: bundleImage(bundle),
                width: AppDimensions.simulatorBundleThumbSize,
                height: AppDimensions.simulatorBundleThumbSize,
                fit: BoxFit.fill,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bundle.nameFor(language),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.semiBold16(context)
                      .copyWith(color: adminHeadingColor(theme)),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  bundleSubtitle(bundle, language),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.regular12(context)
                      .copyWith(color: adminMutedColor(theme)),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Flexible(
                      child: AdminMoneyText(
                        value: price,
                        fontSize: AppFontSizes.size14,
                        color: AppColor.primaryColor,
                      ),
                    ),
                    if (original > price) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(child: SimulatorStruckPrice(value: original)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppIcon(
            rtl ? AppIcons.arrowLeft01 : AppIcons.arrowRight01,
            size: AppSizes.px20,
            color: adminMutedColor(theme),
          ),
        ],
      ),
    );
  }
}

/// صورة الباقة المعروضة: صورتها، وإلا صورة أوّل مكوّن له صورة.
String? bundleImage(AdminBundle bundle) {
  final own = bundle.imageUrl?.trim() ?? '';
  if (own.isNotEmpty) return own;
  for (final component in bundle.components) {
    final url = component.imageUrl?.trim() ?? '';
    if (url.isNotEmpty) return url;
  }
  return null;
}

/// سطر الوصف تحت اسم الباقة، بلغة المعاينة وإلا بالأخرى.
String bundleSubtitle(AdminBundle bundle, AppLanguage language) {
  final arabic = language.isArabic;
  for (final value in [
    arabic ? bundle.descriptionAr : bundle.descriptionEn,
    arabic ? bundle.descriptionEn : bundle.descriptionAr,
  ]) {
    final text = value?.trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}
