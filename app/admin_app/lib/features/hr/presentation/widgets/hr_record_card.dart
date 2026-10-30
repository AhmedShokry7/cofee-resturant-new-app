import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:flutter/material.dart';

/// حقل بطاقة ضيقة: لفظ صغير وقيمته في الطرف الآخر من السطر.
class HrCardField {
  const HrCardField(this.label, this.value);

  final String label;
  final Widget value;
}

/// بطاقة سطر HR على الشاشة الضيقة، حيث لا يتسع الجدول لأعماده.
///
/// البطاقة تُقرأ من نفس الكيان الذي يقرأ منه الجدول خلاياه، فالحقل لا يختلف
/// بين العرضين ولا تُخفى قيمة على الهاتف وتُمنح للمكتب.
class HrRecordCard extends StatelessWidget {
  const HrRecordCard({
    super.key,
    required this.title,
    required this.fields,
    this.subtitle,
    this.badge,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;

  /// حقول البطاقة بترتيب قراءتها، وأقلها ما يميّز السطر عن غيره.
  final List<HrCardField> fields;

  final Widget? badge;

  /// أزرار القرار على البطاقة نفسها، حين يملك المدير صلاحية مراجعتها.
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: adminCardBorderColor(theme)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: adminHeadingColor(theme),
                            fontSize: AppFontSizes.size12_5,
                            fontWeight: AppFontWeights.semiBold,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adminMutedColor(theme),
                              fontSize: AppFontSizes.size9_5,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ?badge,
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final field in fields) _field(theme, field),
              if (trailing != null) ...[
                const SizedBox(height: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(ThemeData theme, HrCardField field) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              field.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9_5,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: field.value),
        ],
      ),
    );
  }
}

/// حقلا «لماذا»: سبب الطلب ثم ملاحظة المراجع، ولا سطر فارغ حيث لم يُكتب سبب.
///
/// الحقلان يُرسلان كما هما من القاعدة — ولا تُخترع ملاحظة حين صمت المرجع، ولا
/// يُحذف السبب الطويل ليبقى شكل البطاقة ثابتًا بين فيتشرَين.
List<HrCardField> hrNoteFields({
  required String reason,
  required String note,
}) => <HrCardField>[
  if (reason.isNotEmpty)
    HrCardField(S.hrReasonLabel, HrCellText(reason, muted: true)),
  if (note.isNotEmpty)
    HrCardField(S.hrFieldNote, HrCellText(note, muted: true)),
];
