import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';

/// شبكة بطاقات تملأ مساحة الصفحة: الأعمدة من عرض البطاقة المثالي، وارتفاع
/// الخلية من البطاقة نفسها.
///
/// الفئات والباندلز كانتا تنسخان السلّم نفسه بأربع عتبات مكتوبة باليد ومعادلة
/// النسبة `cardWidth / (cardWidth + 100)` نفسها؛ النسبة تربط ارتفاع الخلية
/// بعرضها فقط، فمن يغيّر حشو البطاقة أو عدد أسطرها يتركها وهي على قياسها
/// القديم. هنا يُسأل ارتفاع البطاقة عن نفسه، فلا تُترَك بياضٌ أسفل البطاقة
/// ولا تُقطَع أزرارها أسفل الخلية.
class AdminRecordGrid extends StatelessWidget {
  const AdminRecordGrid({
    super.key,
    required this.itemCount,
    required this.cardExtent,
    required this.itemBuilder,
  });

  /// عدد البطاقات المعروضة بعد البحث.
  final int itemCount;

  /// ارتفاع البطاقة عند عرض [cardWidth]؛ تعرفه البطاقة لا الصفحة، لأن حشوه
  /// وأسطره داخلها.
  final double Function(double cardWidth) cardExtent;

  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = (width / AppDimensions.recordCardIdealWidth)
          .floor()
          .clamp(1, AppDimensions.recordCardMaxColumns);
      final cardWidth = (width - (columns - 1) * AppSpacing.md) / columns;

      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          mainAxisExtent: cardExtent(cardWidth),
        ),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      );
    },
  );
}
