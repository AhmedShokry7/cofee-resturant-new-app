import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/auth/presentation/views/phone_auth_page.dart';

/// The divided "or sign in with" block: Google and phone side by side. Used by
/// both the sign-in and the sign-up pages so they stay identical.
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
          children: [
            Expanded(
              child: _ChoiceTile(
                icon: AppIcons.google,
                label: S.continueWithGoogle,
                isLoading: isLoading,
                onTap: () => context.read<AuthCubit>().signInWithGoogle(),
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: _ChoiceTile(
                icon: AppIcons.smartphone,
                label: S.continueWithPhone,
                isLoading: isLoading,
                onTap: () =>
                    Navigator.of(context).pushNamed(PhoneAuthPage.routeName),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One of two equal sign-in choices: icon and label on one line, in the
/// neutral grey of the divider text, inside a border-coloured outline.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
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
        color: AppColor.cardSurface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r16),
          side: BorderSide(color: AppColor.borderColor),
        ),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.px6,
              vertical: AppSpacing.px10,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: AppSizes.px26, color: AppColor.greyColor),
                SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.regular14(context).copyWith(
                      color: AppColor.greyColor,
                      fontWeight: AppFontWeights.medium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
