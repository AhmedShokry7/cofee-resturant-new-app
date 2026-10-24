import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/audit/data/repositories/admin_audit_repository.dart';
import 'package:admin_app/features/audit/presentation/manager/admin_audit_state.dart';

class AdminAuditCubit extends Cubit<AdminAuditState> {
  AdminAuditCubit({AdminAuditRepository? repository})
    : _repository = repository ?? AdminAuditRepository(),
      super(const AdminAuditState());

  final AdminAuditRepository _repository;

  AdminAuditRepository get repository => _repository;

  Future<void> load({int limit = 200}) async {
    emit(state.copyWith(status: AdminAuditStatus.loading, clearError: true));
    try {
      final logs = await _repository.loadLogs(limit: limit);
      emit(
        state.copyWith(
          status: AdminAuditStatus.ready,
          logs: logs,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminAuditStatus.failure,
          errorMessage: '$error',
        ),
      );
    }
  }
}
