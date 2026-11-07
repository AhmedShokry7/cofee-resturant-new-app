import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/assistant/data/assistant_server_memory.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant_memory/assistant_memory_cubit.dart';
import 'package:new_coffee/features/assistant/presentation/views/widgets/assistant_memory_row.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';

/// What the assistant has been allowed to keep about this customer.
///
/// The screen exists because the requirement is not "the app has a memory
/// table" but "the customer can see it and take it back". A signed-out device
/// has no memory island to show, so the page says so instead of pretending the
/// list is merely empty.
class AssistantMemoryPage extends StatelessWidget {
  const AssistantMemoryPage({super.key});

  static const routeName = "assistantMemoryRoute";

  @override
  Widget build(BuildContext context) {
    final signedIn = SupabaseService.isReady && SupabaseService.isSignedIn;
    return BlocProvider(
      create: (_) => AssistantMemoryCubit(
        store: signedIn
            ? ServerAssistantMemoryStore(SupabaseService.client)
            : const NoAssistantMemoryStore(),
        signedIn: signedIn,
      )..load(),
      child: const _AssistantMemoryView(),
    );
  }
}

class _AssistantMemoryView extends StatelessWidget {
  const _AssistantMemoryView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.assistantMemoryTitle)),
      body: BlocBuilder<AssistantMemoryCubit, AssistantMemoryViewState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!state.signedIn) {
            return EmptyState(
              icon: AppIcons.user,
              title: S.assistantMemoryTitle,
              subtitle: S.assistantMemorySignedOut,
            );
          }
          final cubit = context.read<AssistantMemoryCubit>();
          return ListView(
            padding: EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                S.assistantMemorySubtitle,
                style: AppFonts.regular14(context),
              ),
              SizedBox(height: AppSpacing.md),
              SwitchListTile.adaptive(
                value: state.consent.memoryEnabled,
                onChanged: cubit.setMemoryEnabled,
                title: Text(
                  S.assistantMemoryEnable,
                  style: AppFonts.regular14(context),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              SizedBox(height: AppSpacing.md),
              // Reading the web is a second, separate permission: the switch
              // above is about the past, this one is about leaving the shop.
              SwitchListTile.adaptive(
                value: state.consent.webSearchEnabled,
                onChanged: cubit.setWebSearchEnabled,
                title: Text(
                  S.assistantWebSearchEnable,
                  style: AppFonts.regular14(context),
                ),
                subtitle: Text(
                  S.assistantWebSearchNote,
                  style: AppFonts.regular12(context)
                      .copyWith(color: AppColor.greyColor),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              SizedBox(height: AppSpacing.md),
              if (state.memories.isEmpty)
                Text(
                  state.erased
                      ? S.assistantMemoryDeletedAll
                      : S.assistantMemoryEmpty,
                  style: AppFonts.regular14(context),
                )
              else
                for (final item in state.memories)
                  AssistantMemoryRow(
                    item: item,
                    onDelete: () => cubit.forget(item),
                  ),
              SizedBox(height: AppSpacing.lg),
              if (state.memories.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _confirmErase(context, cubit),
                  icon: const Icon(AppIcons.delete),
                  label: Text(S.assistantMemoryDeleteAll),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColor.errorColor,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Deleting everything is the one action here no button can undo, so it is
  /// asked for twice.
  Future<void> _confirmErase(
    BuildContext context,
    AssistantMemoryCubit cubit,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.assistantMemoryDeleteAll),
        content: Text(S.assistantMemoryOffWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await cubit.eraseAll();
    messenger.showSnackBar(
      SnackBar(content: Text(S.assistantMemoryDeletedAll)),
    );
  }
}
