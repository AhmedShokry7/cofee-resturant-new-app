import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores editor drafts on this admin device only. It deliberately has no
/// Supabase client and cannot publish or write to customer-facing tables.
class StudioDraftRepository {
  static String _key(String pageId) =>
      'customer_app_studio.local_draft.v1.$pageId';

  Future<Map<String, Object?>?> load(String pageId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(pageId));
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map ? Map<String, Object?>.from(value) : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(String pageId, Map<String, Object?> draft) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(pageId), jsonEncode(draft));
  }
}
