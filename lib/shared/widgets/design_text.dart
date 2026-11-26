import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/preview/preview_section.dart';
import 'package:new_coffee/features/design/data/model/native_section.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';

/// A label owned by a native screen keeps its normal placement and actions.
class DesignText extends StatelessWidget {
  const DesignText(
    this.fallback, {
    super.key,
    required this.page,
    required this.label,
    this.style,
    this.textAlign,
  });

  final String fallback;
  final String page;
  final String label;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final id = '${page}_label_$label';
    final node = context.select(
      (DesignCubit? cubit) => cubit?.state
          .pageSections(page)
          .where((s) => s.id == id && s.type == 'native.label')
          .firstOrNull,
    );
    if (node == null) return Text(fallback, style: style, textAlign: textAlign);
    if (!node.visible) return const SizedBox.shrink();
    final size = node.numberProperty('fontSize');
    final color = node.property('textColor');
    final inherited = style ?? DefaultTextStyle.of(context).style;
    final alignment = switch (node.property('textAlignment')) {
      'start' => TextAlign.start,
      'center' => TextAlign.center,
      'end' => TextAlign.end,
      'justify' => TextAlign.justify,
      _ => textAlign,
    };
    final weight = switch (node.property('fontWeight')) {
      'normal' => FontWeight.normal,
      'medium' => FontWeight.w500,
      'bold' => FontWeight.bold,
      _ => inherited.fontWeight,
    };
    final lineHeight = node.numberProperty('lineHeight');
    return previewSectionWrap(
      node,
      pageId: page,
      child: Text(
        node.localizedText('text') ?? fallback,
        textAlign: alignment,
        style: inherited.copyWith(
          fontWeight: weight,
          height: lineHeight?.clamp(1, 3).toDouble(),
          fontSize: size?.clamp(8, 72).toDouble(),
          color: color == null
              ? null
              : SplashSettings.colorFromHex(
                  color,
                  fallback:
                      inherited.color ??
                      Theme.of(context).colorScheme.onSurface,
                ),
        ),
      ),
    );
  }
}
