import 'package:flutter/cupertino.dart';

class AppColor {
  static const primaryColor = Color(0xff1D4ED8);
  static const secondryColor = Color(0xff033A58);
  static const greyColor = Color(0xff797979);
  static const lightGreyColor = Color(0xffF5F5F5);
  static const whiteColor = Color(0xffFFFFFF);
  static const blackColor = Color(0xff000000);
  static const borderColor = Color(0xffE6E6E6);
  static const greenColor = Color.fromARGB(255, 1, 116, 1);

  /// Used for messages that block an action, such as an option combination the
  /// selected branch cannot make. It was missing, so an unavailable product had
  /// no established colour to reuse.
  static const errorColor = Color(0xFFDC2626);

  // Dark mode
  static const darkBackground = Color(0xff121212);
  static const darkSurface = Color(0xff1E1E1E);
  static const darkCard = Color(0xff2C2C2C);
  static const darkBorder = Color(0xff3A3A3A);
  static const darkText = Color(0xffE0E0E0);
  static const darkTextSecondary = Color(0xff9E9E9E);
}
