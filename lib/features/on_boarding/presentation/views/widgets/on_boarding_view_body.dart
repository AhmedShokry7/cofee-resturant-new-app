import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_buttons_and_slider_dots.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_page_view_data.dart';
import 'package:new_coffee/shared/widgets/skip_btn.dart';

class OnBoardingViewBody extends StatelessWidget {
  const OnBoardingViewBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: SpacingTokens.lg.w),
        child: Column(
          children: [
            SkipBtn(
              onTap: () async {
                await const SessionRepository().markOnboardingSkipped();
                if (!context.mounted) return;
                Navigator.of(context).pushReplacementNamed(AuthPage.routeName);
              },
            ),
            SizedBox(height: 10.h),
            const Expanded(flex: 6, child: OnBoardingPageViewData()),
            const Expanded(child: OnBoardingButtonsAndSliderDotes()),
          ],
        ),
      ),
    );
  }
}
