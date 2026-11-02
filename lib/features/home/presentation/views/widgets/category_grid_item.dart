import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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
    // The tile is one target: its own label names it, so the semantics only has
    // to say that pressing it does something.
    return Semantics(
      button: true,
      child: Material(
        color: AppColor.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.r16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: AppSizes.px56,
                width: AppSizes.px56,
                decoration: BoxDecoration(
                  color: AppColor.lightGreyColor,
                  borderRadius: BorderRadius.circular(AppRadius.r16),
                  boxShadow: AppShadows.tile,
                ),
                // The database picture when the row carries one, otherwise the
                // icon mapped from `icon_key`. Both live in the same tile so a
                // category without an image never renders an empty box.
                child: imageUrl.isEmpty
                    ? Icon(
                        category.icon,
                        size: AppSizes.px26,
                        color: AppColor.primaryColor,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.r16),
                        child: DbImage(
                          image: imageUrl,
                          iconSize: AppSizes.px26,
                        ),
                      ),
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                category.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.medium12(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
