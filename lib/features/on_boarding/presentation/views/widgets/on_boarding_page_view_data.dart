import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/on_boarding/data/on_boarding_list.dart';
import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_slide.dart';

/// The swipeable set of intro slides, driven by the cubit's controller.
class OnBoardingPageViewData extends StatelessWidget {
  const OnBoardingPageViewData({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnBoardingCubit>();
    final slides = onBoardingSlides();

    return PageView.builder(
      controller: cubit.pageController,
      onPageChanged: cubit.changePage,
      itemCount: slides.length,
      itemBuilder: (context, index) => OnBoardingSlide(slide: slides[index]),
    );
  }
}
