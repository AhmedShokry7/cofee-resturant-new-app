import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_images.dart';
import 'package:admin_app/core/theme/app_color.dart';

/// Compact image-only entry point for the admin assistant.
class AssistantLauncherButton extends StatelessWidget {
  const AssistantLauncherButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: AppColor.primaryColor,
          shape: const CircleBorder(),
          elevation: 5,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: 56,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Image.asset(
                  AppImages.aiBot,
                  key: const ValueKey('assistant_launcher_image'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
