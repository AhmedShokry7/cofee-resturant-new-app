import 'dart:async';

import 'package:web/web.dart' as web;

Stream<Uri> get uriChanges => web.window.onPopState.map((_) => Uri.base);

void updateAddress(Uri uri) {
  web.window.history.replaceState(null, '', uri.toString());
}
