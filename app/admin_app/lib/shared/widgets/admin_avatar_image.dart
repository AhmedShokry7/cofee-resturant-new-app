import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';

/// A customer photo with a neutral placeholder behind it.
///
/// The dashboard only fetches a picture when the value is a real `http(s)`
/// URL. `identity.profiles.avatar_url` holds a PATH inside the PRIVATE
/// `avatars` bucket (migration `084_customer_profile_avatars.sql`), and a
/// staff session may not read that bucket, so a path is never turned into a
/// request that is certain to fail: the placeholder is shown instead until
/// the backend hands out a displayable URL.
class AdminAvatarImage extends StatelessWidget {
  const AdminAvatarImage({
    super.key,
    this.url,
    this.size = 48,
    this.borderRadius,
    this.fallbackText,
    this.placeholderColor,
    this.fallbackColor,
  });

  /// The stored value: a full URL, a storage path, or nothing.
  final String? url;

  final double size;

  /// Rounds the photo and its placeholder. Defaults to a circle.
  final BorderRadius? borderRadius;

  /// Shown instead of the generic person icon when there is no photo.
  final String? fallbackText;

  final Color? placeholderColor;
  final Color? fallbackColor;

  bool get _isFetchable {
    final value = url?.trim() ?? '';
    return value.startsWith('http://') || value.startsWith('https://');
  }

  /// The placeholder keeps the same proportions the screens used before.
  double get _iconSize => size >= 48 ? 24 : 18;

  @override
  Widget build(BuildContext context) {
    final text = fallbackText?.trim() ?? '';
    final placeholder = ColoredBox(
      color: placeholderColor ?? AppColor.secondaryColor,
      child: Center(
        child: text.isEmpty
            ? Icon(AppIcons.user, size: _iconSize)
            : Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  color: fallbackColor ?? AppColor.primaryColor,
                  fontSize: size * 0.34,
                  fontWeight: AppFontWeights.semiBold,
                  height: AppTextHeights.line1_1,
                ),
              ),
      ),
    );
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(size / 2),
      child: SizedBox(
        width: size,
        height: size,
        child: _isFetchable
            ? CachedNetworkImage(
                imageUrl: url!.trim(),
                fit: BoxFit.fill,
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) => placeholder,
              )
            : placeholder,
      ),
    );
  }
}

/// خلفية وحبر الصورة الأولية لمعرف بعينه.
///
/// نفس المعرف يعطي نفس اللون دائمًا في كل الشاشات، فاللون يصير علامة صاحب
/// السجل لا رقمًا يتغير بين جدول وآخر.
(Color, Color) adminInitialTint(String id) {
  var hash = 0;
  for (final code in id.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return AppColor.initialTints[hash % AppColor.initialTints.length];
}
