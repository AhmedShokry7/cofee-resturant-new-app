import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/domain/entities/preview_product.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_struck_price.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';

/// بطاقة منتج كما يرسمها تطبيق العميل.
///
/// الخانات بأرقامها في `ProductCard` هناك: صورة تأخذ بقدر البطاقة، ثم الاسم،
/// ثم سطر التصنيف (أو الوصف إن خلا التصنيف)، ثم السعر. البطاقة تُطبع سعرين
/// فقط: ما حُسب عند القراءة في `PreviewProduct`، لأنها لا تعرف نافذة خصم ولا
/// قراءتها.
///
/// زرّ المفضلة وزرّ الإضافة لا يُرسمان: لا بيانات حساب عند اللوحة، ولا معنى
/// لزرّ لا يضغط شيئًا — ومكانهما تُسمّيه السكة الجانبية.
class SimulatorProductCard extends StatelessWidget {
  const SimulatorProductCard({
    super.key,
    required this.product,
    required this.language,
    this.showPrice = true,
  });

  final PreviewProduct product;
  final AppLanguage language;

  /// شريط بلا سعر يبقى شريطًا ببطاقته نفسها: السطران تحت الصورة وحدهما، لا
  /// بطاقة أخرى رسمها المحرّر.
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final oldPrice = product.oldPrice;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            // القياس من القيود: بطاقة العميل تأخذ الصورة بقدر ما بقي لها،
            // والأيقونة البديلة تحتاج رقمًا متمدّدًا لا اللانهاية.
            child: LayoutBuilder(
              builder: (context, constraints) => AdminNetworkThumb(
                imageUrl: product.imageUrl,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                fit: product.imageFit,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            product.nameFor(language),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.semiBold16(context)
                .copyWith(color: adminHeadingColor(theme)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            product.secondaryFor(language),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.regular12(context)
                .copyWith(color: adminMutedColor(theme)),
          ),
          if (showPrice) ...[
            const SizedBox(height: AppSizes.px6),
            Row(
              children: [
                Flexible(
                  child: AdminMoneyText(
                    value: product.price,
                    fontSize: AppFontSizes.size14,
                    color: AppColor.primaryColor,
                  ),
                ),
                if (oldPrice != null) ...[
                  const SizedBox(width: AppSizes.px6),
                  Flexible(child: SimulatorStruckPrice(value: oldPrice)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
