import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/motion_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant_fab/assistant_fab_cubit.dart';
import 'package:new_coffee/features/assistant/presentation/widgets/assistant_launcher.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// Smart assistant entry point, owned by the Home page.
///
/// Rendered in [HomePage]'s [Scaffold.floatingActionButton] slot, so the
/// button exists exactly once and only while the Home tab is visible. Route
/// filtering is unnecessary: pushed pages, auth flows and the other tabs
/// never contain this widget.
///
/// Everything that decides *what the bubble says* — the saved session, the
/// signed-in name, the order in progress, the rotation timing — belongs to
/// [AssistantFabCubit]. This widget only renders it.
class AssistantFab extends StatelessWidget {
  const AssistantFab({super.key});

  @visibleForTesting
  static const hintCycle = Duration(minutes: 2);

  @visibleForTesting
  static const hintVisible = Duration(seconds: 6);

  /// The FAB lives on Home, where both repositories are registered, but the
  /// widget is also pumped in isolation by tests and by any future host that
  /// has no auth or order layer yet.
  static T? _readOrNull<T extends Object>(BuildContext context) {
    try {
      return context.read<T>();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AssistantFabCubit(
        hintCycle: hintCycle,
        hintVisible: hintVisible,
        orders: _readOrNull<OrdersRepository>(context),
        auth: _readOrNull<AuthRepository>(context),
      )..start(),
      child: const _AssistantFabView(),
    );
  }
}

class _AssistantFabView extends StatelessWidget {
  const _AssistantFabView();

  /// Bot artwork size inside the standard 56dp FAB.
  static const double _fabIconSize = 44;

  Future<void> _openSheet(BuildContext context, AssistantFabCubit cubit) async {
    cubit.sheetOpened();
    await openAssistantSheet(
      context,
      isReturning: cubit.state.isReturningUser,
      firstName: cubit.state.firstName,
    );
    cubit.sheetClosed();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssistantFabCubit, AssistantFabState>(
      builder: (context, state) {
        final cubit = context.read<AssistantFabCubit>();
        // While the sheet is open the entry point hides; ownership by the Home
        // page scaffold already limits visibility to the Home tab.
        if (state.sheetOpen) return const SizedBox.shrink();
        return Column(
          key: const ValueKey('assistant_fab_pos'),
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              opacity: state.showHint ? 1 : 0,
              duration: MotionTokens.entrance,
              child: state.showHint
                  ? _HintBubble(text: cubit.bubbleText)
                  : const SizedBox.shrink(),
            ),
            FloatingActionButton(
              onPressed: () => _openSheet(context, cubit),
              backgroundColor: AppColor.whiteColor,
              elevation: AppElevation.floating,
              shape: const CircleBorder(),
              child: Image.asset(
                AppImages.aiBot,
                key: const ValueKey('assistant_fab_image'),
                width: _fabIconSize,
                height: _fabIconSize,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HintBubble extends StatelessWidget {
  const _HintBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: AppDimensions.assistantBubbleMaxWidth,
      ),
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: AppColor.borderColor),
        boxShadow: AppShadows.floating,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxs),
            child: Icon(
              AppIcons.sparkles,
              size: AppSizes.px14,
              color: AppColor.primaryColor,
            ),
          ),
          SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              text,
              style: AppFonts.medium14(context).copyWith(
                color: AppColor.blackColor,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
