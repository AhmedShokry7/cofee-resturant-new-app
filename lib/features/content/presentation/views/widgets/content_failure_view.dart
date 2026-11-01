import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';

/// The one failure state a content screen shows when the CMS could not be read.
///
/// Both screens drew this themselves, so a fix to one left the other with a
/// different answer to the same problem.
class ContentFailureView extends StatelessWidget {
  const ContentFailureView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          SizedBox(height: SpacingTokens.md.h),
          TextButton(onPressed: onRetry, child: Text(S.retry)),
        ],
      ),
    );
  }
}
