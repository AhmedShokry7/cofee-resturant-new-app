import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:flutter/material.dart';

/// حقل يوم وساعة معًا: وردية مجدولة أو تصحيح بصمة لا يُقَدَّر بنصف قيمة.
///
/// `HrDateField` يعطي اليوم وحده، أما هنا فاليوم والساعة قيمتان من طابع واحد:
/// التفريق بينهما في نموذج التعديل كان يدخل ساعة على يوم خطأ، والقاعدة تقارن
/// الطابعين بطولهما لا بنية الحقل.
class HrStampField extends StatelessWidget {
  const HrStampField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.firstDate,
    this.lastDate,
  });

  final String label;

  /// الطابع المختار، و`null` تعني أن الحقل لم يُمْلأ بعد.
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final bool enabled;

  /// المدى المسموح به للقائمة، وإن غاب بُني حول اليوم كما في حقل التاريخ.
  final DateTime? firstDate;
  final DateTime? lastDate;

  DateTime get _now => DateTime.now();
  DateTime get _first => firstDate ?? DateTime(_now.year - 5);
  DateTime get _last => lastDate ?? DateTime(_now.year + 2, 12, 31);

  Future<void> _pickDay(BuildContext context) async {
    final current = value;
    final initial =
        current == null || current.isBefore(_first) || current.isAfter(_last)
        ? _now
        : current;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _first,
      lastDate: _last,
    );
    if (picked == null) return;
    final base = current ?? _now;
    onChanged(
      DateTime(picked.year, picked.month, picked.day, base.hour, base.minute),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value ?? _now),
    );
    if (picked == null) return;
    final base = value ?? _now;
    onChanged(
      DateTime(base.year, base.month, base.day, picked.hour, picked.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = value;
    return InputDecorator(
      decoration: _decoration(theme),
      child: Row(
        children: [
          Expanded(
            child: Text(
              current == null
                  ? S.hrNotSelected
                  : '${localizedDate(current)} · ${localizedTime(current)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: current == null
                    ? adminMutedColor(theme)
                    : adminHeadingColor(theme),
                fontSize: AppFontSizes.size11_5,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          _tap(context, theme, AppIcons.clock01, () => _pickTime(context)),
          const SizedBox(width: AppSpacing.xs),
          _tap(context, theme, AppIcons.calendar01, () => _pickDay(context)),
        ],
      ),
    );
  }

  InputDecoration _decoration(ThemeData theme) => InputDecoration(
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
  );

  Widget _tap(
    BuildContext context,
    ThemeData theme,
    IconData icon,
    VoidCallback onTap,
  ) => InkWell(
    onTap: enabled ? onTap : null,
    borderRadius: BorderRadius.circular(AppRadius.sm),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      child: AppIcon(icon, size: AppSizes.px16, color: adminMutedColor(theme)),
    ),
  );
}
