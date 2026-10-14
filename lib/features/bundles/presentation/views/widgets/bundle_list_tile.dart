import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/bundles/data/bundles_list.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/bundles/presentation/views/bundle_details_page.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

/// Full-width bundle row for vertical lists (e.g. the Bundles tab).
class BundleListTile extends StatelessWidget {
  const BundleListTile({super.key, required this.bundle});

  final BundleModel bundle;

  @override
  Widget build(BuildContext context) {
    final products = bundleProducts(bundle);
    final image = products.isEmpty ? null : products.first.image;
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        BundleDetailsPage.routeName,
        arguments: bundle,
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.only(bottom: SpacingTokens.md.h),
        padding: EdgeInsets.all(SpacingTokens.md.w),
        decoration: BoxDecoration(
          color: AppColor.whiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColor.borderColor),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: image == null
                  ? SizedBox(width: 64.w, height: 64.w)
                  : Image.asset(
                      image,
                      height: 64.w,
                      width: 64.w,
                      fit: BoxFit.cover,
                    ),
            ),
            SizedBox(width: SpacingTokens.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bundle.title,
                    style: AppFonts.semiBold16(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    bundle.subtitle,
                    style: AppFonts.regular12(
                      context,
                    ).copyWith(color: AppColor.greyColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Text(
                        Formatters.price(bundle.price),
                        style: AppFonts.semiBold14(
                          context,
                        ).copyWith(color: AppColor.primaryColor),
                      ),
                      SizedBox(width: SpacingTokens.xs.w),
                      Flexible(
                        child: Text(
                          Formatters.price(bundleOriginalTotal(bundle)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.regular12(context).copyWith(
                            color: AppColor.greyColor,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              HugeIcons.strokeRoundedArrowRight01,
              size: 20.w,
              color: AppColor.greyColor,
            ),
          ],
        ),
      ),
    );
  }
}
