import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/design/data/model/native_section.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';

/// The line under the headline, written by the copy in [S].
///
/// نصّ الوصف منشور أيضًا: عقدة `welcome.body` بنصّ (`text`) وقياس
/// (`size`) تعلو على نصّ التطبيق، وعقدة مخفية تُسقطه. غياب العقدة يعني
/// نصّ التطبيق كما هو.
class WelcomeViewTextBody extends StatelessWidget {
  const WelcomeViewTextBody({super.key});

  @override
  Widget build(BuildContext context) {
    final node = context.select(
      (DesignCubit cubit) => nativeSection(
        cubit.state.pageSections('welcome'),
        DesignWidgetTypes.welcomeBody,
      ),
    );
    if (nativeHidden(node)) return const SizedBox.shrink();
    final text = (node?.localizedText('text') ?? S.welcomeDescription).trim();
    if (text.isEmpty) return const SizedBox.shrink();
    final alignment = switch (node?.property('alignment')) {
      'start' => TextAlign.start,
      'end' => TextAlign.end,
      _ => TextAlign.center,
    };
    final colorValue = node?.property('color');
    Color color = AppColor.greyColor;
    if (colorValue != null &&
        RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$')
            .hasMatch(colorValue)) {
      final parsed = int.parse(colorValue.substring(1), radix: 16);
      color = colorValue.length == 9
          ? Color(parsed)
          : Color(0xFF000000 | parsed);
    }
    return Text(
      textAlign: alignment,
      text,
      style: AppFonts.regular16(context).copyWith(
        color: color,
        fontSize: node?.numberProperty('size'),
        height: node?.numberProperty('lineHeight'),
      ),
    );
  }
}
