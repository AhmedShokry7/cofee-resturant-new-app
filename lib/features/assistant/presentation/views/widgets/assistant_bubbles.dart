import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/assistant/data/model/chat_message.dart';

/// One line of the chat.
///
/// The customer's line sits on the trailing edge in the brand colour and the
/// assistant's on the leading edge on white, so which side said what is read
/// from the shape of the bubble before the words are.
class AssistantMessageBubble extends StatelessWidget {
  const AssistantMessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    return _AssistantBubbleShell(
      isUser: isUser,
      child: Text(
        message.text,
        style: isUser
            ? AppFonts.regular14(context).copyWith(color: AppColor.whiteColor)
            : AppFonts.regular14(context),
      ),
    );
  }
}

/// The waiting line: the language model is still thinking, and the customer is
/// shown that something is coming instead of that nothing happened.
class AssistantTypingBubble extends StatelessWidget {
  const AssistantTypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AssistantBubbleShell(
      isUser: false,
      child: Text('…', style: TextStyle(height: 1.4)),
    );
  }
}

/// The two bubbles above, which differ only in colour and side.
class _AssistantBubbleShell extends StatelessWidget {
  const _AssistantBubbleShell({required this.isUser, required this.child});

  final bool isUser;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: AppDimensions.assistantPanelMaxWidth,
        ),
        margin: EdgeInsets.only(bottom: AppSpacing.xs),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColor.primaryColor : AppColor.cardSurface,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: isUser ? null : Border.all(color: AppColor.borderColor),
        ),
        child: child,
      ),
    );
  }
}
