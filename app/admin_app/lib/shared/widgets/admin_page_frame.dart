import 'package:flutter/material.dart';

/// The margins every admin page shares: a responsive gutter, a centred
/// column and the same breathing room as the customers and orders pages.
class AdminPageFrame extends StatelessWidget {
  const AdminPageFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : 38),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1600),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              narrow ? 12 : 28,
              narrow ? 16 : 24,
              narrow ? 12 : 28,
              narrow ? 12 : 21,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
