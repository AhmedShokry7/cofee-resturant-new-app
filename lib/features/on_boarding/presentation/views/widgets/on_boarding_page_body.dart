import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_buttons_and_slider_dots.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_page_view_data.dart';
import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/shared/widgets/skip_btn.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OnBoardingPageBody extends StatelessWidget {
  const OnBoardingPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppConstant.horizontalPadding(context) ,
        ),
        child: Column(
          children: [
            SizedBox(height: 12.h),

            SkipBtn(
              onTap: () async {
                await const SessionRepository().markOnboardingSkipped();
                if (!context.mounted) return;
                Navigator.of(context).pushReplacementNamed(
                  AuthPage.routeName,
                );
              },
            ),
            SizedBox(height: 24.h),
            const Expanded(flex: 4, child: OnBoardingPageViewData()),
            const Expanded(child: OnBoardingButtonsAndSliderDotes()),
          ],
        ),
      ),
    );
  }
}
