import 'package:new_coffee/core/locale/app_strings.dart';

String getGreeting(DateTime time) {
  final hour = time.hour;
  if (hour < 12) return S.goodMorning;
  if (hour < 17) return S.goodAfternoon;
  return S.goodEvening;
}

bool isDaytime(DateTime time) => time.hour >= 6 && time.hour < 17;

String? firstNameOf(String? fullName) {
  final parts = (fullName ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  return parts.isEmpty ? null : parts.first;
}
