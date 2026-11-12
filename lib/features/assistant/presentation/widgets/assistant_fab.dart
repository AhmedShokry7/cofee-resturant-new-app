import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant_fab/assistant_fab_cubit.dart';
import 'package:new_coffee/features/assistant/presentation/views/assistant_page.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/shared/utils/optional_provider.dart';

/// Smart assistant entry point, owned by the Home page.
///
/// Rendered in [HomePage]'s [Scaffold.floatingActionButton] slot, so the
/// button exists exactly once and only while the Home tab is visible. Route
/// filtering is unnecessary: pushed pages, auth flows and the other tabs
/// never contain this widget.
///
/// The button carries no speech bubble: it never interrupts the customer with a
/// hint or a suggestion. It only opens the chat, and [AssistantFabCubit] holds
/// the two facts the chat's first line is built from.
class AssistantFab extends StatelessWidget {
  const AssistantFab({super.key});

  /// The FAB lives on Home, where the auth layer is registered, but the widget
  /// is also pumped in isolation by tests and by any future host that has no
  /// signed-in customer yet.
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          AssistantFabCubit(auth: context.maybeRead<AuthRepository>())..start(),
      child: const _AssistantFabView(),
    );
  }
}

class _AssistantFabView extends StatelessWidget {
  const _AssistantFabView();

  /// Bot artwork size inside the standard 56dp FAB.
  static const double _fabIconSize = 44;

  /// The chat opens as a page, so it has room for the conversation the customer
  /// is in and the ones they already had. The entry point hides by itself: a
  /// pushed page covers Home, and its button with it.
  void _open(BuildContext context, AssistantFabCubit cubit) {
    Navigator.of(context).pushNamed(
      AssistantPage.routeName,
      arguments: AssistantPageArgs(
        isReturning: cubit.state.isReturningUser,
        firstName: cubit.state.firstName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // No BlocBuilder: nothing about the button changes with who is holding the
    // phone, and the two facts it passes are read at the moment of the tap.
    return FloatingActionButton(
      onPressed: () => _open(context, context.read<AssistantFabCubit>()),
      backgroundColor: AppColor.cardSurface,
      elevation: AppElevation.floating,
      shape: const CircleBorder(),
      child: Image.asset(
        AppImages.aiBot,
        key: const ValueKey('assistant_fab_image'),
        width: _fabIconSize,
        height: _fabIconSize,
      ),
    );
  }
}
