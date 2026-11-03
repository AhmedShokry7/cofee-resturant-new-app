import 'package:flutter/material.dart';

import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';
import 'package:admin_app/features/option_groups/presentation/manager/admin_option_group_cubit.dart';
import 'package:admin_app/shared/widgets/admin_feedback.dart';

/// قيد 011 على `orders.cart_item_options.option_value_id` (`on delete restrict`)
/// يجعل حذف مجموعة قيمتُها ما تزال في سلّة مفتوحة مرفوضًا (23503)، لأن حذف
/// المجموعة يتسلسل إلى قيمها. الطلبات السابقة لا تمنع شيئًا: عمودها `set null`
/// وتسمياتها مجمّدة في صفّها. فاللوحة تعرض البديل لا نصّ Postgres الخام:
/// التعطيل يخفي المجموعة عن العميل دون أن يمسّ ما سُجّل أو ما لم يُشترَ بعد.
///
/// أسباب رفض القاعدة التي تعرفها هذه الصفحة، بجملة أدقّ من سبب الشيفرة العام.
///
/// دالة لا ثابت: `S` يبني جملته عند القراءة، فلا تُلتقط العربية أو الإنجليزية
/// وقت تحميل الملف بل وقت العرض.
Map<String, String> optionGroupRefusalReasons() => <String, String>{
  'foreign key constraint': S.deleteOptionGroupBlockedHint,
};

/// يسأل الأدمن أن يؤكد حذف مجموعة، ثم يحذفها أو يشرح رفض القاعدة.
void confirmDeleteOptionGroup(
  BuildContext context,
  AdminOptionGroupCubit cubit,
  AdminOptionGroup group,
) {
  showConfirmDeleteSnackBar(
    context,
    message: deleteConfirmationText(group.nameAr, group.nameEn),
    onConfirm: () async {
      try {
        await cubit.deleteGroup(group.id);
      } catch (error) {
        if (!context.mounted) return;
        showErrorSnackBar(
          context,
          adminErrorMessage(error, reasons: optionGroupRefusalReasons()),
        );
      }
    },
  );
}

/// ينشّط المجموعة أو يوقفها، ويبلغ الأدمن إن رفضت القاعدة.
Future<void> toggleOptionGroupActive(
  BuildContext context,
  AdminOptionGroupCubit cubit,
  AdminOptionGroup group,
) async {
  try {
    await cubit.toggleActive(group);
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnackBar(context, adminErrorMessage(error));
  }
}
