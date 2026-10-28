import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:admin_app/core/locale/app_strings.dart';

/// The Excel workbook mark, used wherever a page reads or writes a workbook.
///
/// Renders `assets/icons/excel.svg`. The glyph carries its own brand greens,
/// so it is never recolored and never dimmed by a theme. [size] is the icon
/// box edge and [BoxFit.contain] keeps the 486:500 ratio in every place:
/// 18 beside a header or dialog label, 16 inside a directory toolbar.
class ExcelIcon extends StatelessWidget {
  const ExcelIcon({super.key, this.size = 16});

  /// Icon box edge in design pixels; the glyph scales to fit inside it.
  final double size;

  static const String asset = 'assets/icons/excel.svg';

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    asset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticsLabel: S.excelFile,
  );
}
