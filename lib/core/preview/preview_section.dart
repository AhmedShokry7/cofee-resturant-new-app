import 'package:flutter/material.dart';

import 'package:new_coffee/core/preview/preview_bridge.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';

/// معرّف القسم المحدّد حاليًا في محرّر الأدمن، كما أرسله SELECT_ELEMENT.
///
/// ValueNotifier عام لأن القسم الذي يرسم الصفحة الرئيسية لا يملك شجرة موحدة:
/// كل قسم يستمع بنفسه، والتحديد يظهر فوق القسم الذي يحمل المعرفّ.
final ValueNotifier<String?> previewSelectedSectionId =
    ValueNotifier<String?>(null);

/// يلفّ قسمًا بلمسة تحديد وضع المعاينة، أو يعيده كما هو خارج المعاينة.
///
/// الوظيفة هي المدخل الوحيد الذي يستعمله رسم الصفحة، لضمان أن شجرة الـ
/// widgets في الإنتاج مطابقة حرفيًا لشجرة اليوم: بلا جلسة معاينة لا غلاف
/// في الشجرة أصلًا، لا غلافًا شفافًا.
Widget previewSectionWrap(
  PublishedSection section, {
  required String pageId,
  required Widget child,
}) {
  if (!PreviewBridge().isActive) return child;
  return PreviewSectionTap(section: section, pageId: pageId, child: child);
}

/// يلفّ قسمًا من المستند المنشور بلمسة تحديد وضع المعاينة.
///
/// خارج المعاينة هذا الغلاف لا وجود له في العمل: `PreviewBridge.isActive`
/// خاطئ دون جلسة، فيُعاد الطفل كما هو — بلا listener، بلا طبقة، ولا بكسل
/// يختلف عن شاشة الزبون.
///
/// داخل المعاينة، لمسة على القسم ترسل ELEMENT_SELECTED إلى المحرّر بالمعرفّ
/// والنوع وخصائصه، ويظهر إطار رفيع فوق القسم المحدّد حين يعيد المحرّر
/// SELECT_ELEMENT.
class PreviewSectionTap extends StatefulWidget {
  const PreviewSectionTap({
    super.key,
    required this.section,
    required this.pageId,
    required this.child,
  });

  final PublishedSection section;

  /// صفحة القسم في المستند (home اليوم).
  final String pageId;

  final Widget child;

  @override
  State<PreviewSectionTap> createState() => _PreviewSectionTapState();
}

class _PreviewSectionTapState extends State<PreviewSectionTap> {
  @override
  Widget build(BuildContext context) {
    final bridge = PreviewBridge();
    if (!bridge.isActive) return widget.child;

    return ValueListenableBuilder<String?>(
      valueListenable: previewSelectedSectionId,
      builder: (context, selectedId, child) {
        final selected =
            selectedId != null && selectedId == widget.section.id;
        final wrapped = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            previewSelectedSectionId.value = widget.section.id;
            bridge.sendElementSelected(
              componentId: widget.section.id,
              componentType: widget.section.type,
              pageId: widget.pageId,
              index: null,
              properties: <String, dynamic>{
                'visible': widget.section.visible,
                if (widget.section.dataSource != null)
                  'dataSource': widget.section.dataSource!,
              },
            );
          },
          child: child,
        );
        if (!selected) return wrapped;
        return Stack(
          children: [
            wrapped,
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.blue,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
