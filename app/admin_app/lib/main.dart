import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/auth/presentation/manager/admin_auth_cubit.dart';
import 'package:admin_app/features/auth/presentation/views/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      child: ScreenUtilInit(
        designSize: const Size(360, 690),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp(
            title: 'Admin',
            debugShowCheckedModeBanner: false,
            theme: ThemeClass.light(isArabic: false),
            locale: const Locale('en'),
            supportedLocales: const <Locale>[Locale('en')],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}
