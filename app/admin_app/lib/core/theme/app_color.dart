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

  // Admin dashboard design tokens
  /// Headings and primary values on a light admin surface.
  static const adminHeading = Color(0xFF22332D);

  /// Secondary labels under a value or a table heading.
  static const adminMuted = Color(0xFF819087);

  /// Restrained brand green used by the admin tables and controls.
  static const adminAccent = Color(0xFF267660);

  /// Tinted fill behind the active page number and selected rows.
  static const adminAccentSurface = Color(0xFFE6F1EB);

  /// Border of the large directory card.
  static const adminCardBorder = Color(0xFFEBEFEB);

  /// Background of a table heading row.
  static const adminTableHeader = Color(0xFFF8FAF8);

  /// Border around the table heading cells.
  static const adminTableBorder = Color(0xFFEFF2EF);

  /// Divider between table rows.
  static const adminRowBorder = Color(0xFFF0F2F0);

  /// Border of the compact toolbar buttons.
  static const adminControlBorder = Color(0xFFE3E9E4);

  /// Primary text inside admin tables and record rows.
  static const adminBody = Color(0xFF49584F);

  /// Secondary line under a table name, such as an email address.
  static const adminSubtle = Color(0xFF99A39D);

  /// Amounts and strong inline values inside a table row.
  static const adminAmount = Color(0xFF36473E);

  /// Dates and quiet metadata inside a table row.
  static const adminDate = Color(0xFF8A958E);

  /// Fill of a selected table row.
  static const adminRowSelected = Color(0xFFF6FAF7);

  /// Trend badge colours, matching the statistics cards.
  static const trendPositive = Color(0xFF3D8A68);
  static const trendPositiveSurface = Color(0xFFEDF6EF);
  static const trendNegative = Color(0xFFC65353);
  static const trendNegativeSurface = Color(0xFFFCEEEE);

  /// Amber used for customer flags and in-progress order states.
  static const adminWarning = Color(0xFFA47B2F);
  static const adminWarningSurface = Color(0xFFFBF2DC);

  /// Indigo used by quiet informational marks, such as the last-order tile.
  static const adminInfo = Color(0xFF5F70A8);
  static const adminInfoSurface = Color(0xFFE9EDF8);

  /// Light surface color used as fallback background for product images.
  static const surfaceColor = Color(0xffF7F8FA);

  // Record cards
  /// Border of a record card and of the field cells inside it.
  static const recordBorder = Color(0xFFEEEEEE);

  /// Background of the label and action cells of a record card.
  static const recordCellBackground = Color(0xFFFCFCFC);

  /// Text of the record card footer and of its label cells.
  static const recordText = Color(0xFF444444);

  /// Text of the record card value cells.
  static const recordTextStrong = Color(0xFF333333);

  /// Secondary text inside a record card, such as the currency mark.
  static const recordTextSecondary = Color(0xFF666666);

  /// Muted text for a value that is still empty.
  static const recordTextMuted = Color(0xFF999999);

  /// Deep teal of the marks that sit on top of the product image.
  static const accentDeep = Color(0xFF004D5A);

  /// Placeholder behind a product image that has no file yet.
  static const imagePlaceholder = Color(0xFFF5F5F5);

  /// Fill of the delete circle on the product image.
  static const dangerSurface = Color(0xFFF55157);
}
