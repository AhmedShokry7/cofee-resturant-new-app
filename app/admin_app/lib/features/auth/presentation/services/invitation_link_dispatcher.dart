import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'package:admin_app/features/auth/presentation/models/invitation_link.dart';

import 'invitation_link_browser_stub.dart'
    if (dart.library.html) 'invitation_link_browser_web.dart'
    as browser;

/// Delivers invitation URLs to the signed-out auth screen.
///
/// Start before Supabase initialization so this listener and Supabase's own
/// auth-callback listener both receive the native cold-start URI. The URI is
/// retained until the auth screen consumes it; no token is logged or stored.
class InvitationLinkDispatcher {
  InvitationLinkDispatcher._();

  static final InvitationLinkDispatcher instance = InvitationLinkDispatcher._();

  final AppLinks _appLinks = AppLinks();
  final ValueNotifier<InvitationLinkEvent?> events =
      ValueNotifier<InvitationLinkEvent?>(null);
  StreamSubscription<Uri>? _nativeSubscription;
  StreamSubscription<Uri>? _browserSubscription;
  int _nextId = 0;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    if (kIsWeb) {
      _publish(Uri.base);
      _browserSubscription = browser.uriChanges.listen(_publish);
      return;
    }

    // Subscribe before Supabase.initialize: its auth listener also listens to
    // this broadcast stream and consumes OTP callbacks independently.
    _nativeSubscription = _appLinks.uriLinkStream.listen(
      _publish,
      onError: (Object error, StackTrace stackTrace) {
        // Do not log URI/error payloads; a later link can still be delivered.
      },
    );
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _publish(initialUri);
    } on Object {
      // The stream still handles links received while the app is running.
    }
  }

  void replaceBrowserUrl(Uri uri) {
    if (kIsWeb) browser.updateAddress(uri);
  }

  void acknowledge(int id) {
    if (events.value?.id == id) events.value = null;
  }

  Future<void> dispose() async {
    await _nativeSubscription?.cancel();
    await _browserSubscription?.cancel();
    events.dispose();
  }

  void _publish(Uri uri) {
    if (!InvitationLink.containsInviteParameter(uri)) return;
    events.value = InvitationLinkEvent(id: ++_nextId, uri: uri);
  }
}

/// A unique delivery makes a repeated tap on the same link observable too.
@immutable
class InvitationLinkEvent {
  const InvitationLinkEvent({required this.id, required this.uri});

  final int id;
  final Uri uri;
}
