import 'dart:convert';

/// The stable contract between the customer splash screen, the admin page and
/// the published `app_design_published` document.
class SplashSettings {
  const SplashSettings({
    this.enabled = true,
    this.imageVisible = true,
    this.imageUrl = '',
    this.textAr = '',
    this.textEn = '',
    this.textColor = '#1A1A1A',
    this.textSize = 16,
    this.textAlignment = 'center',
    this.backgroundColor = '#FFFFFF',
    this.imageFit = 'contain',
    this.imageWidth,
    this.imageHeight,
    this.verticalAlignment = 'center',
    this.imageGap = 16,
    this.imageAlignment = 'center',
    this.durationMs = 1000,
    this.animation = 'fadeScale',
    this.animationDurationMs = 300,
  });

  final bool enabled;
  final bool imageVisible;
  final String imageUrl;
  final String textAr;
  final String textEn;
  final String textColor;
  final double textSize;
  final String textAlignment;
  final String backgroundColor;
  final String imageFit;
  final double? imageWidth;
  final double? imageHeight;
  final String verticalAlignment;
  final double imageGap;
  final String imageAlignment;
  final int durationMs;
  final String animation;
  final int animationDurationMs;

  SplashSettings copyWith({
    bool? enabled,
    bool? imageVisible,
    String? imageUrl,
    String? textAr,
    String? textEn,
    String? textColor,
    double? textSize,
    String? textAlignment,
    String? backgroundColor,
    String? imageFit,
    double? imageWidth,
    bool clearImageWidth = false,
    double? imageHeight,
    bool clearImageHeight = false,
    String? verticalAlignment,
    double? imageGap,
    String? imageAlignment,
    int? durationMs,
    String? animation,
    int? animationDurationMs,
  }) => SplashSettings(
    enabled: enabled ?? this.enabled,
    imageVisible: imageVisible ?? this.imageVisible,
    imageUrl: imageUrl ?? this.imageUrl,
    textAr: textAr ?? this.textAr,
    textEn: textEn ?? this.textEn,
    textColor: textColor ?? this.textColor,
    textSize: textSize ?? this.textSize,
    textAlignment: textAlignment ?? this.textAlignment,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    imageFit: imageFit ?? this.imageFit,
    imageWidth: clearImageWidth ? null : imageWidth ?? this.imageWidth,
    imageHeight: clearImageHeight ? null : imageHeight ?? this.imageHeight,
    verticalAlignment: verticalAlignment ?? this.verticalAlignment,
    imageGap: imageGap ?? this.imageGap,
    imageAlignment: imageAlignment ?? this.imageAlignment,
    durationMs: durationMs ?? this.durationMs,
    animation: animation ?? this.animation,
    animationDurationMs: animationDurationMs ?? this.animationDurationMs,
  );

  Map<String, dynamic> toProperties() => {
    'imageVisible': imageVisible,
    'imageUrl': imageUrl.trim(),
    'text_ar': textAr.trim(),
    'text_en': textEn.trim(),
    'textColor': textColor.toUpperCase(),
    'textSize': textSize,
    'textAlignment': textAlignment,
    'backgroundColor': backgroundColor.toUpperCase(),
    'imageFit': imageFit,
    if (imageWidth != null) 'imageWidth': imageWidth,
    if (imageHeight != null) 'imageHeight': imageHeight,
    'verticalAlignment': verticalAlignment,
    'imageGap': imageGap,
    'imageAlignment': imageAlignment,
    'durationMs': durationMs,
    'animation': animation,
    'animationDurationMs': animationDurationMs,
  };

  /// Local guard mirrored by the admin form; the database remains authoritative
  /// and validates the complete design document again inside its RPC.
  String? get validationIssue {
    final color = RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');
    if (!color.hasMatch(textColor) || !color.hasMatch(backgroundColor)) {
      return 'invalid_color';
    }
    if (imageUrl.trim().isNotEmpty) {
      final url = Uri.tryParse(imageUrl.trim());
      if (url?.hasScheme != true ||
          !const {'http', 'https'}.contains(url?.scheme) ||
          url?.host.isEmpty == true) {
        return 'invalid_image_url';
      }
    }
    if (textSize < 8 ||
        textSize > 48 ||
        imageGap < 0 ||
        imageGap > 100 ||
        durationMs < 0 ||
        durationMs > 30000 ||
        animationDurationMs < 0 ||
        animationDurationMs > 5000 ||
        (imageWidth != null && (imageWidth! < 40 || imageWidth! > 600)) ||
        (imageHeight != null && (imageHeight! < 40 || imageHeight! > 700))) {
      return 'invalid_numeric_value';
    }
    return null;
  }

  static SplashSettings fromDocument(Map<String, dynamic>? document) {
    final props = _splashNode(document)?['properties'];
    final p = props is Map ? props : const <String, dynamic>{};
    String string(String key, String fallback) =>
        p[key] is String ? p[key] as String : fallback;
    double number(String key, double fallback) =>
        p[key] is num ? (p[key] as num).toDouble() : fallback;
    int integer(String key, int fallback) =>
        p[key] is num ? (p[key] as num).round() : fallback;
    return SplashSettings(
      enabled: _splashNode(document)?['visible'] is bool
          ? _splashNode(document)!['visible'] as bool
          : true,
      imageVisible: p['imageVisible'] is bool
          ? p['imageVisible'] as bool
          : true,
      imageUrl: string('imageUrl', ''),
      textAr: string('text_ar', ''),
      textEn: string('text_en', ''),
      textColor: string('textColor', '#1A1A1A'),
      textSize: number('textSize', 16),
      textAlignment: string('textAlignment', 'center'),
      backgroundColor: string('backgroundColor', '#FFFFFF'),
      imageFit: string('imageFit', 'contain'),
      imageWidth: p['imageWidth'] is num
          ? (p['imageWidth'] as num).toDouble()
          : null,
      imageHeight: p['imageHeight'] is num
          ? (p['imageHeight'] as num).toDouble()
          : null,
      verticalAlignment: string('verticalAlignment', 'center'),
      imageGap: number('imageGap', 16),
      imageAlignment: string('imageAlignment', 'center'),
      durationMs: integer('durationMs', 1000),
      animation: string('animation', 'fadeScale'),
      animationDurationMs: integer('animationDurationMs', 300),
    );
  }

  /// Replaces only the splash node and leaves every other page and theme
  /// untouched. This matters while the app is managed one screen at a time.
  static Map<String, dynamic> writeToDocument(
    Map<String, dynamic>? source,
    SplashSettings settings,
  ) {
    final doc = source == null
        ? <String, dynamic>{'schema_version': 2, 'pages': <dynamic>[]}
        : (jsonDecode(jsonEncode(source)) as Map).cast<String, dynamic>();
    doc['schema_version'] = 2;
    final pages = doc['pages'] is List
        ? List<dynamic>.from(doc['pages'] as List)
        : <dynamic>[];
    var pageIndex = pages.indexWhere(
      (page) => page is Map && page['page'] == 'splash',
    );
    Map<String, dynamic> page;
    if (pageIndex >= 0) {
      page = (pages[pageIndex] as Map).cast<String, dynamic>();
    } else {
      page = <String, dynamic>{
        'page': 'splash',
        'root': <String, dynamic>{
          'id': 'root_splash',
          'type': 'page.home',
          'children': <dynamic>[],
        },
      };
      pageIndex = pages.length;
      pages.add(page);
    }

    final root = page['root'] is Map
        ? (page['root'] as Map).cast<String, dynamic>()
        : <String, dynamic>{
            'id': 'root_splash',
            'type': 'page.home',
            'children': <dynamic>[],
          };
    final children = root['children'] is List
        ? List<dynamic>.from(root['children'] as List)
        : <dynamic>[];
    final nodeIndex = children.indexWhere(
      (node) => node is Map && node['type'] == 'splash.settings',
    );
    final oldNode = nodeIndex >= 0 && children[nodeIndex] is Map
        ? (children[nodeIndex] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final oldProps = oldNode['properties'] is Map
        ? (oldNode['properties'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final node = <String, dynamic>{
      ...oldNode,
      'id': oldNode['id'] is String ? oldNode['id'] : 'splash_settings',
      'type': 'splash.settings',
      'visible': settings.enabled,
      'properties': {...oldProps, ...settings.toProperties()},
    };
    if (nodeIndex >= 0) {
      children[nodeIndex] = node;
    } else {
      children.add(node);
    }
    root['type'] = 'page.home';
    root['children'] = children;
    page['root'] = root;
    pages[pageIndex] = page;
    doc['pages'] = pages;
    return doc;
  }

  static Map? _splashNode(Map<String, dynamic>? document) {
    final pages = document?['pages'];
    if (pages is! List) return null;
    for (final page in pages) {
      if (page is! Map || page['page'] != 'splash') continue;
      final children = (page['root'] as Map?)?['children'];
      if (children is! List) return null;
      for (final node in children) {
        if (node is Map && node['type'] == 'splash.settings') return node;
      }
    }
    return null;
  }
}
