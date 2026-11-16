import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/preview/preview_section.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/design_sections.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section.dart';

/// مصمِّم صفحة عامة: يقرأ أقسام المستند المنشور لصفحة ويعرضها فوق جسم
/// الصفحة الحقيقي، بلا تغيير بنية الشاشة عند غياب المستند.
///
/// عند غياب الأقسام يُرجع [child] كما هو بالضبط، فتبقى الشاشات الحالية كما
/// هي. عند وجود الأقسام تُعرض فوق الجسم الأصلي ولا تحجب منطق الصفحة ولا
/// تحذف منها شيئًا — إلا التبديل الصريح من المحرر (إخفاء قسم = إخفاء مكون
/// ذلك القسم، وحذفه من المحرر إسقاطه من هنا).
class DesignPageSectionsAbove extends StatelessWidget {
  const DesignPageSectionsAbove({
    super.key,
    required this.pageId,
    required this.child,
  });

  final String pageId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sections = context.select(
      (DesignCubit cubit) => cubit.state.pageSections(pageId),
    );
    final built = buildDesignPageSections(pageId: pageId, sections: sections);
    if (built.isEmpty) return child;
    return Column(
      children: [
        ...built,
        Expanded(child: child),
      ],
    );
  }
}

/// صورة مضغوطة للأقسام لسياقات محدودة الارتفاع (شاشة افتتاحية مثلًا):
/// الأقسام فوق الطفل بلا Expanded.
class DesignPageSectionsInline extends StatelessWidget {
  const DesignPageSectionsInline({
    super.key,
    required this.pageId,
    required this.child,
  });

  final String pageId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sections = context.select(
      (DesignCubit cubit) => cubit.state.pageSections(pageId),
    );
    final built = buildDesignPageSections(pageId: pageId, sections: sections);
    if (built.isEmpty) return child;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...built,
        child,
      ],
    );
  }
}

List<Widget> buildDesignPageSections({
  required String pageId,
  required List<PublishedSection> sections,
}) {
  final widgets = <Widget>[];
  for (final section in sections) {
    if (!section.visible) continue;
    final widget = DesignSectionRenderers.build(section);
    if (widget != null) {
      widgets.add(
        previewSectionWrap(
          section,
          pageId: pageId,
          child: HomeSection(child: widget),
        ),
      );
    }
  }
  return widgets;
}
