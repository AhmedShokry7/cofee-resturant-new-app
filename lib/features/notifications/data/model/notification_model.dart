import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';

class NotificationModel {
  const NotificationModel({
    required this.id,
    String? title,
    String? body,
    String? time,
    IconData? icon,
    this.titleAr,
    this.titleEn,
    this.bodyAr,
    this.bodyEn,
    this.type = 'system',
    this.createdAt,
    this.isRead = true,
  })  : _legacyTitle = title ?? '',
        _legacyBody = body ?? '',
        _legacyTime = time,
        _legacyIcon = icon;

  final String id;
  final String? titleAr;
  final String? titleEn;
  final String? bodyAr;
  final String? bodyEn;
  final String type;
  final DateTime? createdAt;
  final bool isRead;

  final String _legacyTitle;
  final String _legacyBody;
  final String? _legacyTime;
  final IconData? _legacyIcon;

  String get title {
    final text = pickText(
      (ar: titleAr ?? '', en: titleEn ?? ''),
      isArabic: AppLocale.instance.isArabic,
    );
    return text.isEmpty ? _legacyTitle : text;
  }

  String get body {
    final text = pickText(
      (ar: bodyAr ?? '', en: bodyEn ?? ''),
      isArabic: AppLocale.instance.isArabic,
    );
    return text.isEmpty ? _legacyBody : text;
  }

  /// Relative display time. Database rows carry timestamps; legacy display
  /// strings are preserved only for backward compatibility.
  String get time {
    if (_legacyTime != null) return _legacyTime;
    final at = createdAt;
    if (at == null) return '';
    final age = DateTime.now().difference(at);
    if (age.inMinutes < 1) return 'now';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }

  IconData get icon {
    if (_legacyIcon != null) return _legacyIcon;
    return switch (type) {
      'order_status' => HugeIcons.strokeRoundedTruckDelivery,
      'promo' => HugeIcons.strokeRoundedDiscountTag01,
      'loyalty' => HugeIcons.strokeRoundedFavourite,
      _ => HugeIcons.strokeRoundedNotification01,
    };
  }

  factory NotificationModel.fromDatabase(Map<String, dynamic> json) {
    final map = Db.asMap(json);
    final createdAt = Db.textOrNull(map['created_at']);
    return NotificationModel(
      id: Db.text(map['id']),
      titleAr: Db.textOrNull(map['title_ar']),
      titleEn: Db.textOrNull(map['title_en']),
      bodyAr: Db.textOrNull(map['body_ar']),
      bodyEn: Db.textOrNull(map['body_en']),
      type: Db.text(map['type'], 'system'),
      createdAt: createdAt == null
          ? null
          : DateTime.tryParse(createdAt)?.toLocal(),
      isRead: Db.asBool(map['is_read']),
    );
  }
}

