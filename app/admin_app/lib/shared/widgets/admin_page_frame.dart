import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';

/// The margins every admin page shares: a responsive gutter, a centred
/// column and the same breathing room as the customers and orders pages.
class AdminPageFrame extends StatelessWidget {
  const AdminPageFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < AppBreakpoints.pageCanvas;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: narrow
            ? AppDimensions.pageFrameGutterNarrow
            : AppDimensions.pageFrameGutterWide,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.pageFrameMaxContentWidth,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              narrow
                  ? AppDimensions.pageFrameInnerHorizontalNarrow
                  : AppDimensions.pageFrameInnerHorizontalWide,
              narrow
                  ? AppDimensions.pageFrameInnerTopNarrow
                  : AppDimensions.pageFrameInnerTopWide,
              narrow
                  ? AppDimensions.pageFrameInnerHorizontalNarrow
                  : AppDimensions.pageFrameInnerHorizontalWide,
              narrow
                  ? AppDimensions.pageFrameInnerBottomNarrow
                  : AppDimensions.pageFrameInnerBottomWide,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
