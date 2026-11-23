import 'package:material_ui/material_ui.dart';

/// Gives data-directory pages the full height available in the admin shell.
/// Short viewports keep the header scrollable; taller viewports let the
/// directory expand to the bottom edge of the page.
class AdminDirectoryPageLayout extends StatelessWidget {
  const AdminDirectoryPageLayout({
    super.key,
    required this.sections,
    required this.directory,
  });

  final List<Widget> sections;
  final Widget directory;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!constraints.hasBoundedHeight || constraints.maxHeight < 720) {
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
        children: [...sections, Expanded(child: directory)],
      );
    },
  );
}
