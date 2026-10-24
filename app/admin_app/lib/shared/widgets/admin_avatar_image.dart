import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/theme/app_color.dart';

/// A round customer photo with a neutral placeholder behind it.
///
/// The dashboard only fetches a picture when the value is a real `http(s)`
/// URL. `identity.profiles.avatar_url` holds a PATH inside the PRIVATE
/// `avatars` bucket (migration `084_customer_profile_avatars.sql`), and a
/// staff session may not read that bucket, so a path is never turned into a
/// request that is certain to fail: the placeholder is shown instead until
/// the backend hands out a displayable URL.
class AdminAvatarImage extends StatelessWidget {
  const AdminAvatarImage({super.key, this.url, this.size = 48});

  /// The stored value: a full URL, a storage path, or nothing.
  final String? url;

  final double size;

  bool get _isFetchable {
    final value = url?.trim() ?? '';
    return value.startsWith('http://') || value.startsWith('https://');
  }

  /// The placeholder keeps the same proportions the screens used before.
  double get _iconSize => size >= 48 ? 24 : 18;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: _isFetchable
            ? CachedNetworkImage(
                imageUrl: url!.trim(),
                fit: BoxFit.fill,
                placeholder: (_, _) => ColoredBox(
                  color: AppColor.secondaryColor,
                  child: Icon(HugeIcons.strokeRoundedUser, size: _iconSize),
                ),
                errorWidget: (_, _, _) => ColoredBox(
                  color: AppColor.secondaryColor,
                  child: Icon(HugeIcons.strokeRoundedUser, size: _iconSize),
                ),
              )
            : ColoredBox(
                color: AppColor.secondaryColor,
                child: Icon(HugeIcons.strokeRoundedUser, size: _iconSize),
              ),
      ),
    );
  }
}
