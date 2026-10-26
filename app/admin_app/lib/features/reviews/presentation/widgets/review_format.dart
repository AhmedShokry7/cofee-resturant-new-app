import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/reviews/data/models/admin_review.dart';

String reviewCountValue(int value) => localizeDigits(formatCount(value));

String reviewAverageValue(double value) =>
    localizeDigits(value.toStringAsFixed(1));

String reviewPercentValue(double value) =>
    localizeDigits('${(value * 100).round()}%');

String reviewStatusName(AdminReview review) =>
    review.isPublished ? S.reviewsPublished : S.reviewsHidden;

Color reviewStatusColor(AdminReview review) =>
    review.isPublished ? AppColor.adminAccent : AppColor.adminMuted;

String reviewDateLabel(DateTime? value) => localizedDate(value);

String reviewTimeLabel(DateTime? value) =>
    value == null ? '—' : localizedTime(value.toLocal());

String reviewProductName(AdminReview review, [AppLanguage? language]) =>
    review.product.nameFor(language ?? AppLocale.instance.language);

String? reviewProductCategory(AdminReview review, [AppLanguage? language]) =>
    review.product.categoryFor(language ?? AppLocale.instance.language);

String reviewCustomerName(AdminReview review) {
  final name = review.customer.fullName;
  if (name != null && name.isNotEmpty) return name;
  final email = review.customer.email;
  if (email != null && email.isNotEmpty) return email;
  return S.reviewsAnonymous;
}

String? reviewCustomerDetail(AdminReview review) {
  final name = review.customer.fullName;
  final email = review.customer.email;
  if (name == null || name.isEmpty) return null;
  if (email == null || email.isEmpty) return null;
  return email;
}

String? reviewCustomerInitial(AdminReview review) {
  final name = reviewCustomerName(review).trim();
  if (name.isEmpty) return null;
  return name.substring(0, 1).toUpperCase();
}

/// The bold first line of a review, falling back to its body when the
/// customer did not write a title.
String reviewHeadline(AdminReview review) {
  final language = AppLocale.instance.language;
  final title = review.titleFor(language);
  if (title != null) return title;
  return review.bodyFor(language) ?? S.reviewsUntitled;
}

/// The quiet second line. It is null when the body is already the headline.
String? reviewExcerpt(AdminReview review) {
  final language = AppLocale.instance.language;
  final title = review.titleFor(language);
  final body = review.bodyFor(language);
  if (title == null || body == null || body == title) return null;
  return body;
}

String reviewOrderReference(AdminReview review) {
  final number = review.orderNumber;
  return number == null ? S.reviewsNoOrder : S.reviewsOrderNumber(number);
}

String reviewRowsLabel(int from, int to, int count) =>
    S.reviewsRowsLabel(from, to, count);
