import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class ImportedDocument {
  final String filename;
  final String text;

  const ImportedDocument({
    required this.filename,
    required this.text,
  });
}

class DocumentImportException implements Exception {
  final String message;

  const DocumentImportException(this.message);

  @override
  String toString() => message;
}

class DocumentImportService {
  static const _pdfChannel = MethodChannel(
    'com.example.tower_lens/document_import',
  );

  Future<ImportedDocument?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose a PDF, text, or Markdown file',
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'txt', 'md'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw const DocumentImportException(
        'Tower Lens could not read that file. Please choose it again.',
      );
    }

    final extension = p.extension(file.name).toLowerCase();
    final text = switch (extension) {
      '.txt' || '.md' => _decodeText(bytes),
      '.pdf' => await _extractPdfText(bytes),
      _ => throw const DocumentImportException(
          'Choose a PDF, TXT, or Markdown file.',
        ),
    };
    final normalizedText = text.replaceAll('\r\n', '\n').trim();
    if (normalizedText.isEmpty) {
      throw const DocumentImportException(
        'That file does not contain readable text.',
      );
    }

    return ImportedDocument(filename: file.name, text: normalizedText);
  }

  String _decodeText(Uint8List bytes) {
    try {
      var text = utf8.decode(bytes);
      if (text.startsWith('\ufeff')) text = text.substring(1);
      return text;
    } on FormatException {
      throw const DocumentImportException(
        'That text file is not valid UTF-8 and could not be imported.',
      );
    }
  }

  Future<String> _extractPdfText(Uint8List bytes) async {
    try {
      return await _pdfChannel.invokeMethod<String>(
            'extractPdfText',
            {'bytes': bytes},
          ) ??
          '';
    } on PlatformException catch (error) {
      throw DocumentImportException(
        error.message ??
            'Tower Lens could not extract readable text from that PDF.',
      );
    } on MissingPluginException {
      throw const DocumentImportException(
        'PDF import is not available on this device.',
      );
    }
  }
}
