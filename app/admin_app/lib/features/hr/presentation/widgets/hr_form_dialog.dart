import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:flutter/material.dart';

/// هيكل حوارات HR: رأس، ثم حقول بعرض ثابت في منطقة تمرير، ثم شريط حفظ واحد.
///
/// العرض محصور لأن الحوار يفتح على مكتب وعلى هاتف في المسار نفسه، والعمود
/// الضيق يبقى مقروءًا في الاثنين؛ والشريط موحّد كي لا يخترع كل حوار زرًّا
/// ثالثًا أو يحفظ بلا أن يدري المدير أنه قيد الإرسال.
///
/// الحقول داخل تمرير لأن أطول حواراتنا — جدول العمل والسلفة — تتجاوز ارتفاع
/// الشاشة على الهاتف: بلا منطقة تمرير كان الحقل الأخير وشريط الخطأ يُقصّان،
/// فيضغط المدير حفظًا لا يرى سبب رفضه.
class HrFormDialog extends StatelessWidget {
  const HrFormDialog({
    super.key,
    required this.title,
    required this.children,
    required this.saveLabel,
    required this.onSave,
    this.subtitle,
    this.error,
    this.saveKey = const Key('hr-form-save'),
    this.cancelLabel,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final String saveLabel;
  final VoidCallback onSave;

  /// سبب رفض الحفظ، يُعرض فوق الحقول لا تحتها: الشريط والأسفل كانا يخرجَان من
  /// الشاشة على الهاتف، فيبقى المدير بلا حرف يشرح لماذا لم يُرسل شيء.
  final String? error;
  final Key saveKey;
  final String? cancelLabel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      titlePadding: EdgeInsets.zero,
      actionsPadding: EdgeInsets.zero,
      content: SizedBox(
        width: AppDimensions.dialogBodyWidthMedium,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminDialogHeader(
              title: title,
              subtitle: subtitle,
              onClose: () => Navigator.of(context).pop(),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: AdminErrorBanner(message: error!),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
            AdminDialogFooter(
              saving: false,
              onCancel: () => Navigator.of(context).pop(),
              onSave: onSave,
              saveKey: saveKey,
              saveLabel: saveLabel,
              savingLabel: saveLabel,
              cancelLabel: cancelLabel,
            ),
          ],
        ),
      ),
    );
  }
}

/// حقل ترشيح بنفس زخرفة حقول الحوار، بقيمة قد تكون بلا اختيار.
///
/// القائمة الممنوعة من الكتابة تُترك `null` في onChanged، فلا تُخترع قيمة
/// محايدة حين يفتح المدير الحوار على مرجع لم يُقرأ.
Widget hrDropdownField<T>(
  BuildContext context, {
  required String label,
  required T? value,
  required List<DropdownMenuItem<T>> items,
  String hint = '',
  ValueChanged<T?>? onChanged,
}) {
  final theme = Theme.of(context);
  return DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    decoration: adminDialogFieldDecoration(context, label: label, hint: hint),
    style: TextStyle(
      color: adminBodyColor(theme),
      fontSize: AppFontSizes.size11,
    ),
    dropdownColor: theme.colorScheme.surface,
    items: items,
    onChanged: onChanged,
  );
}

/// حقل الموظف في حوارات الإنشاء: مرشَّحوه من `admin_hr_employees` لا من سطور
/// الصفحة التي فُتح الحوار منها.
///
/// `people` ما قرأه المرجع: `null` أن الدليل لم يُقرأ أو رُفض بصلاحية، و`[]` أنه
/// قرئ ولا ملفّ في النطاق — وسؤالان مختلفان عند أول جدولٍ على قاعدةٍ فارغة
/// السطور، فالحقل يقول أيهما بدل صمتٍ لا يُفسَّر. وحين لا مرشَّح لا يُخترع اسم،
/// ويُترك `_staffId` بلا قيمة فيرفض الحفظ قبل أن يصل إلى القاعدة بسطرٍ أجوّف.
Widget hrEmployeeField(
  BuildContext context, {
  required List<HrPersonOption>? people,
  required String? value,
  required ValueChanged<String?> onChanged,
  String? label,
}) {
  final rows = people;
  if (rows == null || rows.isEmpty) {
    return HrCellText(
      rows == null ? S.hrEmployeesUnread : S.hrEmptyEmployees,
      muted: true,
    );
  }
  return hrDropdownField<String>(
    context,
    label: label ?? S.hrColEmployee,
    value: value,
    hint: S.hrEmptyEmployees,
    items: [
      for (final person in rows)
        DropdownMenuItem(
          value: person.id,
          child: Text(
            person.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: onChanged,
  );
}

/// أول مرشَّح مقروء يُلصق به الحقل عند الفتح؛ و`null` أن الدليل لم يُقرأ أو
/// قرئ بلا ملفّ — فلا تُفتَح حوارات الإنشاء على موظفٍ مُختَرع.
String? hrFirstPersonId(List<HrPersonOption>? people) =>
    people == null || people.isEmpty ? null : people.first.id;
