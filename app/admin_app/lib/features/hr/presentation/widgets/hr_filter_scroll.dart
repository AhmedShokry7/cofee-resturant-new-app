import 'package:flutter/material.dart';

/// شريط ترشيح يمرّ أفقيًا على الشاشة الضيقة بدل أن يفيض.
///
/// قطع الترشيح (حالة أو فرع) ألفاظها المحلية أطول من عرض الهاتف، وهي قرار
/// يُضغط لا زينة: التمرير يبقي كل الخيارات مقروءة بلا صفيحة فيض.
class HrFilterScroll extends StatelessWidget {
  const HrFilterScroll({super.key, required this.control});

  /// شريط `AdminSegmentedControl` أو أي صفّ قطع يملكه السطح.
  final Widget control;

  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: control);
}
