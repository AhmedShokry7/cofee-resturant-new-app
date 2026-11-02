import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Reading a provider the host may not have registered.
///
/// Widgets like the home bell, the assistant FAB and the assistant sheet are
/// pumped in isolation by tests and previews that have no notifications, auth or
/// cart layer above them. A missing provider there is a hosting accident, not a
/// bug to report, and each of them used to carry its own try/catch copy of this.
extension OptionalProvider on BuildContext {
  T? maybeRead<T extends Object>() {
    try {
      return read<T>();
    } catch (_) {
      return null;
    }
  }
}
