import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';

/// The Saudi Riyal symbol, used wherever a price shows its currency.
///
/// Renders `assets/icons/sar_currency.svg`. The glyph is monochrome, so a
/// [colorFilter] recolors the whole symbol for the current theme without
/// touching anything else. [BoxFit.contain] keeps its 16:18 aspect ratio.
class CurrencyIcon extends StatelessWidget {
  const CurrencyIcon({super.key, this.size = 16, this.color});

  /// Icon box edge in design pixels; the glyph scales to fit inside it.
  final double size;

  /// Tint for the symbol. Defaults to the muted grey of the record cards.
  final Color? color;

  static const String asset = 'assets/icons/sar_currency.svg';

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? AppColor.greyColor;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(resolved, BlendMode.srcIn),
      semanticsLabel: S.currency,
    );
  }
}
