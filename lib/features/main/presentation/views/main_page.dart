import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/main/presentation/manager/main/main_cubit.dart';
import 'package:new_coffee/features/main/presentation/views/widgets/main_scaffold.dart';

/// The screen the customer lands on: one tab of the app at a time, with the
/// bar that moves between them.
class MainPage extends StatelessWidget {
  const MainPage({super.key});

  static const routeName = "mainRoute";

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MainCubit(),
      child: const MainScaffold(),
    );
  }
}
