import 'package:flutter/material.dart';
import 'package:markdown_editor_live/markdown_editor_live.dart';

class MarkdownEditor extends StatefulWidget {
  final MarkdownEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final int? minLines;
  final int? maxLines;
  final bool autofocus;
  final bool expands;
  final bool enabled;

  const MarkdownEditor({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.minLines,
    this.maxLines = 1,
    this.autofocus = false,
    this.expands = false,
    this.enabled = true,
  });

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
    widget.controller.addListener(_handleSelectionChanged);
  }

  @override
  void didUpdateWidget(MarkdownEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleSelectionChanged);
      widget.controller.addListener(_handleSelectionChanged);
    }
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) {
      widget.controller.focusedLine = null;
    }
  }

  void _handleSelectionChanged() {
    widget.controller.updateFocusedLineFromSelection();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleSelectionChanged);
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _replaceSelection(
    String prefix,
    String suffix, {
    required String placeholder,
  }) {
    final value = widget.controller.value;
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

    widget.controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection(
        baseOffset: selectionStart,
        extentOffset: selectionStart + content.length,
      ),
    );
    widget.onChanged?.call(widget.controller.sourceText);
  }

  void _prefixLines(String prefix) {
    final value = widget.controller.value;
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

    widget.controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection(
        baseOffset: selection.start,
        extentOffset: selection.start + replacement.length,
      ),
    );
    widget.onChanged?.call(widget.controller.sourceText);
  }

  Widget _buildToolbar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Bold',
            icon: const Icon(Icons.format_bold),
            onPressed: widget.enabled
                ? () => _replaceSelection(
                      '**',
                      '**',
                      placeholder: 'bold text',
                    )
                : null,
          ),
          IconButton(
            tooltip: 'Italic',
            icon: const Icon(Icons.format_italic),
            onPressed: widget.enabled
                ? () => _replaceSelection(
                      '*',
                      '*',
                      placeholder: 'italic text',
                    )
                : null,
          ),
          IconButton(
            tooltip: 'Heading',
            icon: const Icon(Icons.title),
            onPressed: widget.enabled ? () => _prefixLines('## ') : null,
          ),
          IconButton(
            tooltip: 'Bulleted list',
            icon: const Icon(Icons.format_list_bulleted),
            onPressed: widget.enabled ? () => _prefixLines('- ') : null,
          ),
          IconButton(
            tooltip: 'Inline code',
            icon: const Icon(Icons.code),
            onPressed: widget.enabled
                ? () => _replaceSelection(
                      '`',
                      '`',
                      placeholder: 'code',
                    )
                : null,
          ),
          IconButton(
            tooltip: 'Link',
            icon: const Icon(Icons.link),
            onPressed: widget.enabled
                ? () => _replaceSelection(
                      '[',
                      '](https://)',
                      placeholder: 'link text',
                    )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      onChanged: (_) => widget.onChanged?.call(widget.controller.sourceText),
      autofocus: widget.autofocus,
      expands: widget.expands,
      minLines: widget.expands ? null : widget.minLines,
      maxLines: widget.expands ? null : widget.maxLines,
      textAlignVertical: widget.expands ? TextAlignVertical.top : null,
      decoration: InputDecoration(
        hintText: widget.hintText,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final toolbar = _buildToolbar();
    if (widget.expands) {
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
