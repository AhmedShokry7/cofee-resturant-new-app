import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/assistant/data/assistant_conversations.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';

/// The conversations this device already had, newest first.
///
/// Opening one puts its own lines back on screen; the list itself is never read
/// by an answer, so a chat from last week cannot leak into this one unless the
/// customer opens it.
class AssistantHistoryDrawer extends StatelessWidget {
  const AssistantHistoryDrawer({super.key});

  Future<void> _delete(
    BuildContext context,
    AssistantCubit cubit,
    String chatId,
  ) async {
    // Captured before the wait: the drawer can be gone by the time the row is,
    // and a message to a dead screen is a message nobody reads.
    final messenger = ScaffoldMessenger.of(context);
    // The drawer paints over the message bar, so a delete confirmed from inside
    // it would leave "undo" where the customer cannot reach it.
    Navigator.of(context).pop();
    final removed = await cubit.deleteChat(chatId);
    if (removed == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(S.assistantChatDeleted),
        persist: false,
        action: SnackBarAction(
          label: S.undo,
          onPressed: () => cubit.restoreChat(removed),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AssistantCubit>();
    return Drawer(
      child: SafeArea(
        child: BlocBuilder<AssistantCubit, AssistantState>(
          buildWhen: (previous, current) =>
              previous.chats != current.chats ||
              previous.activeChatId != current.activeChatId,
          builder: (context, state) {
            final chats = state.chats;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    S.assistantChatsHeading,
                    style: AppFonts.semiBold16(context),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await cubit.newChat();
                    },
                    icon: const Icon(AppIcons.add),
                    label: Text(S.assistantNewChat),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColor.primaryColor,
                      side: BorderSide(color: AppColor.primaryColor),
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                Expanded(
                  child: chats.isEmpty
                      ? Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Text(
                            S.assistantEmptyHistory,
                            style: AppFonts.regular14(context)
                                .copyWith(color: AppColor.greyColor),
                          ),
                        )
                      : ListView.builder(
                          itemCount: chats.length,
                          itemBuilder: (context, index) {
                            final chat = chats[index];
                            return AssistantChatRow(
                              chat: chat,
                              isActive: chat.id == state.activeChatId,
                              onOpen: () {
                                Navigator.of(context).pop();
                                cubit.openChat(chat.id);
                              },
                              onDelete: () => _delete(context, cubit, chat.id),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One saved conversation, with the two things a customer does with it: read it
/// again, or make it gone.
class AssistantChatRow extends StatelessWidget {
  const AssistantChatRow({
    super.key,
    required this.chat,
    required this.isActive,
    required this.onOpen,
    required this.onDelete,
  });

  final AssistantConversation chat;
  final bool isActive;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onOpen,
      selected: isActive,
      selectedTileColor: AppColor.lightGreyColor,
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      title: Text(
        chat.title,
        style: AppFonts.regular14(context),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        onPressed: onDelete,
        icon: const Icon(AppIcons.delete),
        color: AppColor.greyColor,
        tooltip: S.assistantChatDelete,
      ),
    );
  }
}
