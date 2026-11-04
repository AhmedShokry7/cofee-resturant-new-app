import 'package:flutter/material.dart';

import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_theme.dart';

/// طبقة الشكل كما يقرؤها الهاتف داخل اللوحة.
///
/// overrides لا صورة كاملة: الدور الغائب يعيد للموضع لونه الذي كان عليه، فلا
/// يتغيّر شكل لأن الموظف فتح لوحة الألوان، ولا تُخترع هنا قيمة قد لا تكون ما
/// يراه الزبون. لذا تُرجع [color] قيمة `null` لكل دور لم يُكتب، ويقرأ الموضع
/// قيمته التي كان عليها.
@immutable
class SimulatorPalette {
  const SimulatorPalette(this.theme);

  static const SimulatorPalette none = SimulatorPalette(DesignTheme.none);

  static SimulatorPalette of(BuildContext context) =>
      SimulatorPaletteScope.maybeOf(context) ?? none;

  final DesignTheme theme;

  /// اللون الأساسي: الموضع الوحيد في الهاتف الذي له قيمة معروفة اليوم، فأسعار
  /// البطاقات وأزراره وعلامته كلها لون واحد.
  Color get primary =>
      color(DesignColorRole.primary) ?? AppColor.primaryColor;

  /// حلقة الاختيار حول التصنيف: الأساسي نفسه شفافًا، كما كانت عليه الحال قبل
  /// الطبقة. تُحسب هنا لا في الموضع، فيتغيّر معها لو تغيّر اللون.
  Color get primaryRing => primary.withAlpha(75);

  Color? get background => color(DesignColorRole.background);

  Color? get surface => color(DesignColorRole.surface);

  Color? get textPrimary => color(DesignColorRole.textPrimary);

  Color? get textSecondary => color(DesignColorRole.textSecondary);

  Color? get border => color(DesignColorRole.border);

  Color? get secondary => color(DesignColorRole.secondary);

  Color? get success => color(DesignColorRole.success);

  Color? get error => color(DesignColorRole.error);

  Color? get disabled => color(DesignColorRole.disabled);

  /// الأدوار التي يغلّفها هاتف المعاينة فعلًا، لا كل ما تحمله العقد.
  ///
  /// استوديو الشكل يعرض هذه وحدها: الباقي في المستند ينتظر قارئًا لدى الزبون،
  /// ولو أُتيح في اللوحة قبله لكان زرًّا يلوّن شيئًا لا يراه أحد أبدًا.
  static const List<DesignColorRole> paintRoles = <DesignColorRole>[
    DesignColorRole.primary,
    DesignColorRole.background,
    DesignColorRole.surface,
    DesignColorRole.textPrimary,
    DesignColorRole.textSecondary,
    DesignColorRole.border,
  ];

  /// لون الدور المكتوب، أو null لدع ما عند الموضع كما هو.
  Color? color(DesignColorRole role) => _parse(theme.colors[role]);

  /// مضاعف خط الطبقة؛ 1 حين لم يُختر مقياس.
  double get textFactor => DesignScale.textFactor(theme.textScale);

  static Color? _parse(String? hex) {
    if (hex == null) return null;
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    // إلى هنا لا يصل إلا ما قَرأه DesignTheme.fromMap أولًا، فالقيمة التالفة
    // تصل من قاعدة كتبها محرّر آخر لا من اللوحة.
    if (value == null) return null;
    return hex.length == 9 ? Color(value) : Color(0xFF000000 | value);
  }
}

/// يلفّ جوف الهاتف بطبقة ألوان مستند، ويضع مقياس خطه فوق نصوصه كلها.
///
/// خارج الهاتف لا طبقة: اللوحة ترسم بألوانها، والشاشة التي تُختبر وحدها لا تُجبَر
/// على طبقة لا طلب لها.
class SimulatorPaletteScope extends StatelessWidget {
  const SimulatorPaletteScope({
    super.key,
    required this.palette,
    required this.child,
  });

  /// طبقة مستندٍ ما، ومحايدةٌ حين لا مستند بعد.
  factory SimulatorPaletteScope.forDocument({
    Key? key,
    required DesignDocument? document,
    required Widget child,
  }) => SimulatorPaletteScope(
    key: key,
    palette: SimulatorPalette(document?.theme ?? DesignTheme.none),
    child: child,
  );

  final SimulatorPalette palette;
  final Widget child;

  static SimulatorPalette? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_InheritedPalette>()?.palette;

  @override
  Widget build(BuildContext context) {
    final scaled =
        palette.textFactor == 1
            ? child
            : Builder(
                builder: (inner) {
                  final media = MediaQuery.maybeOf(inner);
                  // المضاعف يُضرب في مقياس الجهاز لا يحلّ محلّه: الهاتف يرى
                  // خط الزبون كما يراه في جيبه، مع زيادة التصميم أو نقصانه.
                  final platform =
                      media == null ? 1.0 : media.textScaler.scale(1.0);
                  return MediaQuery(
                    data:
                        (media ?? MediaQueryData.fromView(View.of(inner)))
                            .copyWith(
                              textScaler: TextScaler.linear(
                                platform * palette.textFactor,
                              ),
                            ),
                    child: child,
                  );
                },
              );
    return _InheritedPalette(palette: palette, child: scaled);
  }
}

class _InheritedPalette extends InheritedWidget {
  const _InheritedPalette({required this.palette, required super.child});

  final SimulatorPalette palette;

  @override
  bool updateShouldNotify(_InheritedPalette oldWidget) =>
      !sameTheme(oldWidget.palette.theme, palette.theme);
}
