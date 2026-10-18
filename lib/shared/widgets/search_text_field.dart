import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';

/// Search input styled to match [HomeSearchBar] (light-grey pill), shared so
/// the search page does not repeat the field decoration.
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
      borderRadius: BorderRadius.circular(100.r),
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
        hintStyle: AppFonts.regular14(context).copyWith(
          color: AppColor.greyColor,
        ),
        prefixIcon: Icon(
          HugeIcons.strokeRoundedSearch01,
          size: 20.w,
          color: AppColor.greyColor,
        ),
        filled: true,
        fillColor: AppColor.lightGreyColor,
        contentPadding: EdgeInsets.symmetric(
          horizontal: SpacingTokens.lg.w,
          vertical: SpacingTokens.md.h,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
      ),
    );
  }
}