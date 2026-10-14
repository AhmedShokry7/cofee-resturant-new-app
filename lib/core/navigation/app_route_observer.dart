import 'package:flutter/material.dart';

/// Tracks the top route name of the root navigator so widgets that live
/// above the [Navigator] (e.g. global overlays) can react to navigation.
class AppRouteObserver extends NavigatorObserver {
  AppRouteObserver._();

  static final AppRouteObserver instance = AppRouteObserver._();

  final ValueNotifier<String?> currentRouteName = ValueNotifier<String?>(null);

  void _set(Route<dynamic>? route) {
    currentRouteName.value = route?.settings.name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _set(newRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(previousRoute ?? route);
}
