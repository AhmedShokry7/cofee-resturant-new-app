import 'package:equatable/equatable.dart';

/// حزمة صلاحيات ممنوحة للموظف، لكل فرع أو لكل الفروع عندما يكون الفرع فارغًا.
class AdminPermissionScope extends Equatable {
  const AdminPermissionScope({this.branchId, required this.permissions});

  final String? branchId;
  final List<String> permissions;

  @override
  List<Object?> get props => <Object?>[branchId, permissions];
}
