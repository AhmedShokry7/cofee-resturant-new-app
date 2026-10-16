import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

class CategoryGridItem extends StatelessWidget {
  const CategoryGridItem({
    super.key,
    required this.category,
    required this.onTap,
  });

  final CategoryModel category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = category.imageUrl?.trim() ?? '';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 56.w,
            width: 56.w,
            decoration: BoxDecoration(
              color: AppColor.lightGreyColor,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: AppColor.blackColor.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            // The database picture when the row carries one, otherwise the
            // icon mapped from `icon_key`. Both live in the same tile so a
            // category without an image never renders an empty box.
            child: imageUrl.isEmpty
                ? Icon(category.icon, size: 26.w, color: AppColor.primaryColor)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: DbImage(image: imageUrl, iconSize: 26.w),
                  ),
          ),
          SizedBox(height: SpacingTokens.sm.h),
          Text(
            category.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.medium12(context),
          ),
        ],
      ),
    );
  }
}
