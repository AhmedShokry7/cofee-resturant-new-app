import 'package:flutter/material.dart';

import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';

class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child, this.width = 320});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 2.1;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColor.blackColor,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppColor.borderColor, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppDimensions.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 80,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColor.blackColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
