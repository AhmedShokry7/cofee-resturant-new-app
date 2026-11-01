import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_circle_button.dart';
import 'package:new_coffee/shared/utils/direction_aware_icons.dart';

/// Steps to the next slide, and leaves the onboarding on the last one.
class OnBoardingNextBtn extends StatelessWidget {
  const OnBoardingNextBtn({super.key});

  @override
  Widget build(BuildContext context) {
    return OnBoardingCircleButton(
      icon: DirectionAwareIcons.forward(context),
      filled: true,
      onTap: () => context.read<OnBoardingCubit>().next(),
    );
  }
}
