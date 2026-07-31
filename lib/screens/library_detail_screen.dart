import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../models/library_entry.dart';
import '../widgets/markdown_content.dart';

class LibraryDetailScreen extends StatelessWidget {
  final LibraryEntry entry;
  const LibraryDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y • h:mm a');
    return Scaffold(
      appBar: AppBar(title: Text(entry.folder)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateFormat.format(entry.timestamp),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Source Text', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            MarkdownContent(data: entry.sourceText),
            const SizedBox(height: 16),
            const Text('Instruction', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            MarkdownContent(data: entry.instruction),
            const SizedBox(height: 16),
            const Text('Output', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            MarkdownContent(data: entry.output),
          ],
        ),
      ),
    );
  }
}
