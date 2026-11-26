/// How a failure that happens outside the widgets is reported.
///
/// A release build has no debugger attached, so an uncaught framework error
/// would otherwise disappear without a trace. Everything is logged through
/// `debugPrint` (which stays in release logs) so a crash on a real device can
/// be diagnosed from `adb logcat` instead of guessing.
library;

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Routes the uncaught errors of the framework and the platform here.
void installErrorLogging() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logFailure('FlutterError', details.exceptionAsString(), details.stack);
    _reportCrash(details.exception, details.stack, fatal: true);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logFailure('UncaughtError', error.toString(), stack);
    _reportCrash(error, stack, fatal: true);
    return true;
  };
}

/// Send only the error type and stack to Crashlytics. Exception messages can
/// contain customer input, credentials or provider response data.
void _reportCrash(Object error, StackTrace? stackTrace, {required bool fatal}) {
  if (kIsWeb || Firebase.apps.isEmpty) return;
  unawaited(
    FirebaseCrashlytics.instance.recordError(
      StateError('Unhandled ${error.runtimeType}'),
      stackTrace,
      fatal: fatal,
      reason: 'Unhandled customer app error',
    ),
  );
}

/// Runs a startup step and swallows its failure.
///
/// Startup must always reach `runApp`; a step that fails is logged and the app
/// continues with whatever state is available.
Future<void> runGuarded(String label, Future<void> Function() action) async {
  try {
    await action();
  } catch (error, stackTrace) {
    logFailure(label, error.toString(), stackTrace);
  }
}

/// Logs a failure under the label of the step that hit it.
void logFailure(String label, String message, StackTrace? stackTrace) {
  debugPrint('[$label] $message');
  if (stackTrace != null) {
    debugPrintStack(stackTrace: stackTrace, maxFrames: 12);
  }
}
