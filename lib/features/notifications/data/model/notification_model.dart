import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
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
    this.relatedEntityType,
    this.relatedEntityId,
    this.imageUrl,
    this.destination,
    this.createdAt,
    this.isRead = true,
  }) : _legacyTitle = title ?? '',
       _legacyBody = body ?? '',
       _legacyTime = time,
       _legacyIcon = icon;

  final String id;
  final String? titleAr;
  final String? titleEn;
  final String? bodyAr;
  final String? bodyEn;
  final String type;
  final String? relatedEntityType;
  final String? relatedEntityId;

  /// The campaign picture, or null for a plain message.
  final String? imageUrl;

  /// The screen the composer chose for this message, as a code, never a path.
  final String? destination;
  final DateTime? createdAt;
  final bool isRead;

  final String _legacyTitle;
  final String _legacyBody;
  final String? _legacyTime;
  final IconData? _legacyIcon;

  String get title {
    final text = pickText((
      ar: titleAr ?? '',
      en: titleEn ?? '',
    ), isArabic: AppLocale.instance.isArabic);
    return text.isEmpty ? _legacyTitle : text;
  }

  String get body {
    final text = pickText((
      ar: bodyAr ?? '',
      en: bodyEn ?? '',
    ), isArabic: AppLocale.instance.isArabic);
    return text.isEmpty ? _legacyBody : text;
  }

  /// Relative display time. Database rows carry timestamps; legacy display
  /// strings are preserved only for backward compatibility.
  String get time {
    if (_legacyTime != null) return _legacyTime;
    final at = createdAt;
    if (at == null) return '';
    final age = DateTime.now().difference(at);
    final arabic = AppLocale.instance.isArabic;
    if (age.inMinutes < 1) return arabic ? 'الآن' : 'now';
    if (age.inMinutes < 60) {
      return arabic ? 'قبل ${age.inMinutes} دقيقة' : '${age.inMinutes}m ago';
    }
    if (age.inHours < 24) {
      return arabic ? 'قبل ${age.inHours} ساعة' : '${age.inHours}h ago';
    }
    return arabic ? 'قبل ${age.inDays} يوم' : '${age.inDays}d ago';
  }

  IconData get icon {
    if (_legacyIcon != null) return _legacyIcon;
    return switch (type) {
      'order_status' => AppIcons.deliveryTruck,
      'promo' => AppIcons.discountTag,
      'loyalty' => AppIcons.favourite,
      'subscription' => AppIcons.calendar,
      _ => AppIcons.notification,
    };
  }

  factory NotificationModel.fromDatabase(Map<String, dynamic> json) {
    final map = Db.asMap(json);
    final payload = Db.asMap(map['payload']);
    final createdAt = Db.textOrNull(map['created_at']);
    return NotificationModel(
      id: Db.text(map['id']),
      titleAr: Db.textOrNull(map['title_ar']),
      titleEn: Db.textOrNull(map['title_en']),
      bodyAr: Db.textOrNull(map['body_ar']),
      bodyEn: Db.textOrNull(map['body_en']),
      type: Db.text(map['type'], 'system'),
      relatedEntityType: Db.textOrNull(map['related_entity_type']),
      relatedEntityId: Db.textOrNull(map['related_entity_id']),
      imageUrl: imageUrlOf(payload['image_url']),
      destination: destinationOf(payload['destination']),
      createdAt: createdAt == null
          ? null
          : DateTime.tryParse(createdAt)?.toLocal(),
      isRead: Db.asBool(map['is_read']),
    );
  }
}

/// The picture of a row, or null when the value cannot be one.
///
/// The column is a free jsonb, and a campaign may be sent with no picture at
/// all, so anything that is not an absolute url is dropped here rather than
/// handed to the renderer.
String? imageUrlOf(Object? value) {
  final url = Db.textOrNull(value)?.trim();
  if (url == null) return null;
  return url.startsWith('https://') || url.startsWith('http://') ? url : null;
}

/// The screen code of a row, or null.
///
/// A value that carries a separator is not a code: the app opens only the
/// destinations `routeForNotification` knows, never a path it was handed.
String? destinationOf(Object? value) {
  final code = Db.textOrNull(value)?.trim().toLowerCase();
  if (code == null || code.length > 64) return null;
  return RegExp(r'^[a-z0-9_-]+$').hasMatch(code) ? code : null;
}
