import 'package:flutter/foundation.dart';

/// Owns the search query for the currently visible admin page.
///
/// The shell owns one instance and hands it to both the app bar (which writes
/// the query) and the active page (which binds a handler that filters its own
/// data). Binding is per-page, so switching pages rebinds the handler and the
/// query is cleared by the shell.
class AdminSearchController extends ChangeNotifier {
  String _query = '';
  ValueChanged<String>? _handler;

  String get query => _query;

  bool get hasQuery => _query.trim().isNotEmpty;

  /// Attaches the active page's filter. Pass null to detach the previous page.
  void bind(ValueChanged<String>? handler) {
    _handler = handler;
  }

  void update(String value) {
    final normalized = value.trim();
    if (_query == normalized) return;
    _query = normalized;
    _handler?.call(normalized);
    notifyListeners();
  }

  void clear() {
    if (_query.isEmpty) return;
    _query = '';
    _handler?.call('');
    notifyListeners();
  }
}
