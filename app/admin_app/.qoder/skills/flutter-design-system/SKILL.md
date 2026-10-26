---
name: flutter-design-system
description: نظام التصميم الموحد في Flutter: الألوان والخطوط من الثيم، الأيقونات من hugeicons عبر ملف مركزي، ومنع الـ hard code. إلزامية القراءة قبل إنشاء أو تعديل أي widget أو شاشة أو ستايل. Use before writing or editing any Flutter UI code, widget, color, text style or icon.
---

# نظام التصميم الموحد

## قاعدة ذهبية
**اقرأ هذا الملف كاملًا قبل أي تعديل على الواجهة.** الثيم هو المصدر الوحيد للتصميم، وصفحة المستخدمين هي المرجع البصري.

## 1) الألوان
- كل لون من `Theme.of(context).colorScheme` أو امتداد الثيم المعتمد في المشروع.
- ممنوع: `Color(0xFF...)` و`Colors.xxx` داخل أي widget.

## 2) الخطوط
- اسم الخط يُعرّف مرة واحدة في `ThemeData`.
- كل نمط نص من `Theme.of(context).textTheme` أو من أنماط `AppFonts`، والتعديل عبر `copyWith` فقط.
- الأحجام من `AppFontSizes`، والأوزان من `AppFontWeights`، وارتفاع السطر من `AppTextHeights`، وتباعد الحروف من `AppLetterSpacings` — كلها في `core/theme/typography.dart`.
- ممنوع: رقم حجم أو `FontWeight.wNNN` أو `height:` أو `letterSpacing:` مكتوب مباشرة داخل أي widget.
- عند الحاجة لمقاس أو وزن جديد: أضفه إلى `typography.dart` أولًا ثم استخدمه.

## 3) الأيقونات (باكدج hugeicons)
- الباكدج المعتمد الوحيد: **`hugeicons`**. ممنوع `Icons.xxx` وممنوع أي باكدج أيقونات آخر.
- لا تستخدم `HugeIcons.xxx` مباشرة داخل الـ widgets. كل أيقونة تُعرَّف **مرة واحدة** باسم دلالي في ملف مركزي، وتُرسم عبر widget مشترك.

**الملف المركزي `core/theme/app_icons.dart`**
```dart
import 'package:hugeicons/hugeicons.dart';

/// فهرس أيقونات التطبيق: الاسم الدلالي هنا، والباكدج لا يُستورد في أي مكان آخر.
abstract final class AppIcons {
  static const email = HugeIcons.strokeRoundedMail01;
  static const lock = HugeIcons.strokeRoundedLockPassword;
  static const eye = HugeIcons.strokeRoundedView;
  static const eyeOff = HugeIcons.strokeRoundedViewOff;
}
```

**الـ widget المشترك `core/widgets/app_icon.dart`**
```dart
import 'package:hugeicons/hugeicons.dart';

/// أيقونة موحدة: اللون والحجم الافتراضيان من الثيم.
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.color, this.size});
  final List<List<dynamic>> icon; // نوع بيانات أيقونات hugeicons
  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    return HugeIcon(
      icon: icon,
      color: color ?? Theme.of(context).iconTheme.color ?? Theme.of(context).colorScheme.onSurface,
      size: size ?? AppSizes.iconMd, // من tokens وليس رقمًا مباشرًا
    );
  }
}
```

**الاستخدام داخل أي feature**
```dart
AppIcon(AppIcons.email) // وليس HugeIcon(icon: HugeIcons.strokeRoundedMail01 ...)
```
- عند الحاجة لأيقونة جديدة: أضفها إلى `AppIcons` أولًا بنفس نمط الأسماء (`strokeRounded...`) ثم استخدمها.
- استخدم نمطًا واحدًا لكل التطبيق (`strokeRounded`) إلا إذا كان `users` يستخدم غيره.

## 4) المسافات والأحجام والحواف
- من tokens مركزية (`AppSpacing.md`, `AppRadius.lg`, `AppSizes.iconMd`).
- ممنوع الأرقام السحرية مثل `EdgeInsets.all(16)` أو `SizedBox(height: 24)`.

## 5) النصوص
- كل نص ظاهر للمستخدم من نظام الترجمة (l10n)، ولا نصوص مكتوبة داخل الـ widgets.

## 6) المكونات المشتركة
- قبل إنشاء زر أو حقل أو كارت أو ديالوج، افحص `core/widgets/`. استخدم الموجود أو وسّعه.
- المكون القابل لإعادة الاستخدام يوضع في `core/widgets/` وليس داخل الفيتشر.
- أي ستايل ناقص (لون / نمط نص / أيقونة) **يُضاف للثيم أولًا** ثم يُستخدم. ممنوع ستايل محلي.

## 7) فحص ذاتي قبل التسليم (grep)
ابحث في الملفات التي كتبتها عن هذه الأنماط، ويجب ألا تظهر:
`Color(` · `Colors.` · `fontSize:` برقم · `FontWeight.` · `Icons.` · `HugeIcons.` (خارج app_icons.dart) · `EdgeInsets.all(<رقم>` · `SizedBox(height: <رقم>` · نص عربي أو إنجليزي مباشر داخل `Text('...')`

## 8) قائمة التحقق قبل التسليم
- [ ] لا لون ولا خط ولا أيقونة ولا مسافة ولا نص مكتوب مباشرة.
- [ ] كل الأيقونات من `AppIcons` وتُرسم عبر `AppIcon`.
- [ ] الشكل مطابق لصفحة المستخدمين.
- [ ] كل مكرر انتقل إلى `core/widgets` أو الثيم.
- [ ] كل إضافة للثيم ذُكرت في التقرير النهائي.
