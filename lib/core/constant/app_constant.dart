import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_toxens.dart';

class AppConstant {
  static const String routesKey = "routes";

  static double horizontalPadding(BuildContext context) => SpacingTokens.xl.w;

  static double btnHeight(BuildContext context) => 52.h;
}
