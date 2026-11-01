import 'package:flutter/cupertino.dart';

class AppColor {
  static Color primaryColor = const Color(0xff1D4ED8);

  /// The lighter half of the brand gradient every primary button ends on.
  static const Color primaryColorEnd = Color(0xff2563EB);
  static Color secondryColor = const Color(0xff033A58);
  static const greyColor = Color(0xff797979);
  static const lightGreyColor = Color(0xffF5F5F5);
  static const whiteColor = Color(0xffFFFFFF);
  static const blackColor = Color(0xff000000);
  static const borderColor = Color(0xffE6E6E6);
  static const greenColor = Color.fromARGB(255, 1, 116, 1);

  /// A completed action, such as an item landing in the cart. The pair is the
  /// same green, ending lighter, that the primary button uses for blue.
  static const Color successColorDeep = Color(0xFF15803D);
  static const Color successColor = Color(0xFF22C55E);

  /// Used for messages that block an action, such as an option combination the
  /// selected branch cannot make. It was missing, so an unavailable product had
  /// no established colour to reuse.
  static const errorColor = Color(0xFFDC2626);

  /// The darker half of [errorColor], for a gradient that reports a failure.
  static const Color errorColorDeep = Color(0xFFB91C1C);

  /// The dot that counts unread items. Brighter than [errorColor] because it
  /// sits on a white chip and has to read as a badge, not as an error message.
  static const Color unreadBadgeColor = Color(0xFFFF3B30);

  // Dark mode
  static const darkBackground = Color(0xff121212);
  static const darkSurface = Color(0xff1E1E1E);
  static const darkCard = Color(0xff2C2C2C);
  static const darkBorder = Color(0xff3A3A3A);
  static const darkText = Color(0xffE0E0E0);
  static const darkTextSecondary = Color(0xff9E9E9E);

  /// A glyph on a light surface: pure black reads too harsh next to the text.
  static const Color iconOnLight = Color(0xff242424);

  /// Skeleton placeholders, one step apart so the highlight sweep is visible.
  static const Color skeletonBase = Color(0xffE9E9E9);
  static const Color skeletonHighlight = Color(0xffF7F7F7);

  /// Light surface color used as fallback background for product images.
  static Color surfaceColor = const Color(0xffF9F9F9);
}
