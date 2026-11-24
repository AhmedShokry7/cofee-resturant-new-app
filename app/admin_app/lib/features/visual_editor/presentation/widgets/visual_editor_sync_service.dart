import 'dart:convert';

import 'package:github/github.dart';
import 'package:admin_app/features/visual_editor/presentation/models/visual_editor_model.dart';

/// Service that pushes the editor JSON to a GitHub repo.
class VisualEditorSyncService {
  final String owner;
  final String repo;
  final String branch;
  final String filePath; // e.g. 'editor_state.json'
  final String authToken; // Personal Access Token with repo scope

  VisualEditorSyncService({
    required this.owner,
    required this.repo,
    this.branch = 'main',
    required this.filePath,
    required this.authToken,
  });

  /// Publish the current model JSON to the repo.
  Future<void> publish(VisualEditorModel model) async {
    final github = GitHub(auth: Authentication.withToken(authToken));
    final repoSlug = RepositorySlug(owner, repo);

    // Get the current SHA of the file if it exists.
    String? sha;
    try {
      final existing = await github.repositories.getContents(
        repoSlug,
        filePath,
        ref: branch,
      );
      sha = existing.file?.sha;
    } on NotFound {
      // File does not exist yet – that's fine.
    }

    final encoded = base64Encode(utf8.encode(model.exportJson()));
    if (sha == null) {
      await github.repositories.createFile(
        repoSlug,
        CreateFile(
          path: filePath,
          message: 'Update visual editor state',
          content: encoded,
          branch: branch,
        ),
      );
    } else {
      await github.repositories.updateFile(
        repoSlug,
        filePath,
        'Update visual editor state',
        encoded,
        sha,
        branch: branch,
      );
    }
  }

  /// Publish a raw JSON string (useful when we already have a map).
  Future<void> publishJson(String jsonString) async {
    final github = GitHub(auth: Authentication.withToken(authToken));
    final repoSlug = RepositorySlug(owner, repo);
    String? sha;
    try {
      final existing = await github.repositories.getContents(
        repoSlug,
        filePath,
        ref: branch,
      );
      sha = existing.file?.sha;
    } on NotFound {
      // File does not exist yet – that's fine.
    }
    final encoded = base64Encode(utf8.encode(jsonString));
    if (sha == null) {
      await github.repositories.createFile(
        repoSlug,
        CreateFile(
          path: filePath,
          message: 'Export visual editor state',
          content: encoded,
          branch: branch,
        ),
      );
    } else {
      await github.repositories.updateFile(
        repoSlug,
        filePath,
        'Export visual editor state',
        encoded,
        sha,
        branch: branch,
      );
    }
  }
}
