import 'package:flutter/material.dart';

import 'package:new_coffee/features/auth/presentation/views/otp_page.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/bundles/presentation/views/bundle_details_page.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/home/presentation/views/banner_details_page.dart';
import 'package:new_coffee/features/home/presentation/views/see_all_products_page.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/features/orders/data/model/order_group.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/presentation/views/leave_review_page.dart';
import 'package:new_coffee/features/orders/presentation/views/order_details_page.dart';
import 'package:new_coffee/features/orders/presentation/views/track_order_page.dart';

/// Routes that require arguments passed via [RouteSettings.arguments].
class AppRouteGenerator {
  const AppRouteGenerator._();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == ProductDetailsPage.routeName) {
      final arguments = settings.arguments;
      if (arguments is ProductModel) {
        return MaterialPageRoute(
          builder: (context) => ProductDetailsPage(product: arguments),
        );
      }
    }
    if (settings.name == BundleDetailsPage.routeName) {
      final arguments = settings.arguments;
      if (arguments is BundleModel) {
        return MaterialPageRoute(
          builder: (context) => BundleDetailsPage(bundle: arguments),
        );
      }
    }
    if (settings.name == OrderDetailsPage.routeName) {
      final arguments = settings.arguments;
      if (arguments is OrderItemModel) {
        return MaterialPageRoute(
          builder: (context) => OrderDetailsPage(order: arguments),
        );
      }
      if (arguments is OrderGroup) {
        return MaterialPageRoute(
          builder: (context) => OrderDetailsPage(
            order: arguments.header,
            lines: arguments.lines,
          ),
        );
      }
    }
    if (settings.name == BannerDetailsPage.routeName) {
      final arguments = settings.arguments;
      if (arguments is BannerModel) {
        return MaterialPageRoute(
          builder: (context) => BannerDetailsPage(banner: arguments),
        );
      }
    }
    if (settings.name == SeeAllProductsPage.routeName) {
      final arguments = settings.arguments;
      if (arguments is SeeAllProductsArgs) {
        return MaterialPageRoute(
          builder: (context) => SeeAllProductsPage(args: arguments),
        );
      }
    }
    if (settings.name == OtpPage.routeName) {
      final arguments = settings.arguments;
      if (arguments is String) {
        return MaterialPageRoute(
          builder: (context) => OtpPage(phone: arguments),
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
}
