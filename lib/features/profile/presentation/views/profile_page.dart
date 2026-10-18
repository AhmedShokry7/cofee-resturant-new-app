import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/features/addresses/presentation/views/addresses_page.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/data/models/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
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
import 'package:new_coffee/features/profile/presentation/views/widgets/logout_bottom_sheet.dart';
import 'package:new_coffee/shared/widgets/selection_radio.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: SpacingTokens.sm.h),
        child: Row(
          children: [
            SelectionRadio(selected: selected),
            SizedBox(width: SpacingTokens.md.w),
            Expanded(
              child: Text(label, style: AppFonts.regular16(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsPageState extends State<SettingsPage> {
  late final Future<AuthUser?> _userFuture = _loadUser();

  /// Guards a second sign-out while the first is still in flight, so a double
  /// tap cannot run two sign-outs or navigate twice.
  bool _loggingOut = false;

  Future<AuthUser?> _loadUser() async {
    try {
      return await context.read<AuthRepository>().currentUser();
    } catch (_) {
      return null;
    }
  }

  /// Signs the customer out for real, then returns to the auth screen.
  ///
  /// [AuthRepository] is a global provider (`AppProviders`), so it is available
  /// here; `AuthCubit` is not — it is only provided inside `AuthPage`, which is
  /// the screen being navigated to. Going through the repository therefore adds
  /// no second authentication implementation.
  ///
  /// The stored route key is only cleared after the client sign-out actually
  /// succeeded. If it throws, the customer stays where they are with an
  /// explanation rather than a screen that claims they are signed out while the
  /// session is still live.
  Future<void> _logout(BuildContext context) async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await context.read<AuthRepository>().signOut();
      await const SessionRepository().clear();
      if (!context.mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AuthPage.routeName, (route) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.logoutFailed)),
      );
    }
  }

  Future<void> _pickImage(BuildContext context) =>
      showProfileImagePicker(context);

  /// Lets the customer pick the UI language. The choice is written through
  /// [AppLocale.setLanguage], which persists it and notifies the whole app, so
  /// every screen — including this one — re-renders in the new language and the
  /// choice survives the next start.
  Future<void> _showLanguageDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageOption(
              label: S.arabicLanguage,
              selected: AppLocale.instance.language == AppLanguage.arabic,
              onTap: () {
                AppLocale.instance.setLanguage(AppLanguage.arabic);
                Navigator.of(dialogContext).pop();
              },
            ),
            _LanguageOption(
              label: S.englishLanguage,
              selected: AppLocale.instance.language == AppLanguage.english,
              onTap: () {
                AppLocale.instance.setLanguage(AppLanguage.english);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

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
                  FutureBuilder<AuthUser?>(
                    future: _userFuture,
                    builder: (context, snapshot) {
                      final name = snapshot.data?.name?.trim() ?? '';
                      if (name.isEmpty) return const SizedBox.shrink();
                      return Text(name, style: AppFonts.semiBold24(context));
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: SpacingTokens.md.h),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedUserCircle,
              label: S.yourProfile,
              onTap: () =>
                  Navigator.of(context).pushNamed(EditProfilePage.routeName),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedCreditCard,
              label: S.paymentMethod,
              onTap: () =>
                  Navigator.of(context).pushNamed(SavedCardsPage.routeName),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedPackage,
              label: S.myOrders,
              onTap: () =>
                  Navigator.of(context).pushNamed(OrdersPage.routeName),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedCoupon01,
              label: S.coupon,
              onTap: () =>
                  Navigator.of(context).pushNamed(CouponPage.routeName),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedStar,
              label: S.loyaltyPoints,
              onTap: () =>
                  Navigator.of(context).pushNamed(LoyaltyPage.routeName),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedNotification01,
              label: S.notifications,
              onTap: () =>
                  Navigator.of(context).pushNamed(NotificationsPage.routeName),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedLanguageCircle,
              label: S.language,
              subtitle: S.languageValue(AppLocale.instance.isArabic),
              onTap: () => _showLanguageDialog(context),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedHelpCircle,
              label: S.help,
              onTap: () => Navigator.of(context).pushNamed(HelpPage.routeName),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedShieldKey,
              label: S.privacyPolicy,
              onTap: () =>
                  Navigator.of(context).pushNamed(PrivacyPolicyPage.routeName),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedLocation01,
              label: S.myAddresses,
              onTap: () =>
                  Navigator.of(context).pushNamed(AddressesPage.routeName),
            ),
            ProfileMenuTile(
              icon: HugeIcons.strokeRoundedLogout01,
              label: S.logOut,
              onTap: () =>
                  showLogoutSheet(context, onConfirm: () => _logout(context)),
            ),
          ],
        ),
      ),
    );
  }
}
