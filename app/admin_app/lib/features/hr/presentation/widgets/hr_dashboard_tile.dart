import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:flutter/material.dart';

/// بلاطة عدٍّ من لوحة القوى العاملة: رقمٌ أو كلمة «غير متاح».
///
/// `null` هنا ليست صفرًا: القاعدة تحرم الصلاحية أن تعدّ الباب، فالشاشة تقول
/// إن الرقم لم يُرسل بدل أن تكذب بصفرٍ يطمئن المدير بلا سبب.
Widget hrCountTile({
  required IconData icon,
  required Color tint,
  required Color surface,
  required String label,
  required int? count,
}) => AdminStatTile(
  icon: icon,
  tint: tint,
  surface: surface,
  label: label,
  value: count == null ? S.hrUnavailable : localizeDigits('$count'),
);

/// بلاطة مال: القيمـة محفوظة بعلمة الريال، و`null` تُقرأ لا متاحة لا صفرًا.
Widget hrMoneyTile({
  required IconData icon,
  required Color tint,
  required Color surface,
  required String label,
  required double? amount,
}) => AdminStatTile(
  icon: icon,
  tint: tint,
  surface: surface,
  label: label,
  money: amount,
  value: amount == null ? S.hrUnavailable : null,
);
