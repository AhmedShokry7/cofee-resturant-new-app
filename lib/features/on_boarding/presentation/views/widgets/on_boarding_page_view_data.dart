import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_slide.dart';

/// The swipeable set of intro slides, driven by the cubit's controller.
///
/// الشرائح يملكها المستند المنشور، والمكوّب يقرأها عند فتح الشاشة —
/// هنا لا يعاد قراءتها، فالشريحة تُرسم كما قرأها المكوّب.
class OnBoardingPageViewData extends StatelessWidget {
  const OnBoardingPageViewData({super.key});

  @override
  Widget build(BuildContext context) {
    // watch لا read: شرائح المستند تُحدَّث حيًّا من المعاينة، وعادة البناء
    // هي ما يعيد رسم الشرائح الجديدة على الشاشة المعروضة.
    final cubit = context.watch<OnBoardingCubit>();
    final slides = cubit.slides;

    return PageView.builder(
      controller: cubit.pageController,
      itemCount: slides.length,
      onPageChanged: cubit.changePage,
      itemBuilder: (context, index) => OnBoardingSlide(slide: slides[index]),
    );
  }
}
