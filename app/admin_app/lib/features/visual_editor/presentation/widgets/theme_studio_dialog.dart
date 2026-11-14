import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';

/// استوديو طبقة الشكل: ألوان الأدوار العشرة ومقياسا النص والتقويس.
///
/// دور يُسقط من الحقول يعني «دع ما عند الزبون كما هو» — الطبقة الحيّة
/// تُبنى من المدخلات غير الفارغة فقط، ومفتاح غائب لا يُكتب في المستند.
/// كل تطبيق كامل هو لمسة تراجع واحدة، لأن [VisualEditorCubit.updateTheme]
/// يستقبل الطبقة دفعة واحدة.
class ThemeStudioDialog extends StatefulWidget {
  const ThemeStudioDialog({super.key, required this.initialTheme});

  final DesignTheme initialTheme;

  @override
  State<ThemeStudioDialog> createState() => _ThemeStudioDialogState();
}

class _ThemeStudioDialogState extends State<ThemeStudioDialog> {
  late final Map<DesignColorRole, TextEditingController> _colors;
  late final TextEditingController _textScale;
  late final TextEditingController _radiusScale;

  @override
  void initState() {
    super.initState();
    _colors = {
      for (final role in DesignColorRole.values)
        role: TextEditingController(text: widget.initialTheme.colors[role]),
    };
    _textScale = TextEditingController(text: widget.initialTheme.textScale);
    _radiusScale = TextEditingController(
      text: widget.initialTheme.radiusScale,
    );
  }

  @override
  void dispose() {
    for (final controller in _colors.values) {
      controller.dispose();
    }
    _textScale.dispose();
    _radiusScale.dispose();
    super.dispose();
  }

  /// الطبقة كما يملؤها الحقول الآن: القيم الفارغة دورًا غائبًا.
  DesignTheme get _currentTheme => DesignTheme(
    colors: {
      for (final entry in _colors.entries)
        if (_validHex(entry.value.text)) entry.key: entry.value.text.trim(),
    },
    textScale: _textScale.text.trim().isEmpty ? null : _textScale.text.trim(),
    radiusScale: _radiusScale.text.trim().isEmpty
        ? null
        : _radiusScale.text.trim(),
  );

  /// `#RRGGBB` أو `#AARRGGBB` — كما تدقق القاعدة قبل أن يصل المستند إليها.
  bool _validHex(String raw) {
    final value = raw.trim();
    if (!value.startsWith('#')) return false;
    final hex = value.substring(1);
    if (hex.length != 6 && hex.length != 8) return false;
    return int.tryParse(hex, radix: 16) != null;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    final body = dark ? AppColor.darkText : AppColor.adminBody;
    return AlertDialog(
      title: Text(S.visualEditorThemeStudio),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.visualEditorThemeColors,
                style: TextStyle(
                  fontSize: AppFontSizes.size12,
                  fontWeight: AppFontWeights.semiBold,
                  color: muted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final role in DesignColorRole.values)
                _RoleColorRow(
                  role: role,
                  controller: _colors[role]!,
                  dark: dark,
                  body: body,
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                S.visualEditorThemeScales,
                style: TextStyle(
                  fontSize: AppFontSizes.size12,
                  fontWeight: AppFontWeights.semiBold,
                  color: muted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ScaleDropdown(
                label: S.visualEditorTextScale,
                options: DesignContract.textScales,
                value: _textScale.text.isEmpty ? null : _textScale.text,
                onChanged: (value) =>
                    setState(() => _textScale.text = value ?? ''),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ScaleDropdown(
                label: S.visualEditorRadiusScale,
                options: DesignContract.radiusScales,
                value: _radiusScale.text.isEmpty ? null : _radiusScale.text,
                onChanged: (value) =>
                    setState(() => _radiusScale.text = value ?? ''),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
        FilledButton(
          onPressed: () {
            final theme = _currentTheme;
            context.read<VisualEditorCubit>().updateTheme(theme);
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(S.visualEditorThemeApplied)),
            );
          },
          child: Text(S.save),
        ),
      ],
    );
  }
}

/// صف دور لوني: حقل hex + عيّنة اللون الحيّة.
///
/// Stateful: التحكم في حقل النص مشترك مع الوالد، لكن العيّنة ورسالة الخطأ
/// تعتمدان على النص الحالي، فالاستماع له هو ما يعيد رسمهما عند كل حرف.
class _RoleColorRow extends StatefulWidget {
  const _RoleColorRow({
    required this.role,
    required this.controller,
    required this.dark,
    required this.body,
  });

  final DesignColorRole role;
  final TextEditingController controller;
  final bool dark;
  final Color body;

  @override
  State<_RoleColorRow> createState() => _RoleColorRowState();
}

class _RoleColorRowState extends State<_RoleColorRow> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant _RoleColorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _controller.removeListener(_onTextChanged);
      _controller = widget.controller;
      _controller.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    super.dispose();
  }

  /// اسم الدور بالعربية كما يراه الموظف، والمفتاح الإنجليزي تحته.
  static const _labels = <DesignColorRole, String>{
    DesignColorRole.primary: 'اللون الأساسي',
    DesignColorRole.secondary: 'اللون الثانوي',
    DesignColorRole.background: 'خلفية الصفحة',
    DesignColorRole.surface: 'سطح البطاقات',
    DesignColorRole.textPrimary: 'النص الرئيسي',
    DesignColorRole.textSecondary: 'النص الثانوي',
    DesignColorRole.border: 'الحدود',
    DesignColorRole.success: 'النجاح',
    DesignColorRole.error: 'الخطأ',
    DesignColorRole.disabled: 'المعطّل',
  };

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final valid = _validHex(controller.text);
    final dark = widget.dark;
    final body = widget.body;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _labels[widget.role]!,
                  style: TextStyle(
                    fontSize: AppFontSizes.size12,
                    color: body,
                  ),
                ),
                Text(
                  widget.role.key,
                  style: TextStyle(
                    fontSize: AppFontSizes.size10,
                    color: dark
                        ? AppColor.darkTextSecondary
                        : AppColor.adminMuted,
                  ),
                ),
              ],
            ),
          ),
          // عيّنة: لون صالح يرسم نفسه، فالموظف يرى ما سيصل إلى الهاتف.
          Container(
            width: AppDimensions.iconSizeSm,
            height: AppDimensions.iconSizeSm,
            decoration: BoxDecoration(
              color: valid
                  ? Color(
                      int.parse(controller.text.substring(1), radix: 16) |
                          0xFF000000,
                    )
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: dark ? AppColor.darkBorder : AppColor.adminControlBorder,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: TextField(
              controller: controller,
              onChanged: (_) {},
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                hintText: S.visualEditorColorHint,
                errorText: controller.text.isEmpty || valid
                    ? null
                    : S.visualEditorColorInvalid,
                border: const OutlineInputBorder(),
              ),
              style: TextStyle(
                fontSize: AppFontSizes.size12,
                color: body,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _validHex(String raw) {
    final value = raw.trim();
    if (!value.startsWith('#')) return false;
    final hex = value.substring(1);
    if (hex.length != 6 && hex.length != 8) return false;
    return int.tryParse(hex, radix: 16) != null;
  }
}

/// مقياس من قائمة العقد (textScales/radiusScales)، و«بدون» يعيد الأصل.
class _ScaleDropdown extends StatelessWidget {
  const _ScaleDropdown({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final String? value;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final body = dark ? AppColor.darkText : AppColor.adminBody;
    final valid = value == null || options.contains(value);
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(fontSize: AppFontSizes.size12, color: body),
          ),
        ),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: valid ? value : null,
            isDense: true,
            items: [
              DropdownMenuItem(
                child: Text(
                  S.visualEditorThemeNone,
                  style: TextStyle(fontSize: AppFontSizes.size12),
                ),
              ),
              for (final option in options)
                DropdownMenuItem(
                  value: option,
                  child: Text(
                    option,
                    style: TextStyle(fontSize: AppFontSizes.size12),
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
