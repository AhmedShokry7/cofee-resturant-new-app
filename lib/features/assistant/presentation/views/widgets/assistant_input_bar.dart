import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';

/// The question box and the button that sends it.
///
/// It owns its text: the field is cleared the moment the question goes out, so
/// what is on screen is only what the assistant has been asked.
class AssistantInputBar extends StatefulWidget {
  const AssistantInputBar({super.key, required this.onSend});

  final ValueChanged<String> onSend;

  @override
  State<AssistantInputBar> createState() => _AssistantInputBarState();
}

class _AssistantInputBarState extends State<AssistantInputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            onSubmitted: (_) => _send(),
            style: AppFonts.regular14(context),
            decoration: InputDecoration(
              hintText: S.askAnything,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              filled: true,
              fillColor: AppColor.lightGreyColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: _send,
          child: Container(
            height: AppSpacing.xxxl,
            width: AppSpacing.xxxl,
            decoration: BoxDecoration(
              color: AppColor.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.sent,
              size: AppSizes.px22,
              color: AppColor.whiteColor,
            ),
          ),
        ),
      ],
    );
  }
}
