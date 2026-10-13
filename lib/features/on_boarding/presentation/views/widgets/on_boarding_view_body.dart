import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_buttons_and_slider_dots.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_page_view_data.dart';
import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/shared/widgets/skip_btn.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OnBoardingViewBody extends StatelessWidget {
  const OnBoardingViewBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppConstant.horizontalPadding(context),
        ),
        child: Column(
          children: [
            SizedBox(height: 12.h),

            SkipBtn(
              onTap: () async {
                await SharedPref.setValue(
                  key: AppConstant.routesKey,
                  value: "3",
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
