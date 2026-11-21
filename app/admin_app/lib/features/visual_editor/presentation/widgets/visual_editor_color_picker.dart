import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';

/// Opens the same HSV palette used by Theme Studio and returns the confirmed
/// color as an RGB hex value. Dismissing the dialog leaves the property intact.
Future<String?> showVisualEditorColorPicker({
  required BuildContext context,
  required Color initialColor,
}) async {
  var selectedColor = Color(
    0xFF000000 | (initialColor.toARGB32() & 0x00FFFFFF),
  );
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final hex = visualEditorColorHex(selectedColor);
        return AlertDialog(
          scrollable: true,
          title: Text(S.visualEditorPickColor),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Theme.of(dialogContext).colorScheme.surface,
                  child: ColorPicker(
                    pickerColor: selectedColor,
                    onColorChanged: (color) =>
                        setDialogState(() => selectedColor = color),
                    paletteType: PaletteType.hsvWithHue,
                    colorPickerWidth: 280,
                    pickerAreaHeightPercent: 0.68,
                    pickerAreaBorderRadius: const BorderRadius.all(
                      Radius.circular(8),
                    ),
                    displayThumbColor: true,
                    enableAlpha: false,
                    labelTypes: const [],
                    portraitOnly: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SelectableText(hex),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(S.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(hex),
              child: Text(S.visualEditorColorConfirm),
            ),
          ],
        );
      },
    ),
  );
}

String visualEditorColorHex(Color color) {
  final rgb = color.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${rgb.substring(2).toUpperCase()}';
}

Color visualEditorParseColor(String value) {
  final hex = value.trim().replaceFirst('#', '');
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return AppColor.primaryColor;
  return Color(hex.length == 8 ? parsed : 0xFF000000 | parsed);
}
