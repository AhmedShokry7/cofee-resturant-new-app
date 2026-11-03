import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/addresses/presentation/views/addresses_page.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/current_user/current_user_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/coupon/presentation/views/coupon_page.dart';
import 'package:new_coffee/features/loyalty/presentation/views/loyalty_page.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_details_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_plans_page.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';
import 'package:new_coffee/features/payment/presentation/views/saved_cards_page.dart';
import 'package:new_coffee/features/profile/data/model/profile_photo_exception.dart';
import 'package:new_coffee/features/profile/presentation/manager/profile/profile_cubit.dart';
import 'package:new_coffee/features/profile/presentation/views/edit_profile_page.dart';
import 'package:new_coffee/features/profile/presentation/views/widgets/profile_avatar.dart';
import 'package:new_coffee/features/profile/presentation/views/widgets/profile_image_source_sheet.dart';
import 'package:new_coffee/features/content/presentation/views/help_page.dart';
import 'package:new_coffee/features/content/presentation/views/privacy_policy_page.dart';
import 'package:new_coffee/features/profile/presentation/views/widgets/profile_menu_tile.dart';
import 'package:new_coffee/features/profile/presentation/views/widgets/logout_bottom_sheet.dart';
import 'package:new_coffee/shared/widgets/selection_radio.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The account tab.
///
/// The customer's own name is read through [CurrentUserCubit] instead of a
/// future started inside this widget, so the tab that shows it and the tab that
/// edits it work on one read.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              CurrentUserCubit(repository: context.read<AuthRepository>())
                ..load(),
        ),
        // Signing out is an auth decision with a session marker behind it, so
        // it goes through AuthCubit instead of a second sign-out written here
        // against the repository.
        BlocProvider(
          create: (context) => AuthCubit(context.read<AuthRepository>()),
        ),
      ],
      // Not const: a canonicalised instance would be handed to the same
      // element on every rebuild, so the screen would keep the labels of the
      // language it first started in after the customer switches.
      child: _SettingsView(),
    );
  }
}

class _SettingsView extends StatefulWidget {
  const _SettingsView();

  @override
  State<_SettingsView> createState() => _SettingsViewState();
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
    return Semantics(
      radio: true,
      checked: selected,
      child: Material(
        color: AppColor.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                SelectionRadio(selected: selected),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(label, style: AppFonts.regular16(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsViewState extends State<_SettingsView> {
  /// Asks the auth cubit to sign the customer out.
  ///
  /// The cubit owns the whole decision — the in-flight guard, the provider call,
  /// and clearing the stored route — and only after the sign-out succeeded. This
  /// screen reacts to the answer it emits.
  void _logout(BuildContext context) => context.read<AuthCubit>().signOut();

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
        child: BlocListener<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthSignedOut) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AuthPage.routeName, (route) => false);
            } else if (state is AuthFailure) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
          child: BlocListener<ProfileCubit, ProfileState>(
            listenWhen: (previous, current) =>
                current.error != null && current.error != previous.error,
            listener: (context, state) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_photoErrorMessage(state.error!))),
              );
            },
            child: ListView(
              children: [
                Padding(
                  padding: AppLayout.pageBody,
                  child: Column(
                    children: [
                      BlocBuilder<ProfileCubit, ProfileState>(
                        builder: (context, state) {
                          return Semantics(
                            button: true,
                            child: Material(
                              color: AppColor.transparent,
                              child: InkWell(
                                onTap: () => _pickImage(context),
                                // The splash follows the avatar's circle. The
                                // badge at its edge stays outside the clip: it
                                // is part of this one control, not a second
                                // tap target for the same action.
                                customBorder: const CircleBorder(),
                                child: Stack(
                                  children: [
                                    ProfileAvatar(
                                      state: state,
                                      radius: AppSizes.px52,
                                    ),
                                    Positioned(
                                      bottom: AppSizes.px2,
                                      right: AppSizes.px2,
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
                                        child: Icon(
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
                      ),
                      SizedBox(height: AppSpacing.md),
                      BlocBuilder<CurrentUserCubit, CurrentUserState>(
                        builder: (context, state) {
                          final name = state.name;
                          if (name.isEmpty) return const SizedBox.shrink();
                          return Text(
                            name,
                            style: AppFonts.semiBold24(context),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                ProfileMenuTile(
                  icon: AppIcons.profile,
                  label: S.yourProfile,
                  onTap: () async {
                    final cubit = context.read<CurrentUserCubit>();
                    await Navigator.of(context)
                        .pushNamed(EditProfilePage.routeName);
                    // The edit page writes the name through the same session, so
                    // the tab re-reads it instead of guessing what was typed.
                    cubit.load();
                  },
                ),
                ProfileMenuTile(
                  icon: AppIcons.location,
                  label: S.myAddresses,
                  onTap: () =>
                      Navigator.of(context).pushNamed(AddressesPage.routeName),
                ),
                ProfileMenuTile(
                  icon: AppIcons.creditCard,
                  label: S.paymentMethod,
                  onTap: () =>
                      Navigator.of(context).pushNamed(SavedCardsPage.routeName),
                ),
                ProfileMenuTile(
                  icon: AppIcons.package,
                  label: S.myOrders,
                  onTap: () =>
                      Navigator.of(context).pushNamed(OrdersPage.routeName),
                ),
                ProfileMenuTile(
                  icon: AppIcons.package,
                  label: S.subscriptionPlans,
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamed(SubscriptionPlansPage.routeName),
                ),
                ProfileMenuTile(
                  icon: AppIcons.creditCard,
                  label: S.mySubscription,
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamed(SubscriptionDetailsPage.routeName),
                ),
                ProfileMenuTile(
                  icon: AppIcons.coupon,
                  label: S.coupon,
                  onTap: () =>
                      Navigator.of(context).pushNamed(CouponPage.routeName),
                ),
                ProfileMenuTile(
                  icon: AppIcons.star,
                  label: S.loyaltyPoints,
                  onTap: () =>
                      Navigator.of(context).pushNamed(LoyaltyPage.routeName),
                ),
                ProfileMenuTile(
                  icon: AppIcons.notification,
                  label: S.notifications,
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamed(NotificationsPage.routeName),
                ),
                ProfileMenuTile(
                  icon: AppIcons.language,
                  label: S.language,
                  subtitle: S.languageValue(AppLocale.instance.isArabic),
                  onTap: () => _showLanguageDialog(context),
                ),
                ProfileMenuTile(
                  icon: AppIcons.help,
                  label: S.help,
                  onTap: () =>
                      Navigator.of(context).pushNamed(HelpPage.routeName),
                ),
                ProfileMenuTile(
                  icon: AppIcons.shield,
                  label: S.privacyPolicy,
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamed(PrivacyPolicyPage.routeName),
                ),
                ProfileMenuTile(
                  icon: AppIcons.logout,
                  label: S.logOut,
                  onTap: () => showLogoutSheet(
                    context,
                    onConfirm: () => _logout(context),
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

/// Turns a [ProfilePhotoFailure] token into a sentence a customer can act on.
///
/// Every failure is reported. A photo that did not save is never presented as
/// one that did.
String _photoErrorMessage(String failure) {
  if (failure == ProfilePhotoFailure.unsupportedFormat.name) {
    return S.photoFormatUnsupported;
  }
  if (failure == ProfilePhotoFailure.notSignedIn.name) {
    // The photo belongs to an account, so there is nothing to attach it to
    // without one. This is not a failed save.
    return S.photoSignInRequired;
  }
  if (failure == ProfilePhotoFailure.profileUpdateFailed.name ||
      failure == ProfilePhotoFailure.profileRowMissing.name) {
    return S.photoSaveFailed;
  }
  if (failure == ProfilePhotoFailure.photoLoadFailed.name) {
    return S.photoLoadFailed;
  }
  return S.photoUploadFailed;
}
