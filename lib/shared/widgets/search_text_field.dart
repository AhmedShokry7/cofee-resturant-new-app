import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/shared/widgets/search_pill.dart';

/// Search input styled with [SearchPill], so the search page and the Home bar
/// cannot drift apart.
class SearchTextField extends StatelessWidget {
  const SearchTextField({
    super.key,
    required this.onChanged,
    this.controller,
    this.hint,
    this.textInputAction = TextInputAction.search,
  });

  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final String? hint;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(SearchPill.radius()),
      borderSide: BorderSide.none,
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: textInputAction,
      style: AppFonts.regular16(context),
      cursorColor: AppColor.primaryColor,
      decoration: InputDecoration(
        hintText: hint ?? S.searchHint,
        hintStyle: AppFonts.regular14(context)
            .copyWith(color: AppColor.greyColor),
        prefixIcon: SearchPill.icon(),
        filled: true,
        fillColor: AppColor.lightGreyColor,
        contentPadding: SearchPill.padding(),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
      ),
    );
  }
}
