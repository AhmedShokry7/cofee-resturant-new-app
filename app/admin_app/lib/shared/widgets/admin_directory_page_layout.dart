import 'package:material_ui/material_ui.dart';

/// Gives data-directory pages the full height available in the admin shell.
/// Short viewports keep the header scrollable; taller viewports let the
/// directory expand to the bottom edge of the page.
class AdminDirectoryPageLayout extends StatelessWidget {
  const AdminDirectoryPageLayout({
    super.key,
    required this.sections,
    required this.directory,
    this.scrollOnNarrowWidth = false,
  });

  final List<Widget> sections;
  final Widget directory;

  /// Some pages have tall summary sections that need to scroll with the
  /// directory on phones, even when the viewport itself is desktop-height.
  final bool scrollOnNarrowWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!constraints.hasBoundedHeight ||
          constraints.maxHeight < 720 ||
          (scrollOnNarrowWidth && constraints.maxWidth < 600)) {
        final directoryHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - 240).clamp(420.0, 840.0).toDouble()
            : 560.0;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...sections,
              SizedBox(height: directoryHeight, child: directory),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...sections,
          Expanded(child: directory),
        ],
      );
    },
  );
}
