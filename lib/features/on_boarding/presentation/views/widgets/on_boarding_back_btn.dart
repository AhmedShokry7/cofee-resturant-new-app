import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_circle_button.dart';
import 'package:new_coffee/shared/utils/direction_aware_icons.dart';

/// Returns to the previous slide.
class OnBoardingBackBtn extends StatelessWidget {
  const OnBoardingBackBtn({super.key});

  @override
  Widget build(BuildContext context) {
    return OnBoardingCircleButton(
      icon: DirectionAwareIcons.back(context),
      filled: false,
      onTap: () => context.read<OnBoardingCubit>().back(),
    );
  }
}
