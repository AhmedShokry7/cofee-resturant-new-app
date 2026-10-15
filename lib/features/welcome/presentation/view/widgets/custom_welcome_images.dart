import 'package:flutter/material.dart';
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
              image: const DecorationImage(
                image: AssetImage(AppImages.welcomeImage),
                fit: BoxFit.fill,
              ),
            ),
          ),
        ),
       
      ],
    );
  }
}
