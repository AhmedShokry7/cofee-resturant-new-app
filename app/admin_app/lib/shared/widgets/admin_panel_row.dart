import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';

/// صف بطاقات يأخذ كل عنصر فيه عرضًا متساويًا على الشاشة العريضة، وينقلب عمودًا
/// على الضيقة دون أن تكرر أي صفحة قرار المقاس.
///
/// النقطة الفاصلة هي [AppBreakpoints.wideLayout] نفسها التي تستخدمها بقية
/// الصفحات، فتتحرك اللوحات معًا عند تغيير النافذة بدل أن تنقسم الشاشة على
/// مقاسين مختلفين. العرض يُقاس من الحيز المتاح لا من النافذة، لأن الصفحة
/// تضيف حشوها على الجانبين.
///
/// [weights] تعطي البطاقات أعرض متفاوتة حين يقرأ التصميم إحداها عمودًا جانبيًا
/// والأخرى لوحة عريضة؛ النسبة تبقى قرار الصف فلا تُحمَّل كل بطاقة على حدة.
class AdminPanelRow extends StatelessWidget {
  const AdminPanelRow({
    super.key,
    required this.children,
    this.spacing = AppSizes.px14,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.weights,
  }) : assert(
         weights == null || weights.length == children.length,
         'weights must give every child a share',
       );

  /// البطاقات المعروضة بالترتيب.
  final List<Widget> children;

  /// الفراغ بين بطاقة والتي تليها، أفقيًا ورأسيًا.
  final double spacing;

  /// محاذاة البطاقات داخل الصف حين تختلف أطوالها.
  final CrossAxisAlignment crossAxisAlignment;

  /// نصيب كل بطاقة من العرض على الشاشة العريضة، ومتساوٍ حين تُترك.
  final List<int>? weights;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.wideLayout) {
          return _stacked();
        }
        return _sideBySide();
      },
    );
  }

  /// بطاقات فوق بعضها على الحيز الضيق.
  Widget _stacked() => Column(
    crossAxisAlignment: crossAxisAlignment,
    children: [
      for (final (index, child) in children.indexed) ...[
        child,
        if (index < children.length - 1) SizedBox(height: spacing),
      ],
    ],
  );

  /// بطاقات جنبًا إلى جنب على الحيز العريض، متساوية أو بنصيب [weights].
  Widget _sideBySide() => Row(
    crossAxisAlignment: crossAxisAlignment,
    children: [
      for (final (index, child) in children.indexed) ...[
        Expanded(flex: weights == null ? 1 : weights![index], child: child),
        if (index < children.length - 1) SizedBox(width: spacing),
      ],
    ],
  );
}
