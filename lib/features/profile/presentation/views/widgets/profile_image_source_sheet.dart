import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/profile/data/profile_image_picker.dart';
import 'package:new_coffee/features/profile/presentation/manager/profile/profile_cubit.dart';

Future<void> showProfileImagePicker(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColor.whiteColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
    ),
    builder: (context) => const _ImageSourceSheet(),
  );
  if (source == null || !context.mounted) return;

  try {
    final bytes = await pickProfileImage(source: source);
    if (bytes == null || !context.mounted) return;
    context.read<ProfileCubit>().setImage(bytes);
  } on PlatformException {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Couldn't open the image picker")),
    );
  }
}

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(SpacingTokens.lg.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                height: 4.h,
                width: 100.w,
                decoration: BoxDecoration(
                  color: AppColor.borderColor,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            SizedBox(height: SpacingTokens.lg.h),
            Text(
              "Profile Picture",
              textAlign: TextAlign.center,
              style: AppFonts.semiBold18(context),
            ),
            SizedBox(height: SpacingTokens.md.h),
            _SourceTile(
              icon: HugeIcons.strokeRoundedCamera01,
              label: "Take a photo",
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            _SourceTile(
              icon: HugeIcons.strokeRoundedImage01,
              label: "Choose from gallery",
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: SpacingTokens.sm.w),
      leading: Container(
        height: 44.w,
        width: 44.w,
        decoration: BoxDecoration(
          color: AppColor.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, size: 22.w, color: AppColor.primaryColor),
      ),
      title: Text(label, style: AppFonts.medium16(context)),
    );
  }
}
