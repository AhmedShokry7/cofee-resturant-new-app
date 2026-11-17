import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/constants/app_images.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/data/design_image_upload.dart';
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
    this.onPickImage,
    this.onBrowseImages,
  });

  final EditableComponent component;
  final void Function({
    required String componentId,
    required String propertyKey,
    required dynamic value,
  })
  onPropertyChanged;
  final void Function({
    required String componentId,
    required String propertyKey,
  })
  onResetProperty;
  final Future<String?> Function()? onPickImage;
  final Future<String?> Function()? onBrowseImages;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final entry = ComponentRegistry.get(component.componentType);
    final properties = entry?.properties ?? {};
    final editableProps = Map.fromEntries(
      properties.entries.where((e) => e.value.type != PropertyType.json),
    );

    if (editableProps.isEmpty) {
      return AdminEmptyState(
        icon: AppIcons.settings01,
        message: S.visualEditorNoEditableProperties,
      );
    }

    // تجميع الخصائص حسب المجموعة
    final grouped =
        <String?, List<MapEntry<String, ComponentPropertyDefinition>>>{};
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
                    fields: _pairBilingualFields(grouped[groupKey]!),
                    component: component,
                    onChanged: onPropertyChanged,
                    onReset: onResetProperty,
                    onPickImage: onPickImage,
                    onBrowseImages: onBrowseImages,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// عنصر حقل بعد التجميع: خاصية واحدة، أو زوج عربي/إنجليزي في حقل واحد.
class _FieldItem {
  const _FieldItem.single(this.definition)
    : arDefinition = null,
      enDefinition = null;

  const _FieldItem.bilingual(this.arDefinition, this.enDefinition)
    : definition = null;

  final ComponentPropertyDefinition? definition;
  final ComponentPropertyDefinition? arDefinition;
  final ComponentPropertyDefinition? enDefinition;
}

/// تجميع خصائص `x_ar`/`x_en` في حقل واحد ثنائي اللغة.
///
/// طبيعة النص في التطبيق أن واحدًا يُكتب فيسري في اللغتين، والترجمة
/// المنفصلة استثناء يفتح بزر — فالحقل الواحد هو الوجه الأول لا حقلان
/// يبدو كأن تغيير أحدهما نصف تغيير.
List<_FieldItem> _pairBilingualFields(
  List<MapEntry<String, ComponentPropertyDefinition>> entries,
) {
  final byKey = {for (final e in entries) e.key: e.value};
  final consumed = <String>{};
  final items = <_FieldItem>[];
  for (final e in entries) {
    if (consumed.contains(e.key)) continue;
    final key = e.key;
    if (key.endsWith('_ar')) {
      final enKey = '${key.substring(0, key.length - 3)}_en';
      final en = byKey[enKey];
      if (en != null) {
        consumed.add(enKey);
        items.add(_FieldItem.bilingual(e.value, en));
        continue;
      }
    }
    items.add(_FieldItem.single(e.value));
  }
  return items;
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
            child: Icon(
              AppIcons.tune,
              size: AppDimensions.iconSizeSm,
              color: accent,
            ),
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
    required this.fields,
    required this.component,
    required this.onChanged,
    required this.onReset,
    this.onPickImage,
    this.onBrowseImages,
  });

  final String? groupLabel;
  final List<_FieldItem> fields;
  final EditableComponent component;
  final void Function({
    required String componentId,
    required String propertyKey,
    required dynamic value,
  })
  onChanged;
  final void Function({
    required String componentId,
    required String propertyKey,
  })
  onReset;
  final Future<String?> Function()? onPickImage;
  final Future<String?> Function()? onBrowseImages;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (groupLabel != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              0,
              AppSpacing.sm,
              0,
              AppSpacing.xs,
            ),
            child: _GroupLabel(label: groupLabel!),
          ),
        ],
        for (final field in fields)
          if (field.definition != null)
            _PropertyField(
              componentType: component.componentType,
              definition: field.definition!,
              currentValue: component.properties[field.definition!.key],
              onChanged: (v) => onChanged(
                componentId: component.componentId,
                propertyKey: field.definition!.key,
                value: v,
              ),
              onReset: () => onReset(
                componentId: component.componentId,
                propertyKey: field.definition!.key,
              ),
              onPickImage: onPickImage,
              onBrowseImages: onBrowseImages,
              splashImageVisible:
                  component.properties['imageVisible'] as bool? ?? true,
              onSplashImageVisibilityChanged: (visible) => onChanged(
                componentId: component.componentId,
                propertyKey: 'imageVisible',
                value: visible,
              ),
              clearLabel:
                  component.componentType == 'welcomeHero' ||
                      component.componentType == 'onboardingSlide' ||
                      component.componentType == 'splashSettings'
                  ? S.visualEditorRestoreOriginalImage
                  : S.visualEditorRemoveImage,
            )
          else
            _BilingualPropertyField(
              arDefinition: field.arDefinition!,
              enDefinition: field.enDefinition!,
              arValue: component.properties[field.arDefinition!.key],
              enValue: component.properties[field.enDefinition!.key],
              onChanged: (arKey, enKey, v) {
                // الحقل الواحد يكتب اللغتين معًا: هذا هو الطبيعي —
                // والفصل بين اللغتين يبقى متاحًا بزر داخل الحقل نفسه.
                onChanged(
                  componentId: component.componentId,
                  propertyKey: arKey,
                  value: v,
                );
                onChanged(
                  componentId: component.componentId,
                  propertyKey: enKey,
                  value: v,
                );
              },
              onSingleChanged: (key, v) => onChanged(
                componentId: component.componentId,
                propertyKey: key,
                value: v,
              ),
              onReset: (arKey, enKey) {
                onReset(componentId: component.componentId, propertyKey: arKey);
                onReset(componentId: component.componentId, propertyKey: enKey);
              },
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
    required this.componentType,
    required this.definition,
    required this.currentValue,
    required this.onChanged,
    required this.onReset,
    this.onPickImage,
    this.onBrowseImages,
    this.splashImageVisible = true,
    this.onSplashImageVisibilityChanged,
    this.clearLabel,
  });

  final String componentType;
  final ComponentPropertyDefinition definition;
  final dynamic currentValue;
  final void Function(dynamic value) onChanged;
  final VoidCallback onReset;
  final Future<String?> Function()? onPickImage;
  final Future<String?> Function()? onBrowseImages;
  final bool splashImageVisible;
  final ValueChanged<bool>? onSplashImageVisibilityChanged;
  final String? clearLabel;

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
    if (definition.key == 'imageUrl' && componentType == 'splashSettings') {
      return _SplashImageInput(
        value: currentValue?.toString() ?? '',
        imageVisible: splashImageVisible,
        onChanged: (value) {
          onChanged(value);
          if (value.trim().isNotEmpty) {
            onSplashImageVisibilityChanged?.call(true);
          }
        },
        onVisibilityChanged: onSplashImageVisibilityChanged ?? (_) {},
        pickAndUpload: onPickImage ?? DesignImageUpload.pickAndUpload,
        clearLabel: clearLabel ?? S.visualEditorRestoreOriginalImage,
        browseImages: onBrowseImages,
      );
    }
    return switch (definition.type) {
      PropertyType.string || PropertyType.text => _TextInput(
        value:
            currentValue?.toString() ??
            definition.defaultValue?.toString() ??
            '',
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
        value:
            currentValue as bool? ?? definition.defaultValue as bool? ?? false,
        onChanged: onChanged,
      ),
      PropertyType.color => _ColorInput(
        value:
            currentValue?.toString() ??
            definition.defaultValue?.toString() ??
            '#000000',
        onChanged: onChanged,
      ),
      PropertyType.enum_ => _EnumInput(
        value:
            currentValue?.toString() ??
            definition.defaultValue?.toString() ??
            '',
        options: definition.options?.map((e) => e.toString()).toList() ?? [],
        onChanged: onChanged,
      ),
      PropertyType.fontSize => _EnumInput(
        value:
            currentValue?.toString() ??
            definition.defaultValue?.toString() ??
            '14',
        options:
            definition.options?.map((e) => e.toString()).toList() ??
            ['10', '12', '14', '16', '18', '20', '24', '28', '32'],
        onChanged: onChanged,
      ),
      PropertyType.fontWeight => _EnumInput(
        value:
            currentValue?.toString() ??
            definition.defaultValue?.toString() ??
            'regular',
        options:
            definition.options?.map((e) => e.toString()).toList() ??
            ['light', 'regular', 'medium', 'semibold', 'bold'],
        onChanged: onChanged,
      ),
      PropertyType.alignment => _EnumInput(
        value:
            currentValue?.toString() ??
            definition.defaultValue?.toString() ??
            'start',
        options:
            definition.options?.map((e) => e.toString()).toList() ??
            ['start', 'center', 'end'],
        onChanged: onChanged,
      ),
      PropertyType.borderRadius => _EnumInput(
        value:
            currentValue?.toString() ??
            definition.defaultValue?.toString() ??
            'none',
        options:
            definition.options?.map((e) => e.toString()).toList() ??
            ['none', 'sm', 'md', 'lg', 'full'],
        onChanged: onChanged,
      ),
      PropertyType.spacing => _EnumInput(
        value:
            currentValue?.toString() ??
            definition.defaultValue?.toString() ??
            'md',
        options:
            definition.options?.map((e) => e.toString()).toList() ??
            ['none', 'xs', 'sm', 'md', 'lg', 'xl'],
        onChanged: onChanged,
      ),
      PropertyType.imageUrl => _ImageUrlInput(
        value:
            currentValue?.toString() ??
            definition.defaultValue?.toString() ??
            '',
        onChanged: onChanged,
        pickAndUpload: onPickImage ?? DesignImageUpload.pickAndUpload,
        browseImages: onBrowseImages,
        clearLabel: clearLabel ?? S.visualEditorRemoveImage,
      ),
      PropertyType.fontFamily => _TextInput(
        value:
            currentValue?.toString() ??
            definition.defaultValue?.toString() ??
            '',
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

/// حقل نص ثنائي اللغة: حقل واحد يكتب اللغتين، أو حقلان منفصلان بزر.
///
/// الوجه الأول حقل واحد — تغيير النص يصل للعربي والإنجليزي معًا كما
/// يتوقّع من نص واحد. من أراد ترجمة مختلفة فتح زر «كل لغة منفصلة»
/// فيظهر حقلان بلغة كل منهما، والقيم كما هي بلا فقد.
class _BilingualPropertyField extends StatefulWidget {
  const _BilingualPropertyField({
    required this.arDefinition,
    required this.enDefinition,
    required this.arValue,
    required this.enValue,
    required this.onChanged,
    required this.onReset,
    required this.onSingleChanged,
  });

  final ComponentPropertyDefinition arDefinition;
  final ComponentPropertyDefinition enDefinition;
  final dynamic arValue;
  final dynamic enValue;

  /// وضع الدمج: قيمة واحدة تُكتب في اللغتين.
  final void Function(String arKey, String enKey, String value) onChanged;

  /// وضع الفصل: كل حقل يكتب لغته وحده.
  final void Function(String key, String value) onSingleChanged;
  final void Function(String arKey, String enKey) onReset;

  @override
  State<_BilingualPropertyField> createState() =>
      _BilingualPropertyFieldState();
}

class _BilingualPropertyFieldState extends State<_BilingualPropertyField> {
  /// الوجه الأول: نص واحد للغتين. الفصل قرار يفتحه الموظف زرًا.
  bool _separate = false;

  String get _arText => widget.arValue?.toString() ?? '';

  String get _enText => widget.enValue?.toString() ?? '';

  /// ما يظهر في الحقل الموحّد: لغة واجهة الأدمن أولًا، ثم الأخرى؛
  /// والفارغ يعني «كما هو» لا نصًا مختلقًا.
  String get _mergedText {
    final preferred = AppLocale.instance.isArabic ? _arText : _enText;
    if (preferred.trim().isNotEmpty) return preferred;
    final other = AppLocale.instance.isArabic ? _enText : _arText;
    if (other.trim().isNotEmpty) return other;
    return '';
  }

  /// عنوان الحقل: تسمية العربية بلا لاحقة اللغة — «الوصف بالعربي»
  /// تصبح «الوصف»، فالحقل الواحد لا يحتاج أن يقول أي لغة هو.
  String get _label {
    final label = widget.arDefinition.label;
    const suffix = ' بالعربي';
    final stripped = label.endsWith(suffix)
        ? label.substring(0, label.length - suffix.length)
        : '';
    final trimmed = stripped.trim();
    return trimmed.isNotEmpty ? trimmed : label;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    final accent = dark ? AppColor.secondaryColor : AppColor.adminAccent;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _label,
                  style: TextStyle(
                    fontSize: AppFontSizes.size11,
                    fontWeight: AppFontWeights.medium,
                    color: dark ? AppColor.darkText : AppColor.adminBody,
                  ),
                ),
              ),
              Tooltip(
                message: S.visualEditorResetProperty,
                child: InkWell(
                  onTap: () => widget.onReset(
                    widget.arDefinition.key,
                    widget.enDefinition.key,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(AppIcons.refresh, size: 12, color: muted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (!_separate)
            _BilingualTextInput(
              value: _mergedText,
              hint: S.visualEditorBilingualHint,
              onChanged: (v) => widget.onChanged(
                widget.arDefinition.key,
                widget.enDefinition.key,
                v,
              ),
            )
          else ...[
            Text(
              S.visualEditorBilingualArabicLabel,
              style: TextStyle(fontSize: AppFontSizes.size10, color: muted),
            ),
            _BilingualTextInput(
              value: _arText,
              onChanged: (v) =>
                  widget.onSingleChanged(widget.arDefinition.key, v),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              S.visualEditorBilingualEnglishLabel,
              style: TextStyle(fontSize: AppFontSizes.size10, color: muted),
            ),
            _BilingualTextInput(
              value: _enText,
              onChanged: (v) =>
                  widget.onSingleChanged(widget.enDefinition.key, v),
            ),
          ],
          const SizedBox(height: AppSpacing.xxs),
          // زر الفصل/الدمج: من يريد ترجمة مختلفة يفتح حقلين، ومن عدل
          // يغلقها على الحقل الواحد الذي يكتب اللغتين.
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: InkWell(
              onTap: () => setState(() => _separate = !_separate),
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                child: Text(
                  _separate
                      ? S.visualEditorBilingualBoth
                      : S.visualEditorBilingualSeparate,
                  style: TextStyle(
                    fontSize: AppFontSizes.size10,
                    color: accent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// حقل نص: في وضع الدمج يكتب اللغتين معًا، وفي وضع الفصل يستقبل كاتب
/// لغة واحدة. التزامن مع القيم الخارجية (تراجع/إعادة) كما في حقول النص
/// الأخرى: تغيّرت من الخارج فالحقل يتبعها ما لم يكتب فيها الموظف الآن.
class _BilingualTextInput extends StatefulWidget {
  const _BilingualTextInput({
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;

  @override
  State<_BilingualTextInput> createState() => _BilingualTextInputState();
}

class _BilingualTextInputState extends State<_BilingualTextInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_BilingualTextInput old) {
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
      maxLines: 2,
      minLines: 1,
      onChanged: widget.onChanged,
      style: TextStyle(
        fontSize: AppFontSizes.size12,
        color: dark ? AppColor.darkText : AppColor.adminBody,
      ),
      decoration: _inputDecoration(dark).copyWith(hintText: widget.hint),
    );
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
        Switch(value: value, onChanged: onChanged, activeThumbColor: accent),
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
    return clean.length == 8 ? Color(value) : Color(0xFF000000 | value);
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
    final safeValue = options.contains(value)
        ? value
        : (options.isNotEmpty ? options.first : '');
    return DropdownButtonFormField<String>(
      initialValue: safeValue.isEmpty ? null : safeValue,
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
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

/// حقل صورة شاشة الافتتاحية: معاينة واختيار من المكتبة أو رفع صورة جديدة.
class _SplashImageInput extends StatefulWidget {
  const _SplashImageInput({
    required this.value,
    required this.imageVisible,
    required this.onChanged,
    required this.onVisibilityChanged,
    required this.pickAndUpload,
    required this.clearLabel,
    this.browseImages,
  });

  final String value;
  final bool imageVisible;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onVisibilityChanged;
  final Future<String?> Function() pickAndUpload;
  final String clearLabel;
  final Future<String?> Function()? browseImages;

  @override
  State<_SplashImageInput> createState() => _SplashImageInputState();
}

class _SplashImageInputState extends State<_SplashImageInput> {
  late final TextEditingController _controller;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_SplashImageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _browse() async {
    final url = await widget.browseImages?.call();
    if (!mounted || url == null || url.isEmpty) return;
    setState(() {
      _controller.text = url;
      _error = null;
    });
    widget.onChanged(url);
  }

  Future<void> _upload() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url = await widget.pickAndUpload();
      if (!mounted || url == null || url.isEmpty) return;
      setState(() => _controller.text = url);
      widget.onChanged(url);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final url = _controller.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: dark
                      ? AppColor.darkSurfaceContainer
                      : AppColor.adminTableHeader,
                ),
                if (widget.imageVisible)
                  url.isEmpty
                      ? Image.asset(
                          AppImages.logo,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Icon(
                            AppIcons.image01,
                            color: dark
                                ? AppColor.darkTextSecondary
                                : AppColor.adminMuted,
                          ),
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Icon(
                            AppIcons.image01,
                            color: dark
                                ? AppColor.darkTextSecondary
                                : AppColor.adminMuted,
                          ),
                        ),
                if (!widget.imageVisible)
                  Center(
                    child: Text(
                      S.visualEditorSplashImageHidden,
                      style: TextStyle(
                        color: dark
                            ? AppColor.darkTextSecondary
                            : AppColor.adminMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                url.isEmpty
                    ? S.visualEditorSplashDefaultImage
                    : S.visualEditorSplashCustomImage,
                style: TextStyle(
                  fontSize: AppFontSizes.size10,
                  color: dark
                      ? AppColor.darkTextSecondary
                      : AppColor.adminMuted,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => widget.onVisibilityChanged(!widget.imageVisible),
              icon: Icon(
                widget.imageVisible ? AppIcons.eyeOff : AppIcons.eye,
                size: 14,
              ),
              label: Text(
                widget.imageVisible
                    ? S.visualEditorHideImage
                    : S.visualEditorShowImage,
              ),
            ),
          ],
        ),
        TextField(
          controller: _controller,
          onChanged: (value) {
            setState(() {});
            widget.onChanged(value);
          },
          style: TextStyle(
            fontSize: AppFontSizes.size12,
            color: dark ? AppColor.darkText : AppColor.adminBody,
          ),
          decoration: _inputDecoration(dark).copyWith(hintText: 'https://…'),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (url.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () {
              _controller.clear();
              setState(() => _error = null);
              widget.onChanged('');
            },
            icon: Icon(AppIcons.remove01, size: 14),
            label: Text(widget.clearLabel),
          ),
        if (widget.browseImages != null)
          OutlinedButton.icon(
            onPressed: _uploading ? null : _browse,
            icon: const Icon(AppIcons.image01, size: 14),
            label: Text(S.visualEditorImageLibrary),
          ),
        OutlinedButton.icon(
          onPressed: _uploading ? null : _upload,
          icon: _uploading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(AppIcons.image01, size: 14),
          label: Text(
            _uploading ? S.visualEditorUploadingImage : S.visualEditorPickImage,
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(
              fontSize: AppFontSizes.size11,
              color: AppColor.errorColor,
            ),
          ),
      ],
    );
  }
}

/// حقل صورة: معاينة صغيرة + رابط + زر اختر من الكمبيوتر وارفع.
///
/// الصورة تُرفع إلى دلو التصميم فيُضع رابطها العام هنا — لا حاجة لأي
/// خدمة خارجية. فارغ يعني صورة التطبيق الأصلية للمكان.
class _ImageUrlInput extends StatefulWidget {
  const _ImageUrlInput({
    required this.value,
    required this.onChanged,
    required this.pickAndUpload,
    required this.clearLabel,
    this.browseImages,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final Future<String?> Function() pickAndUpload;
  final Future<String?> Function()? browseImages;
  final String clearLabel;

  @override
  State<_ImageUrlInput> createState() => _ImageUrlInputState();
}

class _ImageUrlInputState extends State<_ImageUrlInput> {
  late final TextEditingController _ctrl;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_ImageUrlInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _ctrl.text) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _browseImages() async {
    final browse = widget.browseImages;
    if (browse == null) return;
    final url = await browse();
    if (!mounted || url == null || url.isEmpty) return;
    setState(() {
      _ctrl.text = url;
      _error = null;
    });
    widget.onChanged(url);
  }

  Future<void> _pickAndUpload() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url = await widget.pickAndUpload();
      if (!mounted) return;
      if (url != null && url.isNotEmpty) {
        widget.onChanged(url);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final url = _ctrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (url.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              height: 120,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  height: 120,
                  color: dark
                      ? AppColor.darkSurfaceContainer
                      : AppColor.adminTableHeader,
                  alignment: Alignment.center,
                  child: Icon(
                    AppIcons.image01,
                    color: dark
                        ? AppColor.darkTextSecondary
                        : AppColor.adminMuted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: () {
              _ctrl.clear();
              setState(() => _error = null);
              widget.onChanged('');
            },
            icon: Icon(AppIcons.remove01, size: 14),
            label: Text(widget.clearLabel),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _ctrl,
          onChanged: (v) {
            setState(() {});
            widget.onChanged(v);
          },
          style: TextStyle(
            fontSize: AppFontSizes.size12,
            color: dark ? AppColor.darkText : AppColor.adminBody,
          ),
          decoration: _inputDecoration(dark).copyWith(hintText: 'https://…'),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (widget.browseImages != null) ...[
          OutlinedButton.icon(
            onPressed: _uploading ? null : _browseImages,
            icon: const Icon(AppIcons.image01, size: 14),
            label: Text(S.visualEditorImageLibrary),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        OutlinedButton.icon(
          onPressed: _uploading ? null : _pickAndUpload,
          icon: _uploading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(AppIcons.image01, size: 14),
          label: Text(
            _uploading ? S.visualEditorUploadingImage : S.visualEditorPickImage,
            style: TextStyle(fontSize: AppFontSizes.size12),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _error!,
            style: TextStyle(
              fontSize: AppFontSizes.size11,
              color: AppColor.errorColor,
            ),
          ),
        ],
      ],
    );
  }
}
