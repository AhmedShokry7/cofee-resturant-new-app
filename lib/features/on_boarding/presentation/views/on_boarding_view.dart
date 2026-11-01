import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_view_body.dart';

/// The three intro slides a first-time customer is walked through.
///
/// It owns the cubit and the one reaction the cubit asks for: handing the
/// customer to the screen the cubit named.
class OnBoardingView extends StatelessWidget {
  const OnBoardingView({super.key});

  static const routeName = "onBoardingView";

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OnBoardingCubit(),
      child: BlocListener<OnBoardingCubit, OnBoardingState>(
        listener: (context, state) {
          if (state is OnBoardingCompleted) {
            Navigator.of(context).pushReplacementNamed(state.nextRoute);
          }
        },
        child: const Scaffold(body: OnBoardingViewBody()),
      ),
    );
  }
}
