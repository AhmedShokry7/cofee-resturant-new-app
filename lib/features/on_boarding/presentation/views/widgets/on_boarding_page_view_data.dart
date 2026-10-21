import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/on_boarding/data/on_boarding_list.dart';
import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OnBoardingPageViewData extends StatelessWidget {
  const OnBoardingPageViewData({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = BlocProvider.of<OnBoardingCubit>(context);
    final onBoardingList = getOnBoardingList(context);
    final itemCount = onBoardingList.length;
    return PageView.builder(
      controller: cubit.pageController,
      onPageChanged: (value) => cubit.changePage(value),
      itemBuilder: (context, index) {
        final item = onBoardingList[index];
        return Column(
          children: [
                SizedBox(height: 8.h),
            Image.asset(item.image, height: 380.h, fit: BoxFit.fill),
            SizedBox(height: 24.h),
            Text(
              textAlign: TextAlign.center,
              item.title,
              style: AppFonts.semiBold24(
                context,
              ).copyWith(color: AppColor.primaryColor),
            ),
            SizedBox(height: 4.h),
            Text(
              textAlign: TextAlign.center,
              item.body,
              style: AppFonts.regular16(
                context,
              ).copyWith(color: AppColor.greyColor),
            ),
          ],
        );
      },
      itemCount: itemCount,
    );
  }
}
