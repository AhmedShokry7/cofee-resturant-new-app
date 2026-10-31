import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/postgres_changes_feed.dart';

/// Subscribes to `engagement.notifications` so the admin directory reacts the
/// moment a campaign is sent, a customer reads a message, or another screen
/// deletes one.
///
/// The event carries nothing the page trusts: it is only a nudge to re-run
/// `admin_notifications`, which applies this reader's own filters and
/// permissions. A missed event therefore costs one reload, not a wrong row.
class NotificationsRealtimeFeed extends PostgresChangesFeed {
  NotificationsRealtimeFeed([SupabaseClient? client])
    : super(
        channelPrefix: 'admin-notifications-live',
        tables: const <RealtimeTable>[
          RealtimeTable('engagement', 'notifications'),
        ],
        client: client,
      );
}
