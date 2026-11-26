import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';

/// صف بطاقات يأخذ كل عنصر فيه عرضًا متساويًا على الشاشة العريضة، وينقلب عمودًا
/// على الضيقة دون أن تكرر أي صفحة قرار المقاس.
///
/// النقطة الفاصلة هي [AppBreakpoints.wideLayout] نفسها التي تستخدمها بقية
/// الصفحات، فتتحرك اللوحات معًا عند تغيير النافذة بدل أن تنقسم الشاشة على
/// مقاسين مختلفين. العرض يُقاس من الحيز المتاح لا من النافذة، لأن الصفحة
/// تضيف حشوها على الجانبين.
///
/// [weights] تعطي البطاقات أعرض متفاوتة حين يقرأ الصميم إحداها عمودًا جانبيًا
/// والأخرى لوحة عريضة؛ النسبة تبقى قرار الصف فلا تُحمَّل كل بطاقة على حدة.
///
/// [equalHeights] تلزّم البطاقات جنبًا إلى جنب بارتفاع واحد: بطاقتان في صف
/// واحد يتحاذّان بحافّهما الأسفل بدل أن تتدلى إحداهما نصف بطاقة. كيف؟
///
/// ارتفاع الصف فارغ، و`Row.stretch` وحده يمدّ الأبناء على لا نهائية فينهار،
/// و`IntrinsicHeight` يمشي في شجرة البطاقات حتى يصطدم بـ `LayoutBuilder`
/// داخل جداول اللوحة، و`LayoutBuilder` لا يجيب عن القياس الداخلي. فالحل
/// قياسٌ حيّ: البطاقات تُرسم بطولها الطبيعي أولًا، وتُسجَّل أحجامها كما
/// يرسمها الإطار، ثم يُعاد القراء بحده المُقاس — بلا قياس داخلي ولا
/// تخمين، ويستقر لأن أقصى المُقاس لا يغيّر أقصى الأطوال.
class AdminPanelRow extends StatefulWidget {
  const AdminPanelRow({
    super.key,
    required this.children,
    this.spacing = AppSizes.px14,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.weights,
    this.equalHeights = false,
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

  /// جعل البطاقات المتجاورة بارتفاع أطولها.
  final bool equalHeights;

  @override
  State<AdminPanelRow> createState() => _AdminPanelRowState();
}

class _AdminPanelRowState extends State<AdminPanelRow> {
  /// ارتفاع الصف المُقاس، و`null` ما دام لم يُقَس بعد.
  double? _height;

  /// أحجام البطاقات على آخر إطار، بالترتيب.
  final Map<int, double> _sizes = {};

  /// هل كان الصف عريضًا في آخر بناء؟ العبور من المكدّس يجعل المُقاس قديمًا.
  bool _wasWide = false;

  @override
  void didUpdateWidget(covariant AdminPanelRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // بطاقات جديدة بترتيبها نفسه: الأحجام القديمة لا تصح عليها.
    if (!identical(oldWidget.children, widget.children)) {
      _sizes.clear();
      _height = null;
    }
  }

  void _record(int index, double height) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_sizes[index] == height) return;
      _sizes[index] = height;
      if (_sizes.length < widget.children.length) return;
      final tallest = _sizes.values.reduce((a, b) => a > b ? a : b);
      if (_height != tallest) {
        setState(() => _height = tallest);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppBreakpoints.wideLayout;
        if (!wide) {
          _wasWide = false;
          return _stacked();
        }
        if (!_wasWide) {
          _sizes.clear();
          _height = null;
          _wasWide = true;
        }
        return _sideBySide();
      },
    );
  }

  /// بطاقات فوق بعضها على الحيز الضيق.
  Widget _stacked() => Column(
    crossAxisAlignment: widget.crossAxisAlignment,
    children: [
      for (final (index, child) in widget.children.indexed) ...[
        child,
        if (index < widget.children.length - 1)
          SizedBox(height: widget.spacing),
      ],
    ],
  );

  /// بطاقات جنبًا إلى جنب على الحيز العريض، متساوية أو بنصيب [weights].
  Widget _sideBySide() {
    final measured = widget.equalHeights && _height == null;
    final row = Row(
      crossAxisAlignment: widget.equalHeights && _height != null
          ? CrossAxisAlignment.stretch
          : widget.crossAxisAlignment,
      children: [
        for (final (index, child) in widget.children.indexed) ...[
          Expanded(
            flex: widget.weights == null ? 1 : widget.weights![index],
            child: measured
                ? _Measured(
                    onSize: (size) => _record(index, size.height),
                    child: child,
                  )
                : child,
          ),
          if (index < widget.children.length - 1)
            SizedBox(width: widget.spacing),
        ],
      ],
    );
    return _height == null ? row : SizedBox(height: _height, child: row);
  }
}

/// يُخبر أباه بحجم ابنه بعد الرسم، دون أن يقيسه ببذاته.
class _Measured extends SingleChildRenderObjectWidget {
  const _Measured({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasured(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMeasured renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderMeasured extends RenderProxyBox {
  _RenderMeasured(this.onSize);

  ValueChanged<Size> onSize;
  Size? _reportedSize;

  @override
  void performLayout() {
    super.performLayout();
    final current = size;
    if (_reportedSize == current) return;
    _reportedSize = current;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(current));
  }
}
