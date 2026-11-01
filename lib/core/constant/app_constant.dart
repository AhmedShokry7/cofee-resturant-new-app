import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';


class AppConstant {
  static const String routesKey = "routes";
  static const String onBoardingRoute = "2";
  static const String authRoute = "3";
  static const String homeRoute = "4";

  /// Separate flag for "the onboarding was finished", independent of [routesKey].
  ///
  /// [routesKey] also encodes the sign-in state, so it can be rewritten by a
  /// logout. Keeping the onboarding marker on its own means a returning
  /// customer is never pushed back to the welcome screen because of it.
  static const String onBoardingDoneKey = "onboarding_done";

  /// The size the design was drawn at. ScreenUtil scales every `.w`, `.h` and
  /// `.sp` unit from it, and any harness that renders a screen has to use the
  /// same one.
  static const Size designSize = Size(360, 690);

  static double btnHeight(BuildContext context) => 52.h;

  /// The glyph inside a round icon button sized by [btnHeight].
  static double btnIconSize(BuildContext context) =>
      MediaQuery.sizeOf(context).height * .03;
}
