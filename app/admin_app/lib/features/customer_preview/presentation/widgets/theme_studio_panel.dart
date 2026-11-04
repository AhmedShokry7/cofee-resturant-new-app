import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, TextInputFormatter;

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_theme.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_palette.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

/// كتابة لون دور: ترجع سبب الرفض بعد فحص المحرّر إياه، وnull يعني طُبِّق.
typedef ThemeColorWriter = String? Function(DesignColorRole role, String hex);

/// كتابة مقياس خط باسم المفتاح، لا برقم: الرقم يقرّر العميل حين يقرأ الشاشة.
typedef ThemeScaleWriter = String? Function(String key);

/// استوديو الشكل: الأدوار التي يراها الموظف في الهاتف، لا كل أدوار العقد.
///
/// القائمة من [SimulatorPalette.paintRoles] وحدها: دور لا يغلفه موضع بعد يُترك
/// في المستند للمطوّر، فلا يلوّن الموظف شيئًا لا يظهر له أبدًا. وما لا يُكتب يبقى
/// على لونه عند الزبون، فاللوحة overrides لا شاشة جديدة، و«الرجوع للتصميم الأصلي»
/// حذف كتابة لا تذكّر قيم.
class ThemeStudioPanel extends StatelessWidget {
  const ThemeStudioPanel({
    super.key,
    required this.theme,
    required this.enabled,
    required this.onSetColor,
    required this.onClearColor,
    required this.onTextScale,
    required this.onRestoreAll,
    required this.onRejection,
  });

  final DesignTheme theme;

  /// false في المشاهدة: الأدوار تُقرأ ولا تُكتب، كما في لوحة الخصائص.
  final bool enabled;
  final ThemeColorWriter onSetColor;
  final ValueChanged<DesignColorRole> onClearColor;
  final ThemeScaleWriter onTextScale;
  final VoidCallback onRestoreAll;

  /// رفض وصل من المحرّر لموضعه في الحقل (مقياس مرفوض، طبقة مقفولة): يُطبع ولا
  /// يُبتلع، كما تفعل لوحة الخصائص مع كتابتها.
  final ValueChanged<String> onRejection;

  AppLanguage get _language => AppLocale.instance.language;

  @override
  Widget build(BuildContext context) {
    final overridden = theme.colors.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Note(text: S.builderThemeNote),
        const SizedBox(height: AppSpacing.md),
        _Heading(title: S.builderThemeColors, count: overridden),
        const SizedBox(height: AppSpacing.sm),
        for (final role in SimulatorPalette.paintRoles) ...[
          _ColorRoleRow(
            // الدور مفتاح الحقل: التبديل بين الصفحات لا يعيد كتابة الحقل من
            // الصفر، والقيمة فيه تبقى ما كُتب لهذا الدور وحده.
            key: ValueKey('theme-${role.key}'),
            role: role,
            hex: theme.colors[role],
            enabled: enabled,
            onApply: (hex) => onSetColor(role, hex),
            onClear: () => onClearColor(role),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _Heading(title: S.builderThemeText, count: null),
        const SizedBox(height: AppSpacing.xs),
        _ScaleRow(
          label: S.builderThemeTextScale,
          keys: DesignScale.textKeys,
          value: theme.textScale,
          language: _language,
          enabled: enabled,
          // الرفض من المحرّر لا من تقدير اللوحة: مقياس لا يقبله المستند يبقى
          // اسمه ومبرّره أمام الموظف.
          onChanged: (key) {
            final reason = onTextScale(key);
            if (reason != null) onRejection(reason);
          },
        ),
        if (enabled && theme.isChanged) ...[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: onRestoreAll,
              child: Text(S.builderThemeRestoreAll),
            ),
          ),
        ],
      ],
    );
  }
}

/// سطر دور لون: اسمه، ما كُتب له، ومربّع يشرح أنه سيُرسم.
class _ColorRoleRow extends StatefulWidget {
  const _ColorRoleRow({
    super.key,
    required this.role,
    required this.hex,
    required this.enabled,
    required this.onApply,
    required this.onClear,
  });

  final DesignColorRole role;

  /// القيمة المكتوبة في المستند؛ null يعني بلا كتابة، فيبقى الدور على لونه.
  final String? hex;
  final bool enabled;

  /// كتابة اللون: ترجع سبب الرفض، فيُطبع تحت الحقل نفسه بدل أن يضيع.
  final String? Function(String hex) onApply;
  final VoidCallback onClear;

  @override
  State<_ColorRoleRow> createState() => _ColorRoleRowState();
}

class _ColorRoleRowState extends State<_ColorRoleRow> {
  AppLanguage get _language => AppLocale.instance.language;

  late final TextEditingController _controller = TextEditingController(
    text: widget.hex ?? '',
  );

  /// آخر ما خرج من هذا الحقل إلى المستند: ما سواه جاء من تراجع أو إعادة أو من
  /// رجوعٍ للأصل، فيُطبع في الحقل كما يطبع في الهاتف.
  String? _lastWritten;

  String? _error;

  @override
  void didUpdateWidget(_ColorRoleRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.hex ?? '';
    if (next != _lastWritten && next != _controller.text) {
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// `#` اختيارية في الكتابة: الستّة الأوحى بها تكمل نفسها، وما عداها يبقى في
  /// الحقل بخطأ موضعي لا يصل إلى المستند.
  static String _normalize(String raw) {
    final text = raw.trim();
    final bare = text.startsWith('#') ? text.substring(1) : text;
    return RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(bare) ? '#$bare' : text;
  }

  void _submit(String raw) {
    final value = _normalize(raw);
    if (value == (widget.hex ?? '')) {
      if (_error != null) setState(() => _error = null);
      return;
    }
    // الصيغة الكاملة أولًا، فالسؤال «هل تمّ اللون؟» يسبق «أهو نصف كتابة؟»:
    // #RRGGBB نفسه كان يمرّ من فرع النصف ويسقط بلا تطبيق.
    if (DesignTheme.isHexColor(value)) {
      if (_error != null) setState(() => _error = null);
      // الكتابة تمرّ بالمحرّر: هو من يفحص الطبقة ثم يكتبها خطوة تراجع واحدة.
      _lastWritten = value.toUpperCase();
      final reason = widget.onApply(value);
      if (reason != null) setState(() => _error = reason);
      return;
    }
    // نصف كتابة ليس خطأ: ستّ أوحى تكتمل في الحقل قبل أن تُرسل إليه.
    if (RegExp(r'^#?[0-9a-fA-F]{0,5}$').hasMatch(value)) {
      if (_error != null) setState(() => _error = null);
      return;
    }
    setState(() => _error = S.builderThemeColorFormat);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final written = widget.hex;
    final field = CustomTextFormField(
      // الاسم فوق الحقل لا داخله: المربّع اللوني وحده لا يكفي حين
      // يختلف دورٌ عن غيره من الأدوار المطفأة.
      label: widget.role.label(_language),
      hint: written == null ? S.builderThemeSystemValue : '#RRGGBB',
      controller: _controller,
      bottomPadding: 0,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      inputFormatters: <TextInputFormatter>[_HexCharsFormatter()],
      validator: (_) => _error,
      autovalidateMode: AutovalidateMode.always,
      onChanged: _submit,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Swatch(colorHex: written),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            // الطبقة تُقرأ في المشاهدة ولا تُكتب: الحقل مطفأ كما في لوحة
            // الخصائص، فالكتابة هنا ستخطوة تراجع على مستند لا يُحفظ.
            child: IgnorePointer(
              key: ValueKey('theme-field-${widget.role.key}'),
              ignoring: !widget.enabled,
              child: Opacity(
                opacity: widget.enabled ? 1 : 0.6,
                child: field,
              ),
            ),
          ),
          if (written != null)
            IconButton(
              tooltip: S.builderThemeRestoreOne(widget.role.label(_language)),
              icon: Icon(
                AppIcons.refresh,
                size: AppDimensions.iconSizeSm,
                color: adminMutedColor(theme),
              ),
              onPressed: widget.enabled ? widget.onClear : null,
            ),
        ],
      ),
    );
  }
}

/// حرفان ستّ عشرانيان و`#` أول الكتابة، لا أكثر: الحقل لا يقبل ما يرفضة المحرّر
/// بعد ذلك بسطر كامل.
class _HexCharsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = FilteringTextInputFormatter.allow(
      RegExp(r'[#0-9a-fA-F]'),
    ).formatEditUpdate(oldValue, newValue);
    if (filtered.text.length <= 9) return filtered;
    return filtered.copyWith(
      text: filtered.text.substring(0, 9),
      selection: TextSelection.collapsed(offset: 9),
    );
  }
}

/// مربّع اللون المكتوب، ومربّع مفرّغ لما لا كتابة له: الفراغ هنا معنى، لا نقص
/// رسم — الدور يرث لون العميل.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.colorHex});

  final String? colorHex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = _parse(colorHex);
    return Container(
      width: AppDimensions.builderSwatchSize,
      height: AppDimensions.builderSwatchSize,
      decoration: BoxDecoration(
        color: parsed,
        border: Border.all(
          color: parsed == null ? adminSubtleColor(theme) : adminCardBorderColor(theme),
          width: parsed == null ? AppSizes.px1 : AppDimensions.builderIndicatorStroke,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );
  }

  static Color? _parse(String? hex) {
    if (hex == null) return null;
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    if (value == null) return null;
    return hex.length == 9 ? Color(value) : Color(0xFF000000 | value);
  }
}

/// مقياس باسمه: الخيارات من [DesignScale] وحدها، فلا رقم حرّ يصل إلى شاشة الزبون.
class _ScaleRow extends StatelessWidget {
  const _ScaleRow({
    required this.label,
    required this.keys,
    required this.value,
    required this.language,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final Set<String> keys;
  final String value;
  final AppLanguage language;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // مقياس محفوظ لا يعرفه السجل يبقى ظاهرًا باسمه: يختفي قرار الموظف أمامه
    // خير من أن يُقبل مقياس لا يرسمه أحد.
    final known = keys.contains(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: AppFonts.regular12(
            context,
          ).copyWith(color: adminBodyColor(Theme.of(context))),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final key in _orderedKeys)
              _ScaleChip(
                label: DesignScale.label(key, language, true),
                selected: known && key == value,
                onTap: enabled ? () => onChanged(key) : null,
              ),
          ],
        ),
      ],
    );
  }

  /// `default` أولًا: هو الرجوع، والموظف يراه قبل أن يبحث عنه بين ثلاث زيادات.
  List<String> get _orderedKeys => <String>[
    DesignScale.defaultKey,
    for (final key in keys)
      if (key != DesignScale.defaultKey) key,
  ];
}

class _ScaleChip extends StatelessWidget {
  const _ScaleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap!(),
    );
  }
}

/// عنوان قسم داخل اللوحة، وعدّ ما كُتب تحته.
class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppFonts.semiBold14(
              context,
            ).copyWith(color: adminHeadingColor(theme)),
          ),
        ),
        if (count != null && count! > 0)
          Text(
            '$count',
            style: TextStyle(
              color: adminSubtleColor(theme),
              fontSize: AppFontSizes.size11,
              fontWeight: AppFontWeights.semiBold,
            ),
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = adminMutedColor(theme);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          AppIcons.informationCircle,
          size: AppDimensions.iconSizeSm,
          color: tone,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: tone,
              fontSize: AppFontSizes.size10_5,
              fontWeight: AppFontWeights.regular,
              height: AppTextHeights.line1_5,
            ),
          ),
        ),
      ],
    );
  }
}
