import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'text_ai_service.dart';

class AnthropicTextAiService implements TextAiService {
  AnthropicTextAiService({
    required this.endpoint,
    required this.model,
    required this.apiKey,
    this.bearerToken = '',
    this.timeout = const Duration(seconds: 45),
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri endpoint;
  final String model;
  final String apiKey;
  final String bearerToken;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<String> runTask({
    required TextAiTaskType taskType,
    required String sourceText,
    required String instruction,
  }) async {
    final headers = <String, String>{
      'content-type': 'application/json',
      'anthropic-version': '2023-06-01',
    };
    if (apiKey.isNotEmpty) headers['x-api-key'] = apiKey;
    if (bearerToken.isNotEmpty) {
      headers['authorization'] = 'Bearer $bearerToken';
    }

    late final http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: headers,
            body: jsonEncode({
              'model': model,
              'max_tokens': 1200,
              'system': _systemPrompt(taskType),
              'messages': [
                {
                  'role': 'user',
                  'content':
                      'Instruction: $instruction\n\nSource text:\n<source>\n$sourceText\n</source>',
                },
              ],
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const TextAiServiceException(
        'The AI request timed out. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const TextAiServiceException(
        'Tower Lens could not reach the AI service. Check your connection and try again.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TextAiServiceException(_errorMessage(response));
    }

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content = body['content'] as List<dynamic>?;
      final text = content
          ?.whereType<Map<String, dynamic>>()
          .where((block) => block['type'] == 'text')
          .map((block) => block['text'])
          .whereType<String>()
          .join('\n')
          .trim();
      if (text == null || text.isEmpty) {
        throw const FormatException('Missing text content');
      }
      return text;
    } on FormatException {
      throw const TextAiServiceException(
        'The AI service returned an unreadable response. Please try again.',
      );
    } on TypeError {
      throw const TextAiServiceException(
        'The AI service returned an unreadable response. Please try again.',
      );
    }
  }

  String _systemPrompt(TextAiTaskType taskType) {
    switch (taskType) {
      case TextAiTaskType.general:
        return 'You are Tower Lens, a careful reading assistant. Follow the user instruction using only the supplied source text. Clearly distinguish what the text says from any inference. Use plain language and do not invent details.';
      case TextAiTaskType.tosSummary:
        return 'You are Tower Lens, a careful terms-of-service reading assistant. Summarize key obligations, concerning clauses, data collection and sharing, cancellation, refunds, dispute terms, and anything unusual using only the supplied source. Use plain language and end with: This is an informational summary only, not legal advice.';
    }
  }

  String _errorMessage(http.Response response) {
    switch (response.statusCode) {
      case 401:
      case 403:
        return 'The AI service rejected the configured credentials.';
      case 402:
        return 'The AI service account needs billing credits before this request can run.';
      case 429:
        final retryAfter = response.headers['retry-after'];
        return retryAfter == null
            ? 'The AI service is busy or rate-limited. Please wait and try again.'
            : 'The AI service is rate-limited. Try again in $retryAfter seconds.';
      default:
        if (response.statusCode >= 500) {
          return 'The AI service is temporarily unavailable. Please try again.';
        }
        return 'The AI service could not complete this request (HTTP ${response.statusCode}).';
    }
  }
}
