import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OnBoardingDots extends StatelessWidget {
  const OnBoardingDots({super.key, required this.currentPage});

  final int currentPage;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnBoardingCubit, OnBoardingState>(
      builder: (context, state) {
        final count = state is OnBoardingLoaded
            ? (state).slides.length
            : 0;
        return Row(
          children: [
            ...List.generate(
              count,
              (index) => AnimatedContainer(
                margin: const EdgeInsets.only(right: 8),
                height: currentPage == index ? 10.h : 6.h,
                width: currentPage == index ? 10.h : 6.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: currentPage == index
                      ? AppColor.primaryColor
                      : AppColor.greyColor.withValues(alpha: .5),
                ),
                duration: const Duration(milliseconds: 300),
              ),
            ),
          ],
        );
      },
    );
  }
}
