import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/theme/theme_class.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/add_address_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/add_card_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/checkout_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/e_receipt_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_method_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_success_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/shipping_addresses_page.dart';
import 'package:new_coffee/features/coupon/presentation/views/coupon_page.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/presentation/views/leave_review_page.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';
import 'package:new_coffee/features/orders/presentation/views/track_order_page.dart';
import 'package:new_coffee/features/payment/presentation/manager/saved_cards/saved_cards_cubit.dart';
import 'package:new_coffee/features/payment/presentation/views/saved_cards_page.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';
import 'package:new_coffee/features/profile/presentation/views/edit_profile_page.dart';
import 'package:new_coffee/features/profile/presentation/views/help_page.dart';
import 'package:new_coffee/features/profile/presentation/views/privacy_policy_page.dart';
import 'package:new_coffee/features/search/presentation/manager/search/search_cubit.dart';
import 'package:new_coffee/features/search/presentation/views/search_page.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/on_boarding_page.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/forget_password_page.dart';
import 'package:new_coffee/features/auth/presentation/views/reset_password_page.dart';
import 'package:new_coffee/features/auth/presentation/views/sign_up_page.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/features/welcome/presentation/view/welcome_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final currentRoute = await SharedPref.getValue(key: AppConstant.routesKey);
  runApp(MyApp(currentRoute: currentRoute));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.currentRoute});

  final String? currentRoute;

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return RepositoryProvider<AuthRepository>(
          create: (context) => const AuthRepositoryImpl(),
          child: MultiBlocProvider(
            providers: [
              BlocProvider(create: (context) => CartCubit()),
              BlocProvider(create: (context) => FavoritesCubit()),
              BlocProvider(create: (context) => CheckoutCubit()),
              BlocProvider(create: (context) => SavedCardsCubit()),
              BlocProvider(create: (context) => SearchCubit()),
            ],
            child: MaterialApp(
              title: 'New Coffee',
              theme: ThemeClass.light(),
              home: _initialPage(),
              onGenerateRoute: _onGenerateRoute,
              routes: {
                OnBoardingView.routeName: (context) => const OnBoardingView(),
                AuthPage.routeName: (context) => const AuthPage(),
                SignUpPage.routeName: (context) => const SignUpPage(),
                ForgetPasswordPage.routeName: (context) =>
                    const ForgetPasswordPage(),
                ResetPasswordPage.routeName: (context) =>
                    const ResetPasswordPage(),
                MainPage.routeName: (context) => const MainPage(),
                CheckoutPage.routeName: (context) => const CheckoutPage(),
                ShippingAddressesPage.routeName: (context) =>
                    const ShippingAddressesPage(),
                AddAddressPage.routeName: (context) => const AddAddressPage(),
                PaymentMethodPage.routeName: (context) =>
                    const PaymentMethodPage(),
                AddCardPage.routeName: (context) => const AddCardPage(),
                PaymentSuccessPage.routeName: (context) =>
                    const PaymentSuccessPage(),
                EReceiptPage.routeName: (context) => const EReceiptPage(),
                CouponPage.routeName: (context) => const CouponPage(),
                OrdersPage.routeName: (context) => const OrdersPage(),
                EditProfilePage.routeName: (context) => const EditProfilePage(),
                SavedCardsPage.routeName: (context) => const SavedCardsPage(),
                HelpPage.routeName: (context) => const HelpPage(),
                PrivacyPolicyPage.routeName: (context) =>
                    const PrivacyPolicyPage(),
                NotificationsPage.routeName: (context) =>
                    const NotificationsPage(),
                SearchPage.routeName: (context) => const SearchPage(),
              },
            ),
          ),
        );
      },
    );
  }

  Widget _initialPage() {
    switch (currentRoute) {
      case AppConstant.homeRoute:
        return const MainPage();
      case AppConstant.authRoute:
        return const AuthPage();
      case AppConstant.onBoardingRoute:
        return const OnBoardingView();
      default:
        return const WelcomePage();
    }
  }
}

Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
  if (settings.name == ProductDetailsPage.routeName) {
    final arguments = settings.arguments;
    if (arguments is ProductModel) {
      return MaterialPageRoute(
        builder: (context) => ProductDetailsPage(product: arguments),
      );
    }
  }
  if (settings.name == TrackOrderPage.routeName) {
    final arguments = settings.arguments;
    if (arguments is OrderItemModel) {
      return MaterialPageRoute(
        builder: (context) => TrackOrderPage(order: arguments),
      );
    }
  }
  if (settings.name == LeaveReviewPage.routeName) {
    final arguments = settings.arguments;
    if (arguments is OrderItemModel) {
      return MaterialPageRoute(
        builder: (context) => LeaveReviewPage(order: arguments),
      );
    }
  }
  return null;
}
