import 'package:flutter/material.dart';

import 'markdown_content.dart';

class MarkdownEditor extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final int? minLines;
  final int? maxLines;
  final bool autofocus;
  final bool expands;

  const MarkdownEditor({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.minLines,
    this.maxLines = 1,
    this.autofocus = false,
    this.expands = false,
  });

  void _replaceSelection(
    String prefix,
    String suffix, {
    required String placeholder,
  }) {
    final value = controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final selectedText = selection.textInside(value.text);
    final content = selectedText.isEmpty ? placeholder : selectedText;
    final replacement = '$prefix$content$suffix';
    final updatedText = selection.textBefore(value.text) +
        replacement +
        selection.textAfter(value.text);
    final selectionStart = selection.start + prefix.length;

    controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection(
        baseOffset: selectionStart,
        extentOffset: selectionStart + content.length,
      ),
    );
    onChanged?.call(updatedText);
  }

  void _prefixLines(String prefix) {
    final value = controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final selectedText = selection.textInside(value.text);
    final content = selectedText.isEmpty ? 'text' : selectedText;
    final replacement = content
        .split('\n')
        .map((line) => '$prefix$line')
        .join('\n');
    final updatedText = selection.textBefore(value.text) +
        replacement +
        selection.textAfter(value.text);

    controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection(
        baseOffset: selection.start,
        extentOffset: selection.start + replacement.length,
      ),
    );
    onChanged?.call(updatedText);
  }

  Future<void> _showPreview(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Markdown preview'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: MarkdownContent(
              data: controller.text,
              emptyPlaceholder: 'Nothing to preview yet.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Bold',
            icon: const Icon(Icons.format_bold),
            onPressed: () => _replaceSelection(
              '**',
              '**',
              placeholder: 'bold text',
            ),
          ),
          IconButton(
            tooltip: 'Italic',
            icon: const Icon(Icons.format_italic),
            onPressed: () => _replaceSelection(
              '*',
              '*',
              placeholder: 'italic text',
            ),
          ),
          IconButton(
            tooltip: 'Heading',
            icon: const Icon(Icons.title),
            onPressed: () => _prefixLines('## '),
          ),
          IconButton(
            tooltip: 'Bulleted list',
            icon: const Icon(Icons.format_list_bulleted),
            onPressed: () => _prefixLines('- '),
          ),
          IconButton(
            tooltip: 'Inline code',
            icon: const Icon(Icons.code),
            onPressed: () => _replaceSelection(
              '`',
              '`',
              placeholder: 'code',
            ),
          ),
          IconButton(
            tooltip: 'Link',
            icon: const Icon(Icons.link),
            onPressed: () => _replaceSelection(
              '[',
              '](https://)',
              placeholder: 'link text',
            ),
          ),
          TextButton.icon(
            onPressed: () => _showPreview(context),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Preview'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      expands: expands,
      minLines: expands ? null : minLines,
      maxLines: expands ? null : maxLines,
      textAlignVertical: expands ? TextAlignVertical.top : null,
      decoration: InputDecoration(
        hintText: hintText,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final toolbar = _buildToolbar(context);
    if (expands) {
      return Column(
        children: [
          toolbar,
          const SizedBox(height: 4),
          Expanded(child: _buildTextField()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        toolbar,
        const SizedBox(height: 4),
        _buildTextField(),
      ],
    );
  }
}
