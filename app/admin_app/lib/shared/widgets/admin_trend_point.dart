/// نقطة واحدة في منحنى الاتجاه: تسمية المحور وقيمتها.
///
/// القيمة خام كما ترجعها القاعدة؛ الرسم لا يعرف عملات ولا وحدات، فيرسم
/// النسب بين النقاط وأسماء المحور تبقى مسؤولية الصفحة التي تملك المعنى.
class AdminTrendPoint {
  const AdminTrendPoint({
    required this.label,
    required this.value,
    this.shortLabel,
    this.tooltipTitle,
    this.tooltipValue,
    this.tooltipDetail,
  });

  /// تسمية قصيرة تحت المحور، مثل رقم اليوم.
  final String label;

  /// القيمة المرسومة على المحور الرأسي.
  final double value;

  /// تسمية أقصر من [label] لعرض كل يوم على محور عريض، كرقم اليوم وحده.
  final String? shortLabel;

  /// سطر التلميحة العلوي: اليوم كاملًا كما يُقرأ في السجل.
  final String? tooltipTitle;

  /// القيمة المهيأة للطبع في التلميحة، بالأرقام المحلية بلا عملة.
  final String? tooltipValue;

  /// سطر تفصيلي ثانٍ في التلميحة، كعدد طلبات اليوم.
  final String? tooltipDetail;
}
