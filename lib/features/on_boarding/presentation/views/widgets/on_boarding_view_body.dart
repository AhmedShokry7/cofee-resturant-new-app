import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_buttons_and_slider_dots.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_page_view_data.dart';
import 'package:new_coffee/shared/widgets/skip_btn.dart';

class OnBoardingViewBody extends StatelessWidget {
  const OnBoardingViewBody({super.key});

  @override
  Widget build(BuildContext context) {
    // One exit for both paths: finishing the last slide and skipping emit the
    // same state, so the onboarding can never leave the customer on a screen
    // that already recorded it as done.
    return BlocListener<OnBoardingCubit, OnBoardingState>(
      listenWhen: (previous, current) => current is OnBoardingCompleted,
      listener: (context, state) =>
          Navigator.of(context).pushReplacementNamed(AuthPage.routeName),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: SpacingTokens.lg.w),
          child: Column(
            children: [
              SkipBtn(
                onTap: () => context.read<OnBoardingCubit>().complete(),
              ),
              SizedBox(height: 10.h),
              const Expanded(flex: 6, child: OnBoardingPageViewData()),
              const Expanded(child: OnBoardingButtonsAndSliderDotes()),
            ],
          ),
        ),
      ),
    );
  }
}
