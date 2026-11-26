import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:new_coffee/core/navigation/app_route_observer.dart';
import 'package:new_coffee/features/notifications/data/services/push_service.dart';

class RefreshOnReturn extends StatefulWidget {
  const RefreshOnReturn({
    super.key,
    required this.onRefresh,
    required this.child,
  });
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  State<RefreshOnReturn> createState() => _RefreshOnReturnState();
}

class _RefreshOnReturnState extends State<RefreshOnReturn>
    with WidgetsBindingObserver {
  ModalRoute<dynamic>? route;
  late final StreamSubscription<dynamic> push;
  bool running = false;
  bool pending = false;
  bool covered = false;

  Future<void> refresh() async {
    if (route?.isCurrent != true) return;
    pending = true;
    if (running) return;
    running = true;
    try {
      while (mounted && pending) {
        pending = false;
        await widget.onRefresh();
      }
    } finally {
      running = false;
    }
  }

  void routeChanged() {
    if (route?.isCurrent == true && covered) unawaited(refresh());
    covered = route?.isCurrent == false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    route = ModalRoute.of(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppRouteObserver.instance.currentRouteName.addListener(routeChanged);
    push = PushService.onForegroundMessage.listen((_) => refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppRouteObserver.instance.currentRouteName.removeListener(routeChanged);
    push.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
