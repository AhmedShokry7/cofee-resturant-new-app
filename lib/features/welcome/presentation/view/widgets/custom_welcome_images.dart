import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:new_coffee/core/constant/app_images.dart';

class CustomWelcomeImages extends StatelessWidget {
  const CustomWelcomeImages({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1000.0.r),
              image: const DecorationImage(
                image: AssetImage(AppImages.logo),
                fit: BoxFit.fill,
              ),
            ),
          ),
        ),
       
      ],
    );
  }
}
