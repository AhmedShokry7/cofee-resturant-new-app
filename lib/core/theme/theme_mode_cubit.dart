import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/shared_pref.dart';

import 'app_color.dart';

/// يملك قرار الوضع (فاتح/داكن) ويحفظه على الهاتف.
///
/// التفضيل يُقرأ مرة عند الإقلاع ويُكتب عند كل تبديل، عبر [SharedPref] الذي
/// لا يرمي عطلًا: هاتف لم يعطِ مخزنًا يُقلع فاتحًا بدل أن يتجمد. وبما أن
/// كثيرًا من الشاشات تقرّأ أدوار الألوان من [AppColor] مباشرة (نمط مستودع
/// التصميم نفسه)، فالتبديل يعيد رسم هذه الأدوار أيضاً عبر [syncRoles].
class ThemeModeCubit extends Cubit<ThemeMode> {
  ThemeModeCubit() : super(ThemeMode.light) {
    _load();
  }

  static const String _key = 'theme_mode';

  Future<void> _load() async {
    final saved = await SharedPref.getValue(key: _key);
    if (isClosed || saved == null) return;
    if (saved == ThemeMode.dark.name) {
      applyRoles(isDark: true);
      emit(ThemeMode.dark);
    }
  }

  Future<void> toggle() =>
      set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  Future<void> set(ThemeMode mode) async {
    applyRoles(isDark: mode == ThemeMode.dark);
    emit(mode);
    await SharedPref.setValue(key: _key, value: mode.name);
  }

  /// يعيد رسم أدوار [AppColor] على حالتي الوضع. يُستدعى عند التبديل وبعد كل
  /// بناء للجذر، فلو أعد مستودع التصميم الأدوار إلى الفاتح بعد التبديل رُسمت
  /// الداكنة من جديد قبل أن يرى MaterialApp الشجرة.
  void syncRoles() => applyRoles(isDark: state == ThemeMode.dark);

  static void applyRoles({required bool isDark}) {
    AppColor.isDarkMode = isDark;
    AppColor.background = isDark
        ? AppColor.darkBackground
        : AppColor.backgroundDefault;
    AppColor.cardSurface = isDark
        ? AppColor.darkCard
        : AppColor.cardSurfaceDefault;
    AppColor.surfaceColor = isDark
        ? AppColor.darkSurface
        : AppColor.surfaceDefault;
    AppColor.textPrimary = isDark
        ? AppColor.darkText
        : AppColor.textPrimaryDefault;
    AppColor.textSecondary = isDark
        ? AppColor.darkTextSecondary
        : AppColor.textSecondaryDefault;
    AppColor.borderColor = isDark
        ? AppColor.darkBorder
        : AppColor.borderDefault;
  }
}
