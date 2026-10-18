import 'package:flutter/material.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/features/addresses/presentation/views/address_form_page.dart';
import 'package:new_coffee/features/addresses/presentation/views/addresses_page.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/forget_password_page.dart';
import 'package:new_coffee/features/auth/presentation/views/phone_auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/reset_password_page.dart';
import 'package:new_coffee/features/auth/presentation/views/sign_up_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/add_address_page.dart';
import 'package:new_coffee/features/payment/presentation/views/add_card_page.dart';
import 'package:new_coffee/features/payment/presentation/views/card_payment_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/checkout_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/e_receipt_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_method_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_success_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/shipping_addresses_page.dart';
import 'package:new_coffee/features/coupon/presentation/views/coupon_page.dart';
import 'package:new_coffee/features/loyalty/presentation/views/loyalty_page.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/on_boarding_page.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';
import 'package:new_coffee/features/payment/presentation/views/saved_cards_page.dart';
import 'package:new_coffee/features/profile/presentation/views/edit_profile_page.dart';
import 'package:new_coffee/features/profile/presentation/views/help_page.dart';
import 'package:new_coffee/features/profile/presentation/views/privacy_policy_page.dart';
import 'package:new_coffee/features/search/presentation/views/search_page.dart';
import 'package:new_coffee/features/welcome/presentation/view/welcome_view.dart';

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
    MainPage.routeName: (context) => const MainPage(),
    CheckoutPage.routeName: (context) => const CheckoutPage(),
    ShippingAddressesPage.routeName: (context) =>
        const ShippingAddressesPage(),
    AddAddressPage.routeName: (context) => const AddAddressPage(),
    PaymentMethodPage.routeName: (context) => const PaymentMethodPage(),
    AddCardPage.routeName: (context) => const AddCardPage(),
    CardPaymentPage.routeName: (context) => const CardPaymentPage(
      orderId: '',
      idempotencyKey: '',
      publicKey: '',
      sdkConfiguration: {},
    ),
    PaymentSuccessPage.routeName: (context) => const PaymentSuccessPage(),
    EReceiptPage.routeName: (context) => const EReceiptPage(),
    CouponPage.routeName: (context) => const CouponPage(),
    LoyaltyPage.routeName: (context) => const LoyaltyPage(),
    OrdersPage.routeName: (context) => const OrdersPage(),
    EditProfilePage.routeName: (context) => const EditProfilePage(),
    SavedCardsPage.routeName: (context) => const SavedCardsPage(),
    HelpPage.routeName: (context) => const HelpPage(),
    PrivacyPolicyPage.routeName: (context) => const PrivacyPolicyPage(),
    NotificationsPage.routeName: (context) => const NotificationsPage(),
    SearchPage.routeName: (context) => const SearchPage(),
    AddressesPage.routeName: (context) => const AddressesPage(),
    AddressFormPage.routeName: (context) => const AddressFormPage(),
  };

  /// Maps the persisted session flag to the first route to show.
  static String initialRouteName(String? savedRoute) {
    switch (savedRoute) {
      case AppConstant.homeRoute:
        return MainPage.routeName;
      case AppConstant.authRoute:
        return AuthPage.routeName;
      case AppConstant.onBoardingRoute:
        return OnBoardingView.routeName;
      default:
        return WelcomePage.routeName;
    }
  }
}
