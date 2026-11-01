/// Cleans a language-model reply before it reaches the chat bubble.
///
/// The chat bubble is a plain text widget, so everything the model adds for a
/// document has to go: Markdown markers, tables, bullet lists, headings and
/// emoji. A reply that reads like a web page is not a chat message, and the
/// customer sees the raw text of a table as a wall of pipes.
library;

/// Removes the Markdown a model adds and keeps the words.
String sanitizeLlmReply(String raw) {
  if (raw.trim().isEmpty) return '';

  var text = raw.replaceAll('\r\n', '\n').trim();

  text = _flattenTables(text);

  // Headings: "## Price" -> "Price".
  text = text.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '');
  // Bold and italic markers: "**price**" -> "price".
  // `replaceAll` does not expand a capture group, so the mapped form is used.
  text = text.replaceAllMapped(
    RegExp(r'\*\*([^*]+)\*\*'),
    (match) => match.group(1) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'(?<!\*)\*([^*\n]+)\*(?!\*)'),
    (match) => match.group(1) ?? '',
  );
  text = text.replaceAll('__', '').replaceAll('~~', '');
  // Inline code ticks.
  text = text.replaceAll('`', '');
  // Bullets: "- item" / "* item" -> "• item".
  text = text.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '• ');
  // Numbered lists keep their number but lose the dot.
  text = text.replaceAllMapped(
    RegExp(r'^\s*(\d+)\.\s+', multiLine: true),
    (match) => '${match.group(1)}) ',
  );
  // A horizontal rule is noise in a chat bubble.
  text = text.replaceAll(RegExp(r'^\s*([-*_])\1{2,}\s*$', multiLine: true), '');

  text = _stripEmoji(text);
  // Removing an emoji leaves the space it was standing on.
  text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');

  // Three or more blank lines become one.
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}

/// Turns a Markdown table into plain lines.
///
/// The model reaches for a table whenever it compares two things, and a table
/// in a chat bubble is a wall of pipes. The rows become sentences: the first
/// column names the row, and every other column gives the value under its own
/// header.
String _flattenTables(String text) {
  final lines = text.split('\n');
  final out = <String>[];
  var index = 0;
  while (index < lines.length) {
    if (_isTableRow(lines[index]) &&
        index + 1 < lines.length &&
        _isTableSeparator(lines[index + 1])) {
      final header = _tableCells(lines[index]);
      index += 2;
      while (index < lines.length && _isTableRow(lines[index])) {
        final cells = _tableCells(lines[index]);
        index++;
        if (cells.length <= 1) {
          out.add(cells.join(' '));
          continue;
        }
        final label = cells.first.trim();
        final parts = <String>[];
        for (var cell = 1; cell < cells.length; cell++) {
          final value = cells[cell].trim();
          if (value.isEmpty) continue;
          final name = cell < header.length ? header[cell].trim() : '';
          parts.add(name.isEmpty ? value : '$name: $value');
        }
        if (parts.isEmpty) continue;
        out.add(
          label.isEmpty ? parts.join('، ') : '$label: ${parts.join('، ')}',
        );
      }
      continue;
    }
    out.add(lines[index]);
    index++;
  }
  return out.join('\n');
}

bool _isTableRow(String line) {
  final trimmed = line.trim();
  return trimmed.startsWith('|') && trimmed.endsWith('|') && trimmed.length > 2;
}

bool _isTableSeparator(String line) {
  final trimmed = line.trim();
  if (!_isTableRow(trimmed)) return false;
  return RegExp(r'^\|[\s:|-]+\|$').hasMatch(trimmed);
}

List<String> _tableCells(String line) {
  var trimmed = line.trim();
  if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
  if (trimmed.endsWith('|')) trimmed = trimmed.substring(0, trimmed.length - 1);
  return trimmed.split('|').map((cell) => cell.trim()).toList();
}

/// Removes the emoji a model likes to put in a reply.
String _stripEmoji(String text) {
  return text.replaceAll(
    RegExp(
      '[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{1F1E6}-\u{1F1FF}]',
      unicode: true,
    ),
    '',
  );
}
