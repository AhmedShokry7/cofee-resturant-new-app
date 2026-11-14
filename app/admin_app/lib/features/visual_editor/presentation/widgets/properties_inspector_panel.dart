import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';

/// لوحة خصائص المكوّن المحدد.
///
/// تعرض الخصائص القابلة للتحرير بحسب نوعها (نص، لون، رقم، اختيار...)
/// وترسل التغييرات فور حدوثها.
class PropertiesInspectorPanel extends StatelessWidget {
  const PropertiesInspectorPanel({
    super.key,
    required this.component,
    required this.onPropertyChanged,
    required this.onResetProperty,
  });

  final EditableComponent component;
  final void Function({
    required String componentId,
    required String propertyKey,
    required dynamic value,
  }) onPropertyChanged;
  final void Function({
    required String componentId,
    required String propertyKey,
  }) onResetProperty;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final entry = ComponentRegistry.get(component.componentType);
    final properties = entry?.properties ?? {};
    final editableProps = Map.fromEntries(
      properties.entries
          .where((e) => e.value.type != PropertyType.json),
    );

    if (editableProps.isEmpty) {
      return AdminEmptyState(
        icon: AppIcons.settings01,
        message: S.visualEditorNoEditableProperties,
      );
    }

    // تجميع الخصائص حسب المجموعة
    final grouped = <String?, List<MapEntry<String, ComponentPropertyDefinition>>>{};
    for (final entry in editableProps.entries) {
      final group = entry.value.group;
      grouped.putIfAbsent(group, () => []).add(entry);
    }

    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColor.darkSurface : AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.adminCardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InspectorHeader(component: component, entry: entry),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.sm),
              children: [
                for (final groupKey in grouped.keys)
                  _PropertyGroup(
                    groupLabel: groupKey,
                    properties: grouped[groupKey]!,
                    component: component,
                    onChanged: onPropertyChanged,
                    onReset: onResetProperty,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorHeader extends StatelessWidget {
  const _InspectorHeader({required this.component, this.entry});

  final EditableComponent component;
  final ComponentRegistryEntry? entry;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    final heading = dark ? AppColor.darkText : AppColor.adminHeading;
    final accent = dark ? AppColor.secondaryColor : AppColor.adminAccent;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: dark
                  ? AppColor.darkSurfaceContainer
                  : AppColor.adminAccentSurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(AppIcons.tune, size: AppDimensions.iconSizeSm, color: accent),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry?.displayName ?? component.componentType,
                  style: TextStyle(
                    fontSize: AppFontSizes.size12,
                    fontWeight: AppFontWeights.semiBold,
                    color: heading,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  component.componentId,
                  style: TextStyle(
                    fontSize: AppFontSizes.size9_5,
                    color: muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyGroup extends StatelessWidget {
  const _PropertyGroup({
    required this.groupLabel,
    required this.properties,
    required this.component,
    required this.onChanged,
    required this.onReset,
  });

  final String? groupLabel;
  final List<MapEntry<String, ComponentPropertyDefinition>> properties;
  final EditableComponent component;
  final void Function({
    required String componentId,
    required String propertyKey,
    required dynamic value,
  }) onChanged;
  final void Function({
    required String componentId,
    required String propertyKey,
  }) onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (groupLabel != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, AppSpacing.xs),
            child: _GroupLabel(label: groupLabel!),
          ),
        ],
        for (final entry in properties)
          _PropertyField(
            definition: entry.value,
            currentValue: component.properties[entry.key],
            onChanged: (v) => onChanged(
              componentId: component.componentId,
              propertyKey: entry.key,
              value: v,
            ),
            onReset: () => onReset(
              componentId: component.componentId,
              propertyKey: entry.key,
            ),
          ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      style: TextStyle(
        fontSize: AppFontSizes.size10,
        fontWeight: AppFontWeights.semiBold,
        color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
        letterSpacing: AppLetterSpacings.space0_8,
      ),
    );
  }
}

class _PropertyField extends StatelessWidget {
  const _PropertyField({
    required this.definition,
    required this.currentValue,
    required this.onChanged,
    required this.onReset,
  });

  final ComponentPropertyDefinition definition;
  final dynamic currentValue;
  final void Function(dynamic value) onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  definition.label,
                  style: TextStyle(
                    fontSize: AppFontSizes.size11,
                    fontWeight: AppFontWeights.medium,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColor.darkText
                        : AppColor.adminBody,
                  ),
                ),
              ),
              Tooltip(
                message: S.visualEditorResetProperty,
                child: InkWell(
                  onTap: onReset,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      AppIcons.refresh,
                      size: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColor.darkTextSecondary
                          : AppColor.adminMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildInput(context),
        ],
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    return switch (definition.type) {
      PropertyType.string || PropertyType.text => _TextInput(
          value: currentValue?.toString() ?? definition.defaultValue?.toString() ?? '',
          multiline: definition.type == PropertyType.text,
          onChanged: onChanged,
        ),
      PropertyType.number || PropertyType.integer => _NumberInput(
          value: currentValue,
          defaultValue: definition.defaultValue,
          isInteger: definition.type == PropertyType.integer,
          validation: definition.validation,
          onChanged: onChanged,
        ),
      PropertyType.boolean => _BooleanInput(
          value: currentValue as bool? ?? definition.defaultValue as bool? ?? false,
          onChanged: onChanged,
        ),
      PropertyType.color => _ColorInput(
          value: currentValue?.toString() ?? definition.defaultValue?.toString() ?? '#000000',
          onChanged: onChanged,
        ),
      PropertyType.enum_ => _EnumInput(
          value: currentValue?.toString() ?? definition.defaultValue?.toString() ?? '',
          options: definition.options?.map((e) => e.toString()).toList() ?? [],
          onChanged: onChanged,
        ),
      PropertyType.fontSize => _EnumInput(
          value: currentValue?.toString() ?? definition.defaultValue?.toString() ?? '14',
          options: definition.options?.map((e) => e.toString()).toList() ??
              ['10', '12', '14', '16', '18', '20', '24', '28', '32'],
          onChanged: onChanged,
        ),
      PropertyType.fontWeight => _EnumInput(
          value: currentValue?.toString() ?? definition.defaultValue?.toString() ?? 'regular',
          options: definition.options?.map((e) => e.toString()).toList() ??
              ['light', 'regular', 'medium', 'semibold', 'bold'],
          onChanged: onChanged,
        ),
      PropertyType.alignment => _EnumInput(
          value: currentValue?.toString() ?? definition.defaultValue?.toString() ?? 'start',
          options: definition.options?.map((e) => e.toString()).toList() ??
              ['start', 'center', 'end'],
          onChanged: onChanged,
        ),
      PropertyType.borderRadius => _EnumInput(
          value: currentValue?.toString() ?? definition.defaultValue?.toString() ?? 'none',
          options: definition.options?.map((e) => e.toString()).toList() ??
              ['none', 'sm', 'md', 'lg', 'full'],
          onChanged: onChanged,
        ),
      PropertyType.spacing => _EnumInput(
          value: currentValue?.toString() ?? definition.defaultValue?.toString() ?? 'md',
          options: definition.options?.map((e) => e.toString()).toList() ??
              ['none', 'xs', 'sm', 'md', 'lg', 'xl'],
          onChanged: onChanged,
        ),
      PropertyType.imageUrl => _TextInput(
          value: currentValue?.toString() ?? definition.defaultValue?.toString() ?? '',
          multiline: false,
          onChanged: onChanged,
        ),
      PropertyType.fontFamily => _TextInput(
          value: currentValue?.toString() ?? definition.defaultValue?.toString() ?? '',
          multiline: false,
          onChanged: onChanged,
        ),
      _ => _TextInput(
          value: currentValue?.toString() ?? '',
          multiline: false,
          onChanged: onChanged,
        ),
    };
  }
}

// ---------- حقول الإدخال ----------

class _TextInput extends StatefulWidget {
  const _TextInput({
    required this.value,
    required this.multiline,
    required this.onChanged,
  });

  final String value;
  final bool multiline;
  final void Function(String) onChanged;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_TextInput old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: _ctrl,
      maxLines: widget.multiline ? 3 : 1,
      onChanged: widget.onChanged,
      style: TextStyle(
        fontSize: AppFontSizes.size12,
        color: dark ? AppColor.darkText : AppColor.adminBody,
      ),
      decoration: _inputDecoration(dark),
    );
  }
}

class _NumberInput extends StatefulWidget {
  const _NumberInput({
    required this.value,
    required this.defaultValue,
    required this.isInteger,
    required this.validation,
    required this.onChanged,
  });

  final dynamic value;
  final dynamic defaultValue;
  final bool isInteger;
  final Map<String, dynamic>? validation;
  final void Function(dynamic) onChanged;

  @override
  State<_NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<_NumberInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.value?.toString() ?? widget.defaultValue?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) {
        final num = widget.isInteger ? int.tryParse(v) : double.tryParse(v);
        if (num != null) widget.onChanged(num);
      },
      style: TextStyle(
        fontSize: AppFontSizes.size12,
        color: dark ? AppColor.darkText : AppColor.adminBody,
      ),
      decoration: _inputDecoration(dark),
    );
  }
}

class _BooleanInput extends StatelessWidget {
  const _BooleanInput({required this.value, required this.onChanged});

  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppColor.secondaryColor : AppColor.adminAccent;
    return Row(
      children: [
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: accent,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          value ? S.visualEditorOn : S.visualEditorOff,
          style: TextStyle(
            fontSize: AppFontSizes.size12,
            color: dark ? AppColor.darkText : AppColor.adminBody,
          ),
        ),
      ],
    );
  }
}

class _ColorInput extends StatelessWidget {
  const _ColorInput({required this.value, required this.onChanged});

  final String value;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = _parseColor(value);
    return Row(
      children: [
        Container(
          width: AppSizes.px24,
          height: AppSizes.px24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(
              color: dark ? AppColor.darkBorder : AppColor.adminCardBorder,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            controller: TextEditingController(text: value),
            onChanged: (v) {
              if (_parseColor(v) != null) onChanged(v);
            },
            style: TextStyle(
              fontSize: AppFontSizes.size12,
              color: dark ? AppColor.darkText : AppColor.adminBody,
            ),
            decoration: _inputDecoration(dark),
          ),
        ),
      ],
    );
  }

  Color? _parseColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    final value = int.tryParse(clean, radix: 16);
    if (value == null) return null;
    return clean.length == 8
        ? Color(value)
        : Color(0xFF000000 | value);
  }
}

class _EnumInput extends StatelessWidget {
  const _EnumInput({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final safeValue = options.contains(value) ? value : (options.isNotEmpty ? options.first : '');
    return DropdownButtonFormField<String>(
      initialValue: safeValue.isEmpty ? null : safeValue,
      items: options
          .map(
            (o) => DropdownMenuItem(value: o, child: Text(o)),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      style: TextStyle(
        fontSize: AppFontSizes.size12,
        color: dark ? AppColor.darkText : AppColor.adminBody,
      ),
      decoration: _inputDecoration(dark),
    );
  }
}

InputDecoration _inputDecoration(bool dark) => InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(
          color: dark ? AppColor.darkBorder : AppColor.adminControlBorder,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(
          color: dark ? AppColor.darkBorder : AppColor.adminControlBorder,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(
          color: dark ? AppColor.secondaryColor : AppColor.adminAccent,
        ),
      ),
      filled: true,
      fillColor: dark ? AppColor.darkSurfaceContainer : AppColor.adminTableHeader,
    );
