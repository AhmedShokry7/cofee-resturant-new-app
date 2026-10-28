import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';

/// يظهر بطاقة واحدة عند أول رسم، بتدرّج يرتّبه [index] على الصفحة.
///
/// الأنيميشن هنا للمرة الأولى فقط: اللوحة تُعاد قراءتها كل تحديث، ولو تحرك كل
/// رقم مع كل قراءة لما استطاع الأدمن أن يقرأ شيئًا. نظام «تقليل الحركة» في
/// الجهاز يُبطل التدرّج كله لأن الحركة المعروضة زينة لا معلومة.
class AdminReveal extends StatefulWidget {
  const AdminReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.step = AppDimensions.revealStepDelay,
  });

  /// المحتوى الذي يدخل تدريجيًا.
  final Widget child;

  /// ترتيب البطاقة على الصفحة، وهو سبب انتظارها.
  final int index;

  /// مدة القفزة بين بطاقة والتي تليها.
  final Duration step;

  @override
  State<AdminReveal> createState() => _AdminRevealState();
}

class _AdminRevealState extends State<AdminReveal> {
  /// نقطة الظهور: تبدأ تحت موضعها قليلًا ثم تستقر.
  static const Offset _risen = Offset.zero;
  static const Offset _lowered = Offset(0, .04);

  bool _shown = false;
  bool _scheduled = false;

  /// الإعداد بعد initState لا فيه: `MediaQuery` لا يُقرأ من `initState`.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _shown = true;
      return;
    }
    Future<void>.delayed(widget.step * widget.index, _reveal);
  }

  void _reveal() {
    if (mounted) setState(() => _shown = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? _risen : _lowered,
      duration: AppDimensions.chartRevealDuration,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: AppDimensions.chartRevealDuration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
