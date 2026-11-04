import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_palette.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// عنوان مقطع داخل شاشة العميل، مع سطره الثانوي ورابطه على طرفه.
///
/// الأرقام من `HomeSectionTitle` و`HomeSectionLink` في تطبيق العميل: العنوان
/// الافتراضي نصف عريض 16، والتصنيف وحده يرفع عنوانه إلى 18، والرابط صندوق
/// بحدّ رفيع وزاوية ستة لا زرّ ملوّن.
class SimulatorSectionHeading extends StatelessWidget {
  const SimulatorSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.titleStyle,
    this.trailingLabel,
    this.onTapTrailing,
  });

  final String title;

  /// سطر تحت العنوان: يطبعه العميل مكان الترجيح الموسمي فقط، ولا يحجز مكانًا
  /// وهو فارغ.
  final String? subtitle;

  /// حجم العنوان. المقاطع تتشارك الصف لا المقاس، كما هناك.
  final TextStyle? titleStyle;

  /// تسمية الرابط، مثل «عرض الكل». لا يُرسم إلا حين يكون له فعل حقيقي في
  /// المحاكي، لأن رابطًا لا يفتح شيئًا وعدٌ كاذب.
  final String? trailingLabel;
  final VoidCallback? onTapTrailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = SimulatorPalette.of(context);
    final link = trailingLabel;
    final onTap = onTapTrailing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (titleStyle ?? AppFonts.semiBold16(context)).copyWith(
                  color: palette.textPrimary ?? adminHeadingColor(theme),
                ),
              ),
            ),
            if (link != null && onTap != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Semantics(
                  link: true,
                  label: link,
                  child: Material(
                    color: AppColor.transparent,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.simulatorSectionLinkRadius,
                    ),
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.simulatorSectionLinkRadius,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppDimensions.simulatorSectionLinkPaddingVertical,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: palette.textSecondary ?? adminMutedColor(theme),
                          ),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.simulatorSectionLinkRadius,
                          ),
                        ),
                        child: Text(
                          link,
                          style: AppFonts.medium12(context).copyWith(
                            color: palette.textPrimary ?? adminBodyColor(theme),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: AppFonts.regular12(context)
                .copyWith(color: palette.textSecondary ?? adminMutedColor(theme)),
          ),
      ],
    );
  }
}
