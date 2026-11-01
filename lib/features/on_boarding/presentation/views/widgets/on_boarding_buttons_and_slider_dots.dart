import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_back_btn.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_circle_button.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_dots.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_next_btn.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The step controls: back where there is somewhere to go back to, the dots,
/// and forward.
class OnBoardingButtonsAndSliderDots extends StatelessWidget {
  const OnBoardingButtonsAndSliderDots({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnBoardingCubit, OnBoardingState>(
      builder: (context, state) {
        final currentPage = state is OnBoardingPageChanged
            ? state.currentPage
            : 0;
        final cubit = context.read<OnBoardingCubit>();
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // The first slide has no way back, so the space the back step
              // would take is kept for the dots to stay where they are.
              if (currentPage != 0)
                const OnBoardingBackBtn()
              else
                SizedBox(width: OnBoardingCircleButton.stepSize),
              OnBoardingDots(
                currentPage: currentPage,
                slideCount: cubit.slideCount,
              ),
              const OnBoardingNextBtn(),
            ],
          ),
        );
      },
    );
  }
}
