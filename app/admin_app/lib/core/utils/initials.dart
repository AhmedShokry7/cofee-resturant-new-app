/// The first letters of the first and last words of [source].
String initialsOf(String source) {
  final words = source
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return '';
  String first(String word) => String.fromCharCode(word.runes.first);
  final initials = words.length == 1
      ? first(words.first)
      : '${first(words.first)}${first(words.last)}';
  return initials.toUpperCase();
}
