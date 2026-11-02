import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';

/// The boxes a sign-in code is typed into, and the code they hold.
///
/// A code arrives one digit at a time, or as one whole string pasted into
/// whichever box has focus. Both shapes have to land, so the typing rule lives
/// with the boxes instead of with the door that rings them.
///
/// The screen owns this object, because it is what the Verify button reads when
/// it submits and what Resend empties before asking for a new code.
class OtpCodeController {
  OtpCodeController({this.length = _defaultLength});

  static const int _defaultLength = 6;

  final int length;

  late final List<TextEditingController> cells = List.generate(
    length,
    (_) => TextEditingController(),
  );

  late final List<FocusNode> focusNodes = List.generate(
    length,
    (_) => FocusNode(),
  );

  /// The digits typed so far, in box order.
  String get code => cells.map((cell) => cell.text).join();

  bool get isComplete => cells.every((cell) => cell.text.isNotEmpty);

  /// Puts a whole code into the boxes — the shape a pasted code or an autofill
  /// suggestion arrives in.
  void fill(String value, {int from = 0}) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < digits.length && from + i < length; i++) {
      cells[from + i].text = digits[i];
    }
  }

  void clear() {
    for (final cell in cells) {
      cell.clear();
    }
  }

  void dispose() {
    for (final cell in cells) {
      cell.dispose();
    }
    for (final node in focusNodes) {
      node.dispose();
    }
  }
}

/// The six boxes themselves.
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({super.key, required this.controller, this.onSubmitted});

  final OtpCodeController controller;

  /// Called when the last box is submitted, with the whole code.
  final ValueChanged<String>? onSubmitted;

  static const double _cellRadius = AppRadius.r12;

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  void _onChanged(String value, int index) {
    final nodes = widget.controller.focusNodes;
    final length = widget.controller.length;
    if (value.length > 1) {
      // A paste, or the SMS suggestion, arrives in whichever box is focused as
      // one string. Clipping every box to a single character threw five of the
      // six digits away before the customer could see them, so the code that
      // was typed correctly still verified as wrong.
      final digits = value.replaceAll(RegExp(r'\D'), '');
      // A whole code pasted into the third box still has to land, so a paste
      // that is long enough to be the entire code starts from the first box.
      final start = digits.length >= length ? 0 : index;
      widget.controller.fill(digits, from: start);
      nodes[(start + digits.length - 1).clamp(0, length - 1)].requestFocus();
      setState(() {});
      return;
    }
    if (value.isNotEmpty && index < length - 1) {
      nodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      nodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        controller.length,
        (index) => SizedBox(
          width: AppSizes.px46,
          child: TextFormField(
            controller: controller.cells[index],
            focusNode: controller.focusNodes[index],
            autofocus: index == 0,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            // Only the first box is offered to the keyboard's code suggestion;
            // `_onChanged` spreads whatever it hands over into the boxes after
            // it.
            autofillHints: index == 0
                ? const [AutofillHints.oneTimeCode]
                : null,
            textInputAction: index == controller.length - 1
                ? TextInputAction.done
                : TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) => _onChanged(value, index),
            onFieldSubmitted: (_) {
              if (index == controller.length - 1) {
                widget.onSubmitted?.call(controller.code);
              }
            },
            style: AppFonts.semiBold18(context),
            cursorColor: AppColor.primaryColor,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              filled: true,
              fillColor: AppColor.lightGreyColor,
              border: _border(),
              enabledBorder: _border(),
              focusedBorder: _border(color: AppColor.primaryColor),
            ),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border({Color? color}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(OtpCodeInput._cellRadius),
      borderSide: BorderSide(color: color ?? AppColor.transparent),
    );
  }
}
