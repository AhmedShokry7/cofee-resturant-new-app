import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/data/db_values.dart';

/// The shop's own documents, fetched from the server for one question.
///
/// The assistant used to put its whole menu into the prompt — two hundred
/// products, every category, every price — and hope the model found the three
/// lines that mattered. That is slow, it costs tokens on every turn, and it is
/// how a model ends up answering from a product it saw in the dump rather than
/// the one the customer asked about.
///
/// This is the replacement: ask the database for the pieces that match the
/// question, send those, and keep their identity so the answer can cite them.
/// A chunk without an id cannot be cited, so every row carries `sourceId`.
class RetrievedSource {
  const RetrievedSource({
    required this.sourceType,
    required this.sourceId,
    required this.title,
    required this.body,
    required this.score,
    this.uri = '',
  });

  /// 'article' | 'product' | 'web'
  final String sourceType;

  /// The slug of an article, the id of a product, the address of a web page —
  /// what the citation names.
  final String sourceId;
  final String title;
  final String body;

  /// 0..1 from the server; used to drop weak matches before they reach the model.
  final double score;

  /// Where the customer can read it themselves. Empty for a shop row the app
  /// already renders (a product, an article page), so no dead link is offered.
  final String uri;

  static RetrievedSource? fromRow(Map<String, dynamic> row) {
    final id = Db.textOrNull(row['source_id']);
    if (id == null || id.isEmpty) return null;
    return RetrievedSource(
      sourceType: Db.text(row['source_type'], 'article'),
      sourceId: id,
      title: Db.text(row['title'], ''),
      body: Db.text(row['body'], ''),
      score: Db.asDouble(row['score'], fallback: 0),
      uri: Db.text(row['uri'], ''),
    );
  }

  /// The link's own identity: the same page reached with a different `utm_`
  /// is one source, not two.
  String get identityKey {
    final parsed = Uri.tryParse(uri);
    if (parsed == null || parsed.host.isEmpty) return '$sourceType:$sourceId';
    return '${parsed.host}${parsed.path}';
  }

  /// The address to open, or null when there is nothing safe to open.
  ///
  /// Only http and https: a provider that handed back a `javascript:` or a
  /// `file:` address would be handing the customer's browser a way out of the
  /// web, and a citation is not worth that.
  Uri? get linkUri {
    final parsed = Uri.tryParse(uri);
    if (parsed == null) return null;
    return (parsed.scheme == 'http' || parsed.scheme == 'https') &&
            parsed.host.isNotEmpty
        ? parsed
        : null;
  }

  bool get isLink => linkUri != null;

  RetrievedSource copyWith({String? sourceId, String? uri}) => RetrievedSource(
    sourceType: sourceType,
    sourceId: sourceId ?? this.sourceId,
    title: title,
    body: body,
    score: score,
    uri: uri ?? this.uri,
  );

  /// The citation as it is written into the customer's own chat history.
  ///
  /// The body stays out: it was the passage fed to the language model for that
  /// one turn, and re-reading an old answer needs the name and the address, not
  /// two paragraphs of shop text parked in the app's preferences.
  Map<String, dynamic> toJson() => {
    'sourceType': sourceType,
    'sourceId': sourceId,
    'title': title,
    'uri': uri,
  };

  static RetrievedSource? fromJson(dynamic value) {
    if (value is! Map) return null;
    final id = Db.textOrNull(value['sourceId']);
    if (id == null || id.isEmpty) return null;
    return RetrievedSource(
      sourceType: Db.text(value['sourceType'], 'article'),
      sourceId: id,
      title: Db.text(value['title'], ''),
      body: '',
      score: 0,
      uri: Db.text(value['uri'], ''),
    );
  }
}

/// The sources of one answer, in the order they were read, with the same page
/// named once.
///
/// The shop rows come first: they are the store's own words, and a customer who
/// was answered from them should not see a blog post above them.
List<RetrievedSource> dedupeSources(List<RetrievedSource> sources) {
  final seen = <String>{};
  final out = <RetrievedSource>[];
  for (final source in sources) {
    if (!seen.add(source.identityKey)) continue;
    out.add(source);
  }
  return List<RetrievedSource>.unmodifiable(out);
}

abstract interface class AssistantRetrieval {
  Future<List<RetrievedSource>> search(
    String query, {
    String? branchId,
    required String locale,
    int limit,
  });
}

/// The retrieval used when there is no backend, or before the customer signs
/// in. Returning nothing is correct: the assistant then answers from the local
/// engine, which never needed a search.
class NoRetrieval implements AssistantRetrieval {
  const NoRetrieval();

  @override
  Future<List<RetrievedSource>> search(
    String query, {
    String? branchId,
    required String locale,
    int limit = 6,
  }) async => const [];
}

/// `public.assistant_search_knowledge` — one query, both kinds of source.
///
/// The product half of the ranking is not implemented here: it delegates to
/// `catalog.search_products`, the same function the search screen uses, so the
/// assistant and the menu cannot disagree about what a query matches or what a
/// product costs today.
class ServerRetrieval implements AssistantRetrieval {
  ServerRetrieval(this._client);

  final SupabaseClient _client;

  @override
  Future<List<RetrievedSource>> search(
    String query, {
    String? branchId,
    required String locale,
    int limit = 6,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    // The function is readable by a signed-in customer only; a guest would get
    // a Postgres permission error on every turn.
    if (_client.auth.currentUser == null) return const [];
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'assistant_search_knowledge',
        params: {
          'p_query': trimmed,
          'p_branch_id': branchId,
          'p_locale': locale,
          'p_limit': limit,
        },
      );
      return [
        for (final row in rows)
          ?RetrievedSource.fromRow((row as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      // The function is not deployed yet, the network is down, the query is
      // too strange for it. All of them mean the same thing to the chat: the
      // local answer stands on its own.
      return const [];
    }
  }
}

/// The prompt block built from the retrieved chunks.
///
/// The bodies are truncated: two paragraphs of a help article say the same
/// thing as one, and every character here is paid for on every turn.
String buildRetrievedContext(
  List<RetrievedSource> sources, {
  int maxChars = 320,
}) {
  if (sources.isEmpty) return '';
  final buffer = StringBuffer(
    'Relevant shop documents, read just now for this question:\n',
  );
  for (final source in sources) {
    var body = source.body.replaceAll('\n', ' ').trim();
    if (body.length > maxChars) body = '${body.substring(0, maxChars)}…';
    buffer.writeln('[${source.sourceId}] ${source.title}: $body');
  }
  // The point of retrieval is the boundary it draws: these rows are the shop's
  // facts, and anything outside them is the model inventing a price.
  buffer.write(
    'Use only these for anything the shop states. If none of them answers the '
    'question, say you do not know instead of guessing.',
  );
  return buffer.toString();
}
