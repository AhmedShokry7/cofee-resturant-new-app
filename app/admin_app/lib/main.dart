import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:admin_app/features/auth/domain/usecases/check_session.dart';
import 'package:admin_app/features/auth/domain/usecases/sign_in.dart';
import 'package:admin_app/features/auth/domain/usecases/sign_out.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:admin_app/features/auth/presentation/pages/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandlers();

  await _guard('locale.init', () => AppLocale.instance.initialize());
  await _guard('theme.init', () => AppTheme.instance.initialize());
  await _guard('supabase.init', () => SupabaseService.init());

  AppConfig.debugLogConfiguration();
  runApp(const AdminApp());
}

/// معالجات الأخطاء العامة: بدونها يبتلع الإصدار المُطلَق كل خطأ بعد
/// `runApp` ويخرج الأدمن من الشاشة دون أثر يُقرأ، فيبقى العطل بلا شاهد.
///
/// تُركّب أخطاء الـ framework كما تُطبع، فالفحص البصري في التطوير لا يتغيّر.
void _installErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _logUncaught('FlutterError', details.exceptionAsString(), details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _logUncaught('UncaughtError', error.toString(), stack);
    return true;
  };
}

Future<void> _guard(String label, Future<void> Function() action) async {
  try {
    await action();
  } catch (error, stackTrace) {
    _logUncaught(label, error.toString(), stackTrace);
  }
}

/// سطرٌ واحد ونهايات المكدس: كافٍ لتشخيص العطل، ولا يحمل أي قيمة اعتمادية
/// لأن ما يُطبع هنا نصُّ الخطأ نفسه لا محتويات الإعدادات.
void _logUncaught(String label, String message, StackTrace? stackTrace) {
  debugPrint('[$label] $message');
  if (stackTrace != null) {
    debugPrintStack(stackTrace: stackTrace, maxFrames: 12);
  }
}

/// جذر التطبيق: يبني الاعتماديات مرة واحدة ويوفرها لشجرة الواجهة.
class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final AuthBloc _authBloc = _createAuthBloc();

  /// نقطة تركيب الاعتماديات: الطبقات تُبنى هنا فقط، لا داخل الواجهات.
  AuthBloc _createAuthBloc() {
    final repository = SupabaseAuthRepository();
    return AuthBloc(
      checkSessionUseCase: CheckSessionUseCase(repository),
      signInUseCase: SignInUseCase(repository),
      signOutUseCase: SignOutUseCase(repository),
    )..add(const AuthSessionCheckRequested());
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: _authBloc,
      child: ListenableBuilder(
        listenable: Listenable.merge([AppLocale.instance, AppTheme.instance]),
        builder: (context, _) {
          return MaterialApp(
            title: S.appName,
            debugShowCheckedModeBanner: false,
            theme: ThemeClass.light(),
            darkTheme: ThemeClass.dark(),
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
