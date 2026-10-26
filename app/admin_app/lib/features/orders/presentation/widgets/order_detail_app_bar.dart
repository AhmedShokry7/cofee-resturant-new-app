import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class OrderDetailAppBar extends StatelessWidget {
  const OrderDetailAppBar({
    super.key,
    required this.orderNumber,
    required this.onBack,
  });

  final String orderNumber;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 16, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: adminRowBorderColor(theme))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: S.back,
            onPressed: onBack,
            style: IconButton.styleFrom(
              fixedSize: const Size(36, 36),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: AppIcon(
              rtl ? AppIcons.arrowRight01 : AppIcons.arrowLeft01,
              size: 18,
              color: adminMutedColor(theme),
            ),
          ),
          const SizedBox(width: AppSizes.px6),
          Expanded(
            child: Text(
              S.orderDetails,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminHeadingColor(theme),
                fontSize: AppFontSizes.size15,
                fontWeight: AppFontWeights.bold,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.px12),
          Flexible(
            child: Text(
              '#$orderNumber',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: dark ? AppColor.darkTextSecondary : AppColor.adminDate,
                fontSize: AppFontSizes.size11,
                fontWeight: AppFontWeights.medium,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
