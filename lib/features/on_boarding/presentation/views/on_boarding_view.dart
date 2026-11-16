import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_state.dart';
import 'package:new_coffee/features/on_boarding/data/on_boarding_document.dart';
import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_view_body.dart';

/// The intro slides a first-time customer is walked through.
///
/// It owns the cubit and the one reaction the cubit asks for: handing the
/// customer to the screen the cubit named.
///
/// شرائح الشاشة ووقت انتقالها يقرؤهما المستند المنشور عند فتح الشاشة:
/// شرائح `onboarding.slide` بعقدها، وعقدة `onboarding.transition` بوقت
/// الحركة والتقديم التلقائي. ما لم ينشره الموظف يعني شرائح اليوم وحركتها.
class OnBoardingView extends StatelessWidget {
  const OnBoardingView({super.key});

  static const routeName = "onBoardingView";

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final sections =
            context.read<DesignCubit>().state.pageSections('onboarding');
        final transition = onboardingTransitionFrom(sections);
        return OnBoardingCubit(
          slides: onboardingSlidesFrom(sections),
          slideDuration: transition.slideDuration,
          autoAdvance: transition.autoAdvance,
        );
      },
      child: BlocListener<DesignCubit, DesignState>(
        // مستند جديد أثناء عرض الشاشة (المعاينة تدفعه مع كل تعديل): تُعاد
        // قراءة الشرائح ووقت الانتقال وتُسلَّم للمكوّب حيًّا، فلا ينتظر
        // الموظف إعادة فتح الصفحة ليرى تعديله.
        listenWhen: (previous, current) => previous.design != current.design,
        listener: (context, designState) {
          final sections = designState.pageSections('onboarding');
          final transition = onboardingTransitionFrom(sections);
          context.read<OnBoardingCubit>().updateDesign(
            slides: onboardingSlidesFrom(sections),
            slideDuration: transition.slideDuration,
            autoAdvance: transition.autoAdvance,
          );
        },
        child: BlocListener<OnBoardingCubit, OnBoardingState>(
          listener: (context, state) {
            if (state is OnBoardingCompleted) {
              Navigator.of(context).pushReplacementNamed(state.nextRoute);
            }
          },
          child: const Scaffold(body: OnBoardingViewBody()),
        ),
      ),
    );
  }
}
