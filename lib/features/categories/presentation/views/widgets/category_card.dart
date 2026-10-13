import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({super.key, required this.category, required this.onTap});

  final CategoryModel category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColor.whiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColor.borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 52.w,
              width: 52.w,
              decoration: BoxDecoration(
                color: AppColor.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                category.icon,
                size: 26.w,
                color: AppColor.primaryColor,
              ),
            ),
            SizedBox(height: SpacingTokens.md.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: SpacingTokens.sm.w),
              child: Text(
                category.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.medium16(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
