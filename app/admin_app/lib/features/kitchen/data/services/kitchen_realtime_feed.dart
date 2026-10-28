import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/postgres_changes_feed.dart';

/// Subscribes to the kitchen tables so the board reacts the moment another
/// screen (or another device) changes a ticket.
class KitchenRealtimeFeed extends PostgresChangesFeed {
  KitchenRealtimeFeed([SupabaseClient? client])
    : super(
        channelPrefix: 'admin-kitchen-live',
        tables: const <RealtimeTable>[
          RealtimeTable('kitchen', 'tickets'),
          RealtimeTable('kitchen', 'ticket_items'),
        ],
        client: client,
      );
}
