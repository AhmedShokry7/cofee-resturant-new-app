import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/profile/presentation/manager/profile/profile_cubit.dart';

/// The customer's photo, with the same fallback everywhere it appears.
///
/// Two sources, in priority order:
///
///   1. [ProfileState.imageBytes] — the photo itself, held in memory. It is the
///      bytes the customer just picked, or the bytes read back from Storage.
///      Drawing it needs no network at all.
///   2. The plain user glyph, for a customer who has saved no photo.
///
/// The image is drawn through [ResizeImage] so a 600px photo is decoded at the
/// size it is actually shown at instead of at its full resolution.
///
/// During an upload the current image stays visible under a scrim. Replacing it
/// with a spinner would blank the avatar on every retry.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.state, required this.radius});

  final ProfileState state;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bytes = state.imageBytes;

    final Widget avatar = bytes != null
        ? CircleAvatar(
            radius: radius,
            backgroundColor: AppColor.lightGreyColor,
            backgroundImage: ResizeImage(
              MemoryImage(bytes),
              width: _pixelSize(context),
            ),
          )
        : CircleAvatar(
            radius: radius,
            backgroundColor: AppColor.lightGreyColor,
            child: Icon(
              HugeIcons.strokeRoundedUser,
              size: radius,
              color: AppColor.greyColor,
            ),
          );

    if (!state.isUploading) return avatar;

    return Stack(
      children: [
        avatar,
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.35),
            child: Center(
              child: SizedBox(
                width: radius * 0.6,
                height: radius * 0.6,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColor.primaryColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The avatar's size in physical pixels, so the photo is decoded for the
  /// screen it is drawn on and not for the 600px the picker produced.
  int _pixelSize(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final pixels = radius * 2 * ratio;
    return pixels.isFinite && pixels > 0 ? pixels.round() : 1;
  }
}
