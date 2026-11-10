import 'package:flutter/material.dart';

/// شبكة بطاقات المقاييس أعلى صفحات الأدمن.
///
/// تتدرج الشبكة من عمود واحد للهاتف الصغير إلى أربعة أعمدة للمساحة الواسعة؛
/// المقاس الفعلي لمحتوى الصفحة هو ما يحدد عددها، لا عرض النافذة وحده.
class AdminMetricGrid extends StatelessWidget {
  const AdminMetricGrid({super.key, required this.children});

  final List<Widget> children;

  static const double _spacing = 13;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1080
            ? 4
            : width >= 740
            ? 3
            : width >= 480
            ? 2
            : 1;
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
