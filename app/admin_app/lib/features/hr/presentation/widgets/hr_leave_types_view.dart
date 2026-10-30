import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_record_card.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';

/// أنواع الإجازة كما قرأها المرجع: رمز، واسمان، ورءوس القرار الثلاثة.
///
/// قائمة `null` تعني أن المرجع لم يُقرأ فتُعرض جملته لا جدولًا فارغًا: «لا
/// أنواع» و«لم تُقرأ الأنواع» سؤالان مختلفان عند من يضيف نوعًا جديدًا.
class HrLeaveTypesView extends StatelessWidget {
  const HrLeaveTypesView({
    super.key,
    required this.leaveTypes,
    required this.onNew,
  });

  /// `null` قبل أن يعود المرجع؛ والفراغ بعده يعني أنه لا نوع مكتوبًا في القاعدة.
  final List<HrLeaveType>? leaveTypes;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final types = leaveTypes;
    return AdminSectionCard(
      title: S.hrLeaveTypesTitle,
      count: types?.length,
      trailing: CustomBtn(
        text: S.hrBtnNewLeaveType,
        variant: BtnVariant.outlined,
        onPressed: onNew,
      ),
      child: types == null
          ? _note(context, S.hrNoLeaveTypesRead)
          : types.isEmpty
          ? _note(context, S.hrEmptyList)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final type in types)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: _type(context, type),
                  ),
              ],
            ),
    );
  }

  /// سطر نوع: اسمه بلغة الواجهة ورمزه، ثم اللسان الآخر لا مثيله.
  Widget _type(BuildContext context, HrLeaveType type) {
    final other = hrLeaveTypeNameOther(type);
    return HrRecordCard(
      title: hrLeaveTypeName(type),
      subtitle: type.code,
      fields: [HrCardField(other.label, HrCellText(other.name))],
      trailing: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          _chip(S.hrLeaveTypePaid, type.isPaid),
          _chip(S.hrLeaveTypeTracks, type.tracksBalance),
          _chip(S.hrLeaveTypeRequiresDoc, type.requiresDocument),
        ],
      ),
    );
  }

  /// شارة رأس القرار: اللفظ يقول مفتوحًا أو مغلقًا.
  ///
  /// السابق كان يطبع «مدفوعة» للمدفوعة وغير المدفوعة ويميّزها بالرمادي وحده،
  /// فلا يقرؤها ناطق ولا يميّزها عمى لون، وهي وصف حال لا زرّ.
  Widget _chip(String label, bool on) => AdminStatusBadge(
    label: '$label • ${on ? S.yes : S.no}',
    color: on ? AppColor.adminAccent : AppColor.greyColor,
  );

  Widget _note(BuildContext context, String message) => Text(
    message,
    style: TextStyle(
      color: adminMutedColor(Theme.of(context)),
      fontSize: AppFontSizes.size11,
      height: AppTextHeights.line1_5,
    ),
  );
}
