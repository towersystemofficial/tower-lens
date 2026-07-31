import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class MarkdownContent extends StatelessWidget {
  final String data;
  final String emptyPlaceholder;

  const MarkdownContent({
    super.key,
    required this.data,
    this.emptyPlaceholder = '(none)',
  });

  @override
  Widget build(BuildContext context) {
    if (data.trim().isEmpty) {
      return Text(
        emptyPlaceholder,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return MarkdownBody(
      data: data,
      selectable: true,
    );
  }
}
