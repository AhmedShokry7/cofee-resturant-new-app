import 'package:flutter/material.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/features/addresses/presentation/views/address_form_page.dart';
import 'package:new_coffee/features/addresses/presentation/views/addresses_page.dart';
import 'package:new_coffee/features/assistant/presentation/views/assistant_memory_page.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/email_auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/forget_password_page.dart';
import 'package:new_coffee/features/auth/presentation/views/phone_auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/reset_password_page.dart';
import 'package:new_coffee/features/auth/presentation/views/sign_up_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/add_address_page.dart';
import 'package:new_coffee/features/payment/presentation/views/add_card_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/checkout_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/e_receipt_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_method_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_success_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/shipping_addresses_page.dart';
import 'package:new_coffee/features/coupon/presentation/views/coupon_page.dart';
import 'package:new_coffee/features/loyalty/presentation/views/loyalty_page.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';
import 'package:new_coffee/features/notifications/presentation/views/notification_settings_page.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/on_boarding_view.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';
import 'package:new_coffee/features/payment/presentation/views/saved_cards_page.dart';
import 'package:new_coffee/features/profile/presentation/views/edit_profile_page.dart';
import 'package:new_coffee/features/content/presentation/views/help_page.dart';
import 'package:new_coffee/features/content/presentation/views/privacy_policy_page.dart';
import 'package:new_coffee/features/search/presentation/views/search_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_plans_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_details_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/cashier_subscription_consume_page.dart';
import 'package:new_coffee/features/welcome/presentation/views/welcome_view.dart';
import 'package:new_coffee/shared/widgets/design_page_sections.dart';

/// Static (argument-free) routes + saved-session entry point.
class AppRoutes {
  const AppRoutes._();

  static Map<String, WidgetBuilder> get routes => {
    WelcomePage.routeName: (context) => const WelcomePage(),
    OnBoardingView.routeName: (context) => const OnBoardingView(),
    AuthPage.routeName: (context) => const AuthPage(),
    SignUpPage.routeName: (context) => const SignUpPage(),
    ForgetPasswordPage.routeName: (context) => const ForgetPasswordPage(),
    ResetPasswordPage.routeName: (context) => const ResetPasswordPage(),
    PhoneAuthPage.routeName: (context) => const PhoneAuthPage(),
    EmailAuthPage.routeName: (context) => const EmailAuthPage(),
    MainPage.routeName: (context) => MainPage(
      initialTab: MainPage.notificationTabIndex(
        ModalRoute.of(context)?.settings.arguments,
      ),
    ),
    CheckoutPage.routeName: (context) =>
        _designable('checkout', const CheckoutPage()),
    ShippingAddressesPage.routeName: (context) =>
        _designable('shipping_addresses', const ShippingAddressesPage()),
    AddAddressPage.routeName: (context) =>
        _designable('add_address', const AddAddressPage()),
    PaymentMethodPage.routeName: (context) =>
        _designable('payment_method', const PaymentMethodPage()),
    AddCardPage.routeName: (context) =>
        _designable('add_card', const AddCardPage()),
    PaymentSuccessPage.routeName: (context) =>
        _designable('payment_success', const PaymentSuccessPage()),
    EReceiptPage.routeName: (context) =>
        _designable('e_receipt', const EReceiptPage()),
    CouponPage.routeName: (context) =>
        _designable('coupon', const CouponPage()),
    LoyaltyPage.routeName: (context) =>
        _designable('loyalty', const LoyaltyPage()),
    OrdersPage.routeName: (context) =>
        _designable('orders', const OrdersPage()),
    EditProfilePage.routeName: (context) =>
        _designable('edit_profile', const EditProfilePage()),
    SavedCardsPage.routeName: (context) =>
        _designable('saved_cards', const SavedCardsPage()),
    HelpPage.routeName: (context) => _designable('help', const HelpPage()),
    PrivacyPolicyPage.routeName: (context) =>
        _designable('privacy', const PrivacyPolicyPage()),
    NotificationsPage.routeName: (context) =>
        _designable('notifications', const NotificationsPage()),
    NotificationSettingsPage.routeName: (context) =>
        _designable('notification_settings', const NotificationSettingsPage()),
    SearchPage.routeName: (context) =>
        _designable('search', const SearchPage()),
    AddressesPage.routeName: (context) =>
        _designable('addresses', const AddressesPage()),
    AddressFormPage.routeName: (context) =>
        _designable('address_form', const AddressFormPage()),
    AssistantMemoryPage.routeName: (context) =>
        _designable('assistant_memory', const AssistantMemoryPage()),
    SubscriptionPlansPage.routeName: (context) =>
        _designable('subscription_plans', const SubscriptionPlansPage()),
    SubscriptionDetailsPage.routeName: (context) =>
        _designable('subscription_details', const SubscriptionDetailsPage()),
    CashierSubscriptionConsumePage.routeName: (context) => _designable(
      'cashier_subscription',
      const CashierSubscriptionConsumePage(),
    ),
  };

  static Widget _designable(String pageId, Widget child) =>
      DesignPageSectionsAbove(pageId: pageId, child: child);

  /// Maps the persisted session flag to the first route to show.
  ///
  /// [onboardingDone] guards the default branch: a customer who already went
  /// through the onboarding must never be sent back to the welcome screen just
  /// because the route value is missing or unreadable.
  static String initialRouteName(
    String? savedRoute, {
    bool onboardingDone = false,
  }) {
    switch (savedRoute) {
      case AppConstant.homeRoute:
        return MainPage.routeName;
      case AppConstant.authRoute:
        return AuthPage.routeName;
      case AppConstant.onBoardingRoute:
        return OnBoardingView.routeName;
      default:
        return onboardingDone ? AuthPage.routeName : WelcomePage.routeName;
    }
  }
}
