import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/auth/presentation/manager/admin_auth_cubit.dart';
import 'package:admin_app/features/auth/presentation/pages/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppLocale.instance.initialize();
  await AppTheme.instance.initialize();

  try {
    await SupabaseService.init();
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[main] Supabase init failed.');
      debugPrint('[main] $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  AppConfig.debugLogConfiguration();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminAuthCubit>(
      create: (_) => AdminAuthCubit()..checkSession(),
      child: ListenableBuilder(
        listenable: Listenable.merge([AppLocale.instance, AppTheme.instance]),
        builder: (context, _) {
          final isArabic = AppLocale.instance.isArabic;
          return MaterialApp(
            title: 'Admin',
            debugShowCheckedModeBanner: false,
            theme: ThemeClass.light(isArabic: isArabic),
            darkTheme: ThemeClass.dark(isArabic: isArabic),
            themeMode: AppTheme.instance.materialThemeMode,
            locale: AppLocale.instance.locale,
            supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => Directionality(
              textDirection: AppLocale.instance.textDirection,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}
