import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';

/// A table a [PostgresChangesFeed] listens to, with the schema holding it.
class RealtimeTable {
  const RealtimeTable(this.schema, this.table);

  final String schema;
  final String table;
}

/// Subscribes to a set of tables so one screen reacts the moment another
/// screen, another device, or the database itself changes them.
///
/// Events are coalesced: one order update writes the order, its history and
/// its ticket, and the reader only needs one reload after that burst.
///
/// The subscription heals itself: a dropped socket or a failed join is retried
/// with a backoff, and every successful (re)join triggers one reload so changes
/// made while the channel was down are not lost.
class PostgresChangesFeed {
  PostgresChangesFeed({
    required this.tables,
    required this.channelPrefix,
    this.client,
  });

  /// The tables whose writes move the counter.
  final List<RealtimeTable> tables;

  /// The prefix of the channel name, so two readers never share a channel.
  final String channelPrefix;

  final SupabaseClient? client;

  RealtimeChannel? _channel;
  SupabaseClient? _activeClient;
  Timer? _debounce;
  Timer? _retry;
  VoidCallback? _onChanged;
  int _attempt = 0;
  int _channelSeq = 0;
  bool _disposed = false;

  bool get isActive => _channel != null;

  void start(VoidCallback onChanged) {
    if (_channel != null || _retry != null) return;
    _disposed = false;
    _onChanged = onChanged;
    _activeClient = client ?? SupabaseService.client;
    _attempt = 0;
    _open();
  }

  void _open() {
    final client = _activeClient;
    final onChanged = _onChanged;
    if (_disposed || client == null || onChanged == null) return;

    var channel = client.channel('$channelPrefix:${_channelSeq++}');
    for (final table in tables) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: table.schema,
        table: table.table,
        callback: (_) => _notify(),
      );
    }

    _channel = channel;
    channel.subscribe((status, _) => _onStatus(channel, status));
  }

  void _onStatus(RealtimeChannel channel, RealtimeSubscribeStatus status) {
    if (_disposed || !identical(channel, _channel)) return;

    switch (status) {
      case RealtimeSubscribeStatus.subscribed:
        _attempt = 0;
        // The first load and the subscribe are raced, and a reconnect may have
        // missed an event: one quiet reload after joining closes the gap.
        _notify();
        break;
      case RealtimeSubscribeStatus.channelError:
      case RealtimeSubscribeStatus.timedOut:
      case RealtimeSubscribeStatus.closed:
        _scheduleReconnect();
        break;
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _onChanged == null || _retry != null) return;
    final seconds = 1 << _attempt.clamp(0, 4);
    _attempt = (_attempt + 1).clamp(0, 4);
    _retry = Timer(Duration(seconds: seconds), _reconnect);
  }

  Future<void> _reconnect() async {
    _retry = null;
    if (_disposed || _onChanged == null) return;

    final oldChannel = _channel;
    final client = _activeClient;
    _channel = null;
    if (oldChannel != null && client != null) {
      try {
        await client.removeChannel(oldChannel);
      } catch (_) {
        // The socket may already be gone; opening a channel reconnects it.
      }
    }
    if (_disposed) return;
    _open();
  }

  void _notify() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _onChanged?.call(),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    _retry?.cancel();
    _retry = null;
    _debounce?.cancel();
    _debounce = null;
    _onChanged = null;
    final channel = _channel;
    final client = _activeClient;
    _channel = null;
    _activeClient = null;
    if (channel != null && client != null) {
      try {
        await client.removeChannel(channel);
      } catch (_) {
        // Closing a dead socket is not an error worth surfacing.
      }
    }
  }
}
