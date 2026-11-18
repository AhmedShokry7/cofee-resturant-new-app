import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/design/data/model/native_section.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/welcome/presentation/manager/welcome/welcome_cubit.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_view_text_body.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_view_text_title.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// What the customer reads and presses inside the wavy panel.
///
/// The tap only asks the cubit to begin; the decision about what has to be
/// written first, and where the app goes after that, is not taken here.
class WelcomePanelContent extends StatelessWidget {
  const WelcomePanelContent({super.key});

  @override
  Widget build(BuildContext context) {
    // The panel is bounded by a Positioned with `bottom: 0`, so the button is
    // placed first and the copy takes what is left. A language whose lines need
    // more room than that scrolls its own copy; the way forward never depends
    // on how much room a translation happens to need.
    return Column(
      children: [
        const Expanded(child: _WelcomeCopy()),
        const _WelcomeCta(),
        SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

/// زر «لنبدأ»، نصّه منشور أيضًا.
///
/// عقدة `welcome.cta` تحمل النصّ باللغتين (`label_ar` / `label_en`) وتُخفى
/// بـ `visible: false`. غياب العقدة أو النصّ يعني نصّ التطبيق كما كان، فلا
/// يتغيّر شيء لمن لم ينشر تصميمًا.
class _WelcomeCta extends StatelessWidget {
  const _WelcomeCta();

  @override
  Widget build(BuildContext context) {
    final node = context.select(
      (DesignCubit cubit) => nativeSection(
        cubit.state.pageSections('welcome'),
        DesignWidgetTypes.welcomeCta,
      ),
    );
    if (nativeHidden(node)) return const SizedBox.shrink();
    final published = node?.localizedText('label')?.trim() ?? '';
    final label = published.isEmpty ? S.letsGetStarted : published;

    return BlocBuilder<WelcomeCubit, WelcomeState>(
      builder: (context, state) {
        return SizedBox(
          width: double.infinity,
          child: CustomBtn(
            text: label,
            isLoading: state.isStarting,
            onPressed: () => context.read<WelcomeCubit>().startOnboarding(),
          ),
        );
      },
    );
  }
}

/// The headline and its description, bottom-aligned in whatever height the
/// panel leaves them, scrollable when that height is not enough.
class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // المسافة بين العنوان ووصفه منشورة أيضًا: عقدة `welcome.spacing`
        // بـ `gap` تعلو على المسافة المرسومة، وغيابها يعني الأصل.
        final gap = context.select(
          (DesignCubit cubit) => nativeSection(
            cubit.state.pageSections('welcome'),
            DesignWidgetTypes.welcomeSpacing,
          )?.numberProperty('gap'),
        );
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const WelcomeViewTextTitle(),
                SizedBox(height: gap ?? AppSpacing.md),
                const WelcomeViewTextBody(),
                SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
      },
    );
  }
}
