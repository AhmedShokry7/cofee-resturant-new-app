import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

class OnBoardingNextBtn extends StatelessWidget {
  const OnBoardingNextBtn({super.key});

  @override
  Widget build(BuildContext context) {
    final myHight = MediaQuery.of(context).size.height;
    return GestureDetector(
      onTap: () {
        BlocProvider.of<OnBoardingCubit>(context).nextBtn(context);
      },
      child: Container(
        height: AppConstant.btnHeight(context) - 15,
        width: AppConstant.btnHeight(context) - 15,
        decoration: const BoxDecoration(
          color: AppColor.primaryColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          HugeIcons.strokeRoundedArrowRight01,
          size: myHight * .03,
          color: AppColor.whiteColor,
        ),
      ),
    );
  }
}
