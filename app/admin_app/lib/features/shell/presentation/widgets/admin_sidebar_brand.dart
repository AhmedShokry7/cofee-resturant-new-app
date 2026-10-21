import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/constants/app_images.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';

/// The brand block at the top of the navigation panel: the logo and the app
/// name.
class AdminSidebarBrand extends StatelessWidget {
  const AdminSidebarBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.lg,
        AppDimensions.lg,
        AppDimensions.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            child: Image.asset(
              AppImages.logo,
              width: AppDimensions.sidebarLogoSize,
              height: AppDimensions.sidebarLogoSize,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Text(
              S.appName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColor.whiteColor,
                fontWeight: FontWeight.w500,
                height: AppDimensions.textHeightTight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
