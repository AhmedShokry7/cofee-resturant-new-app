import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';

/// شبكة بطاقات المقاييس أعلى صفحات الأدمن.
///
/// الصف كان يُنسخ في كل فيتشر بنفس السطر: عمودان على الشاشة الضيقة وأربعة على
/// الواسعة، وفراغ ١٣ بين البطاقات. مرة واحدة هنا، فتنضبط كل صفحات المقاييس معًا
/// بدل أن يختلف تِباعها من شاشة إلى أخرى.
class AdminMetricGrid extends StatelessWidget {
  const AdminMetricGrid({super.key, required this.children});

  final List<Widget> children;

  static const double _spacing = 13;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < AppBreakpoints.wideLayout ? 2 : 4;
        final cardWidth = (width - _spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final child in children)
              SizedBox(width: cardWidth, child: child),
          ],
        );
      },
    );
  }
}
