import 'package:flutter/material.dart';
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
    final highlight =
        (node?.localizedText('highlight') ?? S.yourCoffee).trim();
    final rest = (node?.localizedText('rest') ?? S.yourMoment).trim();
    if (highlight.isEmpty && rest.isEmpty) return const SizedBox.shrink();
    final size = node?.numberProperty('size');
    return Text.rich(
      textAlign: TextAlign.center,
      TextSpan(
        children: [
          if (highlight.isNotEmpty)
            TextSpan(
              text: highlight,
              style: AppFonts.bold24(context).copyWith(
                color: AppColor.primaryColor,
                fontSize: size,
              ),
            ),
          if (highlight.isNotEmpty && rest.isNotEmpty) const TextSpan(text: " "),
          if (rest.isNotEmpty)
            TextSpan(
              text: rest,
              style: AppFonts.semiBold24(context).copyWith(fontSize: size),
            ),
        ],
      ),
    );
  }
}
