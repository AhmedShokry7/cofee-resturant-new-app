import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// One category on the home row: a circle carrying its picture or its glyph,
/// with the name under it.
///
/// The chip owns its own measurements. [CategoryMarquee] lays its row out by
/// [slot] and sizes itself by [height], and the loading skeleton reads the same
/// two numbers, so a change here lands on the row and on its skeleton at once
/// instead of leaving one of them behind.
class CategoryCircleItem extends StatelessWidget {
  const CategoryCircleItem({
    super.key,
    required this.category,
    required this.onTap,
  });

  final CategoryModel category;
  final VoidCallback onTap;

  /// The circle's edge - the same mark size every other category tile uses.
  static const double diameter = AppDimensions.categoryTile;

  /// The air between two circles.
  ///
  /// One step under a card gap: the row still reads as a string of chips rather
  /// than a list of separate tiles, but the circles need enough space that the
  /// name under one does not sit against the circle next to it while the row is
  /// moving.
  static const double gap = AppSpacing.md;

  /// The room one chip takes along the row. The row hands this to `itemExtent`,
  /// so every chip is exactly the same width and one full turn of the loop is
  /// [CategoryMarquee]'s cycle length to the pixel.
  static const double slot = diameter + gap;

  /// The line the name is drawn on.
  ///
  /// It follows the text size the customer picked, because a row that kept a
  /// fixed allowance would cut the descenders off a large-font setting.
  static double labelHeight(BuildContext context) {
    final size = AppFonts.medium12(context).fontSize ?? AppFontSizes.size12;
    return MediaQuery.textScalerOf(context).scale(size) * AppTextHeights.body;
  }

  /// The height the whole row needs: circle, air, name.
  static double height(BuildContext context) =>
      diameter + gap + labelHeight(context);

  @override
  Widget build(BuildContext context) {
    final imageUrl = category.imageUrl?.trim() ?? '';
    // The chip is one target: its own label names it, so the semantics only has
    // to say that pressing it does something.
    return Semantics(
      button: true,
      child: Material(
        color: AppColor.transparent,
        child: InkWell(
          onTap: onTap,
          // Ink that follows the shape being pressed. A square splash behind a
          // circle reads as a bug the moment anyone taps it.
          customBorder: const CircleBorder(),
          child: Column(
            children: [
              Container(
                height: diameter,
                width: diameter,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColor.lightGreyColor,
                  border: Border.all(color: AppColor.primaryRing),
                  boxShadow: AppShadows.tile,
                ),
                // The database picture when the row carries one, otherwise the
                // icon mapped from `icon_key`. Both live in the same circle so a
                // category without an image never renders an empty box.
                child: imageUrl.isEmpty
                    ? Icon(
                        category.icon,
                        size: AppSizes.px26,
                        color: AppColor.primaryColor,
                      )
                    : DbImage(image: imageUrl, iconSize: AppSizes.px26),
              ),
              SizedBox(height: gap),
              SizedBox(
                width: slot,
                height: labelHeight(context),
                child: Text(
                  category.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.medium12(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
