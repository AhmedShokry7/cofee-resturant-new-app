import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/profile/presentation/manager/profile/profile_cubit.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

/// The customer's photo, with the same fallback everywhere it appears.
///
/// Three sources, in priority order:
///
///   1. [ProfileState.localBytes] — the image just picked, so the avatar updates
///      the instant the sheet closes.
///   2. [ProfileState.signedUrl] — the persisted photo, rendered through
///      [DbImage] like every other database image in the app so caching,
///      shimmer and failure behaviour match the rest of the catalogue.
///   3. The plain user glyph, for a customer who has saved no photo.
///
/// During an upload the current image stays visible under a scrim. Replacing it
/// with a spinner would blank the avatar on every retry.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.state, required this.radius});

  final ProfileState state;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bytes = state.localBytes;
    final url = state.signedUrl?.trim();
    final size = radius * 2;

    final Widget avatar = bytes != null
        ? CircleAvatar(
            radius: radius,
            backgroundColor: AppColor.lightGreyColor,
            backgroundImage: MemoryImage(bytes),
          )
        : CircleAvatar(
            radius: radius,
            backgroundColor: AppColor.lightGreyColor,
            child: (url != null && url.isNotEmpty)
                ? DbImage(
                    image: url,
                    width: size,
                    height: size,
                    iconSize: radius * 0.8,
                    borderRadius: BorderRadius.all(Radius.circular(radius)),
                  )
                : Icon(
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
}