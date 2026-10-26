class AppDimensions {
  const AppDimensions._();

  // Spacing
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  // Logo
  static const double logoSmall = 40.0;
  static const double logoMedium = 64.0;
  static const double logoIcon = 36.0;

  // Radii
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 18.0;
  static const double radiusPill = 999.0;

  // Common widths
  static const double formMaxWidth = 420.0;
  static const double sidebarWidth = 248.0;
  static const double sidebarLogoSize = 56.0;

  // Page margins
  /// The left and right margin of every page. Change it here to move the
  /// content of all the admin pages at once.
  static const double pageHorizontalPadding = 32.0;

  /// The top and bottom margin of every page.
  static const double pageVerticalPadding = 24.0;

  /// The padding inside the card that wraps a page body.
  static const double pageCardPadding = 16.0;

  /// The widest the page content may grow before it is centred.
  ///
  /// Raise it to use more of a wide monitor, lower it to keep long rows
  /// readable.
  static const double contentMaxWidth = 1760.0;

  /// Below this width record tables switch to their card representation.
  static const double tableBreakpoint = 720.0;

  /// Below this width the sign-in screen drops the brand panel and keeps the
  /// form alone.
  static const double loginWideBreakpoint = 900.0;

  // Data table
  static const double tableRowMinHeight = 64.0;
  static const double tableRowMaxHeight = 84.0;
  static const double tableColumnSpacing = 28.0;
  static const double tableThumbnailSize = 64.0;
  static const double cardThumbnailSize = 64.0;
  static const double cardImageHeight = 156.0;

  // Record card
  static const double recordCardRadius = 8.0;
  static const double recordFieldRadius = 4.0;
  static const double recordFieldHeight = 36.0;
  static const double recordFieldLabelWidth = 94.0;
  static const double recordFieldValueWidth = 48.0;
  static const double recordFieldActionWidth = 32.0;
  static const double recordCheckBoxSize = 20.0;
  static const double recordCheckBoxColumnWidth = 31.0;
  static const double recordActionCircle = 30.0;
  static const double recordCardImageMaxHeight = 260.0;
  static const double recordImageInset = 15.0;
  static const double recordLangWidth = 48.0;
  static const double recordLanguageTagHeight = 32.0;
  static const double recordPriceRowWidth = 289.0;
  static const double recordFooterHeight = 40.0;
  static const double recordSaveBarHeight = 40.0;

  // Product card grid
  /// The narrowest a product card may become before the grid drops a column.
  static const double productCardMinWidth = 280.0;

  /// The most cards a row may hold on a very wide screen.
  static const int productCardMaxColumns = 5;

  // Form field
  static const double fieldRadius = 12.0;
  static const double fieldPadding = 14.0;
  static const double fieldVerticalPadding = 13.0;
  static const double fieldIconSize = 21.0;
  static const double fieldIconBox = 40.0;
  static const double fieldIconMinHeight = 24.0;
  static const double fieldIconStart = 14.0;
  static const double fieldIconEnd = 10.0;
  static const double fieldLabelGap = 4.0;
  static const double fieldLabelBottom = 8.0;
  static const double fieldBorderWidth = 1.0;
  static const double fieldFocusBorderWidth = 2.0;

  // Shared component sizes
  /// Width of a single order summary card in the horizontal list.
  static const double orderSummaryCardWidth = 168.0;
  static const double searchFieldWidth = 320.0;
  static const double dialogButtonHeight = 40.0;
  static const double placeholderIconBox = 72.0;
  static const double indicatorSize = 24.0;
  static const double iconSizeSm = 20.0;
  static const double spinnerSize = 22.0;
  static const double spinnerSizeLg = 24.0;
  static const double spinnerStroke = 2.5;
  static const double borderStrong = 2.0;
  static const double textHeightTight = 1.4;
}
