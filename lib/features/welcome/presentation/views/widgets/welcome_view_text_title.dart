import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/design/data/model/native_section.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';

/// The headline, split into the brand-colored half and the plain half.
///
/// نص العنوان منشور أيضًا: عقدة `welcome.title` بنصّين — الجزء الملوّن
/// (`highlight`) والباقي (`rest`) — تعلو على نصّ التطبيق، و`size` يعدّل
/// القياس، وعقدة مخفية تُسقط العنوان. غياب العقدة يعني نصّ التطبيق.
class WelcomeViewTextTitle extends StatelessWidget {
  const WelcomeViewTextTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final node = context.select(
      (DesignCubit cubit) => nativeSection(
        cubit.state.pageSections('welcome'),
        DesignWidgetTypes.welcomeTitle,
      ),
    );
    if (nativeHidden(node)) return const SizedBox.shrink();
    final highlight = (node?.localizedText('highlight') ?? S.yourCoffee).trim();
    final rest = (node?.localizedText('rest') ?? S.yourMoment).trim();
    if (highlight.isEmpty && rest.isEmpty) return const SizedBox.shrink();
    final size = node?.numberProperty('size');
    final alignment = switch (node?.property('alignment')) {
      'start' => TextAlign.start,
      'end' => TextAlign.end,
      _ => TextAlign.center,
    };
    final weight = node?.property('textWeight') ?? 'brand';
    FontWeight weightFor(String part) => switch (weight) {
      'light' => AppFontWeights.regular,
      'regular' => AppFontWeights.regular,
      'medium' => AppFontWeights.medium,
      'semibold' => AppFontWeights.semiBold,
      'bold' => AppFontWeights.bold,
      _ => part == 'highlight' ? AppFontWeights.bold : AppFontWeights.semiBold,
    };
    Color colorFor(String? value, Color fallback) {
      if (value == null ||
          !RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(value)) {
        return fallback;
      }
      final parsed = int.parse(value.substring(1), radix: 16);
      return value.length == 9 ? Color(parsed) : Color(0xFF000000 | parsed);
    }

    return Text.rich(
      textAlign: alignment,
      TextSpan(
        children: [
          if (highlight.isNotEmpty)
            TextSpan(
              text: highlight,
              style: AppFonts.bold24(context).copyWith(
                fontSize: size,
                color: colorFor(
                  node?.property('highlightColor'),
                  AppColor.primaryColor,
                ),
                fontWeight: weightFor('highlight'),
              ),
            ),
          if (highlight.isNotEmpty && rest.isNotEmpty)
            const TextSpan(text: " "),
          if (rest.isNotEmpty)
            TextSpan(
              text: rest,
              style: AppFonts.semiBold24(context).copyWith(
                fontSize: size,
                color: colorFor(
                  node?.property('restColor'),
                  AppColor.textPrimary,
                ),
                fontWeight: weightFor('rest'),
              ),
            ),
        ],
      ),
    );
  }
}
