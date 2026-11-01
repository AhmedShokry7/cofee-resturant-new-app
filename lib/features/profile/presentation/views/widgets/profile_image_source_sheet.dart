import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/layout_tokens.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/shared/utils/profile_image_picker.dart';
import 'package:new_coffee/features/profile/presentation/manager/profile/profile_cubit.dart';
import 'package:new_coffee/shared/widgets/sheet_handle.dart';

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
    // Uploads to Storage and records the path on the profile. The cubit keeps
    // the picked bytes on screen meanwhile, so the avatar never blanks.
    unawaited(context.read<ProfileCubit>().upload(bytes));
  } on PlatformException {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.imagePickerFailed)));
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
            const SheetHandle(),
            SizedBox(height: SpacingTokens.lg.h),
            Text(
              S.profilePicture,
              textAlign: TextAlign.center,
              style: AppFonts.semiBold18(context),
            ),
            SizedBox(height: SpacingTokens.md.h),
            _SourceTile(
              icon: HugeIcons.strokeRoundedCamera01,
              label: S.takePhoto,
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            _SourceTile(
              icon: HugeIcons.strokeRoundedImage01,
              label: S.chooseFromGallery,
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
          borderRadius: BorderRadius.circular(LayoutTokens.cardRadius.r),
        ),
        child: Icon(icon, size: 22.w, color: AppColor.primaryColor),
      ),
      title: Text(label, style: AppFonts.medium16(context)),
    );
  }
}
