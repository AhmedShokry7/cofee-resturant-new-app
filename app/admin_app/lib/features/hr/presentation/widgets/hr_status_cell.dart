import 'package:admin_app/features/hr/presentation/widgets/hr_labels.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:flutter/material.dart';

/// شارة حالة سطر HR: اللفظ واللون من حرف القاعدة المخزَّن، لا من تخمين الشاشة.
///
/// حالة لا تعرفها الخريطة تُعرض كما هي بحرفها الحيادي: الاختراع أخطر من
/// الكلمة الخامة، لأن المدير يقرأ اسم الحالة في السجلّ.
class HrStatusCell extends StatelessWidget {
  const HrStatusCell(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = hrStatusLabel(status);
    return AdminStatusBadge(label: label.text, color: label.color);
  }
}
