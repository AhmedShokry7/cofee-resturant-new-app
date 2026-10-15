import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/on_boarding_page.dart';
import 'package:new_coffee/features/welcome/presentation/view/widgets/custom_welcome_images.dart';
import 'package:new_coffee/features/welcome/presentation/view/widgets/welcome_page_text_body.dart';
import 'package:new_coffee/features/welcome/presentation/view/widgets/welcome_page_text_title.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

class WelcomePageBody extends StatelessWidget {
  const WelcomePageBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // صورة تغطي الشاشة بالكامل
          const Positioned.fill(
            child: CustomWelcomeImages(),
          ),

          // تدرج لوني لتحسين وضوح النص
          // Positioned.fill(
          //   child: DecoratedBox(
          //     decoration: BoxDecoration(
          //       gradient: LinearGradient(
          //         begin: Alignment.topCenter,
          //         end: Alignment.bottomCenter,
          //         colors: [
          //           Colors.black.withValues(alpha: 0.05),
          //           Colors.transparent,
          //           Colors.black.withValues(alpha: 0.45),
          //           Colors.black.withValues(alpha: 0.80),
          //         ],
          //         stops: const [0.0, 0.35, 0.65, 1.0],
          //       ),
          //     ),
          //   ),
          // ),

          // المحتوى فوق الصورة
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24.w,
                vertical: 20.h,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const WelcomeViewTextTitle(),

                  SizedBox(height: 12.h),

                  const WelcomeViewTextBody(),

                  SizedBox(height: 12.h),

                  CustomBtn(
                    text: "Let's Get Started",
                    onPressed: () {
                      const SessionRepository().markOnboardingSeen();
                      Navigator.pushReplacementNamed(
                        context,
                        OnBoardingView.routeName,
                      );
                    },
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}