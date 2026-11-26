import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:material_ui/material_ui.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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
          SizedBox(height: AppSpacing.md),
          CustomTextButton(onPressed: onRetry, child: Text(S.retry)),
        ],
      ),
    );
  }
}
