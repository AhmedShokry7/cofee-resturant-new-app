import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/design/data/model/native_section.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';

/// طبقة شاشة الدخول المنشورة فوق أصلها.
///
/// كل شاشة من شاشات الدخول تقرأ عقد شاشتها (`auth.title` و`auth.subtitle`
/// و`auth.social` و`auth.switch_prompt`) من المستند المنشور: نصّ منشور
/// يعلو على نصّ التطبيق، و`visible: false` يخفي المكوّن الأصلي، وغياب
/// العقدة يعني الشاشة كما رسمها المصدر.
class AuthNative {
  const AuthNative._({this.text, required this.visible});

  /// النصّ المنشور، أو null لأصل الشاشة.
  final String? text;

  /// هل المكوّن الأصلي ظاهر؟ غياب العقدة ظهور.
  final bool visible;

  /// طبقة عنصر شاشة دخول، أو null حين لا مستند يقرؤه.
  static AuthNative? of(BuildContext context, String pageId, String type) {
    final node = context.select(
      (DesignCubit cubit) => nativeSection(
        cubit.state.pageSections(pageId),
        type,
      ),
    );
    if (node == null) return null;
    return AuthNative._(
      text: node.localizedText('text'),
      visible: node.visible,
    );
  }

  /// عنوان شاشة الدخول كما نُشر.
  static AuthNative? title(BuildContext context, String pageId) =>
      of(context, pageId, DesignWidgetTypes.authTitle);

  /// سطر الوصف تحت العنوان كما نُشر.
  static AuthNative? subtitle(BuildContext context, String pageId) =>
      of(context, pageId, DesignWidgetTypes.authSubtitle);
}
