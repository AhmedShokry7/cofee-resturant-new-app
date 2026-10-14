import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';

class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.lg.w,
        SpacingTokens.lg.h,
        SpacingTokens.lg.w,
        SpacingTokens.md.h,
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: AppFonts.semiBold20(context),
      ),
    );
  }
}
