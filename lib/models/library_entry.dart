class LibraryEntry {
  final String id;
  final String type; // 'general' | 'tos' | 'ingredient'
  final String folder;
  final String sourceText;
  final String instruction;
  final String output;
  final DateTime timestamp;
  final String? filePath;

  LibraryEntry({
    required this.id,
    required this.type,
    required this.folder,
    required this.sourceText,
    required this.instruction,
    required this.output,
    required this.timestamp,
    this.filePath,
  });

  String get preview {
    final t = sourceText.trim().replaceAll('\n', ' ');
    if (t.isEmpty) return '(no source text)';
    return t.length > 90 ? '${t.substring(0, 90)}…' : t;
  }
}