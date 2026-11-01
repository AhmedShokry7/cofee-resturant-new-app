import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/shared/utils/profile_image_picker.dart';
import 'package:new_coffee/features/profile/presentation/manager/profile/profile_cubit.dart';
import 'package:new_coffee/shared/widgets/sheet_handle.dart';
import 'package:new_coffee/core/theme/tokens.dart';

Future<void> showProfileImagePicker(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColor.whiteColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r32)),
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
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            SizedBox(height: AppSpacing.lg),
            Text(
              S.profilePicture,
              textAlign: TextAlign.center,
              style: AppFonts.semiBold18(context),
            ),
            SizedBox(height: AppSpacing.md),
            _SourceTile(
              icon: AppIcons.camera,
              label: S.takePhoto,
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            _SourceTile(
              icon: AppIcons.image,
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
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      leading: Container(
        height: AppSizes.px44,
        width: AppSizes.px44,
        decoration: BoxDecoration(
          color: AppColor.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        ),
        child: Icon(icon, size: AppSizes.px22, color: AppColor.primaryColor),
      ),
      title: Text(label, style: AppFonts.medium16(context)),
    );
  }
}
