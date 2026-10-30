import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:flutter/material.dart';

/// حقل تاريخ لا يُكتب بالمفاتيح: التقويم وحده يعطي قيمة بصيغة القاعدة.
///
/// التواريخ في HR تُقرأ وتُقارَن كأرقام يوم، والحقل النصي هنا يدخل الأخطاء
/// والمقاسات المختلفة، فالقيمة تُختار أو تبقى `null` وتُرفض الكتابة في القاعدة.
class HrDateField extends StatelessWidget {
  const HrDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;

  /// التاريخ المختار، و`null` تعني أن الحقل لم يُمْلأ بعد.
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final bool enabled;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: adminControlBorderColor(theme)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null ? S.hrNotSelected : localizedDate(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value == null
                      ? adminMutedColor(theme)
                      : adminHeadingColor(theme),
                  fontSize: AppFontSizes.size11_5,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ),
            AppIcon(
              AppIcons.calendar01,
              size: AppSizes.px16,
              color: adminMutedColor(theme),
            ),
          ],
        ),
      ),
    );
  }
}
