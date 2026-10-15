import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OnBoardingPageViewData extends StatelessWidget {
  const OnBoardingPageViewData({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnBoardingCubit, OnBoardingState>(
      builder: (context, state) {
        if (state is OnBoardingInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is OnBoardingError) {
          return Center(child: Text(state.message));
        }
        final slides = state is OnBoardingLoaded
            ? (state as OnBoardingLoaded).slides
            : const [];
        if (slides.isEmpty) {
          return const Center(child: Text('No onboarding slides'));
        }
        final cubit = context.read<OnBoardingCubit>();
        return PageView.builder(
          controller: cubit.pageController,
          onPageChanged: (value) => cubit.changePage(value),
          itemCount: slides.length,
          itemBuilder: (context, index) {
            final item = slides[index];
            return Column(
              children: [
                Expanded(
                  child: Image.asset(item.image, fit: BoxFit.fill),
                ),
                SizedBox(height: 32.h),
                Text(
                  textAlign: TextAlign.center,
                  item.title,
                  style: AppFonts.semiBold24(
                    context,
                  ).copyWith(color: AppColor.primaryColor),
                ),
                SizedBox(height: 12.h),
                Text(
                  textAlign: TextAlign.center,
                  item.body,
                  style: AppFonts.semiBold16(
                    context,
                  ).copyWith(color: AppColor.greyColor),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
