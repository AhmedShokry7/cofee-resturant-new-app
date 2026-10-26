import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';

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
        borderRadius: BorderRadius.circular(AppRadius.phoneBody),
        border: Border.all(color: AppColor.borderColor, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColor.black20,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.phoneScreen),
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
                    borderRadius: BorderRadius.circular(AppRadius.lg),
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
