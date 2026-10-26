---
name: flutter-architecture
description: معمارية Flutter (Clean Architecture بنظام Feature-first) مع Bloc، وفصل الـ UI عن الـ Logic. إلزامية القراءة قبل إنشاء أو تعديل أي شاشة أو feature أو bloc أو cubit أو repository أو model. Use before creating or editing any Flutter feature, screen, bloc, repository or model.
---

# معمارية Flutter الاحترافية (Bloc)

## قاعدة ذهبية
**اقرأ هذا الملف كاملًا قبل أي تعديل.** وقبل كتابة أي كود، افحص فيتشر مرجعيًا موجودًا (مثل `users`) وقلّد بنيته بالضبط.

## 1) بنية المجلدات (Feature-first)

```
lib/
├── core/                       # مشترك (لا يعتمد على أي feature)
│   ├── theme/                  # colors, text_theme, app_icons, spacing
│   ├── widgets/                # widgets مشتركة (app_button, app_text_field, app_icon...)
│   ├── network/                # عميل HTTP و interceptors
│   ├── error/                  # failures & exceptions
│   ├── usecase/                # UseCase الأساسي
│   ├── constants/              # مسارات، مفاتيح، مدد
│   └── l10n/                   # الترجمة
└── features/
    └── <feature_name>/
        ├── data/
        │   ├── models/         # JSON ↔ Entity
        │   ├── datasources/    # remote / local
        │   └── repositories/   # تنفيذ العقود
        ├── domain/             # Dart خالص بدون Flutter
        │   ├── entities/
        │   ├── repositories/   # عقود abstract
        │   └── usecases/       # usecase واحد لكل ملف
        └── presentation/
            ├── bloc/           # bloc/cubit + events + states
            ├── screens/        # تجميع widgets فقط
            └── widgets/        # widgets خاصة بالفيتشر
```

## 2) اتجاه الاعتماد (ممنوع كسره)
`presentation → domain ← data`
- `domain` لا يستورد Flutter ولا أي مكتبة UI.
- الـ Bloc يتعامل مع **UseCases** فقط، ولا يستورد `data` مباشرة.
- فيتشر لا يستورد من فيتشر آخر. المشترك يُنقل إلى `core`.

## 3) مسؤولية كل طبقة
| الطبقة | مسؤوليتها | ممنوع فيها |
|---|---|---|
| Screen | تجميع widgets وتوفير الـ BlocProvider | منطق، API، ستايل مباشر |
| Widget | عرض جزء واحد | منطق عمل |
| Bloc/Cubit | كل المنطق وتغيير الحالة | `BuildContext`، استيراد widgets، التنقل |
| UseCase | عملية عمل واحدة | علم بالواجهة أو JSON |
| Repository | وسيط بين المنطق والبيانات | منطق عرض |
| DataSource | API أو التخزين | منطق عمل |

## 4) قواعد Bloc
- **Bloc** للتدفقات المعقدة ذات الأحداث الكثيرة. **Cubit** للحالات البسيطة. اتبع ما يستخدمه فيتشر `users`.
- كل Bloc في 3 ملفات منفصلة: `xxx_bloc.dart` و`xxx_event.dart` و`xxx_state.dart` (أو `part of`).
- الحالات والأحداث `sealed` أو `abstract` وتستخدم `Equatable`، وكل حالة `immutable`.
- حالات صريحة: `initial / loading / success / failure`، والفشل يحمل `Failure` وليس نصًا.
- الـ UI يرسل **أحداثًا فقط** (`context.read<XBloc>().add(...)`) ولا يغير حالة بنفسه.
- `BlocBuilder` لرسم الواجهة، و`BlocListener` للآثار الجانبية (تنقل، Snackbar، ديالوج)، و`BlocSelector` لتقليل إعادة البناء.
- ممنوع `setState` إلا لحالة واجهة مؤقتة بحتة (animation، focus) وبوجود سابقة في المشروع.
- كل Bloc يُوفَّر عبر `BlocProvider` عند الشاشة، والتبعيات تُحقن عبر نظام الـ DI المعتمد، وليس بإنشائها داخل الـ widget.
- أغلق أي stream أو subscription داخل `close()`.

## 5) أمثلة مرجعية

**Event**
```dart
/// أحداث شاشة تسجيل الدخول.
sealed class LoginEvent extends Equatable {
  const LoginEvent();
  @override
  List<Object?> get props => [];
}

/// المستخدم ضغط على زر تسجيل الدخول.
final class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({required this.email, required this.password});
  final String email;
  final String password;
  @override
  List<Object?> get props => [email, password];
}
```

**State**
```dart
/// حالات شاشة تسجيل الدخول.
sealed class LoginState extends Equatable {
  const LoginState();
  @override
  List<Object?> get props => [];
}

final class LoginInitial extends LoginState {}
final class LoginLoading extends LoginState {}
final class LoginSuccess extends LoginState {}

/// فشل التسجيل، ويحمل نوع الخطأ ليترجم في الواجهة.
final class LoginFailure extends LoginState {
  const LoginFailure(this.failure);
  final Failure failure;
  @override
  List<Object?> get props => [failure];
}
```

**Bloc**
```dart
/// منطق تسجيل الدخول فقط، بدون أي علاقة بالواجهة.
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc(this._login) : super(LoginInitial()) {
    on<LoginSubmitted>(_onSubmitted);
  }

  final LoginUseCase _login;

  Future<void> _onSubmitted(LoginSubmitted e, Emitter<LoginState> emit) async {
    emit(LoginLoading());
    final result = await _login(LoginParams(e.email, e.password));
    // نتيجة Either: يسار = فشل، يمين = نجاح
    result.fold(
      (failure) => emit(LoginFailure(failure)),
      (_) => emit(LoginSuccess()),
    );
  }
}
```

**Screen (تجميع فقط)**
```dart
/// شاشة تسجيل الدخول: توفر الـ Bloc وتجمع الـ widgets.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<LoginBloc>(),
      child: const LoginListener(child: LoginView()),
    );
  }
}
```

## 6) حجم الملفات والتسمية
- المستهدف 50 سطرًا، والحد الأقصى 100. تجاوزه يعني قسّم.
- ملف واحد = كلاس واحد = مسؤولية واحدة.
- أسماء الملفات `snake_case` والكلاسات `PascalCase`.
- كل كلاس ودالة عامة لها تعليق `///` بالعربية يشرح الغرض.

## 7) منع التكرار
قبل إنشاء أي شيء ابحث (`grep`) عن شيء مشابه واستخدمه. أي شيء يتكرر في موضعين ينتقل إلى `core` فورًا.

## 8) قائمة التحقق قبل التسليم
- [ ] اتجاه الاعتماد صحيح.
- [ ] لا منطق في أي widget أو screen.
- [ ] كل تغيير حالة عبر Bloc/Cubit، والأحداث والحالات منفصلة وEquatable.
- [ ] لا `BuildContext` داخل Bloc.
- [ ] لا ملف فوق 100 سطر.
- [ ] لا تكرار.
- [ ] `flutter analyze` بلا تحذيرات.
