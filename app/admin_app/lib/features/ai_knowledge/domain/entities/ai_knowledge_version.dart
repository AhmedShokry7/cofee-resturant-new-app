enum AiKnowledgeVersionStatus {
  draft('draft'),
  pendingReview('pending_review'),
  approved('approved'),
  published('published'),
  archived('archived');

  const AiKnowledgeVersionStatus(this.value);

  final String value;

  static AiKnowledgeVersionStatus fromValue(Object? value) =>
      AiKnowledgeVersionStatus.values.firstWhere(
        (status) => status.value == '$value',
        orElse: () => throw FormatException('Unknown knowledge status: $value'),
      );
}

enum AiKnowledgeTrainingKind {
  article('article'),
  intent('intent'),
  example('example'),
  synonym('synonym');

  const AiKnowledgeTrainingKind(this.value);

  final String value;
}

/// One immutable revision in the admin-only training lifecycle.
class AiKnowledgeVersion {
  const AiKnowledgeVersion({
    required this.id,
    required this.knowledgeKey,
    required this.kind,
    required this.version,
    required this.payload,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.previousVersionId,
    this.submittedBy,
    this.submittedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.publishedBy,
    this.publishedAt,
    this.archivedBy,
    this.archivedAt,
    this.archiveReason,
  });

  final String id;
  final String knowledgeKey;
  final AiKnowledgeTrainingKind kind;
  final int version;
  final Map<String, dynamic> payload;
  final AiKnowledgeVersionStatus status;
  final String createdBy;
  final String? previousVersionId;
  final String? submittedBy;
  final DateTime? submittedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? publishedBy;
  final DateTime? publishedAt;
  final String? archivedBy;
  final DateTime? archivedAt;
  final String? archiveReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AiKnowledgeVersion.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    if (payload is! Map) {
      throw const FormatException('Missing knowledge payload');
    }
    final kindValue = '${json['kind'] ?? ''}';
    final kind = AiKnowledgeTrainingKind.values.where(
      (item) => item.value == kindValue,
    );
    if (kind.isEmpty) {
      throw FormatException('Unknown knowledge kind: $kindValue');
    }
    return AiKnowledgeVersion(
      id: _requiredText(json, 'id'),
      knowledgeKey: _requiredText(json, 'knowledge_key'),
      kind: kind.first,
      version: _integer(json['version']),
      payload: Map<String, dynamic>.unmodifiable(
        Map<String, dynamic>.from(payload),
      ),
      status: AiKnowledgeVersionStatus.fromValue(json['status']),
      previousVersionId: _textOrNull(json['previous_version_id']),
      createdBy: _requiredText(json, 'created_by'),
      submittedBy: _textOrNull(json['submitted_by']),
      submittedAt: _date(json['submitted_at']),
      reviewedBy: _textOrNull(json['reviewed_by']),
      reviewedAt: _date(json['reviewed_at']),
      publishedBy: _textOrNull(json['published_by']),
      publishedAt: _date(json['published_at']),
      archivedBy: _textOrNull(json['archived_by']),
      archivedAt: _date(json['archived_at']),
      archiveReason: _textOrNull(json['archive_reason']),
      createdAt:
          _date(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _date(json['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static String _requiredText(Map<String, dynamic> json, String key) {
    final value = '${json[key] ?? ''}'.trim();
    if (value.isEmpty) throw FormatException('Missing knowledge field: $key');
    return value;
  }

  static String? _textOrNull(Object? value) {
    final text = '$value'.trim();
    return value == null || text.isEmpty ? null : text;
  }

  static DateTime? _date(Object? value) =>
      value is DateTime ? value : DateTime.tryParse('$value');

  static int _integer(Object? value) => value is int
      ? value
      : value is num
      ? value.toInt()
      : int.tryParse('$value') ?? 0;
}

class AiKnowledgeVersionEvent {
  const AiKnowledgeVersionEvent({
    required this.id,
    required this.versionId,
    required this.knowledgeKey,
    required this.version,
    required this.action,
    required this.toStatus,
    required this.actorUserId,
    required this.happenedAt,
    this.fromStatus,
    this.reason,
  });

  final String id;
  final String versionId;
  final String knowledgeKey;
  final int version;
  final String action;
  final String? fromStatus;
  final String toStatus;
  final String actorUserId;
  final String? reason;
  final DateTime happenedAt;

  factory AiKnowledgeVersionEvent.fromJson(Map<String, dynamic> json) =>
      AiKnowledgeVersionEvent(
        id: '${json['id'] ?? ''}',
        versionId: '${json['version_id'] ?? ''}',
        knowledgeKey: '${json['knowledge_key'] ?? ''}',
        version: json['version'] is num
            ? (json['version'] as num).toInt()
            : int.tryParse('${json['version']}') ?? 0,
        action: '${json['action'] ?? ''}',
        fromStatus: json['from_status'] as String?,
        toStatus: '${json['to_status'] ?? ''}',
        actorUserId: '${json['actor_user_id'] ?? ''}',
        reason: json['reason'] as String?,
        happenedAt: json['happened_at'] is DateTime
            ? json['happened_at'] as DateTime
            : DateTime.tryParse('${json['happened_at']}') ??
                  DateTime.fromMillisecondsSinceEpoch(0),
      );
}
