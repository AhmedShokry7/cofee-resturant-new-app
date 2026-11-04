import 'package:flutter/material.dart';

import 'package:new_coffee/features/auth/presentation/views/email_otp_page.dart';
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
import 'package:new_coffee/features/orders/presentation/views/order_details_by_id_page.dart';
import 'package:new_coffee/features/orders/presentation/views/order_details_page.dart';
import 'package:new_coffee/features/orders/presentation/views/track_order_page.dart';

/// Routes that require arguments passed via [RouteSettings.arguments].
///
/// A page name that arrives with the wrong argument falls through and the
/// navigator reports the route as unhandled — pushing a route is the caller's
/// contract, not something a screen can be built around here.
class AppRouteGenerator {
  const AppRouteGenerator._();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final arguments = settings.arguments;
    final Widget? page = switch (settings.name) {
      ProductDetailsPage.routeName when arguments is ProductModel =>
        ProductDetailsPage(product: arguments),
      BundleDetailsPage.routeName when arguments is BundleModel =>
        BundleDetailsPage(bundle: arguments),
      OrderDetailsPage.routeName when arguments is OrderItemModel =>
        OrderDetailsPage(order: arguments),
      OrderDetailsPage.routeName when arguments is OrderGroup =>
        OrderDetailsPage(order: arguments.header, lines: arguments.lines),
      // A notification names an order by id and carries no rows of its own, so
      // the id is read into the frozen invoice before the details are drawn.
      OrderDetailsPage.routeName when arguments is String =>
        OrderDetailsByIdPage(orderId: arguments),
      BannerDetailsPage.routeName when arguments is BannerModel =>
        BannerDetailsPage(banner: arguments),
      SeeAllProductsPage.routeName when arguments is SeeAllProductsArgs =>
        SeeAllProductsPage(args: arguments),
      OtpPage.routeName when arguments is String => OtpPage(phone: arguments),
      EmailOtpPage.routeName when arguments is String => EmailOtpPage(
        email: arguments,
      ),
      TrackOrderPage.routeName when arguments is OrderItemModel =>
        TrackOrderPage(order: arguments),
      LeaveReviewPage.routeName when arguments is OrderItemModel =>
        LeaveReviewPage(order: arguments),
      _ => null,
    };
    if (page == null) return null;
    return MaterialPageRoute(builder: (context) => page);
  }
}
