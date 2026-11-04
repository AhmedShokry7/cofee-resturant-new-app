import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_template.dart';
import 'package:admin_app/features/customer_preview/domain/registry/template_registry.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

/// معرض القوالب: ترتيب جاهز بضغطة، وحفظ ما أعجب الموظف بضغطة.
///
/// القسمان منفصلان بالنية لا بالشكل. المضمّنات من سجلّ القوالب في Dart، لأنها
/// تُبنى من مكوّنات السجل نفسه — نسخة منها في القاعدة كانت ستجمّد خصائص مقاطع
/// يحرّرها السجل بعدها. المحفوظة صفوف في `core.app_design_templates`: اسمها
/// وملفّها عملٌ للموظف، لا شيء في التطبيق يسمّيه.
///
/// التطبيق لا ينشر: القالب يدخل المسودة، والزبون لا يرى شيئًا حتى يضغط الموظف
/// «نشر» بعد أن يرى أثره في الهاتف.
class TemplatesGalleryPanel extends StatefulWidget {
  const TemplatesGalleryPanel({
    super.key,
    required this.saved,
    required this.enabled,
    required this.onApplyBuiltIn,
    required this.onApplySaved,
    required this.onSave,
    required this.onDelete,
  });

  /// ما حفظه الموظف، بأسمائها لا بملفّاتها.
  final List<DesignTemplate> saved;

  /// false في المشاهدة: القالب يُقرأ ولا يُطبَّق، كصفحة لا تُحرَّر.
  final bool enabled;
  final ValueChanged<AppTemplate> onApplyBuiltIn;
  final ValueChanged<String> onApplySaved;

  /// حفظ باسم؛ ترجع true حين وصل القالب إلى القاعدة. الرفض يُطبع في لوحة
  /// الحالة كما تفعل كل كتابة في المحرّر، فلا قناة ثانية للخطأ في هذه الشاشة.
  final Future<bool> Function(String name) onSave;
  final ValueChanged<String> onDelete;

  @override
  State<TemplatesGalleryPanel> createState() => _TemplatesGalleryPanelState();
}

class _TemplatesGalleryPanelState extends State<TemplatesGalleryPanel> {
  final TextEditingController _name = TextEditingController();

  /// حفظ جارٍ: الزرّ لا يُضغط مرتين فيقبض المعرض على قالبين باسم واحد.
  bool _saving = false;

  String? _rejected;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _rejected = S.builderTemplateNameMissing);
      return;
    }
    setState(() {
      _saving = true;
      _rejected = null;
    });
    final saved = await widget.onSave(name);
    if (!mounted) return;
    setState(() {
      _saving = false;
      // الرفض سببه في لوحة الحالة لا هنا: الحقل يخبر عن اسمه، والمحرّر يخبر
      // عمّا رفضته القاعدة. رسالة ثانية كانت ستخالف السبب وتُقرأ منه.
      if (saved) _name.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final language = AppLocale.instance.language;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(S.builderTemplatesNote, style: AppFonts.regular12(context)),
        const SizedBox(height: AppSpacing.md),
        _Heading(title: S.builderBuiltinTemplates),
        const SizedBox(height: AppSpacing.sm),
        for (final template in TemplateRegistry.builtIns)
          _TemplateRow(
            key: ValueKey('builtin-${template.slug}'),
            title: template.name(language),
            subtitle: template.note(language),
            enabled: widget.enabled,
            onApply: () => widget.onApplyBuiltIn(template),
          ),
        const SizedBox(height: AppSpacing.lg),
        _Heading(
          title: S.builderSavedTemplates,
          trailing: '${widget.saved.length}',
        ),
        const SizedBox(height: AppSpacing.sm),
        if (widget.saved.isEmpty)
          Text(S.builderNoSavedTemplates, style: AppFonts.regular12(context)),
        for (final template in widget.saved)
          _TemplateRow(
            key: ValueKey('saved-${template.id}'),
            title: template.name,
            subtitle: _savedOn(template.updatedAt, language),
            enabled: widget.enabled,
            onApply: () => widget.onApplySaved(template.id),
            onDelete: () => widget.onDelete(template.id),
          ),
        const SizedBox(height: AppSpacing.md),
        // القراءة في المشاهدة لا الكتابة: الحقل مطفأ كما في استوديو الشكل،
        // فحفظ قالب من مستند لا يُحرَّر ورقة لا يمسها أحد.
        IgnorePointer(
          ignoring: !widget.enabled || _saving,
          child: Opacity(
            opacity: widget.enabled && !_saving ? 1 : 0.6,
            child: CustomTextFormField(
              key: const ValueKey('template-name-field'),
              hint: S.builderTemplateNameHint,
              controller: _name,
              bottomPadding: 0,
              textInputAction: TextInputAction.done,
              validator: (_) => _rejected,
              autovalidateMode: AutovalidateMode.always,
              onFieldSubmitted: (_) => _save(),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const ValueKey('template-save-button'),
          onPressed: widget.enabled && !_saving ? _save : null,
          icon: Icon(AppIcons.layers01, size: AppDimensions.iconSizeSm),
          label: Text(S.builderSaveAsTemplate),
        ),
      ],
    );
  }

  /// تاريخ الحفظ بلغة اللوحة. الصف الذي لا وقت له يظهر بلا وقت: تاريخ مختلَق
  /// يخدع الموظف في مقارنة قوالبه.
  String _savedOn(DateTime updatedAt, AppLanguage language) {
    if (updatedAt.year < 2000) return '';
    final local = updatedAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return language.isArabic
        ? '$day/$month/${local.year}'
        : '${local.year}-$month-$day';
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppFonts.semiBold14(context)),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(trailing!, style: AppFonts.regular12(context)),
        ],
      ],
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onApply,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onApply;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppFonts.semiBold14(context)),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: AppFonts.regular12(context),
                    maxLines: 3,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          TextButton(
            key: Key('template-apply-$title'),
            onPressed: enabled ? onApply : null,
            child: Text(S.builderApplyTemplate),
          ),
          if (onDelete != null)
            IconButton(
              key: Key('template-delete-$title'),
              onPressed: enabled ? onDelete : null,
              icon: Icon(
                AppIcons.delete01,
                size: AppDimensions.iconSizeSm,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: S.builderDeleteTemplate,
            ),
        ],
      ),
    );
  }
}
