import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/constants/app_images.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/data/design_image_upload.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_color_picker.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';

/// استوديو طبقة الشكل: ألوان الأدوار العشرة ومقياسا النص والتقويس.
///
/// دور يُسقط من الحقول يعني «دع ما عند الزبون كما هو» — الطبقة الحيّة
/// تُبنى من المدخلات غير الفارغة فقط، ومفتاح غائب لا يُكتب في المستند.
/// كل تطبيق كامل هو لمسة تراجع واحدة، لأن [VisualEditorCubit.updateTheme]
/// يستقبل الطبقة دفعة واحدة.
class ThemeStudioDialog extends StatefulWidget {
  const ThemeStudioDialog({
    super.key,
    required this.initialTheme,
    required this.cubit,
  });

  final DesignTheme initialTheme;

  /// يمرّر صراحةً: الحوار في مسار showDialog لا يرث مزوّد الصفحة، فالقراءة
  /// من سياقه تسقط بـ ProviderNotFoundException.
  final VisualEditorCubit cubit;

  @override
  State<ThemeStudioDialog> createState() => _ThemeStudioDialogState();
}

class _ThemeStudioDialogState extends State<ThemeStudioDialog> {
  bool _uploadingLogo = false;
  late final Map<DesignColorRole, TextEditingController> _colors;
  late final TextEditingController _textScale;
  late final TextEditingController _radiusScale;
  late final TextEditingController _appNameAr;
  late final TextEditingController _appNameEn;
  late final TextEditingController _logoUrl;

  @override
  void initState() {
    super.initState();
    final current = widget.initialTheme;
    _colors = {
      for (final role in DesignColorRole.values)
        role: TextEditingController(
          text: current.colors[role] ?? _defaultColor(role),
        ),
    };
    _textScale = TextEditingController(text: widget.initialTheme.textScale);
    _radiusScale = TextEditingController(text: widget.initialTheme.radiusScale);
    _appNameAr = TextEditingController(
      text: widget.initialTheme.appNameAr ?? S.appName,
    );
    _appNameEn = TextEditingController(
      text: widget.initialTheme.appNameEn ?? 'Ghem & Sohob',
    );
    _logoUrl = TextEditingController(text: widget.initialTheme.logoUrl ?? '');
  }

  String _defaultColor(DesignColorRole role) => switch (role) {
    DesignColorRole.primary => '#087F68',
    DesignColorRole.secondary => '#DDF5EE',
    DesignColorRole.background => '#F8FAF8',
    DesignColorRole.surface => '#FFFFFF',
    DesignColorRole.textPrimary => '#22332D',
    DesignColorRole.textSecondary => '#819087',
    DesignColorRole.border => '#E3E9E4',
    DesignColorRole.success => '#2E7D32',
    DesignColorRole.error => '#DC2626',
    DesignColorRole.disabled => '#667085',
  };

  @override
  void dispose() {
    for (final controller in _colors.values) {
      controller.dispose();
    }
    _textScale.dispose();
    _radiusScale.dispose();
    _appNameAr.dispose();
    _appNameEn.dispose();
    _logoUrl.dispose();
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
    appNameAr: _appNameAr.text.trim().isEmpty ? null : _appNameAr.text.trim(),
    appNameEn: _appNameEn.text.trim().isEmpty ? null : _appNameEn.text.trim(),
    logoUrl: _logoUrl.text.trim().isEmpty ? null : _logoUrl.text.trim(),
  );

  bool get _logoIsValid {
    final value = _logoUrl.text.trim();
    if (value.isEmpty) return true;
    return value.startsWith('http://') || value.startsWith('https://');
  }

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
              GridView.count(
                crossAxisCount: 5,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                mainAxisExtent: 104,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final role in DesignColorRole.values)
                    _RoleColorRow(
                      compact: true,
                      role: role,
                      controller: _colors[role]!,
                      dark: dark,
                      body: body,
                      onColorChanged: (value) {
                        _colors[role]!.text = value;
                        if (_validHex(value)) {
                          widget.cubit.updateTheme(_currentTheme);
                        }
                        setState(() {});
                      },
                    ),
                ],
              ),
              Text(
                S.visualEditorBrand,
                style: TextStyle(
                  fontSize: AppFontSizes.size12,
                  fontWeight: AppFontWeights.semiBold,
                  color: muted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _appNameAr,
                      onChanged: (_) => _applyThemeLive(),
                      decoration: InputDecoration(
                        labelText: S.visualEditorBrandNameAr,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _appNameEn,
                      onChanged: (_) => _applyThemeLive(),
                      decoration: InputDecoration(
                        labelText: S.visualEditorBrandNameEn,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _logoUrl,
                          onChanged: (_) {
                            setState(() {});
                            if (_logoIsValid) _applyThemeLive();
                          },
                          decoration: InputDecoration(
                            labelText: S.visualEditorBrandLogoUrl,
                            helperText: _logoIsValid
                                ? S.visualEditorBrandHint
                                : S.visualEditorColorInvalid,
                            errorText: _logoIsValid ? null : '',
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: _uploadingLogo ? null : _pickLogo,
                            icon: _uploadingLogo
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.upload_file_outlined),
                            label: Text(
                              _uploadingLogo
                                  ? S.uploadingImage
                                  : S.visualEditorPickImage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _logoUrl.text.trim().isEmpty
                        ? Image.asset(
                            AppImages.logo,
                            width: 56,
                            height: 56,
                            fit: BoxFit.contain,
                          )
                        : AdminNetworkThumb(
                            imageUrl: _logoUrl.text.trim(),
                            size: 56,
                          ),
                  ),
                ],
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
                onChanged: (value) => setState(() {
                  _textScale.text = value ?? '';
                  _applyThemeLive();
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ScaleDropdown(
                label: S.visualEditorRadiusScale,
                options: DesignContract.radiusScales,
                value: _radiusScale.text.isEmpty ? null : _radiusScale.text,
                onChanged: (value) => setState(() {
                  _radiusScale.text = value ?? '';
                  _applyThemeLive();
                }),
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
            widget.cubit.updateTheme(theme);
            Navigator.of(context).pop();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(S.visualEditorThemeApplied)));
          },
          child: Text(S.save),
        ),
      ],
    );
  }

  void _applyThemeLive() {
    widget.cubit.updateTheme(_currentTheme, recordUndo: false);
  }

  Future<void> _pickLogo() async {
    setState(() => _uploadingLogo = true);
    try {
      final url = await DesignImageUpload.pickAndUpload();
      if (!mounted || url == null) return;
      _logoUrl.text = url;
      _applyThemeLive();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${S.imageCouldNotBeOpened}: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }
}

/// صف دور لوني: حقل hex + عيّنة اللون الحيّة.
///
/// Stateful: التحكم في حقل النص مشترك مع الوالد، لكن العيّنة ورسالة الخطأ
/// تعتمدان على النص الحالي، فالاستماع له هو ما يعيد رسمهما عند كل حرف.
class _RoleColorRow extends StatefulWidget {
  const _RoleColorRow({
    this.compact = false,
    required this.role,
    required this.controller,
    required this.dark,
    required this.body,
    required this.onColorChanged,
  });

  final bool compact;
  final DesignColorRole role;
  final TextEditingController controller;
  final bool dark;
  final Color body;
  final ValueChanged<String> onColorChanged;

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
    if (widget.compact) {
      final color = valid
          ? Color(
              int.parse(controller.text.substring(1), radix: 16) | 0xFF000000,
            )
          : Colors.transparent;
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: dark ? AppColor.darkSurface : Colors.white,
          border: Border.all(
            color: dark ? AppColor.darkBorder : AppColor.adminControlBorder,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _labels[widget.role]!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: body),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: dark
                            ? AppColor.darkBorder
                            : AppColor.adminControlBorder,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  tooltip: S.visualEditorThemeStudio,
                  onPressed: _showPicker,
                  icon: const Icon(Icons.palette_outlined, size: 17),
                ),
              ],
            ),
          ],
        ),
      );
    }
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
                  style: TextStyle(fontSize: AppFontSizes.size12, color: body),
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
              onChanged: widget.onColorChanged,
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
              style: TextStyle(fontSize: AppFontSizes.size12, color: body),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: S.visualEditorThemeStudio,
            onPressed: _showPicker,
            icon: const Icon(Icons.palette_outlined),
          ),
        ],
      ),
    );
  }

  void _showPicker() {
    final controller = _controller;
    final valid = _validHex(controller.text);
    final initial = valid
        ? Color(int.parse(controller.text.substring(1), radix: 16) | 0xFF000000)
        : AppColor.primaryColor;
    showVisualEditorColorPicker(context: context, initialColor: initial).then((
      hex,
    ) {
      if (!mounted || hex == null) return;
      widget.onColorChanged(hex);
    });
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
