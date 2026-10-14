import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/coupon/presentation/views/coupon_page.dart';
import 'package:new_coffee/features/loyalty/presentation/views/loyalty_page.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';
import 'package:new_coffee/features/payment/presentation/views/saved_cards_page.dart';
import 'package:new_coffee/features/profile/presentation/manager/profile/profile_cubit.dart';
import 'package:new_coffee/features/profile/presentation/views/edit_profile_page.dart';
import 'package:new_coffee/features/profile/presentation/views/widgets/profile_image_source_sheet.dart';
import 'package:new_coffee/features/profile/presentation/views/help_page.dart';
import 'package:new_coffee/features/profile/presentation/views/privacy_policy_page.dart';
import 'package:new_coffee/features/profile/presentation/views/widgets/profile_menu_tile.dart';
import 'package:new_coffee/features/settings/presentation/views/widgets/logout_bottom_sheet.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await SharedPref.setValue(
      key: AppConstant.routesKey,
      value: AppConstant.authRoute,
    );
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AuthPage.routeName,
      (route) => false,
    );
  }

  Future<void> _pickImage(BuildContext context) =>
      showProfileImagePicker(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  SpacingTokens.lg.w,
                  SpacingTokens.md.h,
                  SpacingTokens.lg.w,
                  SpacingTokens.lg.w,
                ),
              child: Column(
                children: [
                  BlocBuilder<ProfileCubit, ProfileState>(
                    builder: (context, state) {
                      final bytes = state.imageBytes;
                      return GestureDetector(
                        onTap: () => _pickImage(context),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 52.w,
                              backgroundColor: AppColor.lightGreyColor,
                              backgroundImage: bytes != null
                                  ? MemoryImage(bytes)
                                  : null,
                              child: bytes == null
                                  ? Icon(
                                      HugeIcons.strokeRoundedUser,
                                      size: 52.w,
                                      color: AppColor.greyColor,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => _pickImage(context),
                                child: Container(
                                  height: 36.w,
                                  width: 36.w,
                                  decoration: BoxDecoration(
                                    color: AppColor.primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColor.whiteColor,
                                      width: 3,
                                    ),
                                  ),
                                  child: Icon(
                                    HugeIcons.strokeRoundedCamera01,
                                    size: 18.w,
                                    color: AppColor.whiteColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  SizedBox(height: SpacingTokens.md.h),
                  Text("Ahmed Shokry", style: AppFonts.semiBold24(context)),
                ],
              ),
            ),
            SizedBox(height: SpacingTokens.md.h),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedUserCircle,
              label: "Your Profile",
              onTap: () => Navigator.of(
                context,
              ).pushNamed(EditProfilePage.routeName),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedCreditCard,
              label: "Payment Method",
              onTap: () => Navigator.of(
                context,
              ).pushNamed(SavedCardsPage.routeName),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedPackage,
              label: "My Orders",
              onTap: () =>
                  Navigator.of(context).pushNamed(OrdersPage.routeName),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedCoupon01,
              label: "Coupon",
              onTap: () =>
                  Navigator.of(context).pushNamed(CouponPage.routeName),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedStar,
              label: "Loyalty Points",
              onTap: () =>
                  Navigator.of(context).pushNamed(LoyaltyPage.routeName),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedNotification01,
              label: "Notifications",
              onTap: () =>
                  Navigator.of(context).pushNamed(NotificationsPage.routeName),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedHelpCircle,
              label: "Help",
              onTap: () => Navigator.of(context).pushNamed(HelpPage.routeName),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedShieldKey,
              label: "Privacy Policy",
              onTap: () =>
                  Navigator.of(context).pushNamed(PrivacyPolicyPage.routeName),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedLogout01,
              label: "Log Out",
              onTap: () =>
                  showLogoutSheet(context, onConfirm: () => _logout(context)),
            ),
          ],
        ),
      ),
    );
  }
}
