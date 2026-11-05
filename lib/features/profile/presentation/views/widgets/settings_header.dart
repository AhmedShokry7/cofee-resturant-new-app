import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/manager/current_user/current_user_cubit.dart';
import 'package:new_coffee/features/profile/presentation/manager/profile/profile_cubit.dart';
import 'package:new_coffee/features/profile/presentation/views/widgets/profile_avatar.dart';
import 'package:new_coffee/features/profile/presentation/views/widgets/profile_image_source_sheet.dart';
import 'package:new_coffee/shared/widgets/app_icon.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The top of the Settings tab: the customer's own photo, which they can
/// replace, and the name the account carries.
class SettingsHeader extends StatelessWidget {
  const SettingsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppLayout.pageBody,
      child: Column(
        children: [
          _ProfilePhotoButton(),
          SizedBox(height: AppSpacing.md),
          BlocBuilder<CurrentUserCubit, CurrentUserState>(
            builder: (context, state) {
              final name = state.name;
              if (name.isEmpty) return const SizedBox.shrink();
              return Text(name, style: AppFonts.semiBold24(context));
            },
          ),
        ],
      ),
    );
  }
}

/// The avatar as one control: the whole circle, badge included, asks for a new
/// picture.
class _ProfilePhotoButton extends StatelessWidget {
  const _ProfilePhotoButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        return Semantics(
          button: true,
          label: S.profilePicture,
          child: Material(
            color: AppColor.transparent,
            child: InkWell(
              onTap: () => showProfileImagePicker(context),
              // The splash follows the avatar's circle. The badge at its edge
              // stays outside the clip: it is part of this one control, not a
              // second tap target for the same action.
              customBorder: const CircleBorder(),
              child: Stack(
                children: [
                  ProfileAvatar(state: state, radius: AppSizes.px52),
                  // Reading direction, not the right edge: in Arabic the badge
                  // sits where the eye leaves the circle.
                  PositionedDirectional(
                    bottom: AppSizes.px2,
                    end: AppSizes.px2,
                    child: Container(
                      height: AppSizes.px36,
                      width: AppSizes.px36,
                      decoration: BoxDecoration(
                        color: AppColor.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColor.whiteColor,
                          width: AppSizes.px3,
                        ),
                      ),
                      child: AppIcon(
                        AppIcons.camera,
                        size: AppSizes.px18,
                        color: AppColor.whiteColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
