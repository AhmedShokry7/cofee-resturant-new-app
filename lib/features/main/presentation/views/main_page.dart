import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/main/presentation/manager/main/main_cubit.dart';
import 'package:new_coffee/features/main/presentation/views/widgets/main_scaffold.dart';

/// The screen the customer lands on: one tab of the app at a time, with the
/// bar that moves between them.
class MainPage extends StatelessWidget {
  const MainPage({super.key, this.initialTab});

  /// Optional shell tab selected by a notification destination.
  final int? initialTab;

  static const routeName = "mainRoute";

  static int? notificationTabIndex(Object? value) => switch (value) {
    'home' => 0,
    'categories' => 1,
    'cart' => 2,
    'favorites' => 3,
    'settings' => 4,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MainCubit(initialTab: initialTab),
      child: const MainScaffold(),
    );
  }
}
