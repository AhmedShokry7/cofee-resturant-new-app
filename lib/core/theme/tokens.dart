import 'package:flutter/widgets.dart';

import 'app_color.dart';

// The single page of numbers: spacing, box sizes, corner radii, component
// dimensions, shadows and responsive breakpoints for the whole app. No screen
// writes a literal.
//
// Five families, and no value appears in two of them:
//   AppSpacing    gaps and padding      (4pt grid: 4, 8, 12, 16, 24, 32, 48)
//   AppSizes      box edges and icons   (2pt grid)
//   AppRadius     corner radii
//   AppShadows    the drop under a lifted surface
//   AppDimensions the named size of one specific component, built from the
//                 three families whenever its value equals a step of one.
//
// Values that are not a grid step (11, 13, 15, 26, 46 …) keep their exact
// number: this file only replaces ScreenUtil's scaled units, and settling an
// odd size onto the grid is a decision made while looking at the screen, not a
// silent rounding applied to every page at once.

/// Padding and gaps between elements.
///
/// These are the values the app already used, so moving a page onto them
/// changes where the number comes from, never the layout.
abstract final class AppSpacing {
  AppSpacing._();

  /// No space at all.
  static const double none = 0.0;

  /// Very tight: inside badges and hairline separators.
  static const double xxs = 2.0;

  /// Tight: a line and the next line of the same block.
  static const double xs = 4.0;

  /// Small: the default distance between two siblings.
  static const double sm = 8.0;

  /// Medium: padding of small controls and inter-line gaps.
  static const double md = 12.0;

  /// Large: card padding and the screen margin.
  static const double lg = 16.0;

  /// Larger: gaps between sections inside one page.
  static const double xl = 24.0;

  /// Very large: padding of floating boxes and sheets.
  static const double xxl = 32.0;

  /// The top of the everyday grid: between big page blocks.
  static const double xxxl = 48.0;

  /// A rare air gap between the heaviest blocks of a screen.
  static const double huge = 64.0;
}

/// Box edges, icon bodies and rule thicknesses on a 2pt grid.
///
/// The name is the value, so a size can never be misread at the call site.
/// Use these when the number is the edge of something (an icon, an image, a
/// circle, a bar) rather than the space between two things.
abstract final class AppSizes {
  AppSizes._();

  static const double px1 = 1.0;
  static const double px1_5 = 1.5;
  static const double px2 = 2.0;
  static const double px3 = 3.0;
  static const double px4 = 4.0;
  static const double px5 = 5.0;
  static const double px6 = 6.0;
  static const double px8 = 8.0;
  static const double px10 = 10.0;
  static const double px11 = 11.0;
  static const double px12 = 12.0;
  static const double px13 = 13.0;
  static const double px14 = 14.0;
  static const double px15 = 15.0;
  static const double px16 = 16.0;
  static const double px18 = 18.0;
  static const double px20 = 20.0;
  static const double px22 = 22.0;
  static const double px24 = 24.0;
  static const double px26 = 26.0;
  static const double px28 = 28.0;
  static const double px30 = 30.0;
  static const double px32 = 32.0;
  static const double px36 = 36.0;
  static const double px40 = 40.0;
  static const double px44 = 44.0;
  static const double px46 = 46.0;
  static const double px48 = 48.0;
  static const double px50 = 50.0;
  static const double px52 = 52.0;
  static const double px56 = 56.0;
  static const double px64 = 64.0;
  static const double px72 = 72.0;
  static const double px76 = 76.0;
  static const double px78 = 78.0;
}

/// The semantic icon sizes, built on [AppSizes] so no new number appears here.
abstract final class AppIconSize {
  AppIconSize._();

  /// Inside badges and dots.
  static const double xs = AppSizes.px12;

  /// Next to 12-14 text.
  static const double sm = AppSizes.px14;

  /// The default: form fields and list rows.
  static const double md = AppSizes.px16;

  /// The glyph inside a text field. One step above [md] because it shares the
  /// box with 16pt input text, and a stroke-rounded outline at 16 loses to it.
  /// Every field in the app draws this size, so a form reads as one system.
  static const double field = AppSizes.px20;

  /// Section headings and compact buttons.
  static const double lg = AppSizes.px18;

  /// Ordinary buttons and the tab bar.
  static const double xl = AppSizes.px20;

  /// A circular icon button sitting on a bar.
  static const double xxl = AppSizes.px24;

  /// The glyph of a status message or an empty list.
  static const double xxxl = AppSizes.px32;

  /// A block-sized glyph: an error or success that owns its own area.
  static const double block = AppSizes.px40;

  /// The largest glyph the app draws (a hero mark, a waiting state).
  static const double hero = AppSizes.px48;
}

/// Corner radii. The name is the value; [AppDimensions] gives them roles.
abstract final class AppRadius {
  AppRadius._();

  /// A square corner.
  static const double none = 0.0;

  static const double r4 = 4.0;
  static const double r6 = 6.0;
  static const double r8 = 8.0;
  static const double r10 = 10.0;
  static const double r12 = 12.0;
  static const double r14 = 14.0;
  static const double r16 = 16.0;
  static const double r20 = 20.0;
  static const double r24 = 24.0;
  static const double r32 = 32.0;

  /// The capsule: larger than any element, so it is clipped at half.
  static const double pill = 999.0;
}

/// The named size of one component. No number here repeats one of the families.
abstract final class AppDimensions {
  const AppDimensions._();

  // Buttons and fields
  /// The height of every primary button.
  static const double buttonHeight = AppSizes.px52;

  /// The height of a compact button inside a sheet or an inline field.
  static const double buttonHeightSmall = AppSizes.px40;

  /// The corner of a text field.
  static const double fieldRadius = AppSizes.px18;

  /// The hairline around a resting text field.
  static const double fieldBorderWidth = AppSizes.px1;

  /// The heavier line a focused or rejected field draws around itself.
  static const double fieldBorderWidthActive = AppSizes.px1_5;

  /// The smallest tappable edge - the accessibility floor no screen goes under.
  static const double tapTargetMin = AppSizes.px44;

  /// How far the skip control sits from the top and end edges of the window.
  static const double skipInset = AppSpacing.lg;

  /// The band a screen keeps clear under the skip control, so its first line of
  /// content never starts underneath it.
  static const double skipReservedHeight = AppSizes.px56;

  /// The round social-login button.
  static const double socialButtonSize = AppSizes.px56;

  /// The square search button beside a field.
  static const double searchButtonBox = AppSizes.px46;

  /// The top tab strip of the categories page.
  static const double tabBarHeight = AppSizes.px50;

  /// The grabber that marks a bottom sheet.
  static const double sheetHandleWidth = 100.0;

  // Image boxes
  /// The image of a product card in the grid.
  static const double productCardImage = AppSizes.px76;

  /// The image of a bundle row in a list.
  static const double bundleTileImage = AppSizes.px78;

  /// The tile of a category on the home grid.
  static const double categoryTile = AppSizes.px56;

  /// The width of a product card in a horizontal strip.
  ///
  /// Wide enough for the price and the struck-through old price to sit side by
  /// side without either of them being cut.
  static const double productCardWidth = 168.0;

  /// The width-to-height ratio of a product card.
  static const double productCardAspect = 0.60;

  /// The width of a bundle card in a horizontal strip.
  static const double bundleCardWidth = 180.0;

  // Heroes and section bodies
  /// The product image at the top of the details page.
  static const double productHeroHeight = 300.0;

  /// The bundles strip on the home page.
  static const double bundleSectionHeight = 250.0;

  /// The banner of a bundle's own page.
  static const double bundleHeroHeight = 200.0;

  /// The image of the banner details page.
  static const double bannerHeroHeight = 220.0;

  /// The home carousel slide, single banner included.
  static const double homeBannerHeight = 164.0;

  /// The success ring on the payment-success page, mark included.
  static const double paymentSuccessMark = 124.0;

  /// A short title bar in a loading skeleton.
  static const double skeletonChipWidth = 120.0;

  /// The narrower companion of [skeletonChipWidth].
  static const double skeletonChipShortWidth = 110.0;

  /// The small tag a skeleton draws beside a title line.
  static const double skeletonTagWidth = 70.0;

  /// The pill a skeleton draws in place of a chip or a button.
  static const double skeletonPillWidth = 84.0;

  /// The first tab pill a category-tab skeleton draws.
  static const double skeletonTabWidth = 96.0;

  /// The shorter tab pills after the leading one.
  static const double skeletonTabShortWidth = 72.0;

  // Floating structures
  /// The widest bubble the assistant is allowed to answer in.
  static const double assistantBubbleMaxWidth = 230.0;

  /// The widest the floating assistant panel gets.
  static const double assistantPanelMaxWidth = 270.0;

  // Shapes
  /// The radius of a content card, which is also the card radius of the theme.
  static const double cardRadius = AppRadius.r12;

  /// The radius of the controls the theme draws: buttons, fields, sheets.
  static const double controlRadius = AppRadius.r14;

  /// The radius of an image inside a card - softer than the card itself.
  static const double imageRadius = AppRadius.r8;

  /// The radius of badges and small chips.
  static const double badgeRadius = AppRadius.r6;

  /// The large profile avatar, kept as the radius the page computes from it.
  static const double avatarRadiusLarge = AppSizes.px52;

  /// The round mark of a coupon card.
  static const double couponMark = AppSizes.px44;

  /// The ring the catalog shows while it pages in more products.
  static const double spinnerStroke = 2.5;

  /// How far before the bottom a product grid asks for its next page.
  static const double gridLoadMoreAhead = 300.0;

  /// How much taller a home category tile is than it is wide.
  static const double categoryTileAspect = 1.2;

  // Control sizes a page passes to a shared widget
  /// The favourite heart in the corner of a product card image.
  static const double favoriteButtonCard = AppSizes.px28;

  /// The add-to-cart circle beside a product card price.
  static const double addToCartButtonCard = AppSizes.px36;

  /// The smaller add-to-cart circle inside an assistant answer.
  static const double addToCartButtonAssistant = AppSizes.px32;

  /// A discount badge set inline beside a price.
  static const double discountBadgeInline = AppSizes.px26;

  /// The same badge at the size the product details header draws.
  static const double discountBadgeDetails = AppSizes.px30;

  /// The badge a bundle details header can afford.
  static const double discountBadgeLarge = AppSizes.px52;

  /// The default badge diameter when a page does not pick one.
  static const double discountBadgeDefault = AppSizes.px40;

  /// The number of a discount badge is this fraction of the badge, so the two
  /// stacked lines always fill the circle whatever size the page asked for.
  static const double discountBadgeTextRatio = 0.30;

  // Skeleton line lengths, each named after the real element it mirrors
  /// The long line under a skeleton card title.
  static const double skeletonLineLong = 140.0;

  /// The line a skeleton draws in place of a price row.
  static const double skeletonLineMedium = 110.0;

  /// The short caption line of a skeleton row.
  static const double skeletonLineShort = 90.0;

  /// The title line of a skeleton tile.
  static const double skeletonLineTile = 100.0;

  /// The second caption line of a skeleton row.
  static const double skeletonLineBrief = 80.0;

  /// The thumb a skeleton draws where a bundle row shows its image.
  static const double skeletonThumbLine = 56.0;

  /// The wide block of a loyalty skeleton header.
  static const double skeletonBlock = 160.0;

  /// The height of a skeleton body line.
  static const double skeletonLineHeight = AppSizes.px16;

  /// The height of a skeleton caption line.
  static const double skeletonCaptionHeight = AppSizes.px13;

  /// The height of a skeleton title line.
  static const double skeletonTitleHeight = AppSizes.px18;

  /// The height of a skeleton block that stands in for a mark or a chip.
  static const double skeletonBlockHeight = AppSizes.px30;

  /// The gap between two skeleton lines.
  static const double skeletonLineGap = AppSizes.px6;
}

/// Shadow strengths, one per elevation the app paints.
abstract final class AppElevation {
  const AppElevation._();

  /// A surface that lies flat on the page: cards, fields, bars.
  static const double flat = 0;

  /// The floating bottom bar, lifted just enough to read above content.
  static const double raised = 1.5;

  /// The assistant button, the only control that floats over everything.
  static const double floating = 6;
}

/// The drop under a surface that sits above others.
///
/// A page never writes a [BoxShadow] and never mixes a colour with an alpha
/// number: it picks one of these, so every lifted card in the app is lit the
/// same way.
abstract final class AppShadows {
  const AppShadows._();

  /// The tile of a category grid.
  static final List<BoxShadow> tile = [
    BoxShadow(
      color: AppColor.shadowMedium,
      blurRadius: AppSizes.px4,
      offset: const Offset(0, AppSizes.px4),
    ),
  ];

  /// A panel or chip floating over the page, like the assistant bubble.
  static final List<BoxShadow> floating = [
    BoxShadow(
      color: AppColor.shadowMedium,
      blurRadius: AppSizes.px10,
      offset: const Offset(0, AppSizes.px4),
    ),
  ];

  /// The sheet that slides up over the screen.
  static final List<BoxShadow> sheet = [
    BoxShadow(
      color: AppColor.shadowMedium,
      blurRadius: AppRadius.r16,
      offset: const Offset(0, AppSpacing.xs),
    ),
  ];

  /// The bottom of a details page, thrown upward onto the image above it.
  static final List<BoxShadow> lifted = [
    BoxShadow(
      color: AppColor.shadowSoft,
      blurRadius: AppSizes.px16,
      offset: const Offset(0, -AppSizes.px4),
    ),
  ];

  /// The wash a focused field fills itself with, so the accent stays readable
  /// behind the text.
  static const double focusTint = 0.035;

  /// The glow around a focused text field, tinted with the field's own accent.
  static List<BoxShadow> focused(Color accent) => [
    BoxShadow(
      color: accent.withValues(alpha: 0.07),
      blurRadius: AppRadius.r12,
      offset: const Offset(0, AppSizes.px3),
    ),
  ];
}

/// Window widths where a layout changes shape, at the Material 3 size-class
/// borders: compact is a phone, medium a folded phone opened or a portrait
/// tablet, expanded a landscape tablet, large a desktop window.
///
/// Screens read these through `context.windowSize` and never spell a number.
abstract final class AppBreakpoints {
  const AppBreakpoints._();

  /// Below this: one column, everything full-bleed.
  static const double medium = 600.0;

  /// From here: multi-column grids and a side rail instead of a drawer.
  static const double expanded = 840.0;

  /// From here the page content is centred instead of filling the window.
  static const double large = 1200.0;

  /// The widest a page's content gets before it is centred.
  static const double contentMaxWidth = 1024.0;

  /// The widest a running-text column should ever stretch.
  static const double readingColumnMaxWidth = 720.0;

  /// The narrowest tile a self-counting grid accepts before it drops a column.
  static const double gridTileMinWidth = 160.0;

  /// The most columns a grid may draw; past this the tile grows with the
  /// screen instead of shrinking further.
  static const int gridMaxColumns = 5;

  /// The narrowest product card the responsive grid accepts.
  static const double productCardMinWidth = 150.0;

  /// The most product cards in one row.
  static const int productCardMaxColumns = 4;

  /// The widest a product card gets: past it the row takes another card
  /// instead of stretching the one it has.
  static const double productCardMaxWidth = 240.0;

  /// The widest a category tile gets in the home grid before it stops growing.
  static const double categoryTileMaxWidth = 96.0;
}

/// The padding every scrolling page shares with the skeleton that mirrors it.
abstract final class AppLayout {
  const AppLayout._();

  /// `lg` on the sides and at the bottom, `md` under the app bar.
  static const EdgeInsets pageBody = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.md,
    AppSpacing.lg,
    AppSpacing.lg,
  );
}
