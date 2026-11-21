import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/features/splash_management/domain/splash_settings.dart';

class SplashManagementSnapshot {
  const SplashManagementSnapshot({
    required this.settings,
    required this.document,
    required this.hasDraft,
    this.publishedVersion,
    this.publishedAt,
  });

  final SplashSettings settings;
  final Map<String, dynamic> document;
  final bool hasDraft;
  final int? publishedVersion;
  final DateTime? publishedAt;
}

/// Screen-scoped adapter over the existing, permission-checked app-design RPCs.
/// The document is updated in place so other managed screens survive a splash
/// publish unchanged.
class SplashManagementRepository {
  SplashManagementRepository({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  Future<Map<String, dynamic>?> _getDocument(String slot) async {
    final raw = await _client.rpc(
      'admin_get_app_design',
      params: {'p_slot': slot},
    );
    if (raw == null) return null;
    final decoded = jsonDecode(jsonEncode(raw));
    if (decoded is! Map) {
      throw const FormatException('The saved app design is not an object.');
    }
    return decoded.cast<String, dynamic>();
  }

  Future<SplashManagementSnapshot> load() async {
    final draft = await _getDocument('draft');
    final published = await _getDocument('published');
    final source = draft ?? published;
    final doc = SplashSettings.writeToDocument(
      source,
      source == null
          ? const SplashSettings()
          : SplashSettings.fromDocument(source),
    );
    int? version;
    DateTime? publishedAt;
    final versions = await _client.rpc(
      'admin_list_app_design_versions',
      params: {'p_limit': 1},
    );
    if (versions is List && versions.isNotEmpty && versions.first is Map) {
      final latest = versions.first as Map;
      version = latest['version_number'] is num
          ? (latest['version_number'] as num).round()
          : null;
      publishedAt = DateTime.tryParse(latest['published_at']?.toString() ?? '');
    }
    return SplashManagementSnapshot(
      settings: SplashSettings.fromDocument(doc),
      document: doc,
      hasDraft: draft != null,
      publishedVersion: version,
      publishedAt: publishedAt,
    );
  }

  Future<void> saveDraft(Map<String, dynamic> document) async {
    await _client.rpc(
      'admin_save_app_design_draft',
      params: {'p_document': document},
    );
  }

  Future<Map<String, dynamic>> publish(Map<String, dynamic> document) async {
    final raw = await _client.rpc(
      'admin_publish_app_design',
      params: {'p_document': document, 'p_note': 'Splash screen settings'},
    );
    if (raw is! Map) {
      throw const FormatException(
        'Supabase did not return the published version.',
      );
    }
    return raw.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>?> loadPublishedDocument() =>
      _getDocument('published');
}
