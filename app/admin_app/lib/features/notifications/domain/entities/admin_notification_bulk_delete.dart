/// Ids of deletable notifications that match the directory filters.
class AdminNotificationMatchingIds {
  const AdminNotificationMatchingIds({
    required this.total,
    required this.tooMany,
    this.ids = const <String>[],
  });

  /// Matches the server cap: above this the selection is refused.
  static const int maxSelectable = 1000;

  final int total;
  final bool tooMany;
  final List<String> ids;
}

/// Per-id outcome of one bulk delete request.
class AdminNotificationBulkDeleteBatch {
  const AdminNotificationBulkDeleteBatch({
    this.deletedIds = const <String>[],
    this.notFoundIds = const <String>[],
    this.protectedIds = const <String>[],
  });

  final List<String> deletedIds;
  final List<String> notFoundIds;

  /// Campaign-linked rows the server refused to delete.
  final List<String> protectedIds;
}

/// Combined outcome across every chunk of a bulk delete.
///
/// [unprocessedIds] holds ids that were not confirmed by the server, either
/// because a chunk failed or because an earlier chunk failed and the rest
/// were not attempted. They stay selected so the admin can retry.
class AdminNotificationBulkDeleteResult {
  const AdminNotificationBulkDeleteResult({
    this.deletedIds = const <String>[],
    this.notFoundIds = const <String>[],
    this.protectedIds = const <String>[],
    this.unprocessedIds = const <String>[],
  });

  final List<String> deletedIds;
  final List<String> notFoundIds;
  final List<String> protectedIds;
  final List<String> unprocessedIds;

  int get deletedCount => deletedIds.length;
  bool get hasFailures => unprocessedIds.isNotEmpty;
}
