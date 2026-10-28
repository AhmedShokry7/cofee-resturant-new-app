import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/postgres_changes_feed.dart';

/// Subscribes to the orders table so the directory reacts the moment another
/// screen, the kitchen, or the database itself changes an order.
///
/// The event carries no data the dashboard trusts: it is only a nudge to
/// re-run `admin_orders`, which filters by the reader's own permissions. A
/// branch therefore never sees a row its RPC would not return, and a missed
/// event costs one reload, not a wrong number on screen.
class OrderRealtimeFeed extends PostgresChangesFeed {
  OrderRealtimeFeed([SupabaseClient? client])
    : super(
        channelPrefix: 'admin-orders-live',
        tables: const <RealtimeTable>[RealtimeTable('orders', 'orders')],
        client: client,
      );
}
