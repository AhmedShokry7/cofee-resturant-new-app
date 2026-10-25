import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';

class OrderFilterDropdown extends StatelessWidget {
  const OrderFilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label, value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    isDense: true,
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.fieldVerticalPadding,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
    ),
    items: items,
    onChanged: (selected) {
      if (selected != null) onChanged(selected);
    },
  );
}
