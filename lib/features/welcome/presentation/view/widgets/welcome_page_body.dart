
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/on_boarding_page.dart';
import 'package:new_coffee/features/welcome/presentation/view/widgets/custom_welcome_images.dart';
import 'package:new_coffee/features/welcome/presentation/view/widgets/welcome_page_text_body.dart';
import 'package:new_coffee/features/welcome/presentation/view/widgets/welcome_page_text_title.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';


class WelcomePageBody extends StatelessWidget {
  const WelcomePageBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(SpacingTokens.md),
        child: Column(
          children: [
            const Expanded(flex: 9, child: CustomWelcomeImages()),
            const WelcomeViewTextTitle(),

            SizedBox(height: 8.h),
            const WelcomeViewTextBody(),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: CustomBtn(
                text:"Let's Get Started",
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    OnBoardingView.routeName,
                  );
                  const SessionRepository().markOnboardingSeen();
                },
              ),
            ),
           
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

