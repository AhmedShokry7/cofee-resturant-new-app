import 'package:flutter/cupertino.dart';

class AppColor {
  static const primaryColor = Color(0xff087F68);
  static const secondaryColor = Color(0xffDDF5EE);

  /// Deeper tone of [secondaryColor] used for borders and focus rings on light
  /// backgrounds where the bright brand mint would be hard to see.
  static const secondaryStrong = Color(0xff087F68);

  /// Tinted footer used by the record cards.
  static const cardFooter = Color(0xFFF7F9F8);

  /// Darker tone of [primaryColor] used for the active navigation row.
  static const sidebarActiveBackground = Color(0xff06614F);

  /// Muted text used on the dark navigation panel.
  static const sidebarMuted = Color(0xCCFFFFFF);
  static const greyColor = Color(0xff667085);
  static const lightGreyColor = Color(0xffF4F6F8);
  static const whiteColor = Color(0xffFFFFFF);
  static const white70 = Color(0xB3FFFFFF);
  static const blackColor = Color(0xff000000);
  static const borderColor = Color(0xffE5E9EE);
  static const greenColor = Color.fromARGB(255, 1, 116, 1);

  /// Used for messages that block an action, such as an option combination the
  /// selected branch cannot make. It was missing, so an unavailable product had
  /// no established colour to reuse.
  static const errorColor = Color(0xFFDC2626);

  // Dark mode
  static const darkBackground = Color(0xff111827);
  static const darkSurface = Color(0xff1B2432);

  /// Raised surfaces such as inputs and menus sit above [darkSurface].
  static const darkSurfaceContainer = Color(0xff263244);
  static const darkCard = Color(0xff202B3A);
  static const darkBorder = Color(0xff344154);
  static const darkText = Color(0xffF2F4F7);
  static const darkTextSecondary = Color(0xffAAB5C3);

  /// Light surface color used as fallback background for product images.
  static const surfaceColor = Color(0xffF7F8FA);
}
