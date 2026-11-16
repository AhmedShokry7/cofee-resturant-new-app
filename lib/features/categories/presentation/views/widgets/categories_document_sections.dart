import 'package:flutter/material.dart';

import 'package:new_coffee/core/preview/preview_section.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_body.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_tabs.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/design_sections.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section.dart';

/// أقسام مستند التصنيفات بترتيبها المنشور، وسقط منها ما لا يعرفه الهاتف.
///
/// القاعدة نفسها التي ترسم بها الصفحة الرئيسية من المستند: عقدة لا يعرفها
/// الهاتف تُترك، وفقرٌ خفي لا يحجز مكانه. الفرق الوحيد: قسم `category_list`
/// في هذا المستند هو **متصفّح التصنيفات التفاعلي نفسه** (تبويبات + منتجات
/// التصنيف)، لا شريط تصنيفات مصغّر — فهو عنصر الشاشة الثابت، وموضعه في
/// المستند يحدّد ماذا يليه: المحتوى الحر يُرسم فوقه، والمتصفّح يملأ ما بقي
/// من الشاشة أينما وُجد.
///
/// قائمة فارغة تعني أن المستند لا يحمل صفحة تصنيفات تُرسم — لا أن الصفحة
/// فارغة: الشاشة ترسم عندئذ ما كُتب في مصدرها.
List<Widget> buildCategoriesDocumentSections(List<PublishedSection> document) =>
    <Widget>[
      for (final section in document)
        if (section.type != DesignWidgetTypes.categoryList)
          if (DesignSectionRenderers.build(section) case Widget widget)
            previewSectionWrap(
              section,
              pageId: 'categories',
              child: HomeSection(child: widget),
            ),
    ];

/// هل المستند يحمل عنصر تصفّح التصنيفات ظاهرًا؟ غيابه يعني أن الموظف حذفه،
/// فتُلحق الشاشة بمتصفّحها بعد المحتوى المرسم — لا تسأل الزبون أين منتجاته.
bool categoriesDocumentHasBrowser(List<PublishedSection> document) =>
    document.any(
      (section) =>
          section.type == DesignWidgetTypes.categoryList && section.visible,
    );

/// المتصفّح التفاعلي (تبويبات + منتجات) داخل تركيب المستند: يملأ ما بقي من
/// الشاشة، ويُغلف بغلاف التحديد في وضع المعاينة.
Widget buildCategoriesDocumentBrowser(List<PublishedSection> document) {
  final node = document.firstWhere(
    (section) => section.type == DesignWidgetTypes.categoryList,
    orElse: () => const PublishedSection(
      id: 'categories_browser',
      type: DesignWidgetTypes.categoryList,
    ),
  );
  return previewSectionWrap(
    node,
    pageId: 'categories',
    child: Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [CategoryTabs(), Expanded(child: CategoryBody())],
      ),
    ),
  );
}
