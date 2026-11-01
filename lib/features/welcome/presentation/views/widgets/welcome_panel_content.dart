import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/welcome/presentation/manager/welcome/welcome_cubit.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_view_text_body.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_view_text_title.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// What the customer reads and presses inside the wavy panel.
///
/// The tap only asks the cubit to begin; the decision about what has to be
/// written first, and where the app goes after that, is not taken here.
class WelcomePanelContent extends StatelessWidget {
  const WelcomePanelContent({super.key});

  @override
  Widget build(BuildContext context) {
    // The panel is bounded by a Positioned with `bottom: 0`, so the button is
    // placed first and the copy takes what is left. A language whose lines need
    // more room than that scrolls its own copy; the way forward never depends
    // on how much room a translation happens to need.
    return BlocBuilder<WelcomeCubit, WelcomeState>(
      builder: (context, state) {
        return Column(
          children: [
            const Expanded(child: _WelcomeCopy()),
            SizedBox(
              width: double.infinity,
              child: CustomBtn(
                text: S.letsGetStarted,
                isLoading: state.isStarting,
                onPressed: () => context.read<WelcomeCubit>().startOnboarding(),
              ),
            ),
            SizedBox(height: AppSpacing.sm),
          ],
        );
      },
    );
  }
}

/// The headline and its description, bottom-aligned in whatever height the
/// panel leaves them, scrollable when that height is not enough.
class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const WelcomeViewTextTitle(),
                SizedBox(height: AppSpacing.md),
                const WelcomeViewTextBody(),
                SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
      },
    );
  }
}
