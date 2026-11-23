import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/preview/preview_section.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/design_section_chrome.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/design_sections.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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
    // Favorites renders its own saved-product grid, and search must open on its
    // search field rather than on a generic product shelf. Old published
    // editor defaults can still contain a generic grid for either page.
    final pageSections = pageId == 'favourites' || pageId == 'search'
        ? sections
              .where((section) => section.type != DesignWidgetTypes.productGrid)
              .toList(growable: false)
        : sections;
    final built = buildDesignPageSections(
      pageId: pageId,
      sections: pageSections,
    );
    final body = sections.where((node) => node.type == 'native.body').firstOrNull;
    final content = body == null
        ? child
        : body.visible ? DesignSectionChrome(section: body, child: child) : const SizedBox.shrink();
    if (built.isEmpty) return content;
    // Other published sections may be tall. Keep the search UI usable and let
    // them scroll within a bounded area.
    if (pageId == 'search') {
      return LayoutBuilder(
        builder: (context, constraints) {
          final maxSectionHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight * 0.35
              : 280.0;
          return Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxSectionHeight),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: built,
                  ),
                ),
              ),
              Expanded(child: content),
            ],
          );
        },
      );
    }
    return Column(
      children: [
        ...built,
        Expanded(child: content),
      ],
    );
  }
}

/// Keep added splash elements in the same order as the editor's component
/// tree, with the native logo/text settings occupying their own tree position.
Widget _buildSplashSections(List<PublishedSection> sections, Widget child) {
  final built = <Widget>[];
  var insertedNativeSplash = false;
  void append(Widget widget) {
    if (built.isNotEmpty) {
      built.add(const SizedBox(height: AppSpacing.sm));
    }
    built.add(widget);
  }

  for (final section in sections) {
    if (section.type == DesignWidgetTypes.splashSettings) {
      if (section.visible) {
        append(previewSectionWrap(section, pageId: 'splash', child: child));
      }
      insertedNativeSplash = true;
      continue;
    }
    if (!section.visible) continue;
    final widget = DesignSectionRenderers.build(section);
    if (widget == null) continue;
    append(
      previewSectionWrap(
        section,
        pageId: 'splash',
        child: HomeSection(
          child: DesignSectionChrome(section: section, child: widget),
        ),
      ),
    );
  }
  if (!insertedNativeSplash) append(child);
  return Column(mainAxisSize: MainAxisSize.min, children: built);
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
    if (pageId == 'splash') {
      return _buildSplashSections(sections, child);
    }
    final built = buildDesignPageSections(pageId: pageId, sections: sections);
    if (built.isEmpty) return child;
    return Column(mainAxisSize: MainAxisSize.min, children: [...built, child]);
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
          child: HomeSection(
            child: DesignSectionChrome(section: section, child: widget),
          ),
        ),
      );
    }
  }
  return widgets;
}
