import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';

/// A single before/after row of the event details dialog.
class AuditFieldChange {
  const AuditFieldChange({
    required this.key,
    required this.before,
    required this.after,
  });

  final String key;
  final Object? before;
  final Object? after;
}

const _ignoredChangeFields = <String>{
  'id',
  'created_at',
  'updated_at',
  'archived_at',
  'brand_id',
};

String auditActionLabel(String action) => switch (action) {
  'core.branch.create' => S.auditActionBranchCreate,
  'core.branch.update' => S.auditActionBranchUpdate,
  'core.branch.delete' => S.auditActionBranchDelete,
  'core.branch.activate' => S.auditActionBranchActivate,
  'core.branch.deactivate' => S.auditActionBranchDeactivate,
  'core.branch.image' => S.auditActionBranchImage,
  'marketing.coupon.create' => S.auditActionCouponCreate,
  'marketing.coupon.update' => S.auditActionCouponUpdate,
  'marketing.coupon.delete' => S.auditActionCouponDelete,
  'marketing.coupon.activate' => S.auditActionCouponActivate,
  'marketing.coupon.pause' => S.auditActionCouponPause,
  'loyalty.reward.create' => S.auditActionRewardCreate,
  'loyalty.reward.update' => S.auditActionRewardUpdate,
  'loyalty.reward.delete' => S.auditActionRewardDelete,
  'loyalty.reward.activate' => S.auditActionRewardActivate,
  'loyalty.reward.pause' => S.auditActionRewardPause,
  'loyalty.rule.create' => S.auditActionRuleCreate,
  'loyalty.rule.update' => S.auditActionRuleUpdate,
  'engagement.review.publish' => S.auditActionReviewPublish,
  'engagement.review.hide' => S.auditActionReviewHide,
  'engagement.review.delete' => S.auditActionReviewDelete,
  'engagement.notification.send' => S.auditActionNotificationSend,
  'engagement.notification.resend' => S.auditActionNotificationResend,
  'engagement.notification.read' => S.auditActionNotificationRead,
  'engagement.notification.delete' => S.auditActionNotificationDelete,
  'order.status.update' => S.auditActionOrderStatus,
  'kitchen.ticket.update' => S.auditActionKitchenTicketUpdate,
  'kitchen.item.update' => S.auditActionKitchenItemUpdate,
  'stock.adjust' => S.auditActionStockAdjust,
  'stock.material.create' => S.auditActionMaterialCreate,
  'stock.material.update' => S.auditActionMaterialUpdate,
  'stock.material.delete' => S.auditActionMaterialDelete,
  'staff.provision' => S.auditActionStaffProvision,
  _ => S.auditUnknownAction,
};

String auditDomainKey(AdminAuditLog log) {
  final domain = log.actionDomain.toLowerCase();
  return switch (domain) {
    'orders' => 'order',
    'inventory' => 'stock',
    'payments' => 'payment',
    'subscriptions' => 'subscription',
    'permission' ||
    'permissions' ||
    'role' ||
    'roles' ||
    'identity' ||
    'security' => 'identity',
    _ => domain,
  };
}

String auditDomainLabel(String domain) => switch (domain) {
  'core' => S.auditDomainCore,
  'order' => S.auditDomainOrders,
  'kitchen' => S.auditDomainKitchen,
  'catalog' => S.auditDomainCatalog,
  'marketing' => S.auditDomainMarketing,
  'loyalty' => S.auditDomainLoyalty,
  'subscription' => S.auditDomainSubscriptions,
  'engagement' => S.auditDomainEngagement,
  'stock' => S.auditDomainInventory,
  'staff' => S.auditDomainStaff,
  'payment' => S.auditDomainPayments,
  'identity' => S.auditDomainSecurity,
  _ => S.auditDomainOther,
};

IconData auditDomainIcon(String domain) => switch (domain) {
  'core' => AppIcons.store01,
  'order' => AppIcons.shoppingCart01,
  'kitchen' => AppIcons.chefHat,
  'catalog' => AppIcons.package,
  'marketing' => AppIcons.tag01,
  'loyalty' => AppIcons.gift,
  'subscription' => AppIcons.repeat,
  'engagement' => AppIcons.notification01,
  'stock' => AppIcons.cube,
  'staff' => AppIcons.userMultiple,
  'payment' => AppIcons.creditCard,
  'identity' => AppIcons.securityCheck,
  _ => AppIcons.clipboard,
};

Color auditDomainColor(String domain) => switch (domain) {
  'core' || 'catalog' => AppColor.adminAccent,
  'order' || 'subscription' || 'engagement' || 'kitchen' => AppColor.adminInfo,
  'marketing' || 'loyalty' || 'stock' => AppColor.adminWarning,
  'staff' || 'identity' => AppColor.trendNegative,
  'payment' => AppColor.trendPositive,
  _ => AppColor.adminMuted,
};

Color auditDomainSurface(String domain) => switch (domain) {
  'core' || 'catalog' => AppColor.adminAccentSurface,
  'order' ||
  'subscription' ||
  'engagement' ||
  'kitchen' => AppColor.adminInfoSurface,
  'marketing' || 'loyalty' || 'stock' => AppColor.adminWarningSurface,
  'staff' || 'identity' => AppColor.trendNegativeSurface,
  'payment' => AppColor.trendPositiveSurface,
  _ => AppColor.adminTableHeader,
};

String auditActorName(AdminAuditLog log) {
  final name = log.actorName?.trim();
  if (name != null && name.isNotEmpty) return name;
  final email = log.actorEmail?.trim();
  if (email != null && email.isNotEmpty) return email;
  if ((log.actorUserId ?? '').trim().isEmpty) return S.auditSystemActor;
  return S.auditUnknownActor;
}

String auditActorRole(AdminAuditLog log) {
  final roles = log.actorRolesFor(AppLocale.instance.language);
  if (roles.isNotEmpty) return roles.take(2).join(' • ');
  if ((log.actorUserId ?? '').trim().isEmpty) return S.auditSystemActor;
  return S.auditStaffRole;
}

String auditActorInitial(AdminAuditLog log) {
  final name = auditActorName(log).trim();
  if (name.isEmpty || name == S.auditSystemActor) return '—';
  return name.characters.first.toUpperCase();
}

/// A human name for the row the event touched, taken from the audit payload.
String? auditSubject(AdminAuditLog log) {
  final arabic = AppLocale.instance.isArabic;
  final keys = arabic
      ? const [
          'name_ar',
          'title_ar',
          'product_name_ar',
          'category_name_ar',
          'name_en',
          'title_en',
          'product_name_en',
          'category_name_en',
          'code',
          'order_number',
          'full_name',
          'email',
          'sku',
        ]
      : const [
          'name_en',
          'title_en',
          'product_name_en',
          'category_name_en',
          'name_ar',
          'title_ar',
          'product_name_ar',
          'category_name_ar',
          'code',
          'order_number',
          'full_name',
          'email',
          'sku',
        ];
  for (final key in keys) {
    for (final values in [log.newValues, log.oldValues]) {
      final value = values?[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
  }
  return null;
}

String auditEventTitle(AdminAuditLog log) {
  final subject = auditSubject(log);
  final action = auditActionLabel(log.action);
  return subject == null ? action : '$action • $subject';
}

String auditEntityLabel(String entityType) => switch (entityType) {
  'branch' => S.auditEntityBranch,
  'coupon' => S.auditEntityCoupon,
  'loyalty_reward' => S.auditEntityReward,
  'loyalty_rule' => S.auditEntityRule,
  'product_review' => S.auditEntityReview,
  'notification' => S.auditEntityNotification,
  'notification_campaign' => S.auditEntityCampaign,
  'order' => S.auditEntityOrder,
  'kitchen_ticket' => S.auditEntityKitchenTicket,
  'stock' => S.auditEntityStock,
  'raw_material' => S.auditEntityMaterial,
  'staff_member' => S.auditEntityStaff,
  _ => S.auditEntityOther,
};

String auditShortId(String? value) {
  final id = value?.trim() ?? '';
  if (id.length <= 10) return id;
  return '${id.substring(0, 8)}…';
}

String auditDayLabel(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  final now = DateTime.now();
  if (_sameDay(local, now)) return S.today;
  if (_sameDay(local, now.subtract(const Duration(days: 1)))) {
    return S.yesterday;
  }
  return localizedDate(local);
}

String auditClockLabel(DateTime? value) =>
    value == null ? '—' : localizedTime(value);

String auditRelativeTimeLabel(DateTime? value) => localizedRelativeDay(
  value,
  todayLabel: S.today,
  yesterdayLabel: S.yesterday,
);

String auditFieldLabel(String key) => switch (key) {
  'code' => S.auditFieldCode,
  'name_ar' => S.auditFieldNameAr,
  'name_en' => S.auditFieldNameEn,
  'title_ar' => S.auditFieldTitleAr,
  'title_en' => S.auditFieldTitleEn,
  'description_ar' => S.auditFieldDescriptionAr,
  'description_en' => S.auditFieldDescriptionEn,
  'body_ar' || 'body_en' => S.auditFieldBody,
  'address' || 'address_ar' => S.auditFieldAddressAr,
  'address_en' => S.auditFieldAddressEn,
  'city' => S.auditFieldCity,
  'district' => S.auditFieldDistrict,
  'phone' => S.auditFieldPhone,
  'email' => S.email,
  'latitude' => S.auditFieldLatitude,
  'longitude' => S.auditFieldLongitude,
  'opens_at' => S.auditFieldOpensAt,
  'closes_at' => S.auditFieldClosesAt,
  'is_active' || 'active' => S.status,
  'has_image' || 'image_url' => S.image,
  'discount_type' => S.auditFieldDiscountType,
  'discount_value' => S.auditFieldDiscountValue,
  'max_discount' => S.auditFieldMaxDiscount,
  'min_order_amount' => S.auditFieldMinOrder,
  'applies_to' => S.auditFieldAppliesTo,
  'usage_limit' => S.auditFieldUsageLimit,
  'per_user_limit' => S.auditFieldPerUser,
  'starts_at' => S.auditFieldStartsAt,
  'ends_at' => S.auditFieldEndsAt,
  'valid_from' => S.auditFieldStartsAt,
  'valid_to' => S.auditFieldEndsAt,
  'category_ids' => S.auditFieldCategories,
  'category' => S.category,
  'product_ids' => S.auditFieldProducts,
  'product_id' => S.auditFieldProduct,
  'points_cost' => S.auditFieldPointsCost,
  'stock_available' => S.auditFieldStockAvailable,
  'is_published' => S.auditFieldPublished,
  'is_read' => S.auditFieldRead,
  'type' => S.auditFieldType,
  'audience' => S.auditFieldAudience,
  'audience_user' => S.auditFieldAudienceUser,
  'recipients' => S.auditFieldRecipients,
  'queued' => S.auditFieldQueued,
  'user_id' || 'user' => S.auditFieldUser,
  'campaign_id' => S.auditEntityCampaign,
  'points_per_currency_unit' => S.auditFieldPointsRate,
  'point_value' => S.auditFieldPointValue,
  'status' => S.status,
  'branch' || 'branch_id' => S.auditFieldBranch,
  'delta' => S.auditFieldDelta,
  'reason' => S.auditFieldReason,
  'result' => S.auditFieldResult,
  'sku' => S.auditFieldSku,
  'unit' => S.auditFieldUnit,
  'unit_cost' => S.auditFieldUnitCost,
  'reorder_level' => S.auditFieldReorderLevel,
  'material' => S.auditFieldMaterial,
  'quantity' => S.auditFieldQuantity,
  'balance' => S.auditFieldBalance,
  'reference' => S.auditFieldReference,
  'notes' => S.auditFieldNote,
  'full_name' => S.name,
  'role' => S.role,
  'rating' => S.auditFieldRating,
  'comment' => S.auditFieldComment,
  'note' => S.auditFieldNote,
  'order_id' => S.orderNumber,
  'order_number' => S.orderNumber,
  'item_id' => S.auditFieldItem,
  'created_at' => S.createdAt,
  'updated_at' => S.updatedAt,
  _ => key.replaceAll('_', ' '),
};

String auditValueLabel(String key, Object? value) {
  if (value == null) return S.auditDetailsNoValue;
  if (value is bool) {
    return switch (key) {
      'has_image' => value ? S.auditValueHasImage : S.auditValueNoImage,
      'queued' => value ? S.auditValueQueued : S.auditValueNotQueued,
      'is_published' => value ? S.published : S.reviewsHidden,
      'is_read' || 'read' => value ? S.auditValueRead : S.auditValueUnread,
      'is_active' || 'active' => value ? S.activeStatus : S.inactiveStatus,
      _ => value ? S.yes : S.no,
    };
  }
  if (value is num) return _numberLabel(value);
  if (value is List) {
    if (value.isEmpty) return S.auditValueEmptyList;
    if (key == 'category_ids' || key == 'product_ids') {
      return S.auditSelectedCount(value.length);
    }
    if (value.every((item) => item is num || item is String || item is bool)) {
      return value.map(_scalarLabel).join('، ');
    }
    return S.auditSelectedCount(value.length);
  }
  if (value is Map) return _compactJson(value);

  final text = '$value'.trim();
  if (text.isEmpty) return S.auditDetailsNoValue;
  if (key == 'status' || key.endsWith('_status')) {
    final order = S.orderStatusLabel(text);
    if (order != text) return order;
    return switch (text) {
      'active' => S.activeStatus,
      'inactive' => S.inactiveStatus,
      'published' => S.published,
      'hidden' => S.reviewsHidden,
      _ => text,
    };
  }
  if (key == 'opens_at' || key == 'closes_at') return _clockLabel(text);
  if (key == 'starts_at' ||
      key == 'ends_at' ||
      key == 'valid_from' ||
      key == 'valid_to' ||
      key.endsWith('_at')) {
    final date = DateTime.tryParse(text);
    if (date != null) return localizedDateTime(date);
  }
  if (key == 'applies_to') {
    return switch (text) {
      'all' => S.auditValueAppliesAll,
      'category' => S.auditValueAppliesCategory,
      'product' => S.auditValueAppliesProduct,
      _ => text,
    };
  }
  if (key == 'discount_type') {
    return switch (text) {
      'percentage' => S.auditValueDiscountPercentage,
      'fixed_amount' => S.auditValueDiscountFixed,
      _ => text,
    };
  }
  if (key == 'audience') {
    return switch (text) {
      'all' => S.auditValueAudienceAll,
      'push_enabled' => S.auditValueAudiencePush,
      'has_device' => S.auditValueAudienceDevice,
      'customer' => S.auditValueAudienceCustomer,
      _ => text,
    };
  }
  if (key == 'reason') {
    return switch (text) {
      'restock' => S.auditValueStockRestock,
      'adjustment' => S.auditValueStockAdjustment,
      'waste' => S.auditValueStockWaste,
      'return' => S.auditValueStockReturn,
      'receipt' => S.auditValueStockReceipt,
      'issue' => S.auditValueStockIssue,
      'count' => S.auditValueStockCount,
      _ => text,
    };
  }
  if (key == 'unit') {
    return switch (text) {
      'kg' => S.inventoryUnitKg,
      'g' => S.inventoryUnitGram,
      'l' => S.inventoryUnitLiter,
      'ml' => S.inventoryUnitMilliliter,
      'piece' => S.inventoryUnitPiece,
      'pack' => S.inventoryUnitPack,
      'box' => S.inventoryUnitBox,
      'bag' => S.inventoryUnitBag,
      'bottle' => S.inventoryUnitBottle,
      'can' => S.inventoryUnitCan,
      _ => text,
    };
  }
  if (key == 'type') {
    return switch (text) {
      'promo' => S.auditValueTypePromo,
      'system' => S.auditValueTypeSystem,
      'loyalty' => S.auditValueTypeLoyalty,
      'subscription' => S.auditValueTypeSubscription,
      'order_status' => S.auditValueTypeOrder,
      _ => text,
    };
  }
  if (key == 'role') {
    return switch (text) {
      'owner' => S.owner,
      'manager' => S.roleManager,
      'branch_manager' => S.roleBranchManager,
      'cashier' => S.roleCashier,
      'staff' => S.staff,
      _ => text,
    };
  }
  return text;
}

List<AuditFieldChange> auditChanges(AdminAuditLog log) {
  final before = log.oldValues ?? const <String, dynamic>{};
  final after = log.newValues ?? const <String, dynamic>{};
  final keys = <String>{...before.keys, ...after.keys};
  final changes = <AuditFieldChange>[];
  for (final key in keys) {
    if (_ignoredChangeFields.contains(key)) continue;
    final beforeValue = before[key];
    final afterValue = after[key];
    if (_sameValue(beforeValue, afterValue)) continue;
    changes.add(
      AuditFieldChange(key: key, before: beforeValue, after: afterValue),
    );
  }
  return changes;
}

String _numberLabel(num value) {
  final text = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
  return localizeDigits(text);
}

String _scalarLabel(Object? value) {
  if (value is bool) return value ? S.yes : S.no;
  if (value is num) return _numberLabel(value);
  return '$value';
}

String _compactJson(Map<dynamic, dynamic> value) {
  try {
    return const JsonEncoder.withIndent(' ').convert(value);
  } catch (_) {
    return S.auditEntityOther;
  }
}

String _clockLabel(String text) {
  final parts = text.split(':');
  if (parts.length < 2) return text;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return text;
  return localizedTime(DateTime(2000, 1, 1, hour, minute));
}

bool _sameValue(Object? first, Object? second) {
  if (identical(first, second)) return true;
  if (first == null || second == null) return first == second;
  if (first is num && second is num) return first == second;
  try {
    return jsonEncode(first) == jsonEncode(second);
  } catch (_) {
    return first == second;
  }
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
