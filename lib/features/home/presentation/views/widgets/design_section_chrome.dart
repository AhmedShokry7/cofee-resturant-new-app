import 'package:flutter/material.dart';

import 'package:new_coffee/features/design/data/model/published_design.dart';

/// طبقة المقاس والمظهر المشتركة لأقسام مستند التصميم.
///
/// تُقرأ من خصائص القسم نفسها فلا تحفظ في مكان ثانٍ: الخاصية الغائبة تعني
/// «كما هو» — لا قياس ولا خلفية ولا حدّ — فيبقى الرسم يوم النشر مطابقًا
/// لما كان عليه حرفيًا حين لم يلمس الموظف هذه الخصائص.
///
/// تطبيقها من الخارج إلى الداخل: الهامش، ثم المقاس والحدود المعلنة، ثم
/// الخلفية/الحدّ/الظل، ثم الحشو، ثم نسبة العرض إلى الارتفاع، ثم الشفافية.
/// القصّ يغلّف الصورة أو اللوحة كي لا يخرج المحتوى عنها؛ `Flex` لا يُطبَّق
/// هنا عمدًا: أبناء `ListView` بلا ارتفاع محدود فالمرونة داخل عمود تمرير
/// خطأ تخطيطي — موضعه الوحيد الصفّ (`section.row`) الذي يغلّف أبناءه بـ
/// `Expanded` عند طلب المرونة.
class DesignSectionChrome extends StatelessWidget {
  const DesignSectionChrome({super.key, required this.section, required this.child});

  final PublishedSection section;
  final Widget child;

  static bool needsChrome(PublishedSection section) {
    const keys = [
      'width', 'minWidth', 'maxWidth', 'height', 'minHeight', 'maxHeight',
      'padTop', 'padBottom', 'padLeft', 'padRight',
      'marginTop', 'marginBottom', 'marginLeft', 'marginRight',
      'backgroundColor', 'borderColor', 'borderWidth',
      'radiusTL', 'radiusTR', 'radiusBL', 'radiusBR',
      'shadowColor', 'shadowOffsetX', 'shadowOffsetY', 'shadowBlur',
      'opacity', 'aspectRatio',
    ];
    for (final key in keys) {
      final value = section.properties[key];
      if (value is num || (value is String && value.trim().isNotEmpty)) {
        return true;
      }
    }
    return false;
  }

  Color? _hexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final trimmed = hex.trim();
    final value = int.tryParse(trimmed.replaceFirst('#', ''), radix: 16);
    if (value == null) return null;
    return trimmed.replaceFirst('#', '').length == 8
        ? Color(value)
        : Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    Widget current = child;
    if (!needsChrome(section)) return current;

    // الشفافية أولًا حتى يُحسب كل ما تحتها معتمًا كأثر بصري واحد.
    final opacity = section.numberProperty('opacity');
    if (opacity != null && (opacity < 0 || opacity > 1)) {
      // قيمة خارج [0,1] لا تُطبَّق: توليد ظلّ بلا محتوى أسوأ من تجاهلها.
    } else if (opacity != null) {
      current = Opacity(opacity: opacity, child: current);
    }

    final aspectRatio = section.numberProperty('aspectRatio');
    if (aspectRatio != null && aspectRatio > 0) {
      current = AspectRatio(aspectRatio: aspectRatio, child: current);
    }

    final padLeft = section.numberProperty('padLeft');
    final padRight = section.numberProperty('padRight');
    final padTop = section.numberProperty('padTop');
    final padBottom = section.numberProperty('padBottom');
    if (padLeft != null || padRight != null || padTop != null || padBottom != null) {
      current = Padding(
        padding: EdgeInsets.only(
          left: padLeft ?? 0,
          right: padRight ?? 0,
          top: padTop ?? 0,
          bottom: padBottom ?? 0,
        ),
        child: current,
      );
    }

    final background = _hexColor(section.property('backgroundColor'));
    final borderColor = _hexColor(section.property('borderColor'));
    final borderWidth = section.numberProperty('borderWidth');
    final hasRadius = section.properties.containsKey('radiusTL') ||
        section.properties.containsKey('radiusTR') ||
        section.properties.containsKey('radiusBL') ||
        section.properties.containsKey('radiusBR');
    if (background != null || borderColor != null || hasRadius || section.properties.containsKey('shadowColor')) {
      final tl = section.numberProperty('radiusTL') ?? 0;
      final tr = section.numberProperty('radiusTR') ?? 0;
      final bl = section.numberProperty('radiusBL') ?? 0;
      final br = section.numberProperty('radiusBR') ?? 0;
      final radius = BorderRadius.only(
        topLeft: Radius.circular(tl),
        topRight: Radius.circular(tr),
        bottomLeft: Radius.circular(bl),
        bottomRight: Radius.circular(br),
      );
      final shadowColor = _hexColor(section.property('shadowColor'));
      final decoration = BoxDecoration(
        color: background,
        borderRadius: radius,
        border: (borderColor != null || borderWidth != null)
            ? Border.all(
                color: borderColor ?? const Color(0xFF000000),
                width: borderWidth ?? 1,
              )
            : null,
        boxShadow: shadowColor == null
            ? null
            : [
                BoxShadow(
                  color: shadowColor,
                  offset: Offset(
                    section.numberProperty('shadowOffsetX') ?? 0,
                    section.numberProperty('shadowOffsetY') ?? 2,
                  ),
                  blurRadius: section.numberProperty('shadowBlur') ?? 8,
                ),
              ],
      );
      current = DecoratedBox(decoration: decoration, child: current);
      // القصّ يغلّف حين توجد زوايا أو حدّ أو ظلّ: محتوى يخرج عن الخلفية
      // الملوّنة يمزّق الشكل الذي طلبه الموظف.
      if (hasRadius || borderColor != null || borderWidth != null) {
        current = ClipRRect(borderRadius: radius, child: current);
      }
    }

    // البانران يملكان ارتفاعًا ذاتيًا (ارتفاع الشرائح) يُدار من خاصية
    // `height` نفسها: تكبيره هنا يضاعف الارتفاع ويخرج النقاط من الإطار.
    final structuralHeight = section.type == 'section.banner_carousel' ||
        section.type == 'section.promo_banner';
    final width = section.numberProperty('width');
    final height = structuralHeight
        ? null
        : section.numberProperty('height');
    final minWidth = section.numberProperty('minWidth');
    final maxWidth = section.numberProperty('maxWidth');
    final minHeight = section.numberProperty('minHeight');
    final maxHeight = section.numberProperty('maxHeight');
    if (width != null || height != null || minWidth != null || maxWidth != null || minHeight != null || maxHeight != null) {
      current = ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minWidth ?? 0,
          maxWidth: maxWidth ?? double.infinity,
          minHeight: minHeight ?? 0,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: SizedBox(width: width, height: height, child: current),
      );
    }

    final mLeft = section.numberProperty('marginLeft');
    final mRight = section.numberProperty('marginRight');
    final mTop = section.numberProperty('marginTop');
    final mBottom = section.numberProperty('marginBottom');
    if (mLeft != null || mRight != null || mTop != null || mBottom != null) {
      current = Padding(
        padding: EdgeInsets.only(
          left: mLeft ?? 0,
          right: mRight ?? 0,
          top: mTop ?? 0,
          bottom: mBottom ?? 0,
        ),
        child: current,
      );
    }
    return current;
  }
}
