import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/addresses/presentation/views/addresses_page.dart';
import 'package:new_coffee/features/assistant/presentation/views/assistant_memory_page.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/current_user/current_user_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/content/presentation/views/help_page.dart';
import 'package:new_coffee/features/content/presentation/views/privacy_policy_page.dart';
import 'package:new_coffee/features/coupon/presentation/views/coupon_page.dart';
import 'package:new_coffee/features/loyalty/presentation/views/loyalty_page.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';
import 'package:new_coffee/features/payment/presentation/views/saved_cards_page.dart';
import 'package:new_coffee/features/profile/presentation/manager/profile/profile_cubit.dart';
import 'package:new_coffee/features/profile/presentation/views/edit_profile_page.dart';
import 'package:new_coffee/features/profile/presentation/views/widgets/logout_bottom_sheet.dart';
import 'package:new_coffee/features/profile/presentation/views/widgets/profile_menu_tile.dart';
import 'package:new_coffee/features/profile/presentation/views/widgets/settings_header.dart';
import 'package:new_coffee/features/profile/presentation/views/widgets/settings_language_dialog.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_details_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_plans_page.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// What the Settings tab is made of: the customer's photo and name, the
/// destinations of the account, the language, and the way out.
///
/// This widget only wires. Each tile hands its tap to the cubit that owns the
/// decision or pushes the route the app already registers; nothing here reads
/// or writes the backend itself.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

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
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(state.errorCopy!)));
            },
            child: _SettingsEntries(),
          ),
        ),
      ),
    );
  }
}

/// The header and the list of destinations.
class _SettingsEntries extends StatelessWidget {
  const _SettingsEntries();

  /// Opens the account-details form and re-reads the name when it closes.
  ///
  /// The edit page writes the name through the same session, so the tab asks
  /// for it again instead of guessing what the customer typed. The cubit is
  /// taken before the push: once another route is on top, this element is
  /// deactivated and looking it up through its context throws.
  Future<void> _openProfile(BuildContext context) async {
    final cubit = context.read<CurrentUserCubit>();
    await Navigator.of(context).pushNamed(EditProfilePage.routeName);
    cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    // A memory belongs to an account. A device that is not signed in has no
    // island to review, so the door to it is not shown rather than shown empty.
    final signedIn = context.watch<CurrentUserCubit>().state.user != null;
    return ListView(
      children: [
        SettingsHeader(),
        SizedBox(height: AppSpacing.md),
        ProfileMenuTile(
          icon: AppIcons.profile,
          label: S.yourProfile,
          onTap: () => _openProfile(context),
        ),
        ProfileMenuTile(
          icon: AppIcons.location,
          label: S.myAddresses,
          onTap: () => Navigator.of(context).pushNamed(AddressesPage.routeName),
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
          onTap: () => Navigator.of(context).pushNamed(OrdersPage.routeName),
        ),
        // One glyph per destination: a plan and a past order are not the same
        // thing, and a card and a subscription are not either.
        ProfileMenuTile(
          icon: AppIcons.coffee,
          label: S.subscriptionPlans,
          onTap: () =>
              Navigator.of(context).pushNamed(SubscriptionPlansPage.routeName),
        ),
        ProfileMenuTile(
          icon: AppIcons.calendar,
          label: S.mySubscription,
          onTap: () =>
              Navigator.of(context)
                  .pushNamed(SubscriptionDetailsPage.routeName),
        ),
        ProfileMenuTile(
          icon: AppIcons.coupon,
          label: S.coupon,
          onTap: () => Navigator.of(context).pushNamed(CouponPage.routeName),
        ),
        ProfileMenuTile(
          icon: AppIcons.star,
          label: S.loyaltyPoints,
          onTap: () => Navigator.of(context).pushNamed(LoyaltyPage.routeName),
        ),
        ProfileMenuTile(
          icon: AppIcons.notification,
          label: S.notifications,
          onTap: () =>
              Navigator.of(context).pushNamed(NotificationsPage.routeName),
        ),
        ProfileMenuTile(
          icon: AppIcons.language,
          label: S.language,
          subtitle: S.languageValue(AppLocale.instance.isArabic),
          // A dialog, not a page: no chevron promising a screen behind it.
          opensPage: false,
          onTap: () => showSettingsLanguageDialog(context),
        ),
        ProfileMenuTile(
          icon: AppIcons.help,
          label: S.help,
          onTap: () => Navigator.of(context).pushNamed(HelpPage.routeName),
        ),
        ProfileMenuTile(
          icon: AppIcons.shield,
          label: S.privacyPolicy,
          onTap: () =>
              Navigator.of(context).pushNamed(PrivacyPolicyPage.routeName),
        ),
        if (signedIn)
          ProfileMenuTile(
            icon: AppIcons.memory,
            label: S.assistantMemoryTitle,
            onTap: () =>
                Navigator.of(context).pushNamed(AssistantMemoryPage.routeName),
          ),
        ProfileMenuTile(
          icon: AppIcons.logout,
          label: S.logOut,
          opensPage: false,
          onTap: () => showLogoutSheet(
            context,
            onConfirm: () => context.read<AuthCubit>().signOut(),
          ),
        ),
      ],
    );
  }
}
