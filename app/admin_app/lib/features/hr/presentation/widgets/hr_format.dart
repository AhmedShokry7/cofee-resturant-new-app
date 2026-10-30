import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';

/// لفظ المدة بالدقائق: ساعة ودقائق بحروف المدير، لا رقم خام.
///
/// الدوال في 212 ترد `worked_minutes` عدديًا، وعرضه كما هو يجعل المدير يقسّم
/// على ستين في رأسه عند كل بطاقة حضور. والصفر يُكتب كما تُكتب بقيم العمود
/// نفسه («0د» لا «د 0»)، فلا يبدو الصفّ الفارغ جملةً أخرى عند من يقرأ جدولًا.
String hrDuration(int minutes) {
  if (minutes <= 0) return localizeDigits('0${S.hrMinutesShort}');
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return localizeDigits('$rest${S.hrMinutesShort}');
  if (rest == 0) return localizeDigits('$hours${S.hrHoursShort}');
  return localizeDigits('$hours${S.hrHoursShort} $rest${S.hrMinutesShort}');
}

/// اسم بلغة الواجهة من عمودين مترجمين، فإن خلا لسانٌ سقط إلى الآخر.
///
/// الصفوف تخزّن الاسمَين، فالقائمة التي تختار العربي دائمًا تُجبر الواجهة
/// الإنجليزية على قراءة لا تفهمها، والسقوط للسان الآخر أصدق من خلية صامتة.
String hrBilingualName({required String nameAr, required String nameEn}) {
  final arabic = AppLocale.instance.isArabic;
  final primary = arabic ? nameAr : nameEn;
  if (primary.trim().isNotEmpty) return primary;
  return arabic ? nameEn : nameAr;
}

/// اسم الفرع بلغة الواجهة، فإن غاب أحدهما سقط إلى الآخر.
String hrBranchName(HrBranch? branch) {
  if (branch == null || branch.id.isEmpty) return S.hrNoBranch;
  return hrBilingualName(nameAr: branch.nameAr, nameEn: branch.nameEn);
}

/// اسم نوع الإجازة بلغة الواجهة: هو والفرع فيلسوفان في عرضٍ واحد.
String hrLeaveTypeName(HrLeaveType type) =>
    hrBilingualName(nameAr: type.nameAr, nameEn: type.nameEn);

/// اللسان الذي لم يقرأه العنوان، مع لفظه.
///
/// البطاقة تعرض الاسمَين: بعرض لغة الواجهة مرتين — في العنوان ثم في حقل
/// «الاسم الإنجليزي» — يظن القارئ أن الصفّ اسم واحد وله خلية زائدة.
({String label, String name}) hrLeaveTypeNameOther(HrLeaveType type) {
  final arabic = AppLocale.instance.isArabic;
  return (
    label: arabic ? S.hrLeaveTypeNameEn : S.hrLeaveTypeNameAr,
    name: arabic ? type.nameEn : type.nameAr,
  );
}

/// اسم موظف قد يكون خاليًا في ردّ القاعدة، فلا تُعرض خلية بيضاء صامتة.
String hrPersonName(String name) =>
    name.trim().isEmpty ? S.hrUnknownPerson : name;
