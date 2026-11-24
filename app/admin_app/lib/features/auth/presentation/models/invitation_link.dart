/// URL contract for employee invitations.
///
/// Employee invitation tokens deliberately use `invite`, never Supabase's
/// `token`, `token_hash`, or `type` parameters used by OTP/action links.
abstract final class InvitationLink {
  static const String queryParameter = 'invite';
  static const String _defaultApplicationUrl =
      'https://ahmedshokry7.github.io/cofee-resturant-new-app/admin/';
  static const String configuredApplicationUrl = String.fromEnvironment(
    'ADMIN_APP_URL',
    defaultValue: _defaultApplicationUrl,
  );

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Extracts one UUID `invite` parameter from the URL query or a hash route.
  /// URI parsing performs percent-decoding; a malformed encoding is rejected.
  static String? tokenFromUri(Uri uri) {
    if (uri.queryParametersAll.containsKey(queryParameter)) {
      return _tokenFromParameters(uri.queryParametersAll);
    }

    final fragment = uri.fragment;
    if (fragment.isEmpty) return null;
    final normalized = fragment.startsWith('/')
        ? fragment.substring(1)
        : fragment.startsWith('?')
        ? fragment.substring(1)
        : fragment;
    try {
      final fragmentQuery = normalized.startsWith('?')
          ? normalized
          : '?$normalized';
      final fragmentUri = Uri.tryParse(fragmentQuery);
      if (fragmentUri == null ||
          !fragmentUri.queryParametersAll.containsKey(queryParameter)) {
        return null;
      }
      return _tokenFromParameters(fragmentUri.queryParametersAll);
    } on FormatException {
      return null;
    }
  }

  /// True when `invite` exists, even if empty or malformed, so the UI can
  /// explain a broken link rather than silently opening an unrelated screen.
  static bool containsInviteParameter(Uri uri) {
    if (uri.queryParametersAll.containsKey(queryParameter)) return true;
    final fragment = uri.fragment;
    if (fragment.isEmpty) return false;
    final normalized = fragment.startsWith('/')
        ? fragment.substring(1)
        : fragment.startsWith('?')
        ? fragment.substring(1)
        : fragment;
    try {
      final fragmentQuery = normalized.startsWith('?')
          ? normalized
          : '?$normalized';
      final parsed = Uri.tryParse(fragmentQuery);
      return parsed?.queryParametersAll.containsKey(queryParameter) ?? false;
    } on FormatException {
      return normalized.startsWith('$queryParameter=');
    }
  }

  /// Makes an acceptance URL while preserving unrelated query parameters.
  /// Native builds require an explicitly configured HTTPS application URL.
  static Uri? applicationBaseUri(Uri currentUri, {String? applicationUrl}) {
    final isWebOrigin =
        currentUri.hasScheme &&
        currentUri.host.isNotEmpty &&
        currentUri.scheme != 'about';
    final usableUri = isWebOrigin
        ? currentUri
        : _configuredBaseUri(applicationUrl ?? configuredApplicationUrl);
    if (usableUri == null) return null;
    return usableUri.replace(query: '', fragment: '');
  }

  /// Makes an acceptance URL while preserving unrelated query parameters.
  /// Native builds require an explicitly configured HTTPS application URL.
  static Uri? acceptanceUri(
    Uri currentUri,
    String token, {
    String? applicationUrl,
  }) {
    final usableUri = applicationBaseUri(
      currentUri,
      applicationUrl: applicationUrl,
    );
    if (usableUri == null) return null;
    final params = <String, List<String>>{
      for (final entry in usableUri.queryParametersAll.entries)
        if (entry.key != queryParameter) entry.key: entry.value,
      queryParameter: <String>[token],
    };
    return usableUri.replace(queryParameters: params, fragment: '');
  }

  static Uri? _configuredBaseUri(String value) {
    value = value.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return uri;
  }

  static String? _tokenFromParameters(Map<String, List<String>> parameters) {
    final values = parameters[queryParameter];
    if (values == null || values.length != 1) return null;
    return _validated(values.single);
  }

  static Uri withoutInviteParameter(Uri uri) {
    final params = <String, List<String>>{
      for (final entry in uri.queryParametersAll.entries)
        if (entry.key != queryParameter) entry.key: entry.value,
    };
    return uri.replace(queryParameters: params, fragment: '');
  }

  static String? _validated(String? value) {
    if (value == null) return null;
    final token = value.trim();
    return _uuid.hasMatch(token) ? token : null;
  }
}
