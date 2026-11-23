import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';

/// The margins every admin page shares: a responsive gutter, a centred
/// column and the same breathing room as the customers and orders pages.
class AdminPageFrame extends StatelessWidget {
  const AdminPageFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final narrow = width < AppBreakpoints.pageCanvas;
        final inset = AppDimensions.pageHorizontalInset(width);
        final topInset = narrow
            ? AppDimensions.pageFrameInnerTopNarrow
            : AppDimensions.pageFrameInnerTopWide;
        final bottomInset = narrow
            ? AppDimensions.pageFrameInnerBottomNarrow
            : AppDimensions.pageFrameInnerBottomWide;
        final minContentHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - topInset - bottomInset).clamp(
                0.0,
                double.infinity,
              ).toDouble()
            : 0.0;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimensions.pageFrameMaxContentWidth,
              ),
              child: Padding(
                padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minContentHeight),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
