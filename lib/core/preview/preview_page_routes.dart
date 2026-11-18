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
import 'package:new_coffee/features/checkout/presentation/views/checkout_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/e_receipt_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_method_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_success_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/shipping_addresses_page.dart';
import 'package:new_coffee/features/content/presentation/views/help_page.dart';
import 'package:new_coffee/features/content/presentation/views/privacy_policy_page.dart';
import 'package:new_coffee/features/coupon/presentation/views/coupon_page.dart';
import 'package:new_coffee/features/loyalty/presentation/views/loyalty_page.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/features/notifications/presentation/views/notification_settings_page.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/on_boarding_view.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';
import 'package:new_coffee/features/payment/presentation/views/add_card_page.dart';
import 'package:new_coffee/features/payment/presentation/views/saved_cards_page.dart';
import 'package:new_coffee/features/profile/presentation/views/edit_profile_page.dart';
import 'package:new_coffee/features/search/presentation/views/search_page.dart';
import 'package:new_coffee/features/splash/presentation/views/splash_view.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/cashier_subscription_consume_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_details_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_plans_page.dart';
import 'package:new_coffee/features/welcome/presentation/views/welcome_view.dart';

/// Routes the admin preview can open without page-specific arguments.
/// Tabs resolve to MainPage; the preview selects their tab separately.
/// Product details needs a real product argument, so it is opened from a
/// product card rather than by guessing a placeholder route here.
const Map<String, String> previewPageRoutes = {
  'splash': SplashView.routeName,
  'welcome': WelcomePage.routeName,
  'onboarding': OnBoardingView.routeName,
  'auth': AuthPage.routeName,
  'sign_up': SignUpPage.routeName,
  'forget_password': ForgetPasswordPage.routeName,
  'reset_password': ResetPasswordPage.routeName,
  'phone_auth': PhoneAuthPage.routeName,
  'email_auth': EmailAuthPage.routeName,
  'home': MainPage.routeName,
  'categories': MainPage.routeName,
  'search': SearchPage.routeName,
  'cart': MainPage.routeName,
  'favourites': MainPage.routeName,
  'settings': MainPage.routeName,
  'checkout': CheckoutPage.routeName,
  'shipping_addresses': ShippingAddressesPage.routeName,
  'add_address': AddAddressPage.routeName,
  'payment_method': PaymentMethodPage.routeName,
  'add_card': AddCardPage.routeName,
  'payment_success': PaymentSuccessPage.routeName,
  'e_receipt': EReceiptPage.routeName,
  'coupon': CouponPage.routeName,
  'orders': OrdersPage.routeName,
  'edit_profile': EditProfilePage.routeName,
  'saved_cards': SavedCardsPage.routeName,
  'addresses': AddressesPage.routeName,
  'address_form': AddressFormPage.routeName,
  'loyalty': LoyaltyPage.routeName,
  'subscription_plans': SubscriptionPlansPage.routeName,
  'subscription_details': SubscriptionDetailsPage.routeName,
  'cashier_subscription': CashierSubscriptionConsumePage.routeName,
  'notifications': NotificationsPage.routeName,
  'notification_settings': NotificationSettingsPage.routeName,
  'help': HelpPage.routeName,
  'privacy': PrivacyPolicyPage.routeName,
  'assistant_memory': AssistantMemoryPage.routeName,
};
