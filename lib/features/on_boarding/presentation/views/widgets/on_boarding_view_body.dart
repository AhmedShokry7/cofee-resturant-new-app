import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_buttons_and_slider_dots.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_page_view_data.dart';
import 'package:new_coffee/shared/widgets/skip_btn.dart';

/// The slide, its art, and the row that steps through them.
///
/// Layout only. The skip control is the one thing it acts on, and it only asks
/// the cubit to end the onboarding.
class OnBoardingViewBody extends StatelessWidget {
  const OnBoardingViewBody({super.key});

  /// The slides take the tall part of the screen, the step row the short one.
  static const int _slidesFlex = 6;
  static const int _stepsFlex = 1;

  /// Room between the skip label and the first slide.
  static const double _skipGap = 10;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: SpacingTokens.lg.w),
        child: Column(
          children: [
            SkipBtn(
              onTap: () => context.read<OnBoardingCubit>().complete(),
            ),
            SizedBox(height: _skipGap.h),
            const Expanded(
              flex: _slidesFlex,
              child: OnBoardingPageViewData(),
            ),
            const Expanded(
              flex: _stepsFlex,
              child: OnBoardingButtonsAndSliderDots(),
            ),
          ],
        ),
      ),
    );
  }
}
