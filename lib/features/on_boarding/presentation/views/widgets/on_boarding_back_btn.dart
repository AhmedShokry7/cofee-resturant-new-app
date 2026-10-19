import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';

class OnBoardingBackBtn extends StatelessWidget {
  const OnBoardingBackBtn({super.key});

  @override
  Widget build(BuildContext context) {
    final myHight = MediaQuery.of(context).size.height;
    return GestureDetector(
      onTap: () {
        BlocProvider.of<OnBoardingCubit>(context).backBtn();
      },
      child: Container(
        height: AppConstant.btnHeight(context) - 10,
        width: AppConstant.btnHeight(context) - 10,
        decoration: BoxDecoration(
          border: Border.all(color: AppColor.primaryColor, width: 2),
          shape: BoxShape.circle,
        ),
        child: Icon(
                 HugeIcons.strokeRoundedArrowLeft01,
          size: myHight * .03,
          color: AppColor.primaryColor,
        ),
      ),
    );
  }
}
