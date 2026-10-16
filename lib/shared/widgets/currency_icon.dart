import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Standard Saudi Riyal symbol used everywhere a currency icon is shown.
///
/// Renders `assets/icons/sar_currency.svg` (the official SAR glyph). The SVG
/// carries a single `#242424` fill on every path and no background, so a
/// monochrome [colorFilter] recolors the whole symbol without touching
/// anything else. [BoxFit.contain] preserves its 16:18 aspect ratio.
class CurrencyIcon extends StatelessWidget {
  const CurrencyIcon({super.key, this.size = 16, this.color});

  /// Icon box edge in design pixels; the glyph scales to fit inside it.
  final double size;

  /// Tint for the symbol. Defaults to the theme's surface text color so the
  /// icon stays legible in both light and dark modes.
  final Color? color;

  static const String asset = 'assets/icons/sar_currency.svg';

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : const Color(0xFF242424));
    return SvgPicture.asset(
      asset,
      width: size.w,
      height: size.w,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(resolved, BlendMode.srcIn),
      semanticsLabel: 'Saudi Riyal',
    );
  }
}
