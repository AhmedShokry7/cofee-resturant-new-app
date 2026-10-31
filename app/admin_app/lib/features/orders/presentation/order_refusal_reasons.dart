import 'package:admin_app/core/locale/app_strings.dart';

/// عبارات الرفض التي تسمّيها دوال الطلب بعينها، لكتاب العبارة في
/// `adminErrorMessage`.
///
/// المفاتيح مقاطع من نص قاعدة البيانات بحروفه الصغيرة، كما ترميه 190 و191
/// و200، والقيم جمل الأدمن: من يطلب كمية أكبر من المخزون يسمع «المخزون لا
/// يكفي هذه الكمية» بدل «قيمة مرفوضة»، ومن يعبث بطلب مُستردّ يسمع سبب
/// الاسترداد. وما لا مقطع له هنا يأخذ سبب شيفرة SQLSTATE وحده.
Map<String, String> orderRefusalReasons() => <String, String>{
  'insufficient stock for product': S.orderRefusalStock,
  'you do not manage this branch': S.orderRefusalBranch,
  'refunded order is not editable': S.orderRefusalRefunded,
  'order is not editable': S.orderRefusalNotEditable,
  'order item not found': S.orderRefusalItemGone,
  'product is not available in this branch': S.orderRefusalProductUnavailable,
  'is not allowed': S.orderRefusalTransition,
  'can no longer be cancelled': S.orderRefusalCancelClosed,
  'order is already': S.orderRefusalAlready,
};
