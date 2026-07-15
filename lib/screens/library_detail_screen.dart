import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../models/library_entry.dart';

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
            Text(dateFormat.format(entry.timestamp), style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            const Text('Source Text', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            SelectableText(entry.sourceText.isEmpty ? '(none)' : entry.sourceText),
            const SizedBox(height: 16),
            const Text('Instruction', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            SelectableText(entry.instruction.isEmpty ? '(none)' : entry.instruction),
            const SizedBox(height: 16),
            const Text('Output', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            SelectableText(entry.output.isEmpty ? '(none)' : entry.output),
          ],
        ),
      ),
    );
  }
}