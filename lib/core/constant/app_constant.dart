import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_tokens.dart';

class AppConstant {
  static const String routesKey = "routes";
  static const String onBoardingRoute = "2";
  static const String authRoute = "3";
  static const String homeRoute = "4";

  static double horizontalPadding(BuildContext context) => SpacingTokens.lg.w;

  static double btnHeight(BuildContext context) => 52.h;
}
