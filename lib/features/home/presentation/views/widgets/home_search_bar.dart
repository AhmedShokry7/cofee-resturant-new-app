import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/search/presentation/manager/search/search_cubit.dart';
import 'package:new_coffee/features/search/presentation/views/search_page.dart';

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<SearchCubit>().search('');
        Navigator.of(context).pushNamed(SearchPage.routeName);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: SpacingTokens.lg.w,
          vertical: SpacingTokens.md.h,
        ),
        decoration: BoxDecoration(
          color: AppColor.lightGreyColor,
          borderRadius: BorderRadius.circular(100.r),
        ),
        child: Row(
          children: [
            Icon(
              HugeIcons.strokeRoundedSearch01,
              size: 20.w,
              color: AppColor.greyColor,
            ),
            SizedBox(width: SpacingTokens.sm.w),
            Text(
              S.searchHint,
              style: AppFonts.regular14(context)
                  .copyWith(color: AppColor.greyColor),
            ),
          ],
        ),
      ),
    );
  }
}
