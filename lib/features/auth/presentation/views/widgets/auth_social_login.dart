import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class AuthSocialLogin extends StatelessWidget {
  const AuthSocialLogin({super.key, this.label, this.isLoading = false});

  final String? label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                label ?? S.orSignInWith,
                style: AppFonts.regular14(context)
                    .copyWith(color: AppColor.greyColor),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialButton(
              icon: AppIcons.google,
              label: S.continueWithGoogle,
              isLoading: isLoading,
              onTap: () => context.read<AuthCubit>().signInWithGoogle(),
            ),
            SizedBox(width: AppSpacing.lg),
            _SocialButton(
              icon: AppIcons.facebook,
              label: S.continueWithFacebook,
              isLoading: isLoading,
              onTap: () => context.read<AuthCubit>().signInWithFacebook(),
            ),
            SizedBox(width: AppSpacing.lg),
            _SocialButton(
              icon: AppIcons.apple,
              label: S.continueWithApple,
              isLoading: isLoading,
              onTap: () => context.read<AuthCubit>().signInWithApple(),
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;

  /// What the button does, said out loud.
  ///
  /// A circle with a logo inside announces itself to a screen reader as an
  /// image with no name; the provider is only guessable from the picture.
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      enabled: !isLoading,
      child: Material(
        color: AppColor.whiteColor,
        clipBehavior: Clip.antiAlias,
        shape: const CircleBorder(
          side: BorderSide(color: AppColor.borderColor),
        ),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          child: SizedBox(
            height: AppSizes.px56,
            width: AppSizes.px56,
            child: Icon(icon, size: AppSizes.px26, color: AppColor.blackColor),
          ),
        ),
      ),
    );
  }
}
