import 'package:flutter/material.dart';

import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_format.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';

/// The initials tile shown for a staff member.
class StaffAvatar extends StatelessWidget {
  const StaffAvatar({super.key, required this.member, this.size = 29});

  final AdminStaffMember member;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = adminInitialTint(member.id);
    return AdminAvatarImage(
      size: size,
      borderRadius: BorderRadius.circular(size * 0.31),
      fallbackText: staffInitials(member),
      placeholderColor: colors.$1,
      fallbackColor: colors.$2,
    );
  }
}
