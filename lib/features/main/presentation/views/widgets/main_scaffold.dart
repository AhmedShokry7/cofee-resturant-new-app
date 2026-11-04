import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/location/data/services/location_permission_service.dart';
import 'package:new_coffee/features/main/presentation/manager/main/main_cubit.dart';
import 'package:new_coffee/features/main/presentation/views/widgets/main_bottom_bar.dart';
import 'package:new_coffee/features/main/presentation/views/widgets/main_tabs.dart';
import 'package:new_coffee/features/notifications/data/services/push_service.dart';

/// The five tabs and the bar between them.
///
/// The shell also owns the two things that can only happen once the app is
/// really on screen: the screen a tapped notification asked for, and the
/// first-launch location prompt.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  @override
  void initState() {
    super.initState();
    // The first frame of the shell is the moment the app is really usable, so
    // it is the one place that asks the customer for something on their behalf.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // A push that opened the app waits here, because there was no navigator
      // to show its screen when the tap arrived. The main page is the last stop
      // of the splash, so this is the first moment the screen can be shown.
      final route = PushService.takePendingRoute();
      if (route != null) {
        Navigator.of(context).pushNamed(route.route, arguments: route.entityId);
      }

      // The location prompt is fired, never awaited: it is a system dialog, and
      // waiting for it before the screen appeared is what froze the app on a
      // device whose dialog never came back. It marks itself as prompted, so it
      // asks at most once per install.
      unawaited(LocationPermissionService.requestOnFirstLaunch());
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = buildMainTabs();
    return BlocBuilder<MainCubit, MainState>(
      builder: (context, state) {
        return Scaffold(
          // A tab is built only after the customer opens it, and stays built
          // afterwards, so switching away never loses its state.
          body: IndexedStack(
            index: state.index,
            children: [
              for (var i = 0; i < tabs.length; i++)
                state.isBuilt(i) ? tabs[i].page : const SizedBox.shrink(),
            ],
          ),
          bottomNavigationBar: MainBottomBar(
            tabs: tabs,
            currentIndex: state.index,
            onTap: (index) => context.read<MainCubit>().changeTab(index),
          ),
        );
      },
    );
  }
}
