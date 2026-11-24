import 'dart:math' as math;

import 'package:admin_app/features/notifications/domain/entities/admin_notification_bulk_delete.dart';
import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';

/// يحذف إشعارات محددة على دفعات متتالية. عند فشل دفعة تتوقف الدفعات التالية
/// ويعاد ما لم يُؤكَّد حذفه ليبقى محددًا للمحاولة مرة أخرى.
class BulkDeleteNotificationsUseCase {
  const BulkDeleteNotificationsUseCase(this._repository);

  /// Matches the server's per-request limit.
  static const int batchSize = 100;

  final NotificationsRepository _repository;

  Future<AdminNotificationBulkDeleteResult> call(List<String> ids) async {
    final unique = ids.toSet().toList(growable: false);
    final deleted = <String>[];
    final notFound = <String>[];
    final protectedIds = <String>[];

    for (var start = 0; start < unique.length; start += batchSize) {
      final end = math.min(start + batchSize, unique.length);
      final AdminNotificationBulkDeleteBatch batch;
      try {
        batch = await _repository.deleteNotificationsBatch(
          unique.sublist(start, end),
        );
      } catch (_) {
        return AdminNotificationBulkDeleteResult(
          deletedIds: deleted,
          notFoundIds: notFound,
          protectedIds: protectedIds,
          unprocessedIds: unique.sublist(start),
        );
      }
      deleted.addAll(batch.deletedIds);
      notFound.addAll(batch.notFoundIds);
      protectedIds.addAll(batch.protectedIds);
    }

    return AdminNotificationBulkDeleteResult(
      deletedIds: deleted,
      notFoundIds: notFound,
      protectedIds: protectedIds,
    );
  }
}
