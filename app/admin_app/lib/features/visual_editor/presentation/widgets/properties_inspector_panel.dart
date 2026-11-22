import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/constants/app_images.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/banners/di/banners_dependencies.dart';
import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/bundles/di/bundles_dependencies.dart';
import 'package:admin_app/features/visual_editor/data/design_image_upload.dart';
import 'package:admin_app/features/visual_editor/data/visual_editor_image_asset_repository.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_color_picker.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_theme_tokens.dart';
import 'package:admin_app/features/catalog/di/catalog_dependencies.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';

// نفس أبعاد العرض التلقائي في معاينة المحرر وشاشة الافتتاحية عند الزبون.
// تُستخدم لعرض القيمة الفعّالة في الحقل حين تكون الخاصية متروكة على «تلقائي».
const double _splashWidthRatio = 0.66;
const double _splashMinWidth = 160;
const double _splashMaxWidth = 320;
const double _splashAssetWidth = 1024;
const double _splashAssetHeight = 827;

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
    this.onPropertiesChanged,
    this.showHeader = true,
    this.splashGroup,
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
  final void Function({
    required String componentId,
    required Map<String, dynamic> values,
  })?
  onPropertiesChanged;
  final bool showHeader;
  final String? splashGroup;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final entry = ComponentRegistry.get(component.componentType);
    final registryProps = entry?.properties ?? {};
    final editableProps = Map.fromEntries(
      registryProps.entries.where(
        (e) =>
            e.value.type != PropertyType.json &&
            !e.key.startsWith('bannerDraft_'),
      ),
    );

    // تجميع الخصائص حسب المجموعة
    final grouped =
        <String?, List<MapEntry<String, ComponentPropertyDefinition>>>{};
    for (final e in editableProps.entries) {
      final definition = e.value;
      final group =
          definition.type == PropertyType.spacing ||
              RegExp(
                r'^(padding|margin|inset|gap)',
                caseSensitive: false,
              ).hasMatch(e.key)
          ? 'المسافات'
          : definition.group;
      grouped.putIfAbsent(group, () => []).add(e);
    }

    // --- خصائص حقيقية موجودة في المكوّن لكن غير مسجلة ---
    // نعرضها كحقول نصية خام حتى يمكن التعديل عليها
    final knownKeys = registryProps.keys.toSet()..add('visible');
    final docProps = component.properties;
    final extraProps = docProps.entries
        .where(
          (e) =>
              !knownKeys.contains(e.key) &&
              e.value is! Map &&
              e.value is! List &&
              // المفاتيح القديمة أحادية اللغة يغطيها زوج _ar/_en المسجل
              // في المستند نفسه — لا عرض لها كخصائص إضافية خام.
              !docProps.containsKey('${e.key}_ar') &&
              !docProps.containsKey('${e.key}_en'),
        )
        .toList();

    final hasContent = editableProps.isNotEmpty || extraProps.isNotEmpty;

    // عائلات الخصائص المتقاربة: كل ما يتعلق بالصورة في قسم واحد بصفوف
    // ثلاثية، وكذلك النص — بأسلوب فيجما بدل تشتّتها بين المجموعات.
    final imageFamily = <MapEntry<String, ComponentPropertyDefinition>>[];
    final textFamily = <MapEntry<String, ComponentPropertyDefinition>>[];
    final reducedGroups =
        <String?, List<MapEntry<String, ComponentPropertyDefinition>>>{};
    for (final entry in grouped.entries) {
      final kept = <MapEntry<String, ComponentPropertyDefinition>>[];
      for (final e in entry.value) {
        final family = _fieldFamily(e.value);
        if (family == 'image') {
          imageFamily.add(e);
        } else if (family == 'text') {
          textFamily.add(e);
        } else {
          kept.add(e);
        }
      }
      if (kept.isNotEmpty) reducedGroups[entry.key] = kept;
    }
    _sortFamilyFields(imageFamily, const [
      'imageFit',
      'imageShape',
      'imageAlignment',
      'imageCornerRadius',
      'imageWidth',
      'imageHeight',
      'imageGap',
      'imagePadding',
    ]);
    _sortFamilyFields(textFamily, const [
      'size',
      'textWeight',
      'alignment',
      'lineHeight',
    ]);
    final familySections = <Widget>[
      if (imageFamily.isNotEmpty)
        _PropertySection(
          groupLabel: 'الصورة',
          fields: [for (final e in imageFamily) _FieldItem.single(e.value)],
          fieldsPerRow: 3,
          component: component,
          onChanged: onPropertyChanged,
          onReset: onResetProperty,
          onPickImage: onPickImage,
          onBrowseImages: onBrowseImages,
        ),
      if (textFamily.isNotEmpty)
        _PropertySection(
          groupLabel: 'النص',
          fields: [for (final e in textFamily) _FieldItem.single(e.value)],
          fieldsPerRow: 3,
          component: component,
          onChanged: onPropertyChanged,
          onReset: onResetProperty,
          onPickImage: onPickImage,
          onBrowseImages: onBrowseImages,
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColor.darkSurface : AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.adminCardBorder,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isUnbounded = constraints.maxHeight.isInfinite;
          final content = !hasContent
              ? AdminEmptyState(
                  icon: AppIcons.settings01,
                  message: S.visualEditorNoEditableProperties,
                )
              : ListView(
                  shrinkWrap: isUnbounded,
                  physics: isUnbounded
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  children: [
                    if (component.componentType == 'splashSettings') ...[
                      _splashLayer(
                        S.visualEditorSplashBackground,
                        const {'backgroundColor'},
                        editableProps,
                        component,
                        onPropertyChanged,
                        onResetProperty,
                        onPickImage,
                        onBrowseImages,
                      ),
                      _splashLayer(
                        S.visualEditorSplashImageSettings,
                        const {
                          'imageVisible',
                          'imageUrl',
                          'imageFit',
                          'imageShape',
                          'imageCornerRadius',
                          'imageWidth',
                          'imageHeight',
                          'imageAlignment',
                        },
                        editableProps,
                        component,
                        onPropertyChanged,
                        onResetProperty,
                        onPickImage,
                        onBrowseImages,
                      ),
                      _splashLayer(
                        S.visualEditorSplashText,
                        const {
                          'text_ar',
                          'text_en',
                          'textColor',
                          'textSize',
                          'textWeight',
                          'textAlignment',
                        },
                        editableProps,
                        component,
                        onPropertyChanged,
                        onResetProperty,
                        onPickImage,
                        onBrowseImages,
                      ),
                      _splashLayer(
                        S.visualEditorSplashLayout,
                        const {
                          'verticalAlignment',
                          'imageGap',
                          'contentPaddingHorizontal',
                          'contentPaddingVertical',
                          'imagePadding',
                          'textPaddingHorizontal',
                          'textPaddingVertical',
                          'textMarginTop',
                          'textMarginBottom',
                        },
                        editableProps,
                        component,
                        onPropertyChanged,
                        onResetProperty,
                        onPickImage,
                        onBrowseImages,
                      ),
                      _splashLayer(
                        S.visualEditorSplashNavigationSettings,
                        const {
                          'durationMs',
                          'animation',
                          'animationDurationMs',
                        },
                        editableProps,
                        component,
                        onPropertyChanged,
                        onResetProperty,
                        onPickImage,
                        onBrowseImages,
                      ),
                    ] else ...[
                      // تعديل البنارات أول ما يفتح: قائمة البانرات
                      // ومفاتيح التنقل والنقاط فوق كل شيء — الموظف
                      // لا يبحث عنها تحت مجموعات عامة.
                      if (component.componentType == 'bannerCarousel')
                        _BannerDraftControls(
                          component: component,
                          onChanged: onPropertyChanged,
                          onPropertiesChanged: onPropertiesChanged,
                          pickImage:
                              onPickImage ?? DesignImageUpload.pickAndUpload,
                        ),
                      // أقسام بأسلوب فيجما: عائلات الصورة/النص أولًا
                      // بصفوف ثلاثية، ثم بقية المجموعات بترتيب ثابت
                      // (الموضع ← الأبعاد ← المظهر ← الانتقال) — بلا
                      // طيّ يخفي الإعدادات.
                      ...familySections,
                      for (final groupKey in _orderedGroupKeys(
                        reducedGroups.keys,
                      ))
                        _PropertySection(
                          groupLabel: groupKey,
                          fields: _pairBilingualFields(
                            reducedGroups[groupKey]!,
                          ),
                          component: component,
                          onChanged: onPropertyChanged,
                          onReset: onResetProperty,
                          onPickImage: onPickImage,
                          onBrowseImages: onBrowseImages,
                        ),
                      if (extraProps.isNotEmpty)
                        _ExtraPropsGroup(
                          props: extraProps,
                          componentId: component.componentId,
                          onChanged: onPropertyChanged,
                          dark: dark,
                        ),
                    ],
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: isUnbounded ? MainAxisSize.min : MainAxisSize.max,
            children: [
              if (showHeader) ...[
                _InspectorHeader(component: component, entry: entry),
                const Divider(height: 1),
              ],
              if (isUnbounded) content else Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  Widget _splashLayer(
    String title,
    Set<String> keys,
    Map<String, ComponentPropertyDefinition> properties,
    EditableComponent component,
    void Function({
      required String componentId,
      required String propertyKey,
      required dynamic value,
    })
    onChanged,
    void Function({required String componentId, required String propertyKey})
    onReset,
    Future<String?> Function()? onPickImage,
    Future<String?> Function()? onBrowseImages,
  ) {
    if (splashGroup != null && splashGroup != title)
      return const SizedBox.shrink();
    final fields = properties.entries
        .where((entry) => keys.contains(entry.key))
        .toList();
    if (fields.isEmpty) return const SizedBox.shrink();
    return _PropertySection(
      groupLabel: title,
      fields: _pairBilingualFields(fields),
      component: component,
      onChanged: onChanged,
      onReset: onReset,
      onPickImage: onPickImage,
      onBrowseImages: onBrowseImages,
    );
  }
}

/// ترتيب أقسام لوحة الخصائص بأسلوب فيجما: الهندسة أولًا (الموضع ←
/// الأبعاد ← المظهر ← الانتقال ← المسافات) ثم مجموعات المحتوى بترتيب
/// السجل — بلا طيّ يخفي الإعدادات.
const List<String> _figmaSectionOrder = [
  'الموضع',
  'التخطيط',
  'المظهر',
  'الانتقال',
  'المسافات',
];

List<String?> _orderedGroupKeys(Iterable<String?> keys) {
  int rank(String? key) {
    final index = key == null ? -1 : _figmaSectionOrder.indexOf(key);
    return index < 0 ? _figmaSectionOrder.length : index;
  }

  final list = keys.toList()
    ..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : (a ?? '').compareTo(b ?? '');
    });
  return list;
}

/// تصنيف الخصائص إلى عائلات بصفوف موحدة: الصورة، النص.
String? _fieldFamily(ComponentPropertyDefinition d) {
  if (d.type == PropertyType.color ||
      d.type == PropertyType.boolean ||
      d.type == PropertyType.imageUrl ||
      d.type == PropertyType.json) {
    return null;
  }
  if (d.key.startsWith('image') || d.label.contains('الصورة')) {
    return 'image';
  }
  if (d.type == PropertyType.fontSize || d.type == PropertyType.fontWeight) {
    return 'text';
  }
  if (d.type == PropertyType.alignment && d.label.contains('محاذاة')) {
    return 'text';
  }
  const textKeyStems = [
    'size',
    'textWeight',
    'lineHeight',
    'highlight',
    'rest',
    'label',
    'text',
    'subtitle',
    'question',
  ];
  if (textKeyStems.any(d.key.startsWith)) {
    return 'text';
  }
  return null;
}

/// ترتيب حقول العائلة بأولوية ثابتة حتى تتجمع المتقاربات في صفوف
/// منطقية (طريقة العرض/الشكل/المحاذاة ثم الأبعاد...).
void _sortFamilyFields(
  List<MapEntry<String, ComponentPropertyDefinition>> entries,
  List<String> priority,
) {
  int rank(MapEntry<String, ComponentPropertyDefinition> e) {
    final index = priority.indexOf(e.key);
    return index < 0 ? priority.length : index;
  }

  entries.sort((a, b) => rank(a).compareTo(rank(b)));
}

class _PropertySection extends StatelessWidget {
  const _PropertySection({
    required this.groupLabel,
    required this.fields,
    required this.component,
    required this.onChanged,
    required this.onReset,
    this.onPickImage,
    this.onBrowseImages,
    this.fieldsPerRow = 0,
  });

  final String? groupLabel;
  final List<_FieldItem> fields;
  final EditableComponent component;
  final int fieldsPerRow;
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final label = groupLabel?.trim().isNotEmpty == true
        ? groupLabel!
        : S.visualEditorProperties;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ترويسة القسم بنبرة فيجما: عنوان صغير عريض، والمحتوى ظاهر
          // دائمًا تحته بلا طيّ.
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.xs,
              end: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: AppFontWeights.semiBold,
                color: dark ? AppColor.darkText : AppColor.adminHeading,
              ),
            ),
          ),
          _PropertyGroup(
            groupLabel: null,
            fields: fields,
            fieldsPerRow: fieldsPerRow,
            component: component,
            onChanged: onChanged,
            onReset: onReset,
            onPickImage: onPickImage,
            onBrowseImages: onBrowseImages,
          ),
        ],
      ),
    );
  }
}

// --------------- خصائص إضافية (غير مسجلة في السجل) ---------------

class _ExtraPropsGroup extends StatelessWidget {
  const _ExtraPropsGroup({
    required this.props,
    required this.componentId,
    required this.onChanged,
    required this.dark,
  });

  final List<MapEntry<String, dynamic>> props;
  final String componentId;
  final void Function({
    required String componentId,
    required String propertyKey,
    required dynamic value,
  })
  onChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    final body = dark ? AppColor.darkText : AppColor.adminBody;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            'خصائص إضافية',
            style: TextStyle(
              fontSize: AppFontSizes.size10,
              fontWeight: AppFontWeights.semiBold,
              color: muted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        for (final entry in props)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: AppFontSizes.size11,
                    fontWeight: AppFontWeights.medium,
                    color: body,
                  ),
                ),
                const SizedBox(height: 4),
                _ExtraPropField(
                  propKey: entry.key,
                  value: entry.value,
                  componentId: componentId,
                  onChanged: onChanged,
                  dark: dark,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ExtraPropField extends StatefulWidget {
  const _ExtraPropField({
    required this.propKey,
    required this.value,
    required this.componentId,
    required this.onChanged,
    required this.dark,
  });

  final String propKey;
  final dynamic value;
  final String componentId;
  final void Function({
    required String componentId,
    required String propertyKey,
    required dynamic value,
  })
  onChanged;
  final bool dark;

  @override
  State<_ExtraPropField> createState() => _ExtraPropFieldState();
}

class _ExtraPropFieldState extends State<_ExtraPropField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(_ExtraPropField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final newText = widget.value?.toString() ?? '';
      if (_ctrl.text != newText) {
        _ctrl.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // بولياني
    if (widget.value is bool) {
      return Switch.adaptive(
        value: widget.value as bool,
        onChanged: (v) => widget.onChanged(
          componentId: widget.componentId,
          propertyKey: widget.propKey,
          value: v,
        ),
        activeThumbColor: const Color(0xFF5A6A3A),
      );
    }
    // رقمي
    if (widget.value is num) {
      return TextField(
        controller: _ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) {
          final n = num.tryParse(v);
          if (n != null) {
            widget.onChanged(
              componentId: widget.componentId,
              propertyKey: widget.propKey,
              value: n,
            );
          }
        },
        decoration: _inputDecoration(widget.dark),
        style: TextStyle(
          fontSize: 12,
          color: widget.dark ? AppColor.darkText : AppColor.adminBody,
        ),
      );
    }
    // نصي
    return TextField(
      controller: _ctrl,
      onChanged: (v) => widget.onChanged(
        componentId: widget.componentId,
        propertyKey: widget.propKey,
        value: v,
      ),
      decoration: _inputDecoration(widget.dark),
      style: TextStyle(
        fontSize: 12,
        color: widget.dark ? AppColor.darkText : AppColor.adminBody,
      ),
    );
  }

  InputDecoration _inputDecoration(bool dark) => InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(
        color: dark ? AppColor.darkBorder : AppColor.adminCardBorder,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(
        color: dark ? AppColor.darkBorder : AppColor.adminCardBorder,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: const BorderSide(color: Color(0xFF5A6A3A)),
    ),
    filled: true,
    fillColor: dark ? AppColor.darkSurfaceContainer : const Color(0xFFF9F7F4),
  );
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
                  component.componentType == 'splashSettings'
                      ? S.visualEditorSplashImage
                      : entry?.displayName ?? component.componentType,
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

class _BannerDraftControls extends StatefulWidget {
  const _BannerDraftControls({
    required this.component,
    required this.onChanged,
    this.onPropertiesChanged,
    required this.pickImage,
  });

  final EditableComponent component;
  final void Function({
    required String componentId,
    required String propertyKey,
    required dynamic value,
  })
  onChanged;
  final void Function({
    required String componentId,
    required Map<String, dynamic> values,
  })?
  onPropertiesChanged;
  final Future<String?> Function() pickImage;

  @override
  State<_BannerDraftControls> createState() => _BannerDraftControlsState();
}

class _BannerDraftControlsState extends State<_BannerDraftControls> {
  late Future<List<VisualEditorImageAsset>> _targets;
  List<AdminBanner> _publishedBanners = const [];
  bool _loadingBanners = true;
  bool _draftStarted = false;
  String? _draftComponentId;
  int? _uploadingIndex;

  bool get _hasDraft =>
      _draftStarted || widget.component.properties['bannerDraftCount'] != null;

  int get _count =>
      (widget.component.properties['bannerDraftCount'] as num?)?.toInt().clamp(
        0,
        10,
      ) ??
      _publishedBanners.length.clamp(0, 10);

  @override
  void initState() {
    super.initState();
    _draftComponentId = widget.component.componentId;
    _targets = _loadTargets();
    _loadPublishedBanners();
  }

  @override
  void didUpdateWidget(covariant _BannerDraftControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.component.componentId != widget.component.componentId ||
        (oldWidget.component.properties['bannerDraftCount'] != null &&
            widget.component.properties['bannerDraftCount'] == null)) {
      _draftStarted = false;
      _draftComponentId = widget.component.componentId;
    }
  }

  Future<void> _loadPublishedBanners() async {
    try {
      final now = DateTime.now().toUtc();
      final banners = await BannersDependencies.repository.loadBanners();
      if (mounted) {
        setState(
          () => _publishedBanners = banners
              .where((banner) {
                final startsAt = banner.startsAt?.toUtc();
                final endsAt = banner.endsAt?.toUtc();
                return banner.isPublished &&
                    (startsAt == null || !now.isBefore(startsAt)) &&
                    (endsAt == null || !now.isAfter(endsAt));
              })
              .toList(growable: false),
        );
      }
    } catch (_) {
      // The editor remains usable when the customer banner list is unavailable.
    } finally {
      if (mounted) setState(() => _loadingBanners = false);
    }
  }

  Future<List<VisualEditorImageAsset>> _loadTargets() async {
    try {
      final snapshot = await CatalogDependencies.catalog.loadCatalog(
        limit: 100,
      );
      final bundles = await BundlesDependencies.repository.loadBundles();
      return [
        for (final category in snapshot.categories)
          VisualEditorImageAsset(
            kind: VisualEditorImageAssetKind.category,
            id: category.id,
            imageUrl: category.imageUrl ?? '',
            label: AppLocale.instance.isArabic
                ? category.nameAr
                : category.nameEn,
          ),
        for (final product in snapshot.products)
          VisualEditorImageAsset(
            kind: VisualEditorImageAssetKind.product,
            id: product.id,
            imageUrl: product.imageUrl ?? '',
            label: AppLocale.instance.isArabic
                ? product.nameAr
                : product.nameEn,
          ),
        for (final bundle in bundles)
          VisualEditorImageAsset(
            kind: VisualEditorImageAssetKind.bundle,
            id: bundle.id,
            imageUrl: bundle.imageUrl ?? '',
            label: AppLocale.instance.isArabic ? bundle.nameAr : bundle.nameEn,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  void _setMany(Map<String, dynamic> values) {
    final batch = widget.onPropertiesChanged;
    if (batch != null) {
      batch(componentId: widget.component.componentId, values: values);
      return;
    }
    for (final entry in values.entries) {
      widget.onChanged(
        componentId: widget.component.componentId,
        propertyKey: entry.key,
        value: entry.value,
      );
    }
  }

  String _key(int index, String field) => 'bannerDraft_${index}_$field';

  String _bannerValue(int index, String field) {
    if (_hasDraft) {
      return widget.component.properties[_key(index, field)]?.toString() ??
          (field == 'targetType' ? 'none' : '');
    }
    if (index >= _publishedBanners.length) {
      return field == 'targetType' ? 'none' : '';
    }
    final banner = _publishedBanners[index];
    return switch (field) {
      'image' => banner.imageUrl,
      'targetType' => banner.targetType,
      'targetId' => banner.targetId ?? '',
      'targetUrl' => banner.targetUrl ?? '',
      _ => '',
    };
  }

  Map<String, dynamic> _draftSeed() {
    final values = <String, dynamic>{};
    final count = _publishedBanners.length.clamp(0, 10);
    for (var index = 0; index < count; index++) {
      final banner = _publishedBanners[index];
      values[_key(index, 'image')] = banner.imageUrl;
      values[_key(index, 'targetType')] = banner.targetType;
      values[_key(index, 'targetId')] = banner.targetId ?? '';
      values[_key(index, 'targetUrl')] = banner.targetUrl ?? '';
    }
    values['bannerDraftCount'] = count;
    return values;
  }

  void _startDraft({Map<String, dynamic> additional = const {}}) {
    if (_draftComponentId != widget.component.componentId) {
      _draftStarted = false;
      _draftComponentId = widget.component.componentId;
    }
    if (_hasDraft) {
      if (additional.isNotEmpty) _setMany(additional);
      return;
    }
    _draftStarted = true;
    _setMany({..._draftSeed(), ...additional});
  }

  void _updateBanner(int index, String field, dynamic value) {
    _startDraft(additional: {_key(index, field): value});
  }

  Future<void> _uploadImage(int index) async {
    setState(() => _uploadingIndex = index);
    try {
      final url = await widget.pickImage();
      if (url != null && mounted) _updateBanner(index, 'image', url);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _uploadingIndex = null);
    }
  }

  void _deleteBanner(int index) {
    final count = _count;
    const fields = ['image', 'targetType', 'targetId', 'targetUrl'];
    final remaining = [
      for (var current = 0; current < count; current++)
        if (current != index)
          {for (final field in fields) field: _bannerValue(current, field)},
    ];
    final updates = <String, dynamic>{};
    for (var current = 0; current < remaining.length; current++) {
      for (final field in fields) {
        updates[_key(current, field)] = remaining[current][field] ?? '';
      }
    }
    for (final field in fields) {
      updates[_key(remaining.length, field)] = field == 'targetType'
          ? 'none'
          : '';
    }
    updates['bannerDraftCount'] = remaining.length;
    _startDraft(additional: updates);
  }

  @override
  Widget build(BuildContext context) {
    final count = _count;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    bool flag(String key) => widget.component.properties[key] as bool? ?? true;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ترويسة المجموعة: أيقونة + عنوان + عدّاد — ثم بطاقة السلوك
          // بصفّين مفصولين: التنقل التلقائي والنقاط.
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: VisualEditorTokens.accentSurface(context),
                    borderRadius: BorderRadius.circular(
                      VisualEditorTokens.radiusSm,
                    ),
                  ),
                  child: Icon(
                    AppIcons.promotion,
                    size: 14,
                    color: AppColor.primaryColor,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    S.banners,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: AppFontWeights.semiBold,
                      color: VisualEditorTokens.text(context),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: VisualEditorTokens.surfaceSecondary(context),
                    borderRadius: BorderRadius.circular(
                      VisualEditorTokens.radiusPill,
                    ),
                    border: Border.all(
                      color: VisualEditorTokens.border(context),
                    ),
                  ),
                  child: Text(
                    '$count/10',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: AppFontWeights.medium,
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: VisualEditorTokens.surface(context),
              borderRadius: BorderRadius.circular(VisualEditorTokens.radiusMd),
              border: Border.all(color: VisualEditorTokens.border(context)),
            ),
            child: Column(
              children: [
                _BannerBehaviorRow(
                  icon: Icons.motion_photos_on_outlined,
                  label: AppLocale.instance.isArabic
                      ? 'التنقل التلقائي بين البانرات'
                      : 'Autoplay',
                  value: flag('autoplay'),
                  dark: dark,
                  onChanged: (value) => widget.onChanged(
                    componentId: widget.component.componentId,
                    propertyKey: 'autoplay',
                    value: value,
                  ),
                ),
                Divider(height: 1, color: VisualEditorTokens.border(context)),
                _BannerBehaviorRow(
                  icon: Icons.more_horiz_rounded,
                  label: AppLocale.instance.isArabic
                      ? 'نقاط عدد البانرات'
                      : 'Banner count dots',
                  value: flag('showDots'),
                  dark: dark,
                  onChanged: (value) => widget.onChanged(
                    componentId: widget.component.componentId,
                    propertyKey: 'showDots',
                    value: value,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_loadingBanners && count == 0)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          for (var index = 0; index < count; index++)
            _BannerDraftItem(
              key: ValueKey(
                'banner-draft-${widget.component.componentId}-$index',
              ),
              index: index,
              imageUrl: _bannerValue(index, 'image'),
              targetType: _bannerValue(index, 'targetType'),
              targetId: _bannerValue(index, 'targetId'),
              targetUrl: _bannerValue(index, 'targetUrl'),
              targets: _targets,
              uploading: _uploadingIndex == index,
              onUpload: () => _uploadImage(index),
              onDelete: () => _deleteBanner(index),
              onTargetTypeChanged: (value) =>
                  _updateBanner(index, 'targetType', value),
              onTargetIdChanged: (value) =>
                  _updateBanner(index, 'targetId', value),
              onTargetUrlChanged: (value) =>
                  _updateBanner(index, 'targetUrl', value),
            ),
          // إضافة بانر: زر عرض كامل بحد ناعم مائل للون الأساسي.
          Material(
            color: VisualEditorTokens.accentSurface(context),
            borderRadius: BorderRadius.circular(VisualEditorTokens.radiusMd),
            child: InkWell(
              onTap: count >= 10 || _loadingBanners
                  ? null
                  : () {
                      final next = count;
                      final values = <String, dynamic>{};
                      for (final field in const [
                        'image',
                        'targetType',
                        'targetId',
                        'targetUrl',
                      ]) {
                        values[_key(next, field)] = field == 'targetType'
                            ? 'none'
                            : '';
                      }
                      values['bannerDraftCount'] = count + 1;
                      _startDraft(additional: values);
                    },
              borderRadius: BorderRadius.circular(VisualEditorTokens.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    VisualEditorTokens.radiusMd,
                  ),
                  border: Border.all(
                    color: VisualEditorTokens.accentBorder(context),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      AppIcons.add01,
                      size: 15,
                      color: count >= 10 ? muted : AppColor.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      count >= 10
                          ? (AppLocale.instance.isArabic
                                ? 'الحد الأقصى 10 بانرات'
                                : 'Maximum 10 banners')
                          : S.addBanner,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: AppFontWeights.semiBold,
                        color: count >= 10 ? muted : AppColor.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppLocale.instance.isArabic
                ? 'التعديلات تظهر فورًا في المعاينة، ويظهر للزبون بعد النشر.'
                : 'Changes show in the preview immediately; customers see them when published.',
            style: TextStyle(fontSize: AppFontSizes.size10, color: muted),
          ),
        ],
      ),
    );
  }
}

class _BannerDraftItem extends StatelessWidget {
  const _BannerDraftItem({
    super.key,
    required this.index,
    required this.imageUrl,
    required this.targetType,
    required this.targetId,
    required this.targetUrl,
    required this.targets,
    required this.uploading,
    required this.onUpload,
    required this.onDelete,
    required this.onTargetTypeChanged,
    required this.onTargetIdChanged,
    required this.onTargetUrlChanged,
  });

  final int index;
  final String imageUrl;
  final String targetType;
  final String targetId;
  final String targetUrl;
  final Future<List<VisualEditorImageAsset>> targets;
  final bool uploading;
  final VoidCallback onUpload;
  final VoidCallback onDelete;
  final ValueChanged<String> onTargetTypeChanged;
  final ValueChanged<String> onTargetIdChanged;
  final ValueChanged<String> onTargetUrlChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    final body = dark ? AppColor.darkText : AppColor.adminBody;
    final hasImage = imageUrl.trim().isNotEmpty;
    const needsTargetId = ['category', 'product', 'bundle'];

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: VisualEditorTokens.surface(context),
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusMd),
        border: Border.all(color: VisualEditorTokens.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصورة المصغّرة: النقر عليها يرفع صورة جديدة — بلا زر
              // رفع منفصل يشغل مساحة. عند الرفع طبقة تحميل فوقها.
              GestureDetector(
                onTap: uploading ? null : onUpload,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        VisualEditorTokens.radiusSm,
                      ),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: hasImage
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    _uploadPlaceholder(context, dark, muted),
                              )
                            : _uploadPlaceholder(context, dark, muted),
                      ),
                    ),
                    if (uploading)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.4),
                          child: const Center(
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${S.banners} ${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: AppFontWeights.semiBold,
                              color: body,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: onDelete,
                          borderRadius: BorderRadius.circular(
                            VisualEditorTokens.radiusSm,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Icon(
                              AppIcons.delete01,
                              size: 15,
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasImage
                          ? (AppLocale.instance.isArabic
                                ? 'انقر الصورة لتبديلها'
                                : 'Tap the image to replace it')
                          : (AppLocale.instance.isArabic
                                ? 'لا صورة بعد — انقر المربع لرفعها'
                                : 'No image yet — tap to upload'),
                      style: TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // الوجهة: قائمة نوع مضغوطة ثم حقلها الخاص إن وجد.
          DropdownButtonFormField<String>(
            key: ValueKey('banner-target-type-$targetType'),
            initialValue:
                const [
                  'none',
                  'category',
                  'product',
                  'bundle',
                  'url',
                ].contains(targetType)
                ? targetType
                : 'none',
            isDense: true,
            style: TextStyle(fontSize: 12, color: body),
            decoration: _targetDecoration(context, S.targetType),
            items: [
              DropdownMenuItem(value: 'none', child: Text(S.none)),
              DropdownMenuItem(
                value: 'category',
                child: Text(S.targetCategory),
              ),
              DropdownMenuItem(value: 'product', child: Text(S.targetProduct)),
              DropdownMenuItem(value: 'bundle', child: Text(S.bundles)),
              DropdownMenuItem(value: 'url', child: Text(S.url)),
            ],
            onChanged: (value) {
              if (value != null) onTargetTypeChanged(value);
            },
          ),
          if (needsTargetId.contains(targetType)) ...[
            const SizedBox(height: AppSpacing.xs),
            FutureBuilder<List<VisualEditorImageAsset>>(
              future: targets,
              builder: (context, snapshot) {
                final kind = switch (targetType) {
                  'category' => VisualEditorImageAssetKind.category,
                  'product' => VisualEditorImageAssetKind.product,
                  _ => VisualEditorImageAssetKind.bundle,
                };
                final assets =
                    (snapshot.data ?? const <VisualEditorImageAsset>[])
                        .where((asset) => asset.kind == kind)
                        .toList(growable: false);
                final ids = assets.map((asset) => asset.id).toSet();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        'banner-target-choice-$targetType-$targetId',
                      ),
                      initialValue: ids.contains(targetId) ? targetId : null,
                      isDense: true,
                      style: TextStyle(fontSize: 12, color: body),
                      decoration: _targetDecoration(
                        context,
                        targetType == 'category'
                            ? S.targetCategory
                            : targetType == 'product'
                            ? S.targetProduct
                            : S.bundles,
                      ),
                      items: [
                        for (final asset in assets)
                          DropdownMenuItem(
                            value: asset.id,
                            child: Text(
                              asset.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) onTargetIdChanged(value);
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextFormField(
                      key: ValueKey('banner-target-id-$targetId'),
                      initialValue: targetId,
                      style: const TextStyle(fontSize: 12),
                      decoration: _targetDecoration(
                        context,
                        AppLocale.instance.isArabic
                            ? 'أو أدخل المعرّف يدويًا'
                            : 'Or enter the ID manually',
                      ),
                      onChanged: onTargetIdChanged,
                    ),
                  ],
                );
              },
            ),
          ],
          if (targetType == 'url') ...[
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              key: ValueKey('banner-target-url-$targetUrl'),
              initialValue: targetUrl,
              style: const TextStyle(fontSize: 12),
              decoration: _targetDecoration(context, S.targetUrl),
              onChanged: onTargetUrlChanged,
            ),
          ],
        ],
      ),
    );
  }

  Widget _uploadPlaceholder(BuildContext context, bool dark, Color muted) =>
      ColoredBox(
        color: VisualEditorTokens.surfaceSecondary(context),
        child: Center(child: Icon(AppIcons.upload01, size: 18, color: muted)),
      );

  InputDecoration _targetDecoration(BuildContext context, String label) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 11,
          color: VisualEditorTokens.textMuted(context),
        ),
        isDense: true,
        filled: true,
        fillColor: VisualEditorTokens.surfaceSecondary(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
          borderSide: BorderSide(color: VisualEditorTokens.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
          borderSide: BorderSide(color: VisualEditorTokens.border(context)),
        ),
      );
}

// صف سلوك داخل بطاقة البانرات: أيقونة + تسمية + مفتاح — بنفس نبرة
// لوحة المحرر (حدود ناعمة، سطح ثانوي، ودعم داكن).
class _BannerBehaviorRow extends StatelessWidget {
  const _BannerBehaviorRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.dark,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final bool dark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.sm + 2,
        end: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: muted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: AppColor.primaryColor,
            activeThumbColor: Colors.white,
            onChanged: onChanged,
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
    this.fieldsPerRow = 0,
  });

  final String? groupLabel;
  final List<_FieldItem> fields;
  final EditableComponent component;
  final int fieldsPerRow;
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
        // صفوف الخصائص: عائلة مخصصة (٣ حقول بالصف) أو التزاوج
        // العام للحقول الرقمية الصغيرة والأزواج ثنائية اللغة.
        for (final row
            in fieldsPerRow > 0
                ? _chunkFields(fields, fieldsPerRow)
                : _layoutFieldRows(fields))
          if (row.length == 2)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _fieldWidget(
                    component,
                    row[0],
                    onChanged,
                    onReset,
                    onPickImage,
                    onBrowseImages,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _fieldWidget(
                    component,
                    row[1],
                    onChanged,
                    onReset,
                    onPickImage,
                    onBrowseImages,
                  ),
                ),
              ],
            )
          else if (row.length > 1)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _fieldWidget(
                      component,
                      row[i],
                      onChanged,
                      onReset,
                      onPickImage,
                      onBrowseImages,
                    ),
                  ),
                ],
              ],
            )
          else
            _fieldWidget(
              component,
              row.single,
              onChanged,
              onReset,
              onPickImage,
              onBrowseImages,
            ),
      ],
    );
  }

  /// تقسيم مباشر إلى صفوف ثابتة (للعائلات المتقاربة).
  List<List<_FieldItem>> _chunkFields(List<_FieldItem> fields, int size) {
    final rows = <List<_FieldItem>>[];
    for (var i = 0; i < fields.length; i += size) {
      rows.add(fields.sublist(i, (i + size).clamp(0, fields.length)));
    }
    return rows;
  }

  /// تجميع الحقول في صفوف: الحقلان المتتاليان الصغيران (رقم/حجم خط/
  /// مسافة، أو زوج ثنائي اللغة) يتشاركان صفًّا — والباقي منفرد.
  List<List<_FieldItem>> _layoutFieldRows(List<_FieldItem> fields) {
    bool isCompact(_FieldItem item) {
      final def = item.definition ?? item.arDefinition;
      if (def == null) return false;
      return const {
            PropertyType.number,
            PropertyType.integer,
            PropertyType.fontSize,
            PropertyType.spacing,
          }.contains(def.type) ||
          item.arDefinition != null;
    }

    final rows = <List<_FieldItem>>[];
    var pending = List<_FieldItem>.empty(growable: true);
    for (final field in fields) {
      if (isCompact(field)) {
        pending.add(field);
        if (pending.length == 2) {
          rows.add(pending);
          pending = List<_FieldItem>.empty(growable: true);
        }
      } else {
        if (pending.isNotEmpty) {
          rows.add(pending);
          pending = List<_FieldItem>.empty(growable: true);
        }
        rows.add([field]);
      }
    }
    if (pending.isNotEmpty) rows.add(pending);
    return rows;
  }

  Widget _fieldWidget(
    EditableComponent component,
    _FieldItem field,
    void Function({
      required String componentId,
      required String propertyKey,
      required dynamic value,
    })
    onChanged,
    void Function({required String componentId, required String propertyKey})
    onReset,
    Future<String?> Function()? onPickImage,
    Future<String?> Function()? onBrowseImages,
  ) {
    if (field.definition != null) {
      return _PropertyField(
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
      );
    }
    return _BilingualPropertyField(
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

  /// القيمة المعروضة في حقل رقمي: المخزّنة إن وُجدت، وإلا القيمة التي يستخدمها
  /// الرسم فعليًا. بهذا تظهر أبعاد الافتتاحية التلقائية بدل حقل فارغ، ويبقى
  /// الحفظ صريحًا عند أول تعديل للموظف.
  dynamic _effectiveNumberValue(BuildContext context) {
    if (currentValue != null || componentType != 'splashSettings') {
      return currentValue;
    }
    final size = MediaQuery.maybeSizeOf(context);
    if (size == null) return null;
    final defaultWidth = (size.shortestSide * _splashWidthRatio).clamp(
      _splashMinWidth,
      _splashMaxWidth,
    );
    final width = defaultWidth.clamp(40.0, size.shortestSide);
    final displayWidth = width == width.roundToDouble() ? width.round() : width;
    return switch (definition.key) {
      'imageWidth' => displayWidth,
      'imageHeight' => (width * _splashAssetHeight / _splashAssetWidth).round(),
      _ => null,
    };
  }

  Widget _buildInput(BuildContext context) {
    if (definition.type == PropertyType.color &&
        componentType == 'splashSettings') {
      return _SplashColorInput(
        value:
            currentValue?.toString() ??
            definition.defaultValue?.toString() ??
            '#000000',
        pickerKey:
            componentType == 'splashSettings' &&
                definition.key == 'backgroundColor'
            ? const ValueKey('splash-color-picker')
            : ValueKey('color-picker-$componentType-${definition.key}'),
        onChanged: onChanged,
      );
    }
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
        value: _effectiveNumberValue(context),
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
      PropertyType.color => _SplashColorInput(
        value:
            currentValue?.toString() ??
            definition.defaultValue?.toString() ??
            '#000000',
        pickerKey: ValueKey('color-picker-$componentType-${definition.key}'),
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
        optionLabel: _spacingLabel,
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
        fallbackAsset: componentType == 'welcomeHero'
            ? AppImages.welcomeImage
            : null,
        imageFit: componentType == 'welcomeHero'
            ? BoxFit.cover
            : BoxFit.contain,
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
  /// تظهر الترجمتان الحالية معًا حتى لا تُخفى ترجمة عند تحرير النص.
  bool _separate = true;

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
  void didUpdateWidget(_NumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldValue = oldWidget.value ?? oldWidget.defaultValue;
    final newValue = widget.value ?? widget.defaultValue;
    if (oldValue == newValue) return;

    final currentValue = widget.isInteger
        ? int.tryParse(_ctrl.text)
        : double.tryParse(_ctrl.text);
    if (currentValue == newValue) return;
    _ctrl.text = newValue?.toString() ?? '';
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
      decoration: _inputDecoration(dark).copyWith(
        hintText: widget.defaultValue == null ? S.visualEditorAutoValue : null,
      ),
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

class _ColorInput extends StatefulWidget {
  const _ColorInput({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_ColorInput> createState() => _ColorInputState();
}

class _ColorInputState extends State<_ColorInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_ColorInput oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = _parseColor(widget.value) ?? Colors.white;
    return Row(
      children: [
        Tooltip(
          message: S.visualEditorColorHint,
          child: InkWell(
            key: ValueKey('color-picker-${widget.value}'),
            onTap: () => _showPicker(context, color),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              width: 42,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: dark ? AppColor.darkBorder : AppColor.adminCardBorder,
                ),
              ),
              child: Icon(
                AppIcons.paintBrush,
                size: 18,
                color: color.computeLuminance() > 0.5
                    ? AppColor.adminBody
                    : AppColor.whiteColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            controller: _controller,
            onChanged: (v) {
              if (_parseColor(v) != null) widget.onChanged(v);
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

  Future<void> _showPicker(BuildContext context, Color initial) async {
    final hex = await showVisualEditorColorPicker(
      context: context,
      initialColor: initial,
    );
    if (!mounted || hex == null) return;
    _controller.text = hex;
    widget.onChanged(hex);
  }

  Color? _parseColor(String hex) => _parseSplashColor(hex);
}

/// حقل صورة شاشة الافتتاحية: معاينة واختيار من المكتبة أو رفع صورة جديدة.
String _spacingLabel(String token) {
  final size = switch (token) {
    'none' => AppSpacing.none,
    'xxs' => AppSpacing.xxs,
    'xs' => AppSpacing.xs,
    'sm' => AppSpacing.sm,
    'md' => AppSpacing.md,
    'lg' => AppSpacing.lg,
    'xl' => 24.0,
    'xxl' => 32.0,
    'xxxl' => 48.0,
    _ => null,
  };
  return size == null ? token : '$token (${size.toStringAsFixed(0)} px)';
}

class _EnumInput extends StatelessWidget {
  const _EnumInput({
    required this.value,
    required this.options,
    required this.onChanged,
    this.optionLabel,
  });

  final String value;
  final List<String> options;
  final String Function(String)? optionLabel;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final safeValue = options.contains(value)
        ? value
        : (options.isNotEmpty ? options.first : '');
    return DropdownButtonFormField<String>(
      key: ValueKey(safeValue),
      isExpanded: true,
      initialValue: safeValue.isEmpty ? null : safeValue,
      items: options
          .map(
            (o) => DropdownMenuItem(
              value: o,
              child: Text(optionLabel?.call(o) ?? o),
            ),
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

class _SplashColorInput extends StatefulWidget {
  const _SplashColorInput({
    required this.value,
    required this.onChanged,
    this.pickerKey = const ValueKey('splash-color-picker'),
  });

  final String value;
  final ValueChanged<String> onChanged;
  final Key pickerKey;

  @override
  State<_SplashColorInput> createState() => _SplashColorInputState();
}

class _SplashColorInputState extends State<_SplashColorInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_SplashColorInput oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    final color = _parseSplashColor(widget.value) ?? Colors.white;
    return Row(
      children: [
        Tooltip(
          message: S.visualEditorColorHint,
          child: InkWell(
            key: widget.pickerKey,
            onTap: () => _showPicker(context, color),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              width: 42,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColor.darkBorder
                      : AppColor.adminCardBorder,
                ),
              ),
              child: Icon(
                AppIcons.paintBrush,
                size: 18,
                color: color.computeLuminance() > 0.5
                    ? AppColor.adminBody
                    : AppColor.whiteColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              key: ValueKey('${widget.pickerKey}-hex'),
              controller: _controller,
              onChanged: (raw) {
                final normalized = _normalizeSplashColor(raw);
                if (normalized != null) widget.onChanged(normalized);
              },
              style: TextStyle(
                fontSize: AppFontSizes.size12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColor.darkText
                    : AppColor.adminBody,
              ),
              decoration: _inputDecoration(
                Theme.of(context).brightness == Brightness.dark,
              ).copyWith(hintText: S.visualEditorColorHint),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showPicker(BuildContext context, Color initial) async {
    final hex = await showVisualEditorColorPicker(
      context: context,
      initialColor: initial,
    );
    if (!mounted || hex == null) return;
    _controller.text = hex;
    widget.onChanged(hex);
  }
}

Color? _parseSplashColor(String raw) {
  final value = _normalizeSplashColor(raw);
  if (value == null) return null;
  final clean = value.substring(1);
  final parsed = int.tryParse(clean, radix: 16);
  if (parsed == null) return null;
  return clean.length == 8 ? Color(parsed) : Color(0xFF000000 | parsed);
}

String? _normalizeSplashColor(String raw) {
  final clean = raw.trim().replaceFirst('#', '');
  if (!RegExp(r'^(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(clean)) {
    return null;
  }
  return '#${clean.toUpperCase()}';
}

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
    this.fallbackAsset,
    this.imageFit = BoxFit.contain,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final Future<String?> Function() pickAndUpload;
  final Future<String?> Function()? browseImages;
  final String clearLabel;
  final String? fallbackAsset;
  final BoxFit imageFit;

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
    final showImagePreview = url.isNotEmpty || widget.fallbackAsset != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showImagePreview) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              height: 120,
              child: ColoredBox(
                color: dark
                    ? AppColor.darkSurfaceContainer
                    : AppColor.adminTableHeader,
                child: url.isEmpty
                    ? Image.asset(
                        widget.fallbackAsset!,
                        fit: widget.imageFit,
                        errorBuilder: (_, _, _) => Icon(
                          AppIcons.image01,
                          color: dark
                              ? AppColor.darkTextSecondary
                              : AppColor.adminMuted,
                        ),
                      )
                    : Image.network(
                        url,
                        fit: widget.imageFit,
                        errorBuilder: (_, _, _) => Icon(
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
