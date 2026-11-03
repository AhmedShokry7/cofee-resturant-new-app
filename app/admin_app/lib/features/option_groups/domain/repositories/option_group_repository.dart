import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';

/// عقد قراءة مجموعات الخيارات وكتابة أحجامها وإضافاتها وأسعارها ونطاقها.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ أخطاء القاعدة تبقى استثناءات تُترجم أعلى الطبقات كما تفعل الباقات.
abstract interface class OptionGroupRepository {
  /// يقرأ كل المجموعات مع قيمها ونطاقها، حتى المعطّلة منها: 225 جعلت الموظف
  /// صاحب `catalog.product.write` يرى ما أوقفه ليعيد تشغيله.
  Future<List<AdminOptionGroup>> loadGroups();

  /// ينشئ المجموعة مع قيمها وصفوف نطاقها.
  Future<AdminOptionGroup> createGroup(AdminOptionGroup group);

  /// يعدّل المجموعة: يحدّث ما له معرّف، ويضيف الجديد، ويحذف ما أُزيل.
  Future<AdminOptionGroup> updateGroup(AdminOptionGroup group);

  /// يحذف المجموعة مع ربطها ونطاقها؛ وترفضها القاعدة إن كانت قيمها بيعت.
  Future<void> deleteGroup(String groupId);

  /// ينشّط المجموعة أو يوقفها، فالإيقاف هو البديل الآمن للحذف.
  Future<void> setGroupActive(String groupId, bool isActive);
}
