import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_dots.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_back_btn.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_next_btn.dart';
import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OnBoardingButtonsAndSliderDotes extends StatelessWidget {
  const OnBoardingButtonsAndSliderDotes({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnBoardingCubit, OnBoardingState>(
      builder: (context, state) {
        int currentPage = 0;
        if (state is OnBoardingPageChanged) {
          currentPage = state.currentPage;
        }
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              currentPage != 0
                  ? const OnBoardingBackBtn()
                  : SizedBox(width: AppConstant.btnHeight(context)),
              OnBoardingDots(currentPage: currentPage),
              const OnBoardingNextBtn(),
            ],
          ),
        );
      },
    );
  }
}
