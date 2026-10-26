import 'package:flutter/material.dart';

import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_member.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_format.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';

class LoyaltyMemberAvatar extends StatelessWidget {
  const LoyaltyMemberAvatar({super.key, required this.member, this.size = 29});

  final AdminLoyaltyMember member;
  final double size;

  @override
  Widget build(BuildContext context) => AdminAvatarImage(
    url: member.avatarUrl,
    size: size,
    borderRadius: BorderRadius.circular(size * 0.31),
    fallbackText: loyaltyMemberInitials(member),
  );
}

class LoyaltyTierBadge extends StatelessWidget {
  const LoyaltyTierBadge({super.key, required this.tier});

  final String tier;

  @override
  Widget build(BuildContext context) =>
      AdminStatusBadge(label: loyaltyTierLabel(tier), color: _tierColor(tier));

  static Color _tierColor(String tier) => switch (tier) {
    'silver' => AppColor.adminInfo,
    'gold' => AppColor.adminWarning,
    'platinum' => const Color(0xFF7E57C2),
    _ => const Color(0xFFB67653),
  };
}
