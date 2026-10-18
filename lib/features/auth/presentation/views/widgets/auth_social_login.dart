import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';

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
              padding: EdgeInsets.symmetric(horizontal: SpacingTokens.sm.w),
              child: Text(
                label ?? S.orSignInWith,
                style: AppFonts.regular14(context)
                    .copyWith(color: AppColor.greyColor),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        SizedBox(height: SpacingTokens.lg.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialButton(
              icon: HugeIcons.strokeRoundedGoogle,
              isLoading: isLoading,
              onTap: () => context.read<AuthCubit>().signInWithGoogle(),
            ),
            SizedBox(width: SpacingTokens.lg.w),
            _SocialButton(
              icon: HugeIcons.strokeRoundedFacebook01,
              isLoading: isLoading,
              onTap: () => context.read<AuthCubit>().signInWithFacebook(),
            ),
            SizedBox(width: SpacingTokens.lg.w),
            _SocialButton(
              icon: HugeIcons.strokeRoundedApple,
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
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final size = 56.w;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColor.borderColor),
        ),
        child: Icon(icon, size: 26.w, color: AppColor.blackColor),
      ),
    );
  }
}