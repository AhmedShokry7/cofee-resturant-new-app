import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, TextInputFormatter;

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/customer_feed.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_node.dart';
import 'package:admin_app/features/customer_preview/domain/registry/action_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/data_source_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/design_property.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_spec.dart';
import 'package:admin_app/features/customer_preview/domain/services/design_tree.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

/// كتابة خاصية: ترجع سبب الرفض بعد فحص المحرّر إياها، وnull يعني طُبّقت.
typedef DesignPropertyWriter = String? Function(
  String id,
  String key,
  Object? value,
);

/// لوحة الخصائص: ما يملك الموظف تغييريه في العنصر المحدَّد، لا أكثر.
///
/// الحقول من [WidgetSpec.properties] وحدها: لا حقل لخاصية لا يعرفها المكوّن،
/// ولا قائمة فيها قيمة رفضها السجل. الخصائص التي يملؤها حال الهاتف — كالتصنيف
/// الذي تقف عليه شاشة التصنيفات — تُعرض ملاحظة لا حقلًا، لأن يسمّيه المستند
/// نسخة ثانية من قرار الشاشة، والاثنان يتعارضان عند أول نقرة.
class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({
    super.key,
    required this.node,
    required this.page,
    required this.feed,
    required this.enabled,
    required this.onSet,
    required this.onRejection,
  });

  /// العقدة المحدَّدة؛ null يعني لا تحديد، فتقول اللوحة ذلك ولا تتجمَّد.
  final DesignNode? node;
  final AppPage page;

  /// البيانات المقروءة للتصنيفات والمنتجات. null قبل أن تصل، فتكتفي القوائم
  /// بالقيمة المحفوظة في المستند.
  final CustomerFeed? feed;

  /// false في المشاهدة وعلى الصفحة المقفولة: تُعرض القيم ولا تُكتب.
  final bool enabled;
  final DesignPropertyWriter onSet;

  /// سبب رفض وصل من فحص المحرّر: يُطبع للموظف ولا يُبتلع.
  final ValueChanged<String> onRejection;

  AppLanguage get _language => AppLocale.instance.language;

  @override
  Widget build(BuildContext context) {
    final selected = node;
    if (selected == null) return _Message(text: S.builderNoSelection);
    final spec = WidgetRegistry.of(selected.type);
    if (spec == null) {
      // نوع لا يعرفه السجل: لا حقل يُعرض له، فكتابته تصل إلى مستند لا يُرسم.
      return _Message(text: S.builderRejection('unknownType'));
    }
    final fields = <Widget>[
      _Header(name: spec.name.of(_language), type: selected.type),
      const SizedBox(height: AppSpacing.xxs),
      _Message(text: _levelNote(spec)),
      const SizedBox(height: AppSpacing.md),
    ];
    final shown = <Widget>[
      for (final property in spec.properties)
        if (page.supplies(property.key))
          _SuppliedNote(label: property.label.of(_language))
        else
          _field(context, selected, property),
    ];
    if (shown.isEmpty) {
      fields.add(_Message(text: S.builderSuppliedNote));
    } else {
      fields.addAll(shown);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: fields,
    );
  }

  String _levelNote(WidgetSpec spec) => switch (spec.level) {
    WidgetEditLevel.editable => S.builderLevelEditable,
    WidgetEditLevel.partial => S.builderLevelPartial,
    WidgetEditLevel.locked => S.builderLevelLocked,
  };

  Widget _field(
    BuildContext context,
    DesignNode node,
    DesignPropertySpec property,
  ) {
    // مكوّن تحت سيطرة المطوّر: قيمته تُعرض ولا تُكتب، والسطح كله صامت.
    final writable =
        enabled &&
        !DesignTree.isLocked(node.type) &&
        !page.supplies(property.key);
    final label = property.label.of(_language);
    final value = node.property(property.key);
    final control = switch (property.kind) {
      DesignPropertyKind.text => _TextField(
        label: label,
        property: property,
        value: value,
        onChanged: (next) => _write(node.id, property.key, next),
      ),
      DesignPropertyKind.count => _CountField(
        label: label,
        property: property,
        value: value,
        onChanged: (next) => _write(node.id, property.key, next),
      ),
      DesignPropertyKind.toggle => _LabelledToggle(
        label: label,
        value: value is bool
            ? value
            : property.defaultValue is bool && property.defaultValue != null
            ? property.defaultValue! as bool
            : false,
        onChanged: writable
            ? (next) => _write(node.id, property.key, next)
            : null,
      ),
      DesignPropertyKind.token ||
      DesignPropertyKind.choice ||
      DesignPropertyKind.dataSource ||
      DesignPropertyKind.action => _ChoiceField(
        label: label,
        property: property,
        value: value,
        language: _language,
        onChanged: writable
            ? (next) => _write(node.id, property.key, next)
            : null,
      ),
      DesignPropertyKind.categoryReference => _ReferenceField(
        label: label,
        heading: S.builderCategoryField,
        value: value,
        options: _categoryOptions(),
        onChanged: writable
            ? (next) => _write(node.id, property.key, next)
            : null,
      ),
      DesignPropertyKind.productReference => _ReferenceField(
        label: label,
        heading: S.builderProductField,
        value: value,
        options: _productOptions(),
        onChanged: writable
            ? (next) => _write(node.id, property.key, next)
            : null,
      ),
    };
    if (writable) return control;
    return IgnorePointer(
      ignoring: true,
      child: Opacity(opacity: 0.6, child: control),
    );
  }

  /// الكتابة تمرّ بالمحرّر وحده: هو الذي يفحص الحدّين والقيم المسموحة قبل أن
  /// تلمس القيمة المستند، والرفض يعود من فحصه لا من تقدير اللوحة.
  void _write(String id, String key, Object? value) {
    final reason = onSet(id, key, value);
    if (reason != null) onRejection(reason);
  }

  List<_Option> _categoryOptions() {
    final rows = feed?.visibleCategories;
    if (rows == null) return const <_Option>[];
    return <_Option>[
      for (final category in rows)
        _Option(
          value: category.id,
          label: _name(category.nameAr, category.nameEn),
        ),
    ];
  }

  List<_Option> _productOptions() {
    final rows = feed?.catalog;
    if (rows == null) return const <_Option>[];
    return <_Option>[
      for (final product in rows)
        _Option(
          value: product.id,
          label: _name(product.nameAr, product.nameEn),
        ),
    ];
  }

  String _name(String arabic, String english) =>
      _language.isArabic ? arabic : english;
}

/// خيار في قائمة: قيمة المستند وتسميته المقروءة.
class _Option {
  const _Option({required this.value, required this.label});

  final String value;
  final String label;
}

/// اسم المكوّن من السجل، ومفتاح نوعه تحته للمطوّر.
class _Header extends StatelessWidget {
  const _Header({required this.name, required this.type});

  final String name;
  final String type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: AppFonts.semiBold14(context)
                .copyWith(color: adminHeadingColor(theme)),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          type,
          style: TextStyle(
            color: adminSubtleColor(theme),
            fontSize: AppFontSizes.size9,
            fontWeight: AppFontWeights.regular,
          ),
        ),
      ],
    );
  }
}

/// سطر شرح بلا حقل: لا تحديد، أو كل الخصائص يملؤها حال الهاتف.
class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: adminMutedColor(Theme.of(context)),
        fontSize: AppFontSizes.size10_5,
        fontWeight: AppFontWeights.regular,
        height: AppTextHeights.line1_5,
      ),
    );
  }
}

/// خاصية يحدّدها ما يفعله الهاتف: تُسمَّى ولا تُحرَّر.
class _SuppliedNote extends StatelessWidget {
  const _SuppliedNote({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: adminBodyColor(theme),
              fontSize: AppFontSizes.size10_5,
              fontWeight: AppFontWeights.semiBold,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            S.builderSuppliedNote,
            style: TextStyle(
              color: adminSubtleColor(theme),
              fontSize: AppFontSizes.size9,
              fontWeight: AppFontWeights.regular,
              height: AppTextHeights.line1_4,
            ),
          ),
        ],
      ),
    );
  }
}

/// نص يكتبه الموظف: الفراغ يُرفض في الحقل نفسه، فلا جولة كتابة تعرف اللوحة
/// نتائجها سلفًا.
class _TextField extends StatefulWidget {
  const _TextField({
    required this.label,
    required this.property,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DesignPropertySpec property;
  final Object? value;
  final ValueChanged<String?> onChanged;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value is String ? widget.value! as String : '',
  );

  /// آخر ما خرج من هذا الحقل إلى المستند: ما سواه جاء من Undo أو من طبقة أخرى،
  /// فيُطبع في الحقل.
  String? _lastWritten;

  String? _error;

  @override
  void didUpdateWidget(_TextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.value is String ? widget.value! as String : '';
    if (next != _lastWritten && next != _controller.text) {
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final text = raw.trim();
    _lastWritten = text;
    if (text.isEmpty && !widget.property.optional) {
      setState(() => _error = S.builderRequiredField);
      return;
    }
    if (_error != null) setState(() => _error = null);
    // الفراغ في خاصية اختيارية يعني «لا قيمة»، لا نصًا فارغًا في المستند.
    widget.onChanged(text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    return CustomTextFormField(
      label: widget.label,
      hint: S.builderNoValue,
      controller: _controller,
      bottomPadding: AppSpacing.md,
      validator: (_) => _error,
      autovalidateMode: AutovalidateMode.always,
      onChanged: _submit,
    );
  }
}

/// عدد صحيح داخل حدّي المكوّن: الحدّان قرار المطوّر في السجل، ويظهران في
/// الحقل ولا يُمنع الموظف صامتًا.
class _CountField extends StatefulWidget {
  const _CountField({
    required this.label,
    required this.property,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DesignPropertySpec property;
  final Object? value;
  final ValueChanged<int?> onChanged;

  @override
  State<_CountField> createState() => _CountFieldState();
}

class _CountFieldState extends State<_CountField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value is int ? '${widget.value}' : '',
  );

  int? _lastWritten;
  String? _error;

  @override
  void didUpdateWidget(_CountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.value is int ? widget.value! as int : null;
    if (next != _lastWritten && '$next' != _controller.text) {
      _controller.text = next == null ? '' : '$next';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      // خاصية العدد إلزامية في كل السجل: الفراغ يبقى في الحقل لا في المستند.
      setState(() => _error = S.builderCountRequired);
      return;
    }
    final parsed = int.tryParse(text);
    _lastWritten = parsed;
    if (parsed == null) {
      setState(() => _error = S.builderCountRequired);
      return;
    }
    final min = widget.property.min;
    final max = widget.property.max;
    if ((min != null && parsed < min) || (max != null && parsed > max)) {
      setState(() => _error = S.builderCountRange(_bound(min), _bound(max)));
      return;
    }
    if (_error != null) setState(() => _error = null);
    widget.onChanged(parsed);
  }

  String _bound(int? value) => value == null ? '0' : '$value';

  @override
  Widget build(BuildContext context) {
    return CustomTextFormField(
      label: widget.label,
      hint: S.builderCountRange(
        _bound(widget.property.min),
        _bound(widget.property.max),
      ),
      controller: _controller,
      bottomPadding: AppSpacing.md,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      validator: (_) => _error,
      autovalidateMode: AutovalidateMode.always,
      onChanged: _submit,
    );
  }
}

/// علم صحيح/خطأ مع تسميته.
class _LabelledToggle extends StatelessWidget {
  const _LabelledToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: _Label(text: label)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// قائمة بقيم السجل وحدها. قيمة محفوظة لا يعرفها السجل تُعرض كما هي، ولا تُدرج
/// في الخيارات: تختفي طبقة أمام الموظف باسمٍ لم يعد موجودًا خير من أن تُقبل.
class _ChoiceField extends StatelessWidget {
  const _ChoiceField({
    required this.label,
    required this.property,
    required this.value,
    required this.language,
    required this.onChanged,
  });

  final String label;
  final DesignPropertySpec property;
  final Object? value;
  final AppLanguage language;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final current = value is String ? value! as String : null;
    final known = current != null && property.choices.contains(current);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Label(text: label),
          const SizedBox(height: AppSpacing.xxs),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: known ? current : null,
              hint: Text(
                current == null
                    ? '$label: ${S.builderNoValue}'
                    : '$label: $current',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.regular12(context),
              ),
              items: <DropdownMenuItem<String>>[
                for (final choice in property.choices)
                  DropdownMenuItem(
                    value: choice,
                    child: Text(
                      _optionLabel(choice),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.regular12(context),
                    ),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  String _optionLabel(String choice) => switch (property.kind) {
    DesignPropertyKind.dataSource =>
      DataSourceRegistry.of(choice)?.name.of(language) ?? choice,
    DesignPropertyKind.action =>
      ActionRegistry.of(choice)?.name.of(language) ?? choice,
    _ => property.choiceLabel(choice, language),
  };
}

/// قائمة تصنيف أو منتج من البيانات المقروءة: لا معرّف يُكتب باليد، لأن معرّفًا
/// محرَّفًا صفحةُ فارغة عند الزبون.
class _ReferenceField extends StatelessWidget {
  const _ReferenceField({
    required this.label,
    required this.heading,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;

  /// «التصنيف» أو «المنتج»: تُطبع حين لا بيانات مقروءة بعد.
  final String heading;
  final Object? value;
  final List<_Option> options;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final current = value is String ? value! as String : null;
    if (options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: _Message(text: '$heading: ${current ?? S.builderNoValue}'),
      );
    }
    // المعرّف المحفوظ قد لا يكون في ما تُرجم الآن — تصنيف أوقف أو منتج خرج من
    // الفرع. يُعرض باسمه ولا يُستبدل صامتًا، فيراها الموظف ويختار غيرها.
    final listed = options.any((option) => option.value == current);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Label(text: label),
          const SizedBox(height: AppSpacing.xxs),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: listed ? current : null,
              hint: Text(
                listed || current == null ? heading : '$heading: $current',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.regular12(context),
              ),
              items: <DropdownMenuItem<String>>[
                for (final option in options)
                  DropdownMenuItem(
                    value: option.value,
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.regular12(context),
                    ),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// تسمية خاصية فوق حقلها.
class _Label extends StatelessWidget {
  const _Label({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: adminBodyColor(Theme.of(context)),
        fontSize: AppFontSizes.size10_5,
        fontWeight: AppFontWeights.semiBold,
        height: AppTextHeights.line1_4,
      ),
    );
  }
}
