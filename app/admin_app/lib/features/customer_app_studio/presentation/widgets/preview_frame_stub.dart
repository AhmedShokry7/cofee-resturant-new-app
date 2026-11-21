import 'package:material_ui/material_ui.dart';

class StudioPreviewFrame extends StatelessWidget {
  const StudioPreviewFrame({
    super.key,
    required this.pageId,
    required this.designDocument,
    required this.selectedElementId,
    required this.darkMode,
    required this.width,
    this.runtimeReleaseAvailable = false,
    this.onStatusChanged,
  });

  final String pageId;
  final Map<String, Object?> designDocument;
  final String? selectedElementId;
  final bool darkMode;
  final int width;
  final bool runtimeReleaseAvailable;
  final ValueChanged<String>? onStatusChanged;

  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Safe customer preview runtime is not deployed.'),
  );
}
